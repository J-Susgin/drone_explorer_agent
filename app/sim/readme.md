# Drone Explorer

Webots apartment world with a flying camera drone, controlled over Zenoh.
Everything runs in Podman.

```
.
├── agent/   # agent code (Dockerfile + src/)
└── sim/     # simulator
    ├── run_app.sh        # start the simulator
    ├── run_testers.sh    # run a Zenoh test script
    ├── Containerfile
    ├── entrypoint.sh
    ├── controllers/      # Webots controller (Zenoh bridge)
    ├── protos/           # drone model
    ├── worlds/           # my_complete_apartment.wbt
    └── dummy_io_testers/ # Zenoh test scripts
```

## Requirements

- Podman
- Linux host. `gui` mode also needs an X session on that host.
- Working over SSH (VS Code Remote-SSH or plain ssh): use `stream`.

## 1. Start the simulator

```bash
cd sim
chmod +x run_app.sh run_testers.sh entrypoint.sh
./run_app.sh --build stream
```

| Mode       | What it does                                         |
|------------|------------------------------------------------------|
| `stream`   | Webots in a virtual screen, viewable in your browser |
| `gui`      | Webots window on the host's own screen               |
| `headless` | No display. Zenoh only.                              |

`--build` rebuilds the image. **Use it after any change** in `controllers/`,
`protos/`, `worlds/` or `dummy_io_testers/`. These folders are copied into the
image at build time.

Stop: `Ctrl-C`, or `podman rm -f drone-sim`.

## 2. See the simulation (stream mode)

Open: <http://localhost:6080/vnc.html> and click **Connect**.

Wait 10-20 s. Software rendering is slow on first load.

- **VS Code Remote-SSH**: port 6080 is forwarded automatically (see the Ports tab).
- **Plain ssh**: `ssh -L 6080:localhost:6080 <server>`

The stream is bound to the server's localhost and has no password.
Do not expose it to the network.

## 3. Test the connection

The simulator must be running. In a second terminal:

```bash
cd sim
./run_testers.sh zenoh_sub_pose.py        # prints the drone pose
./run_testers.sh zenoh_sub_camera.py      # camera, then open http://localhost:8081
./run_testers.sh zenoh_pub_move_cmd.py    # sends a move command
```

Add `--build` before the script name to rebuild the tester image.
Port 8081 is forwarded the same way as 6080.

> `zenoh_sub_camera.py` needs special image forwarding when performing stream.

## Zenoh topics

| Topic               | Direction  | Payload                                              |
|---------------------|------------|------------------------------------------------------|
| `drone/pose`        | sim -> you | JSON: `{"pose7d": [x, y, z, rx, ry, rz, angle]}`     |
| `drone/camera/image`| sim -> you | Encoded camera frame (see `flying_camera_webots_io.py`) |
| `drone/cmd/move`    | you -> sim | JSON: `{"pose": [x, y, z], "rot": [x, y, z, angle]}` |

## Logs

- Webots and controller output: `sim/.log/stream.log` (or `gui.log`, `headless.log`)
- Container output: `podman logs drone-sim`

The controller prints `Zenoh session fully initialized` when it is ready.

## Troubleshooting

| Problem                           | Fix                                                          |
|-----------------------------------|--------------------------------------------------------------|
| Browser shows a directory listing | Open `/vnc.html`, not `/`                                    |
| Black screen in the browser       | Wait. Then check `.log/stream.log`                           |
| Port 6080 in use                  | `NOVNC_PORT=6081 ./run_app.sh stream`                        |
| Tester sees nothing               | Is the sim running? Both must be on network `sil_net`        |
| Camera tester shows no image      | Check `[DBG] frame bytes` in `.log/stream.log`. 0 = camera problem in the sim |
| Code change has no effect         | Rebuild: `./run_app.sh --build <mode>`                       |
| Slow simulation                   | Expected. Rendering is on CPU. Simplify the world.           |