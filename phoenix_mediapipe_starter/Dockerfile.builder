# syntax=docker/dockerfile:1

# Single image that runs BOTH the Phoenix app and the MediaPipe Python worker.
#
# Debian (trixie) rather than Alpine: MediaPipe ships manylinux wheels and its
# native deps (libgomp, libGL) are only reliably available on glibc images.
#
# Python lives in a virtualenv created *inside* the image at
# /app/priv/python/.venv, so nothing has to be installed or executed on the
# host. The venv interpreter is exposed to the app via PYTHON_BIN.
FROM elixir:1.20-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MIX_ENV=dev \
    PYTHONUNBUFFERED=1 \
    PYTHON_BIN=/app/priv/python/.venv/bin/python3

# Erlang build tooling + the runtime libraries MediaPipe/OpenCV need.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        libegl1 \
        libgl1 \
        libglib2.0-0 \
        libgles2 \
        libgomp1 \
        libportaudio2 \
        libsm6 \
        libxext6 \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force \
    && mix local.rebar --force

WORKDIR /app

# Fetch dependencies first so code edits do not invalidate this layer.
COPY mix.exs ./
COPY config/ ./config/
RUN mix deps.get

COPY lib/ ./lib/
COPY priv/ ./priv/
# Tests ship with the image so `docker compose run --rm app mix test` works
# without bind mounts.
COPY test/ ./test/

# Build the in-image Python virtualenv (mediapipe, opencv, numpy).
RUN sh priv/python/setup_venv.sh

# Compile the application.
RUN mix compile

# Create the database, migrate, and serve.
CMD ["sh", "-c", "mix ecto.create --quiet || true && mix ecto.migrate --quiet && mix phx.server"]

