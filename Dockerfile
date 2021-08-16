# First build the application assets
FROM node:16-buster as assets

ENV DEBIAN_FRONTEND="noninteractive" TZ="America/New_York"

RUN apt-get update && apt-get install -y python3 build-essential webp bash imagemagick libncurses5-dev libncursesw5-dev \
    && rm -rf /root/.cache \
    && rm -rf /var/lib/apt/lists/*

COPY js .
RUN yarn install \
    && yarn run build

# Then, build the application binary
FROM elixir:1.12 AS builder

ENV DEBIAN_FRONTEND="noninteractive" TZ="America/New_York"

RUN apt-get update && apt-get install -y build-essential git cmake \
    && rm -rf /root/.cache \
    && rm -rf /var/lib/apt/lists/*

COPY mix.exs mix.lock ./
ENV MIX_ENV=prod
RUN mix local.hex --force \
    && mix local.rebar --force \
    && mix deps.get

COPY lib ./lib
COPY priv ./priv
COPY config/config.exs config/prod.exs ./config/
COPY config/docker.exs ./config/runtime.exs
COPY rel ./rel
COPY support ./support
COPY --from=assets ./priv/static ./priv/static

RUN mix phx.digest \
    && mix release

# Finally setup the app
FROM debian:buster

ENV DEBIAN_FRONTEND="noninteractive" TZ="America/New_York"

ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="mobilizon" \
    org.opencontainers.image.description="Mobilizon for Docker" \
    org.opencontainers.image.vendor="joinmobilizon.org" \
    org.opencontainers.image.documentation="https://docs.joinmobilizon.org" \
    org.opencontainers.image.licenses="AGPL-3.0" \
    org.opencontainers.image.source="https://framagit.org/framasoft/mobilizon" \
    org.opencontainers.image.url="https://joinmobilizon.org" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE

RUN apt-get update && apt-get install -y openssl libncursesw5 libncurses5 file postgresql-client \
    && rm -rf /root/.cache \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/uploads && chown nobody:nogroup /app/uploads
RUN mkdir -p /etc/mobilizon && chown nobody:nogroup /etc/mobilizon

USER nobody
EXPOSE 4000

ENV MOBILIZON_DOCKER=true

COPY --from=builder --chown=nobody:nogroup _build/prod/rel/mobilizon ./
RUN cp /releases/*/runtime.exs /etc/mobilizon/config.exs
COPY docker/production/docker-entrypoint.sh ./

ENTRYPOINT ["./docker-entrypoint.sh"]
