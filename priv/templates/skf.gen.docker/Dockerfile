# syntax=docker/dockerfile:experimental

# ===========================================================
# === BUILD STAGE - Development image with necessary deps ===
# ===========================================================
# Used for development purposes and as a base for pre-release

FROM verybigthings/elixir:1.10.2 AS build

ARG WORKDIR=/opt/app
ARG APP_USER=user

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

# Set SKIP_ASSETS to true (in your Makefile) if your Phoenix project does not have static assets
ARG SKIP_ASSETS=false

ENV SKIP_ASSETS=${SKIP_ASSETS}

# First we're copying the minimal subset of the app needed to fetch and build the deps. This
# allows us to use the cached docker layer in the cases where only the regular code is changed,
# which means we avoid about extra 4 minutes during the docker build.
COPY mix.exs mix.lock ./
COPY config .
RUN --mount=type=ssh MIX_ENV=prod mix do deps.get, deps.compile

# Now we copy the entire project and build the OTP release.
COPY . .
RUN mix release

############################################
## RELEASE STAGE - production application ##
############################################
# Minimal (debian-slim) image for production purposes
# Copies the bundle from pre-release image

FROM debian:10-slim AS release

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
  libjson-c-dev \
  curl

# Create a non root user and the working folder
RUN useradd --create-home ${APP_USER}
WORKDIR $WORKDIR
RUN chown ${APP_USER}: ${WORKDIR}

# Copy over the build artifact from the previous step
COPY --chown=${APP_USER} --from=pre-release /opt/cache/_build/prod/rel/<%= app %> .

USER ${APP_USER}

CMD trap 'exit' INT; ${WORKDIR}/bin/<%= app %> start


#############################################################################################
## RELEASE PHASE - check config and run migrations on Heroku before production application ##
#############################################################################################
FROM release AS release-phase

CMD trap 'exit' INT; \
  /opt/app/bin/check_config.sh && \
  /opt/app/bin/migrate.sh
