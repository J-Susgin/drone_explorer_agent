#!/usr/bin/env bash
# Runs the gateway on the same network as the simulator, published only on the Tailscale address.
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="localhost/drone-explorer/gateway:latest"
NETWORK="sil_net"
TS_IP="${TS_IP:-100.95.220.22}"

podman network exists "$NETWORK" || podman network create "$NETWORK"
podman build -t "$IMAGE" .
podman rm -f gateway >/dev/null 2>&1 || true
podman run -d --name gateway --network "$NETWORK" -p "${TS_IP}:8000:8000" "$IMAGE"

echo "Gateway: ws://${TS_IP}:8000/ws"
echo "Logs:    podman logs -f gateway"