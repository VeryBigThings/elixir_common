# syntax=docker/dockerfile:experimental

# ===========================================================
# === BUILD STAGE - Development image with necessary deps ===
# ===========================================================
# Used for development purposes and as a base for pre-release

FROM verybigthings/elixir:1.9.4 AS build

ARG WORKDIR=/opt/app
ARG MIX_ENV=prod
ARG APP_USER=user

ENV MIX_ENV=${MIX_ENV}
ENV WORKDIR=$WORKDIR
ENV APP_USER=$APP_USER
ENV CACHE_DIR=/opt/cache
ENV MIX_HOME=$CACHE_DIR/mix
ENV HEX_HOME=$CACHE_DIR/hex
ENV BUILD_PATH=$CACHE_DIR/_build
ENV REBAR_CACHE_DIR=$CACHE_DIR/rebar

RUN apt-get update && apt-get install -y \
  bash \
  git \
  inotify-tools \
  less \
  locales \
  make \
  postgresql-client \
  postgresql-contrib \
  redis-tools \
  vim

WORKDIR $WORKDIR

ENV PHOENIX_VERSION 1.4.6

RUN mix local.hex --force && \
  mix local.rebar --force

RUN mix archive.install hex phx_new $PHOENIX_VERSION --force

RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan github.com > ~/.ssh/known_hosts

# Set entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash", "-c", "while true; do sleep 10; done;"]

# =========================
# === PRE-RELEASE STAGE ===
# =========================
# Compiles application code and bundles the application to Erlang/OTP release

FROM build AS pre-release

ARG APP_NAME

# Set SKIP_ASSETS to true (in your Makefile) if your Phoenix project does not have static assets
ARG SKIP_ASSETS=false

ENV APP_NAME=${APP_NAME} \
  SKIP_ASSETS=${SKIP_ASSETS}

COPY . .

# Fetch and compile deps and compile app code
RUN --mount=type=ssh mix do deps.get, deps.compile, compile

# Build the OTP release
RUN mix release

############################################
## RELEASE STAGE - production application ##
############################################
# Minimal (debian-slim) image for production purposes
# Copies the bundle from pre-release image

FROM debian:10-slim AS release

ARG APP_NAME
ARG APP_USER=user
ARG WORKDIR=/opt/app

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV WORKDIR=$WORKDIR
ENV APP_USER=$APP_USER

RUN apt-get update && apt-get install -y \
  bash \
  git \
  libpq-dev \
  libjson-c-dev

ENV APP_NAME=${APP_NAME}
# Copy over the build artifact from the previous step and create a non root user
RUN useradd --create-home ${APP_USER}
WORKDIR $WORKDIR

COPY --from=pre-release /opt/cache/_build/prod/rel/${APP_NAME} .

RUN chown -R ${APP_USER}: ${WORKDIR}
USER ${APP_USER}

CMD trap 'exit' INT; ${WORKDIR}/bin/${APP_NAME} start


#############################################################################################
## RELEASE PHASE - check config and run migrations on Heroku before production application ##
#############################################################################################
FROM release AS release-phase

CMD trap 'exit' INT; \
  /opt/app/<%= Mix.Vbt.otp_app() %>/bin/check_config.sh && \
  /opt/app/<%= Mix.Vbt.otp_app() %>/bin/migrate.sh
