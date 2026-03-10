# ============================================================================
# Stage 1: Build
# ============================================================================
ARG ELIXIR_VERSION=1.16.1
ARG OTP_VERSION=26.2.2
ARG DEBIAN_VERSION=bookworm-20240130-slim
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y build-essential git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mix do tailwind.install --if-missing, esbuild.install --if-missing
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application source
COPY priv priv
COPY lib lib
COPY assets assets

# Compile the application and pack assets
RUN mix compile
RUN mix assets.deploy

# Build the release
COPY config/runtime.exs config/
RUN mix release

# ============================================================================
# Stage 2: Runtime
# ============================================================================
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

# Create a non-root user
RUN groupadd --system app && \
    useradd --system --gid app --home /app app

# Copy the release from the builder stage
COPY --from=builder --chown=app:app /app/_build/prod/rel/globaltask ./

USER app

# Runtime configuration
ENV PHX_SERVER=true
ENV PORT=4000

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:4000/ || exit 1

# Automatically run pending migrations before starting the Phoenix Release
CMD ["sh", "-c", "bin/globaltask eval 'Globaltask.Release.migrate()' && bin/globaltask start"]
