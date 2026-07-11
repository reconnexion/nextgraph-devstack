# Local NextGraph dev stack

Minimal setup for working on **ngd**, the **WASM engine**, the **app-side SDK**, and **third-party apps**. The public `https://nextgraph.net` is used as-is for the login trampoline (`/redir`) and the `ng_bootstrap` registry (which accepts `http://localhost:14400` brokers by design).

There is deliberately **no wallet-management app** (the one production nextgraph.eu serves at `/`): wallets are provisioned from the command line and imported through the wallet-unlock page.

| service | role | where |
|---------|------|-------|
| `ngd`   | broker (websocket + `/.ng_bootstrap`), pure Rust | http://localhost:14400 (the only localhost port the public nextgraph.net relay allows) |
| `auth`  | wallet-unlock page; the WASM engine runs here | http://localhost:14400/auth/ (ngd proxies to nginx on 14401) |
| `app`   | demo third-party app ([nextgraph-refine-app](https://github.com/reconnexion/nextgraph-refine-app)) | http://localhost:8080/nextgraph-refine-app/ |
| `provision` | helper: create an account + wallet file | `docker compose run` (not started by `up`) |

All NextGraph code builds from the `main` branch of the **local `./nextgraph-rs` submodule**.

## Run

See `make` for help.
But basically:

```
$ make build  ; after any change in the SDK
... wait ---
$ make up
$ make provision
... will provision the first admin using the invitation link found on the log,
... and export its wallet into ./wallets
$ sensible-browser 'http://localhost:14400/auth/#/wallet/login?o=http%3A%2F%2Flocalhost%3A8080%2Fnextgraph-refine-app%2F'
```

Then upload the wallet found in `./wallets` to log in (password: `secret`).

Create more users with:
```
$ make provision-more
```

Since the ngd data volume lives outside the docker instance, there is no need to run `make provision` again after a recompilation, and the wallet in your local storage is still valid.

Shall you want to restart from a clean state though, run `make reset` which will stop the service and delete the volumes.

## Testing another app

If you have any other app using Nextgraph's SDK, just open it directly. If it's calling the SDK as it should, and you have that `ng_bootstrap` properly set, then you will be properly redirected to your local broker.

## Notice

- ngd's embedded front-ends are stubs; with `NG_DEV3=1` every non-websocket, non-`/.ng_bootstrap` path is proxied to the auth service, so `localhost:14400/` shows the auth app's home. There is no wallet-management UI in this stack.

- The demo app's other `@ng-org/*` dependencies (orm, …) still come from npm; wire them like `@ng-org/web` in `docker/app.Dockerfile` if you need to hack on them.

- There is currently an issue with Nextgraph auth app, that will bounce to [the redir server](https://nextgraph.net) to register this broker as a source of wallets for the current user, using a popup. The browser will probably not allow this popup to open.  If it happens to you (you will know because your `ng_bootstrap` variable in your local storage for [https://nextgraph.net](https://nextgraph.net) will be absent) click on the **popup-blocked** icon in the right of the URL bar and click on the link. That will be enough to write `ng_bootstrap` permanently.

- Chrome will ask for **local network access** the first time: the app iframe is embedded by the public [https://nextgraph.net](https://nextgraph.net) page, which needs permission to reach [http://localhost:8080](http://localhost:8080) (or anything else on localhost). Allow it. For headless runs, pass `--disable-features=LocalNetworkAccessChecks`.
