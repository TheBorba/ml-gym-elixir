#!/bin/sh
# Creates the Python virtualenv used by MyApp.VideoAnalysis.PythonPort.
#
# This runs *inside* the application container during `docker build` (see
# Dockerfile.builder). The venv lives at priv/python/.venv in the image and
# is exposed to the app through PYTHON_BIN.
#
# Running it by hand inside a running container is also supported:
#   docker compose run --rm app sh priv/python/setup_venv.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VENV_DIR="$SCRIPT_DIR/.venv"

PYTHON=${PYTHON:-python3}

if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "error: '$PYTHON' not found on PATH" >&2
  exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
  echo "creating virtualenv at $VENV_DIR"
  "$PYTHON" -m venv "$VENV_DIR"
fi

echo "installing requirements"
"$VENV_DIR/bin/python3" -m pip install --upgrade pip >/dev/null
"$VENV_DIR/bin/python3" -m pip install -r "$SCRIPT_DIR/requirements.txt"

echo
echo "done. Interpreter: $VENV_DIR/bin/python3"
echo "The app resolves it automatically; set PYTHON_BIN to override."
