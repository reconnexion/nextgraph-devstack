# syntax=docker/dockerfile:1
# The wallet-unlock ("auth") page of the local broker, built from the LOCAL
# ./nextgraph-rs checkout (the build context) and served by nginx on
# localhost:14401. ngd (running with NG_DEV3=1) reverse-proxies its
# non-websocket paths here, so in the browser this page lives on the broker
# origin http://localhost:14400 -- where the wallets are kept in
# localStorage.
#
# This page contains the WASM engine (sdk/js/lib-wasm): wallets are opened
# and sessions run here. When working on the engine/worker, this is the
# image to rebuild.
#
# Built with default (production) settings: it embeds the auth relay iframe
# from the real https://nextgraph.net/auth/, whose origin allowlist accepts
# http://localhost:14400 by design.

FROM rust:1 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        clang libclang-dev pkg-config libssl-dev git curl ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g pnpm@10.15.0

# NextGraph requires its own fork of wasm-pack (see DEV.md)
RUN cargo install wasm-pack --git https://git.nextgraph.org/NextGraph/wasm-pack.git --branch master --locked

ENV WEBPACK_PARALLELISM=1
ENV NODE_OPTIONS="--max-old-space-size=3000"
ENV npm_config_store_dir=/pnpm-store

WORKDIR /ng
COPY . .
RUN rm -rf .cargo

# Fix (skipped if your branch already has it): gate API calls on the WASM
# worker being ready. Upstream posts RPC messages to the worker immediately;
# the worker only installs its onmessage handler after the async WASM
# import, so a call made too early can be silently dropped and the page
# hangs on its splash screen.
RUN if grep -q 'function call_sdk(method:string, args?: any) {' sdk/js/api-web/main.ts; then \
        sed -i 's|function call_sdk(method:string, args?: any) {|async function call_sdk(method:string, args?: any) {\n    await worker_ready;|' sdk/js/api-web/main.ts \
        && grep -q 'await worker_ready;' sdk/js/api-web/main.ts; \
    fi

# The WASM engine (profiling flavor, same as upstream's dev3 scripts)
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,id=auth-target,target=/ng/target \
    cd sdk/js/lib-wasm && wasm-pack build --dev --target bundler && node prepare-web.js

RUN --mount=type=cache,target=/pnpm-store pnpm install

# Plain `vite build` instead of the package's `build` script: the latter
# gzips/deletes files to prepare them for embedding into ngd, which is wrong
# for a static server.
RUN cd engine/broker/auth && pnpm exec vite build --base=./

FROM nginx:alpine
COPY --from=builder /ng/engine/broker/auth/dist /usr/share/nginx/html
COPY <<'EOF' /etc/nginx/conf.d/default.conf
server {
    listen 14401;
    root /usr/share/nginx/html;
    location / {
        try_files $uri /index.html;
    }
}
EOF
