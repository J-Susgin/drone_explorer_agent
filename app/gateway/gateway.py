import asyncio
import base64
import json
import os
import threading
from contextlib import asynccontextmanager

import zenoh
from fastapi import FastAPI, WebSocket

CAMERA_KEY = os.getenv("CAMERA_KEY", "drone/camera/image")
POSE_KEY = os.getenv("POSE_KEY", "drone/pose")
SEND_HZ = float(os.getenv("SEND_HZ", "10"))


class Latest:
    """Keeps only the newest value. Zenoh writes it, the WebSocket reads it."""

    def __init__(self):
        self._lock = threading.Lock()
        self._seq = 0
        self._value = None

    def set(self, value):
        with self._lock:
            self._seq += 1
            self._value = value

    def get(self):
        with self._lock:
            return self._seq, self._value


frame = Latest()
pose = Latest()
subscribers = []  # keep references so the subscriptions stay alive


def on_camera(sample):
    try:
        frame.set(base64.b64decode(sample.payload.to_bytes()))
    except Exception as e:
        print(f"[WARN] bad camera payload: {e}")


def on_pose(sample):
    try:
        data = json.loads(sample.payload.to_string())
        pose.set(data.get("pose7d", []))
    except Exception as e:
        print(f"[WARN] bad pose payload: {e}")


@asynccontextmanager
async def lifespan(app):
    session = zenoh.open(zenoh.Config())
    subscribers.append(session.declare_subscriber(CAMERA_KEY, on_camera))
    subscribers.append(session.declare_subscriber(POSE_KEY, on_pose))
    print(f"[INFO] subscribed to {CAMERA_KEY} and {POSE_KEY}")
    yield
    session.close()


app = FastAPI(lifespan=lifespan)


@app.websocket("/ws")
async def stream(ws: WebSocket):
    await ws.accept()
    last_frame = -1
    last_pose = -1
    try:
        while True:
            fseq, jpeg = frame.get()
            if jpeg is not None and fseq != last_frame:
                await ws.send_bytes(jpeg)  # binary message: raw JPEG
                last_frame = fseq

            pseq, p7 = pose.get()
            if p7 is not None and pseq != last_pose:
                await ws.send_text(json.dumps({"pose7d": p7}))  # text message: JSON
                last_pose = pseq

            await asyncio.sleep(1.0 / SEND_HZ)
    except Exception:
        print("[INFO] client disconnected")