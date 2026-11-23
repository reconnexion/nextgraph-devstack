YARN=.yarn/releases/yarn-1.22.22.cjs

.PHONY: build run clean

SOURCES = \
	utils.ts \
	types.ts \
	handler.ts \
	main.ts

JS_FILES = $(addprefix dist/, $(SOURCES:.ts=.js))

all: build

$(YARN):
	npx yarn@1.22.22 policies set-version 1.22.22

package.json: $(YARN)
	$(YARN) init -y
	jq 'del(.main)' $@ > $@.tmp && mv -f $@.tmp $@

node_modules/tsx/package.json: $(YARN) package.json
	$(YARN) add -D typescript @types/node tsx
	$(YARN) add @ng-org/nextgraph
	@touch $@

$(JS_FILES) &: $(addprefix src/, $(SOURCES)) $(YARN)
	$(YARN) tsc

build: $(JS_FILES)

# Not the key of the docker-compose plugin-demo, so that both can run at once:
PLUGIN_PRIVKEY ?= foSaUx9WBoNhu0JjlcqPDgEdFsZy5nDA_bPZqdnt7mkA

# Note: ngd should write this peed-id in some world-readable file
run: $(JS_FILES)
	NGD_PEER_ID=$$(docker logs ng-dev-ngd-1 2>&1 | head -9 | sed -ne 's/^.*PeerId of node: \(.*\)$$/\1/p') \
	PLUGIN_PRIVKEY=$(PLUGIN_PRIVKEY) \
	node dist/main.js

clean:
	$(RM) $(JS_FILES)
