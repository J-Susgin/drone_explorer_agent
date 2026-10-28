import json
import zenoh


def listener(sample):
  data = json.loads(sample.payload.to_string())
  pose7d = data.get("pose7d", [])
  print(f"Received Pose (7D): {pose7d}")


session = zenoh.open(zenoh.Config())
sub = session.declare_subscriber("drone/pose", listener)

input("Press Enter to exit...\n")