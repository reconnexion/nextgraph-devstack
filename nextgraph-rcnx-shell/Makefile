.PHONY: all clean run check

TARGET ?= debug
ifdef NDEBUG
TARGET = release
endif

all: dist/index.html

clean:
	@$(RM) -r dist

pnpm-lock.yaml: package.json
	pnpm install &&\
	date > $@

# Type declarations of the linked @ng-org/* packages (see paths in
# tsconfig.app.json):
NG_JS = ../nextgraph-rs/sdk/js

ng_deps = \
  $(NG_JS)/$(1)/package.json \
  $(NG_JS)/$(1)/tsconfig.json \
  $(shell find $(NG_JS)/$(1)/src -type f)

NG_DTS = \
  $(NG_JS)/web/dist/index.d.ts \
  $(NG_JS)/orm/dist/core.d.ts \
  $(NG_JS)/shex-orm/dist/index.d.ts \
  $(NG_JS)/alien-deepsignals/dist/index.d.ts

NG_RS = ../nextgraph-rs

ifeq ($(TARGET),release)
WASM_PACK_FLAGS =
else
WASM_PACK_FLAGS = --dev
endif

# Same as lib-wasm's cargo run-scripts "app"/"appdev":
$(NG_JS)/lib-wasm/pkg/lib_wasm.d.ts: \
  $(NG_RS)/Cargo.lock \
  $(shell find $(NG_RS)/engine $(NG_RS)/sdk/rust $(NG_JS)/lib-wasm/src \
    -name target -prune -o -name node_modules -prune -o \
    \( -name '*.rs' -o -name Cargo.toml \) -print)
	cd $(NG_JS)/lib-wasm && \
	rm -rf pkg/snippets && \
	wasm-pack build $(WASM_PACK_FLAGS) --target bundler && \
	node prepare-web.js

$(NG_JS)/web/dist/index.d.ts: \
  $(call ng_deps,web) \
  $(NG_JS)/web/vite.config.ts \
  $(NG_JS)/lib-wasm/pkg/lib_wasm.d.ts
	cd $(NG_JS)/web && pnpm build

$(NG_JS)/shex-orm/dist/index.d.ts: \
  $(call ng_deps,shex-orm) \
  ../nextgraph-rs/tsconfig.base.json
	cd $(NG_JS)/shex-orm && pnpm build:ts

# tsc emits despite type errors (in tests and unused framework adapters), so
# fail only when nothing was emitted:
$(NG_JS)/orm/dist/core.d.ts \
$(NG_JS)/alien-deepsignals/dist/index.d.ts: \
$(NG_JS)/%.d.ts: \
  ../nextgraph-rs/tsconfig.base.json
	cd $(NG_JS)/$(firstword $(subst /, ,$*)) && \
	rm -rf dist && \
	{ pnpm build:ts || test -f ../$*.d.ts; }

$(NG_JS)/orm/dist/core.d.ts: $(call ng_deps,orm)
$(NG_JS)/alien-deepsignals/dist/index.d.ts: $(call ng_deps,alien-deepsignals)

# FIXME: too much noise therefore "|| true"
type_check.ok: \
  $(NG_DTS) \
  tsconfig.json \
  tsconfig.app.json \
  vite.config.ts \
  $(wildcard src/*.ts) \
  $(wildcard src/*.svelte) \
  $(wildcard src/lib/*.svelte)
	pnpm exec svelte-check --tsconfig ./tsconfig.app.json || true
	date > $@

dist/index.html: \
  pnpm-lock.yaml \
  type_check.ok
	pnpm exec vite build

# Note: node listens only to IPv6 by default, can't listen to both, so here we
# pick the lesser evil:
run: dist/index.html
	pnpm exec vite preview --host 127.0.0.1
