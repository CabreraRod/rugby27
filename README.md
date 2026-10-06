# Rugby 27

A modern spiritual successor to classic console rugby. Original code, original
procedural assets. Built incrementally: every milestone is playable.

**Current state:** Milestone 07 — 6 v 6 with real tackling and a basic
AI on both sides: AI carriers pick lines into space and choose carry vs.
pass, support runners flatten and hunt gaps, defenders chase on intercept
lines, cover and dive. Team styles (tempo, width, aggression, passing)
change how each side plays. F2 switches to a single-player sandbox.

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
| Defending: switch player | Q / E | LB / RB |
| Defending: tackle / dive tackle | run into the carrier / Space | run into the carrier / A |
| Carrying: fend / sidestep | V / Z, X | X / right-stick flick |
| Camera side / end-on | C | Back |
| Debug overlay | F1 | — |
| Sandbox (one player) ↔ team mode | F2 | D-pad up |
| Pick up the ball | run over it | run over it |
| Dev: drop ball / toss ball | F / T | — / D-pad down |
| Dev: ground / role / next player / reset / reload tuning | G / B / N / R / F5 | B / — / Y / Start / — |

All feel lives in `data/tuning/*.json` (movement, ball, passing, support, defence, tackle) —
edit while the game runs and press **F5** to hot-reload. Pass directions are
the attacker's left/right, not the screen's.

## Tests

```sh
./tools/run_tests.sh            # uses $GODOT or `godot` on PATH
godot --headless --path . --script res://tools/pass_soak.gd     # passing stats
godot --headless --path . --script res://tools/defence_soak.gd  # defence stats
godot --headless --path . --script res://tools/tackle_soak.gd   # tackle stats
godot --headless --path . --script res://tools/ai_soak.gd     # AI vs AI A/B matrix
```

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Gameplay](docs/GAMEPLAY.md)
- [Roadmap](docs/ROADMAP.md)
- [Technical decisions](docs/TECHNICAL_DECISIONS.md)
- [Research: what players say about Rugby 08](docs/RESEARCH_RUGBY08.md)
