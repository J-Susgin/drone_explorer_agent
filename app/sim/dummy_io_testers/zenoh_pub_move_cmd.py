import json
import time
import zenoh


def main():
  print("[INFO] Opening Zenoh session for movement command publisher...")
  session = zenoh.open(zenoh.Config())

  key_expression = "drone/cmd/move"
  print(f"[INFO] Publishing movement commands to '{key_expression}'...")

  # Example target command (e.g., move slightly forward and up)
  cmd_payload = {
      "pose": [0.0, 2.0, 1.0],  # [x, y, z] translation
      "rot": [0.0, 0.0, 1.0, 0.0],  # [x, y, z, angle] rotation
  }

  payload_str = json.dumps(cmd_payload)

  try:
    while True:
      print(f"[PUB] Sending command: {payload_str}")
      session.put(key_expression, payload_str)
      time.sleep(2.0)  # Send every 2 seconds
  except KeyboardInterrupt:
    print("\n[INFO] Stopping movement publisher.")
  finally:
    session.close()


if __name__ == "__main__":
  main()