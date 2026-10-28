#!/usr/bin/env python3
# controllers/simple_controller/simple_controller.py
import base64
import json
import threading
import time

from controller import Supervisor
import zenoh

from flying_camera_webots_io import WebotsIO, capture_and_encode


class ZenohNode:

  def __init__(self):
    self._session = None
    self._latest_command = None
    self._cam_pub = None
    self._pose_pub = None
    self._move_sub = None

    # Run Zenoh initialization in a background thread to prevent
    # blocking Webots startup (which causes the 67% freeze).
    threading.Thread(target=self._init_zenoh, daemon=True).start()

  def _init_zenoh(self):
    try:
      print("[INFO] Initializing Zenoh session in background...")
      conf = zenoh.Config()
      self._session = zenoh.open(conf)

      # Publishers
      self._cam_pub = self._session.declare_publisher("drone/camera/image")
      self._pose_pub = self._session.declare_publisher("drone/pose")

      # Subscriber
      self._move_sub = self._session.declare_subscriber(
          "drone/cmd/move", self._on_move_command
      )
      print("[INFO] Zenoh session fully initialized and active.")
    except Exception as e:
      print(f"[ERR] Failed to initialize Zenoh session: {e}")

  def _on_move_command(self, sample):
    try:
      payload = sample.payload.to_string()
      data = json.loads(payload)  # Expected format: {"pose": [x, y, z], "rot": [x, y, z, angle]}
      self._latest_command = data
    except Exception as e:
      print(f"[WARN] Failed to parse incoming command: {e}")

  def send_image(self, b64_img):
    if self._cam_pub and b64_img:
      self._cam_pub.put(b64_img.encode("ascii"))

  def send_pose(self, pose7d):
    if self._pose_pub:
      payload = json.dumps({"pose7d": pose7d})
      self._pose_pub.put(payload)

  def get_move(self):
    cmd = self._latest_command
    self._latest_command = None
    return cmd

  def close(self):
    if self._session:
      self._session.close()


# ===== WEBOTS SETUP =====
def setup_supervisor():
  supervisor = Supervisor()
  robot_node = supervisor.getSelf()
  timestep = int(supervisor.getBasicTimeStep())

  robot_controller = WebotsIO(
      robot_node.getField("translation"),
      robot_node.getField("rotation"),
  )

  camera = supervisor.getDevice("camera")
  camera.enable(timestep)
  return supervisor, robot_controller, camera, timestep


def run_main_loop(supervisor, timestep, robot_controller, camera, zenoh_node):
  """Main simulation loop."""
  height, width = 480, 640

  while supervisor.step(timestep) != -1:
    encoded = capture_and_encode(camera, height, width)
    pose7d = list(robot_controller.pose3d) + list(robot_controller.rot4d)

    zenoh_node.send_image(encoded)
    zenoh_node.send_pose(pose7d)

    move_cmd = zenoh_node.get_move()
    if move_cmd:
      target_pose = move_cmd.get("pose", None)
      target_rot = move_cmd.get("rot", None)
      robot_controller.move(target_pose3d=target_pose, target_rot4d=target_rot)

    time.sleep(1.0 / 30.0)


# ===== ENTRYPOINT =====
def main():
  supervisor, robot_controller, camera, timestep = setup_supervisor()
  zenoh_node = ZenohNode()
  try:
    run_main_loop(supervisor, timestep, robot_controller, camera, zenoh_node)
  except KeyboardInterrupt:
    print("[INFO] Interrupted.")
  finally:
    zenoh_node.close()
    print("[INFO] Controller shut down cleanly.")


if __name__ == "__main__":
  main()