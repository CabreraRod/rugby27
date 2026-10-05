# Rugby 27

A modern spiritual successor to classic console rugby. Original code, original
procedural assets. Built incrementally: every milestone is playable.

**Current state:** Milestone 04 — a six-player backline: you control the
ball carrier, pass left/right along a line of teammates that run with you,
and control follows the ball. F2 switches to a single-player sandbox.

## Run

1. Install **Godot 4.4 or newer** (standard edition, not .NET):
   https://godotengine.org/download
2. Open Godot → **Import** → select `project.godot` in this folder.
3. Press **F5** (Run Project).

## Controls

| | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick (analog) |
| Sprint | Shift | RT |
| Pass left / right (tap = quick, hold = long) | Q / E | LB / RB |
| Camera side / end-on | C | Back |
| Debug overlay | F1 | — |
| Sandbox (one player) ↔ team mode | F2 | D-pad up |
| Pick up the ball | run over it | run over it |
| Dev: drop ball / toss ball | F / T | X / D-pad down |
| Dev: ground / role / next player / reset / reload tuning | G / B / N / R / F5 | B / — / Y / Start / — |

All feel lives in `data/tuning/*.json` (movement, ball, passing, support) —
edit while the game runs and press **F5** to hot-reload. Pass directions are
the attacker's left/right, not the screen's.

## Tests

```sh
./tools/run_tests.sh            # uses $GODOT or `godot` on PATH
godot --headless --path . --script res://tools/pass_soak.gd   # passing stats
```

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Gameplay](docs/GAMEPLAY.md)
- [Roadmap](docs/ROADMAP.md)
- [Technical decisions](docs/TECHNICAL_DECISIONS.md)
- [Research: what players say about Rugby 08](docs/RESEARCH_RUGBY08.md)
