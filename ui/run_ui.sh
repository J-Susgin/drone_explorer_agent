#!/usr/bin/env bash
# Builds and runs the UI container on the laptop.
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="localhost/drone-explorer/ui:latest"
PORT="${PORT:-8080}"

podman build -t "$IMAGE" .
podman rm -f drone-ui >/dev/null 2>&1 || true
podman run -d --name drone-ui -p "127.0.0.1:${PORT}:8080" "$IMAGE"

echo "Open: http://localhost:${PORT}/index.html?gw=ws://localhost:8000/ws"
echo "Logs: podman logs -f drone-ui"