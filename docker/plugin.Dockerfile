# syntax=docker/dockerfile:1
# The demo service plugin: registers itself as "demo-plugin" to the local ngd
# (127.0.0.1:14400, so to be run with network_mode: host).
#
# Built from the LOCAL ./nextgraph-rs checkout (for the node SDK
# @ng-org/nextgraph) and ./service-plugin-demo; see docker-compose.yml.
#
# Environment:
#   PLUGIN_PRIVKEY  the plugin's peer private key (from `ngcli gen-key`)
#   NGD_PEER_ID     ngd's peer-id; read from ngd at startup if unset

# ---- build @ng-org/nextgraph (lib-wasm for nodejs) ----------------------
# Same as the WASM engine build in docker/auth.Dockerfile, with which it
# shares its cargo target cache.
FROM rust:1 AS sdk-build

RUN apt-get update && apt-get install -y --no-install-recommends \
        clang libclang-dev pkg-config libssl-dev git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# For prepare-node.js only:
COPY --from=node:22-trixie-slim /usr/local/bin/node /usr/local/bin/node

# git.nextgraph.org is unreliable: fetch its repos from the GitHub backups
# instead. Cargo.lock is unaffected (same source URLs and revisions); cargo
# must use the git CLI for the rewrite to apply.
COPY <<'EOF' /etc/gitconfig
[url "https://github.com/reconnexion/"]
	insteadOf = https://git.nextgraph.org/NextGraph/
	insteadOf = https://git.nextgraph.org/rixed/
EOF
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true

# NextGraph requires its own fork of wasm-pack (see DEV.md)
RUN cargo install wasm-pack --git https://git.nextgraph.org/NextGraph/wasm-pack.git --branch master --locked

WORKDIR /ng
COPY nextgraph-rs .
RUN rm -rf .cargo

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,id=auth-target,target=/ng/target \
    cd sdk/js/lib-wasm && wasm-pack build --dev -t nodejs -d pkg-node && node prepare-node.js

# ---- compile the plugin -------------------------------------------------
# Same relative layout as on the host, so that the
# link:../nextgraph-rs/... dependency resolves unchanged.
FROM node:22-trixie-slim AS build
COPY --from=sdk-build /ng/sdk/js/lib-wasm/pkg-node /ws/nextgraph-rs/sdk/js/lib-wasm/pkg-node
WORKDIR /ws/service-plugin-demo
COPY service-plugin-demo/package.json service-plugin-demo/yarn.lock ./
RUN yarn install --frozen-lockfile
COPY service-plugin-demo/tsconfig.json ./
COPY service-plugin-demo/src src
RUN yarn tsc

# ---- runtime -------------------------------------------------------------
FROM node:22-trixie-slim
COPY --from=sdk-build /ng/sdk/js/lib-wasm/pkg-node /ws/nextgraph-rs/sdk/js/lib-wasm/pkg-node
WORKDIR /ws/service-plugin-demo
COPY service-plugin-demo/package.json service-plugin-demo/yarn.lock ./
RUN yarn install --frozen-lockfile --production && yarn cache clean
COPY --from=build /ws/service-plugin-demo/dist dist
COPY service-plugin-demo/ngd-peer-id.mjs ./
COPY --chmod=755 <<'EOF' /usr/local/bin/entrypoint.sh
#!/bin/sh
set -e
if [ -z "$NGD_PEER_ID" ]; then
  NGD_PEER_ID=$(node ngd-peer-id.mjs)
  export NGD_PEER_ID
fi
exec node dist/main.js
EOF
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
