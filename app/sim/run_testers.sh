#!/usr/bin/env bash
#
# run_tester.sh - Run Zenoh I/O testers using a pre-built Podman image
# Usage:
#   ./run_tester.sh zenoh_sub_pose.py
#   ./run_tester.sh --build zenoh_sub_camera.py

set -euo pipefail

TESTER_IMAGE="${TESTER_IMAGE:-localhost/drone-explorer/tester:latest}"
NETWORK="sil_net"
BUILD=false
SCRIPT_NAME=""

# Parse arguments to handle --build and the script name flexibly
for arg in "$@"; do
    case "$arg" in
        --build)
            BUILD=true
            ;;
        *)
            if [[ -z "$SCRIPT_NAME" ]]; then
                SCRIPT_NAME="$arg"
            else
                echo "Usage: $0 [--build] <script_name.py>"
                exit 1
            fi
            ;;
    esac
done

if [[ -z "$SCRIPT_NAME" ]]; then
    echo "Usage: $0 [--build] <script_name.py>"
    echo "Available scripts in dummy_io_testers:"
    ls -l dummy_io_testers/
    exit 1
fi

# Build the image if requested or if it doesn't exist yet
if [[ "$BUILD" == "true" ]] || ! podman image exists "$TESTER_IMAGE"; then
    echo "Building tester image ($TESTER_IMAGE)..."
    podman build -t "$TESTER_IMAGE" -f ./dummy_io_testers/Containerfile.tester .
fi

# Allow host X11 connections if running a GUI app
if command -v xhost >/dev/null 2>&1; then
    xhost +local:podman >/dev/null 2>&1 || true
fi

DISPLAY_VAL="${DISPLAY:-:0}"

echo "Starting tester container for: $SCRIPT_NAME..."

podman run --rm -it \
    --network "$NETWORK" \
    --device /dev/dri \
    -e DISPLAY="$DISPLAY_VAL" \
    -e QT_X11_NO_MITSHM=1 \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v "$(pwd)/dummy_io_testers:/workspace/dummy_io_testers" \
    -w /workspace/dummy_io_testers \
    "$TESTER_IMAGE" \
    python3 "$SCRIPT_NAME"