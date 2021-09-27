
FROM verybigthings/elixir:1.12 AS build

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

ENV PHOENIX_VERSION 1.5.3

RUN mix local.hex --force && \
  mix local.rebar --force
RUN mix archive.install hex phx_new $PHOENIX_VERSION --force

# Set entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash", "-c", "while true; do sleep 10; done;"]
