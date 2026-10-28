import base64
import cv2
import numpy as np
import zenoh


def listener(sample):
  jpeg_bytes = base64.b64decode(sample.payload.to_bytes())
  img_np = np.frombuffer(jpeg_bytes, dtype=np.uint8)
  img = cv2.imdecode(img_np, cv2.IMREAD_COLOR)
  cv2.imshow("Zenoh Drone Stream", img)
  cv2.waitKey(1)


session = zenoh.open(zenoh.Config())
sub = session.declare_subscriber("drone/camera/image", listener)

input("Press Enter to exit...\n")