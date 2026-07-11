# syntax=docker/dockerfile:1
# The demo third-party web app (nextgraph-refine-app), served on http://localhost:8080
#
# Build contexts (see docker-compose.yml):
#   main context: repository root (for nextgraph-refine-app/)
#   ngrepo:       the local ./nextgraph-rs checkout -- the app-side SDK
#                 (@ng-org/web) is built from it and replaces the published
#                 npm dist, so SDK changes flow into the app.

# ---- build @ng-org/web from the local nextgraph-rs checkout -------------
# The runtime bundle of @ng-org/web does not contain the WASM engine (that
# runs in the broker's auth page); its build only needs @ng-org/lib-wasm for
# TypeScript types, so a type stub replaces the real wasm-pack output.
FROM node:22-alpine AS sdk-build
RUN npm install -g pnpm@10.15.0
WORKDIR /ws
COPY --from=ngrepo sdk/js/web sdk/js/web
RUN rm -rf sdk/js/web/node_modules sdk/js/web/dist \
    && printf 'packages:\n  - sdk/js/lib-wasm/pkg\n  - sdk/js/web\n' > pnpm-workspace.yaml \
    && printf '{"name":"ng-local","private":true}\n' > package.json \
    && mkdir -p sdk/js/lib-wasm/pkg \
    && printf '{"name":"@ng-org/lib-wasm","version":"0.1.2","main":"lib_wasm.js","types":"lib_wasm.d.ts"}\n' > sdk/js/lib-wasm/pkg/package.json \
    && printf 'export {};\n' > sdk/js/lib-wasm/pkg/lib_wasm.d.ts \
    && touch sdk/js/lib-wasm/pkg/lib_wasm.js
RUN pnpm install && pnpm -C sdk/js/web build

# ---- build the app ------------------------------------------------------
FROM node:22-alpine AS build
WORKDIR /app
COPY nextgraph-refine-app/package.json nextgraph-refine-app/package-lock.json ./
RUN npm ci
# use the locally built app-side SDK instead of the published dist
COPY --from=sdk-build /ws/sdk/js/web/dist node_modules/@ng-org/web/dist
COPY nextgraph-refine-app/ .
RUN npm run build

# The app's vite config sets base=/nextgraph-refine-app/ for production
# builds (it is deployed on GitHub Pages), so serve it under that path.
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html/nextgraph-refine-app
COPY <<'EOF' /etc/nginx/conf.d/default.conf
server {
    listen 8080;
    root /usr/share/nginx/html;
    location = / {
        return 302 /nextgraph-refine-app/;
    }
    location /nextgraph-refine-app/ {
        try_files $uri /nextgraph-refine-app/index.html;
    }
}
EOF
