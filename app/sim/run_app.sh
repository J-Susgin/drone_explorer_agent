#!/usr/bin/env bash
#
# run.sh - podman launcher for the Webots simulator container
# Usage:
#   ./run.sh [--build] [headless|gui|stream]
#   ./run.sh --build stream
#   ./run.sh gui
#
# stream = Xvfb + x11vnc + noVNC inside the container, published on
#          127.0.0.1:6080 on the host. Reach it through an SSH tunnel.

set -euo pipefail

IMAGE="${IMAGE:-localhost/drone-explorer/sim:latest}"
CONTAINER_NAME="drone-sim"
NETWORK="sil_net"
NOVNC_PORT="${NOVNC_PORT:-6080}"

BUILD=false
MODE=""

usage() {
    echo "Usage: $0 [--build] [headless|gui|stream]"
    exit 1
}

for arg in "$@"; do
    case "$arg" in
        --build)               BUILD=true ;;
        --remote)              MODE="${MODE:-stream}" ;;  # legacy flag, now implied by stream
        headless|gui|stream)   MODE="$arg" ;;
        *)                     usage ;;
    esac
done

[[ -z "$MODE" ]] && usage

# --- build image if requested ---
if [[ "$BUILD" == "true" ]]; then
    echo "Building image: $IMAGE"
    podman build -t "$IMAGE" .
fi

# --- host dirs must exist before bind-mounting ---
mkdir -p "$(pwd)/.cache" "$(pwd)/.log"

# --- network setup & CNI compatibility fix ---
if ! podman network exists "$NETWORK" 2>/dev/null; then
    echo "Creating network: $NETWORK"
    podman network create "$NETWORK"
fi

for conflist in "$HOME/.config/cni/net.d/${NETWORK}.conflist" "/etc/cni/net.d/${NETWORK}.conflist"; do
    if [[ -f "$conflist" ]]; then
        sed -i 's/"cniVersion": "1.0.0"/"cniVersion": "0.4.0"/g' "$conflist" 2>/dev/null || true
    fi
done

# --- clean up any previous run ---
podman rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

# --- args shared by all modes ---
COMMON_ARGS=(
    --name "$CONTAINER_NAME"
    --network "$NETWORK"
    --rm
    -e HOME=/home/hostuser
    -e QT_X11_NO_MITSHM=1
    -v "$(pwd)/config/preferences.xml:/home/hostuser/workspace/.config/Webots/preferences.xml"
    -v "$(pwd)/.cache:/home/hostuser/.cache/Cyberbotics/Webots"
    -v "$(pwd)/.logs:/home/hostuser/workspace/sim/logs"
    -p 7447:7447/tcp
    -p 7447:7447/udp
)

# interactive TTY only when one exists
if [[ -t 0 && -t 1 ]]; then
    COMMON_ARGS+=(-it)
fi

# GPU device only if present
if [[ -d /dev/dri ]]; then
    COMMON_ARGS+=(--device /dev/dri)
fi

case "$MODE" in
    gui)
        : "${DISPLAY:?DISPLAY is not set on the host. GUI mode needs an X session}"
        command -v xhost >/dev/null 2>&1 && xhost +local:podman >/dev/null 2>&1 || true

        echo "Starting simulator in GUI mode..."
        exec podman run "${COMMON_ARGS[@]}" \
            -e WEBOTS_MODE=gui \
            -e DISPLAY="$DISPLAY" \
            -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
            "$IMAGE"
        ;;
    stream)
        echo "Starting simulator in stream mode (noVNC on 127.0.0.1:${NOVNC_PORT})..."
        echo "From your laptop:"
        echo "  ssh -L ${NOVNC_PORT}:localhost:${NOVNC_PORT} <this-server>"
        echo "  then open http://localhost:${NOVNC_PORT}/vnc.html"
        exec podman run "${COMMON_ARGS[@]}" \
            -p "127.0.0.1:${NOVNC_PORT}:6080/tcp" \
            -e WEBOTS_MODE=stream \
            "$IMAGE"
        ;;
    headless)
        echo "Starting simulator in headless mode..."
        exec podman run "${COMMON_ARGS[@]}" \
            -e WEBOTS_MODE=headless \
            "$IMAGE"
        ;;
esac