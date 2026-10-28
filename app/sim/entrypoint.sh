#!/usr/bin/env bash
set -e
mkdir -p /home/hostuser/workspace/sim/logs
WORLD=./worlds/my_complete_apartment.wbt

case "$WEBOTS_MODE" in
  gui)
    exec webots --batch --stdout --stderr --mode=realtime "$WORLD" \
      > logs/gui.log 2>&1 ;;
  stream)
    Xvfb :99 -screen 0 1920x1080x24 &
    export DISPLAY=:99
    sleep 1
    fluxbox &
    x11vnc -display :99 -forever -shared -nopw -localhost -rfbport 5900 -quiet &
    websockify --web=/usr/share/novnc 6080 localhost:5900 &
    exec webots --batch --stdout --stderr --mode=realtime "$WORLD" \
      > logs/stream.log 2>&1 ;;
  *)
    Xvfb :99 -screen 0 1920x1080x24 &
    export DISPLAY=:99
    exec webots --batch --minimize --stdout --stderr --mode=realtime "$WORLD" \
      > logs/headless.log 2>&1 ;;
esac