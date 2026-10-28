#!/usr/bin/env bash
#
# run.sh - podman replacement for `docker compose up --build` (headless/gui simulator)
#
# Usage:
#   ./run.sh gui
#   ./run.sh --build gui
#   ./run.sh --build headless
#
# Env overrides:
#   IMAGE=localhost/drone-explorer/sim:latest ./run.sh --build gui

set -euo pipefail

IMAGE="${IMAGE:-localhost/drone-explorer/sim:latest}"
CONTAINER_NAME="drone-sim"
NETWORK="sil_net"

BUILD=false
MODE=""

# Parse arguments to support --build in any order
for arg in "$@"; do
    case "$arg" in
        --build)
            BUILD=true
            ;;
        headless|gui)
            MODE="$arg"
            ;;
        *)
            echo "Usage: $0 [--build] [headless|gui]"
            exit 1
            ;;
    esac
done

if [[ -z "$MODE" ]]; then
    echo "Usage: $0 [--build] [headless|gui]"
    exit 1
fi

# --- build image if requested ---
if [[ "$BUILD" == "true" ]]; then
    echo "Building Podman image: $IMAGE..."
    podman build -t "$IMAGE" .
fi

# --- network setup & CNI compatibility fix ---
if ! podman network exists "$NETWORK" 2>/dev/null; then
    echo "Creating network: $NETWORK"
    podman network create "$NETWORK"
fi

# ALWAYS ensure the CNI config file is patched to version 0.4.0
for conflist in "$HOME/.config/cni/net.d/${NETWORK}.conflist" "/etc/cni/net.d/${NETWORK}.conflist"; do
    if [[ -f "$conflist" ]]; then
        sed -i 's/"cniVersion": "1.0.0"/"cniVersion": "0.4.0"/g' "$conflist" 2>/dev/null || true
    fi
done

# --- clean up any previous run with the same name ---
podman rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

COMMON_ARGS=(
    --name "$CONTAINER_NAME"
    --network "$NETWORK"
    --device /dev/dri
    --rm
    -it
    -e HOME=/home/hostuser
    -e QT_X11_NO_MITSHM=1
    -v "$(pwd)/config/preferences.xml:/home/hostuser/workspace/.config/Webots/preferences.xml"
    -v "$(pwd)/.cache:/home/hostuser/.cache/Cyberbotics/Webots"
    -v "$(pwd)/logs:/home/hostuser/workspace/sim/logs"
    -p 7447:7447/tcp
    -p 7447:7447/udp
)

if [[ "$MODE" == "gui" ]]; then
    : "${DISPLAY:?DISPLAY is not set on the host — GUI mode needs an X session}"

    # Allow the container to connect to the host X server.
    # xhost isn't always installed; don't hard-fail if it's missing.
    if command -v xhost >/dev/null 2>&1; then
        xhost +local:podman >/dev/null 2>&1 || true
    fi

    echo "Starting simulator in GUI mode..."
    podman run "${COMMON_ARGS[@]}" \
        -e WEBOTS_MODE=gui \
        -e DISPLAY="$DISPLAY" \
        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
        "$IMAGE"
else
    echo "Starting simulator in headless mode..."
    podman run "${COMMON_ARGS[@]}" \
        -e WEBOTS_MODE=headless \
        -e DISPLAY=:99 \
        "$IMAGE"
fi