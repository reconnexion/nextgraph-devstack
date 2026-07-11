# syntax=docker/dockerfile:1
# NextGraph broker (ngd), built from the LOCAL ./nextgraph-rs checkout (the
# build context, see docker-compose.yml). Pure Rust image.
#
# ngd listens on localhost:14400 (websocket + /.ng_bootstrap). It runs with
# NG_DEV3=1, which makes it reverse-proxy every other path to
# http://localhost:14401 -- the auth service (wallet-unlock page). The
# wallet-management app ngd would normally embed is deliberately stubbed:
# login, wallet import, and the trampoline all go through the auth page, and
# the public https://nextgraph.net handles redir + the ng_bootstrap registry.
#
# Port 14400 is load-bearing: it is the only localhost broker port the
# public nextgraph.net auth relay accepts (`?o=http://localhost:14400`).
#
# Targets:
#   ngd        (default runtime)
#   provision  one-shot helper that creates a user on the broker and writes
#              a wallet file; see docker-compose.yml `provision` service.

FROM rust:1 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        clang libclang-dev pkg-config libssl-dev git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY nextgraph-rs /ng/nextgraph-rs/
COPY async-tungstenite /ng/async-tungstenite/
COPY rust-rocksdb /ng/rust-rocksdb/

WORKDIR /ng/nextgraph-rs
COPY docker/cargo.config.toml .cargo/config.toml

# Stub front-end embeds: rust-embed needs the folders to exist at compile
# time, and ngd unwraps index(.html).gzip if a browser reaches it without
# NG_DEV3. The dir list covers both the main and refactor-app layouts.
RUN printf '<html><body>This ngd does not serve the web app (see docker/README.md).</body></html>' > /tmp/stub.html \
    && for d in app/shell/dist-web app/nextgraph/dist-web engine/broker/auth/dist; do \
        mkdir -p $d; \
        [ -f $d/index.gzip ] || gzip -c /tmp/stub.html > $d/index.gzip; \
        [ -f $d/index.html.gzip ] || gzip -c /tmp/stub.html > $d/index.html.gzip; \
        [ -f $d/index.sha256 ] || sha256sum /tmp/stub.html | cut -d' ' -f1 | tr -d '\n' > $d/index.sha256; \
    done

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,id=ngd-target,target=/ng/nextgraph-rs/target \
    cargo build -p ngd -p ngcli \
    && cp target/debug/ngd target/debug/ngcli /

# ---- provision helper ----------------------------------------------------
# Creates a password wallet bound to the running broker, connects once so
# the broker (--registration-open) registers the account, and writes the
# .ngw wallet file to /wallets. The wallet is then imported in the browser
# via the auth page ("Import a Wallet File"), which also records the local
# broker in the public nextgraph.net ng_bootstrap registry.
FROM builder AS provision-builder

COPY <<'EOF' /provision/Cargo.toml
[package]
name = "ng-provision"
version = "0.1.0"
edition = "2021"

[dependencies]
nextgraph = { path = "/ng/nextgraph-rs/sdk/rust" }
async-std = { version = "1.12.0", features = ["attributes", "unstable"] }
tokio = { version = "1", features = ["rt", "net", "time"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

[workspace]
EOF

COPY docker/provision.rs /provision/src/main.rs

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,id=ngd-target,target=/ng/nextgtraph-rs/target \
    --mount=type=cache,id=provision-target,target=/provision/target \
    cargo build --manifest-path /provision/Cargo.toml \
    && cp /provision/target/debug/ng-provision /ng-provision

FROM debian:trixie-slim AS provision
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libssl3t64 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=provision-builder /ng-provision /usr/local/bin/ng-provision
ENV RUST_LOG=info
ENV RUST_BACKTRACE=1
# The app URL to embed in the printed login link can be passed as the first
# argument (else NG_APP_URL env, else the bundled demo app):
#   docker compose run --rm provision https://my-other-app.example/
ENTRYPOINT ["ng-provision"]

# ---- ngd runtime (default target) ----------------------------------------
FROM debian:trixie-slim AS ngd
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates libssl3t64 tini \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /ngd /ngcli /usr/local/bin/
ENV RUST_LOG=debug
ENV RUST_BACKTRACE=1
VOLUME /data
ENTRYPOINT ["/usr/bin/tini", "--"]
# --registration-open : the provision helper (and anyone local) can create accounts
CMD ["ngd", "--base", "/data", "--save-key", "-l", "14400", "--registration-open", "-v"]
