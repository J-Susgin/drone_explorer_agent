#!/usr/bin/env bash
# Serves the page in a small container on localhost:8080.
set -euo pipefail
cd "$(dirname "$0")"

PORT="${PORT:-8080}"
GW="${GW:-ws://100.95.220.22:8000/ws}"

echo "Open: http://localhost:${PORT}/index.html?gw=${GW}"

exec podman run --rm -p "127.0.0.1:${PORT}:8000" \
  -v "$(pwd):/srv:ro" -w /srv \
  docker.io/library/python:3.11-slim \
  python -m http.server 8000