# Rugby 27

A modern spiritual successor to classic console rugby. Original code, original
procedural assets. Built incrementally: every milestone is playable.

**Current state:** Milestone 03 — full-size pitch, broadcast camera, one
controllable player, and a physical ball you can pick up, carry, drop and
lose in touch.

## Run

1. Install **Godot 4.4 or newer** (standard edition, not .NET):
   https://godotengine.org/download
2. Open Godot → **Import** → select `project.godot` in this folder.
3. Press **F5** (Run Project).

## Controls

| | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick (analog) |
| Sprint | Shift | RT / RB |
| Camera side / end-on | C | Back |
| Debug overlay | F1 | — |
| Pick up the ball | run over it | run over it |
| Dev: drop ball / toss ball | F / T | X / LB |
| Dev: ground / role / next player / reset / reload tuning | G / B / N / R / F5 | B / — / Y / Start / — |

Movement and ball feel live in `data/tuning/movement.json` and `data/tuning/ball.json` — edit them while the game
runs and press **F5** to hot-reload.

## Tests

```sh
./tools/run_tests.sh            # uses $GODOT or `godot` on PATH
```

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Gameplay](docs/GAMEPLAY.md)
- [Roadmap](docs/ROADMAP.md)
- [Technical decisions](docs/TECHNICAL_DECISIONS.md)
