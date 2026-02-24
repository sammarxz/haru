ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.2
ARG DEBIAN_VERSION=bookworm-20260202-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends build-essential git curl nodejs npm \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Copy umbrella mix files first (for better layer caching)
COPY mix.exs mix.lock ./
COPY apps/haru_core/mix.exs apps/haru_core/
COPY apps/haru_web/mix.exs apps/haru_web/

RUN mix deps.get --only $MIX_ENV

# Compile-time config (must come before deps.compile)
RUN mkdir config
COPY config/config.exs config/prod.exs config/

RUN mix deps.compile

# Download tailwind and esbuild binaries
RUN mix tailwind.install --if-missing
RUN mix esbuild.install --if-missing

# Install JS dependencies
COPY apps/haru_web/assets/package.json apps/haru_web/assets/package-lock.json ./apps/haru_web/assets/
RUN npm install --prefix apps/haru_web/assets

# Copy source (priv dirs needed before compile)
COPY apps/ apps/

RUN mix compile

# Build and minify assets — write to apps/haru_web/priv/static/
RUN mix tailwind haru_web --minify \
  && mix esbuild haru_web --minify \
  && mix esbuild snippet --minify

# Digest: copy freshly built assets into _build so the release picks them up
RUN mix phx.digest apps/haru_web/priv/static \
  --output _build/prod/lib/haru_web/priv/static

# runtime.exs is evaluated at boot, not at compile time — copy last
COPY config/runtime.exs config/

RUN mix release haru

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM ${RUNNER_IMAGE} AS final

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
  libstdc++6 openssl libncurses6 locales ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

COPY --from=builder --chown=nobody:root /app/_build/prod/rel/haru ./

USER nobody

COPY entrypoint.sh /app/
USER root
RUN chmod +x /app/entrypoint.sh
USER nobody

ENV MIX_ENV="prod"
ENV PHX_SERVER="true"

CMD ["/app/entrypoint.sh"]
