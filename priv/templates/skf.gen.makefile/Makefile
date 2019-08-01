.PHONY: \
	dev \
	test \
	test_ci \
	compile \
	capture-backup \
	latest.dump \
	import-latest-db \
	seed-db reset-db \
	reseed-db set-remotes \
	devstack \
	devstack-build \
	devstack-clean \
	devstack-shell \
	devstack-run

DEFAULT_GOAL: help

<%= if cloud == "heroku" do %>
DEVELOPMENT?=https://git.heroku.com/<%= app %>_backend-develop.git
STAGING?=https://git.heroku.com/<%= app %>_backend-stage.git
PRODUCTION?=https://git.heroku.com/<%= app %>_backend-prod.git
<% end %>

PGDATABASE?=<%= app %>_backend_dev

export LOCAL_USER_ID ?= $(shell id -u $$USER)

# ============= #
# POOR MANS CLI #
# ============= #

require-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "ERROR: Environment variable not set: \"$*\""; \
		exit 1; \
	fi

dev:
	@MIX_ENV=dev mix ecto.setup && iex -S mix phx.server 

heroku-console:
	@MIX_ENV=dev heroku run "iex -S mix" --remote develop
	
heroku-logs:
	@MIX_ENV=dev heroku logs --tail --remote develop

test:
	@MIX_ENV=test mix test

compile:
	@mix do deps.get, compile

capture-backup: require-REMOTE
	heroku pg:backups:capture --remote ${REMOTE}

latest.dump: require-REMOTE
	heroku pg:backups:download --remote ${REMOTE}

import-latest-db: require-PGDATABASE latest.dump
	dropdb --if-exists ${PGDATABASE} && \
	createdb ${PGDATABASE} && \
	pg_restore --verbose --clean --no-acl --no-owner --dbname=${PGDATABASE} latest.dump

reset-db:
	mix do ecto.reset

seed-db:
	mix seed

reseed-db: reset-db seed-db

set-remotes: require-DEVELOPMENT require-STAGING require-PRODUCTION
	@git remote rm development || true
	@git remote rm staging || true
	@git remote rm production || true
	git remote add development ${DEVELOPMENT}
	git remote add staging ${STAGING}
	git remote add production ${PRODUCTION}


# -----------------------
# --- DOCKER DEVSTACK ---
# -----------------------

## Builds the development Docker image
devstack-build:
	@docker-compose build

## Stops all development containers
devstack-clean:
	@docker-compose down -v

## Starts all development containers in the foreground
devstack: devstack-build
	@docker-compose up

## Spawns an interactive Bash shell in development web container
devstack-shell:
	@docker exec -e COLUMNS="`tput cols`" -e LINES="`tput lines`" -u ${LOCAL_USER_ID} -it $$(docker-compose ps -q web) /bin/bash -c "reset -w && /bin/bash"

## Starts the development server inside docker
devstack-run:
	@docker-compose up -d &&\
		docker-compose exec web mix deps.get && \
		docker-compose exec web mix ecto.setup && \
		docker-compose exec web iex -S mix phx.server

## Git push code to heroku
heroku-deploy: require-CIRCLE_BRANCH require-HEROKU_API_KEY require-HEROKU_APP_NAME
	@git push --force https://heroku:${HEROKU_API_KEY}@git.heroku.com/${HEROKU_APP_NAME}.git ${CIRCLE_BRANCH}:master

#
# HELP
#

## Shows the help menu
help:
	@echo "Please use \`make <target>' where <target> is one of\n\n"
	@awk '/^[a-zA-Z\-\_\/0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "%-30s %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)
