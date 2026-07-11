use std::fs::{create_dir_all, File};
use std::io::Write;
use std::net::IpAddr;
use std::time::Duration;

use serde::Serialize;

use nextgraph::local_broker::{
    init_local_broker, user_connect, wallet_create_v0, wallet_open_with_password, LocalBrokerConfig,
};
use nextgraph::net::types::{Invitation, LocalBootstrapInfo};
use nextgraph::net::utils::retrieve_ng_bootstrap;
use nextgraph::repo::types::{PrivKey, PubKey};
use nextgraph::wallet::types::CreateWalletV0;

// mirror of ngcli's on-disk config (bin/ngcli/src/main.rs). serde produces the
// exact JSON ngcli reads back: {"V0":{"ip":"..","port":..,"peer_id":{"Ed25519PubKey":[..]},"user":{"Ed25519PrivKey":[..]}}}
#[derive(Serialize)]
struct CliConfigV0 {
    ip: IpAddr,
    port: u16,
    peer_id: PubKey,
    user: Option<PrivKey>,
}
#[derive(Serialize)]
enum CliConfig {
    V0(CliConfigV0),
}

// like JS encodeURIComponent: percent-encode everything except the unreserved set
fn encode_uri_component(s: &str) -> String {
    let mut out = String::with_capacity(s.len() * 3);
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9'
            | b'-' | b'_' | b'.' | b'!' | b'~' | b'*' | b'\'' | b'(' | b')' => out.push(b as char),
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}

#[async_std::main]
async fn main() {
    let username = std::env::var("NG_USER").unwrap_or("user1".to_string());
    let password = std::env::var("NG_PASS").unwrap_or("secret".to_string());
    let broker_url =
        std::env::var("NG_BROKER_URL").unwrap_or("http://localhost:14400".to_string());
    let out_dir = std::env::var("NG_OUT_DIR").unwrap_or("/wallets".to_string());
    // app URL to redirect to: first CLI arg, else NG_APP_URL, else the demo app
    let app_url = std::env::args()
        .nth(1)
        .or_else(|| std::env::var("NG_APP_URL").ok())
        .unwrap_or("http://localhost:8080/nextgraph-refine-app/".to_string());

    // The FIRST account on a fresh broker must present the setup invitation
    // that ngd prints in its logs at first start (registration without a
    // code even crashes the connection task server-side on a userless
    // broker). Later accounts need no code (--registration-open) and stale
    // codes are rejected, so only pass NG_INVITE for the first user.
    let core_registration = std::env::var("NG_INVITE").ok().map(|s| {
        // accept the raw invitation string or a full .../#/i/<string> link
        let raw = s.rsplit("/i/").next().unwrap_or(&s).trim().to_string();
        let Invitation::V0(v0) =
            Invitation::try_from(raw).expect("invalid NG_INVITE invitation string");
        *v0.code.expect("NG_INVITE invitation carries no code").slice()
    });

    // retrieve_ng_bootstrap uses reqwest and needs a tokio reactor, while
    // the local_broker APIs run on async-std; give it its own runtime
    let info = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap()
        .block_on(retrieve_ng_bootstrap(&broker_url))
        .expect("cannot fetch /.ng_bootstrap from the broker; is ngd up?");
    let LocalBootstrapInfo::V0(info) = info;

    init_local_broker(Box::new(|| LocalBrokerConfig::InMemory)).await;

    let res = wallet_create_v0(CreateWalletV0 {
        security_img: None,
        security_txt: username.clone(),
        pin: None,
        pazzle_length: 0,
        password: Some(password.clone()),
        mnemonic: false,
        send_bootstrap: false,
        send_wallet: false,
        result_with_wallet_file: true,
        local_save: false,
        core_bootstrap: info.bootstrap.clone(),
        core_registration,
        additional_bootstrap: None,
        pdf: false,
        device_name: "provision".to_string(),
    })
    .await
    .expect("wallet_create_v0 failed");

    // connect once so the broker registers the account server-side
    let status = async_std::future::timeout(Duration::from_secs(30), user_connect(&res.user))
        .await
        .expect(
            "user_connect timed out. On a FRESH broker the first account needs the setup \
             invitation: re-run with NG_INVITE taken from `docker compose logs ngd` \
             (the http://localhost:14400/#/i/... link).",
        )
        .expect("user_connect failed");
    println!("connection status: {:?}", status);
    for (user, server, _, error, _) in &status {
        if let Some(e) = error {
            panic!("connection/registration of {} to {} failed: {}", user, server, e);
        }
    }
    if status.is_empty() {
        panic!("no connection was attempted; wallet has no broker?");
    }

    create_dir_all(&out_dir).ok();
    let path = format!("{}/{}.ngw", out_dir, username);
    let mut f = File::create(&path).expect("create wallet file");
    f.write_all(&res.wallet_file).expect("write wallet file");

    // For the first user (registered with a setup invitation, i.e. an admin) --
    // or on demand via NG_WRITE_CLI_CONFIG=1 -- also drop an ngcli config into
    // <NG_CLI_DIR> (default /data/client, the ngd volume) so
    // `docker exec ngd ngcli admin ...` needs no key/-s/-u.
    let write_cli = core_registration.is_some()
        || std::env::var("NG_WRITE_CLI_CONFIG")
            .map(|v| v == "1" || v == "true")
            .unwrap_or(false);
    if write_cli {
        let cli_dir = std::env::var("NG_CLI_DIR").unwrap_or("/data/client".to_string());
        // ip ngcli (running inside the ngd container) uses to reach ngd.
        // host networking => 127.0.0.1; override with NG_CLI_IP otherwise.
        let ip: IpAddr = std::env::var("NG_CLI_IP")
            .unwrap_or("127.0.0.1".to_string())
            .parse()
            .expect("invalid NG_CLI_IP");
        let port: u16 = broker_url
            .rsplit(':')
            .next()
            .and_then(|p| p.parse().ok())
            .unwrap_or(14400);
        let peer_id = info
            .bootstrap
            .servers
            .get(0)
            .expect("broker bootstrap has no server")
            .peer_id;
        // the user's private key lives in the (encrypted) wallet we just made
        let opened = wallet_open_with_password(&res.wallet, password.clone())
            .expect("re-open wallet for user key");
        let user_priv = opened
            .individual_site(&res.user)
            .expect("wallet has no individual site for this user")
            .0;
        // ngcli's own connection identity; a fresh key is fine (ngcli would
        // otherwise generate an ephemeral one each run)
        let client_key = PrivKey::random_ed();

        create_dir_all(&cli_dir).ok();
        File::create(format!("{}/key", cli_dir))
            .expect("create ngcli key file")
            .write_all(client_key.to_string().as_bytes()) // no trailing newline
            .expect("write ngcli key file");
        let cfg = CliConfig::V0(CliConfigV0 {
            ip,
            port,
            peer_id,
            user: Some(user_priv),
        });
        File::create(format!("{}/config.json", cli_dir))
            .expect("create ngcli config.json")
            .write_all(serde_json::to_string_pretty(&cfg).unwrap().as_bytes())
            .expect("write ngcli config.json");
        println!("ngcli config written to {} (key + config.json)", cli_dir);
    }

    println!("=========================================================");
    println!("wallet written to {}", path);
    println!("user id: {}", res.user);
    println!("To use it, import the file once per browser (password: {}) at:", password);
    println!(
        "http://localhost:14400/auth/#/wallet/login?o={}",
        encode_uri_component(&app_url)
    );
}
