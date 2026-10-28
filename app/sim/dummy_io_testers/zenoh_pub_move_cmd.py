import json
import zenoh

session = zenoh.open(zenoh.Config())
# Move drone to x=1.0, y=2.0, z=0.5
command = {"pose": [1.0, 2.0, 0.5], "rot": [0.0, 0.0, 1.0, 0.0]}
session.put("drone/cmd/move", json.dumps(command))