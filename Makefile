.PHONY: build up down reset provision provision-more push ngcli-run
PROJECT = ng-dev
COMPOSE = docker compose -p $(PROJECT)
DOCKER_REGISTRY ?= ghcr.io/reconnexion

all: help

help:
	@echo 'Targets:'
	@echo '  - help: This'
	@echo
	@echo '  - build: Build all docker images.'
	@echo '  - pull: alternatively, pull images from $(DOCKER_REGISTRY).'
	@echo '  - up: Start (or update) the docker compose stack (project name: ng-dev)'
	@echo '  - down: Stop the docker compose stack'
	@echo '  - reset: Stop the docker compose stack and delete the volumes'
	@echo '           (to restart from a clean state)'
	@echo '  - provision: Provision the first admin user (using the initial'
	@echo '               invitation link)'
	@echo '  - provision-more: Provision one more random user.'
	@echo '  - ngcli-run CMD='\''wtv'\'': Run this command with ngd'\'s' container ngcli'

# Build one after another to not summon the OOM killer:
build:
	$(COMPOSE) build --progress=plain ngd
	$(COMPOSE) build --progress=plain provision
	$(COMPOSE) build --progress=plain auth
	$(COMPOSE) build --progress=plain app

pull:
	$(COMPOSE) pull

up:
	$(COMPOSE) up --detach

APP_SITE=http://localhost:8080/
provision:
	@NG_INVITE=$$($(COMPOSE) logs ngd | grep -o 'http://localhost:14400/#/i/[A-Za-z0-9_-]*' | tail -1); \
	if test -n "$$NG_INVITE"; then \
	  $(COMPOSE) run --rm -e NG_USER=user5 -e NG_PASS=secret -e NG_INVITE="$$NG_INVITE" provision '$(APP_SITE)'; \
	else \
	  echo Cannot read NG_INVITE; \
	fi

provision-more:
	NG_USER=user-$$(od -An -N4 -tx4 /dev/urandom | tr -d ' \n'); \
	$(COMPOSE) run --rm -e "NG_USER=$$NG_USER" -e NG_PASS=secret provision

down:
	$(COMPOSE) down

reset:
	$(COMPOSE) down -v

push:
	@for img_suf in ngd auth app provision; do \
	  img="ng-dev-$$img_suf"; \
	  docker image push "$(DOCKER_REGISTRY)/$$img" ;\
	done

CMD ?= admin list-users -a

ngcli-run:
	docker exec -t ng-dev-ngd-1 ngcli --base /data $(CMD)
