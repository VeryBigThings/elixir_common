<%=
  common_targets =
	  """
		.PHONY: ~w/dev test compile seed-db reset-db reseed-db
		"""

	devstack_targets =
	  if docker do
		  """
			# devstack
			.PHONY: devstack devstack-build devstack-clean devstack-shell devstack-run
			"""
		end

	heroku_targets =
		if cloud == "heroku" do
		  """
			# heroku
			.PHONY: set-remote heroku-console heroku-capture-backup heroku-latest.dump import-latest-db \\
							heroku/login heroku/build-web heroku/build-release heroku/push-web heroku/push-release \\
							heroku/build-and-push heroku/release
			"""
		end

	[common_targets, heroku_targets, devstack_targets]
	|> Stream.reject(&is_nil/1)
	|> Enum.join("\n")
%>
DEFAULT_GOAL: help

# TODO read database name from Mix.Config
PGDATABASE?=<%= app %>_backend_dev


export LOCAL_USER_ID ?= $(shell id -u $$USER)
export DOCKER_BUILDKIT=1

# -------------------
# --- DEFINITIONS ---
# -------------------

require-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "ERROR: Environment variable not set: \"$*\""; \
		exit 1; \
	fi

# -----------------
# --- MIX TASKS ---
# -----------------

dev:
	mix ecto.setup && iex -S mix phx.server

test:
	mix test

compile:
	@mix do deps.get, compile

reset-db:
	@mix do ecto.reset

seed-db:
	@mix seed

reseed-db: reset-db seed-db

<%= if cloud && cloud == "heroku" do %>
# --------------
# --- HEROKU ---
#  -------------

DEVELOPMENT?=https://git.heroku.com/<%= app %>_backend-develop.git
STAGING?=https://git.heroku.com/<%= app %>_backend-stage.git
PRODUCTION?=https://git.heroku.com/<%= app %>_backend-prod.git

## Set Heroku remotes
set-remotes: require-DEVELOPMENT require-STAGING require-PRODUCTION
	@git remote rm development || true && git remote add development ${DEVELOPMENT}
	@git remote rm staging || true && git remote add staging ${STAGING}
	@git remote rm production || true && git remote add production ${PRODUCTION}


## Attach to IEx console on Heroku {REMOTE}
heroku-console: require-REMOTE
	heroku run "iex -S mix" --remote ${REMOTE}

## Show (and tail) Heroku logs from given {REMOTE}
heroku-logs: require-REMOTE
	heroku logs --tail --remote ${REMOTE}

## Backup database on given Heroku {REMOTE}
heroku-capture-backup: require-REMOTE
	heroku pg:backups:capture --remote ${REMOTE}

## Pull latest database backup from Heroku {REMOTE}
heroku-latest.dump: require-REMOTE
	heroku pg:backups:download --remote ${REMOTE}

import-latest-db: require-PGDATABASE heroku-latest.dump
	dropdb --if-exists ${PGDATABASE} && \
	createdb ${PGDATABASE} && \
	pg_restore --verbose --clean --no-acl --no-owner --dbname=${PGDATABASE} heroku-latest.dump

# -------------------------------
# --- DOCKER HEROKU PRODSTACK ---
# -------------------------------

APP_NAME?=`grep 'app:' mix.exs | sed -e 's/\[//g' -e 's/ //g' -e 's/app://' -e 's/[:,]//g'`
HEROKU_REGISTRY=registry.heroku.com

## Logs in to heroku container registry
heroku/login: require-HEROKU_API_KEY require-HEROKU_REGISTRY
	@docker login --username=_ --password=$(HEROKU_API_KEY) $(HEROKU_REGISTRY)

## Builds the production Docker web image
heroku/build-web: require-APP_NAME require-HEROKU_REGISTRY require-HEROKU_APP_NAME
	@docker build --ssh default .\
		--target release \
		--build-arg MIX_ENV=prod \
		--build-arg APP_NAME=${APP_NAME} \
		--tag ${HEROKU_REGISTRY}/${HEROKU_APP_NAME}/web

## Builds the production Docker release phase image
heroku/build-release: require-HEROKU_REGISTRY require-HEROKU_APP_NAME
	@docker build --ssh default .\
		--target release-phase \
		--build-arg MIX_ENV=prod \
		--build-arg APP_NAME=${APP_NAME} \
		--tag ${HEROKU_REGISTRY}/${HEROKU_APP_NAME}/release

## Push heroku web image to container registry
heroku/push-web: require-HEROKU_APP_NAME require-HEROKU_REGISTRY
	@docker push ${HEROKU_REGISTRY}/${HEROKU_APP_NAME}/web

## Push heroku release phase image to container registry
heroku/push-release: require-HEROKU_APP_NAME require-HEROKU_REGISTRY
	@docker push ${HEROKU_REGISTRY}/${HEROKU_APP_NAME}/release

## Builds production images and pushes them to heroku container registry
heroku/build-and-push: heroku/login heroku/build-web heroku/build-release heroku/push-web heroku/push-release

## Creates a new release on heroku
heroku/release: require-HEROKU_APP_NAME require-HEROKU_API_KEY
	@HEROKU_API_KEY=$(HEROKU_API_KEY) heroku container:release web release -a $(HEROKU_APP_NAME)
<% end %>

<%= if docker do %>
# -----------------------
# --- DOCKER DEVSTACK ---
# -----------------------

## Builds the development Docker image
devstack-build:
	@docker build --ssh default .\
		--target build \
		--build-arg MIX_ENV=dev \
		--tag <%= app %>:latest

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
devstack-run: devstack-build
	@docker-compose up -d &&\
		docker-compose exec web mix deps.get && \
		docker-compose exec web mix ecto.setup && \
		docker-compose exec web iex -S mix phx.server
<% end %>

# ------------
# --- HELP ---
# ------------

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
