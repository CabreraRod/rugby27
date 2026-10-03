# Rugby 27 — Architecture

Status: Milestone 01 (field + camera + one controllable player).

## Principles

1. **Gameplay first.** Systems exist only when they plug into the playable loop.
2. **Simulation ≠ presentation.** Gameplay state lives in plain objects and
   physics bodies; visuals, HUD and camera only *read* it.
3. **Controllers drive bodies.** A `RugbyPlayer` never reads input. A
   controller (human now, AI later) sets an *intent* every physics tick. Human
   and AI players obey identical movement rules.
4. **Pure cores, thin nodes.** The hard maths (`LocomotionModel`,
   `StaminaModel`) is node-free and deterministic, so it's unit-tested
   headlessly. Nodes are glue.
5. **Data-driven.** Players, teams and feel-tuning come from `data/*.json`.
   No player or team is hard-coded into a gameplay system.
6. **One-way dependencies.** Lower layers never import higher ones.

## Coordinate convention

Defined in `game/field/field_dimensions.gd` and used everywhere:

- `+X` along the pitch (try line → try line), halfway at `X = 0`, try lines at `X = ±50`.
- `+Z` across the pitch, touchlines at `Z = ±35`.
- `+Y` up, pitch surface at `Y = 0`.
- Ground-plane vectors are `Vector2(x, z)`.

## Layers (dependency direction ↓)

```
match/        composition (scene bootstrap; later MatchDirector, phases, clock)
  ├─ ui/, debug/, camera/, presentation/   read-only views
  ├─ players/  controllers → RugbyPlayer → locomotion cores
  ├─ field/    pitch geometry + builder
  └─ core/     input setup, JSON loading
data/          JSON (tuning, players, teams)
```

## Current files

| Path | Responsibility |
|---|---|
| `game/core/input_setup.gd` | Autoload. Registers input actions in code (keyboard + gamepad). |
| `game/core/json_loader.gd` | JSON reading with clear errors. |
| `game/field/field_dimensions.gd` | Single source of truth for pitch geometry. |
| `game/field/pitch.gdshader` | Procedural grass stripes + all markings (no textures). |
| `game/field/field_builder.gd` | Ground collision, pitch surface, H-posts with solid protectors. |
| `game/presentation/stadium_environment.gd` | Sky, sun/shadows, simple stands and boards. |
| `game/players/locomotion/movement_tuning.gd` | Global feel parameters (from `data/tuning/movement.json`). |
| `game/players/locomotion/locomotion_stats.gd` | Per-player numbers derived from tuning × attributes × role × fatigue. |
| `game/players/locomotion/locomotion_model.gd` | Pure planar movement step (accel curve, turn rate, plant-and-cut). |
| `game/players/locomotion/stamina_model.gd` | Sprint drain, regen delay, soft fatigue, lockout hysteresis. |
| `game/players/player_attributes.gd` | 1–99 ratings, normalized accessors. |
| `game/players/player_profile.gd` | Name/number/position/attributes from JSON. |
| `game/players/rugby_player.gd` | `CharacterBody3D`: state machine, role, facing, physics integration. |
| `game/players/human_controller.gd` | Camera-relative device input → intent. Runs before players each tick. |
| `game/players/player_visual.gd` | Procedural body + procedural run cycle/lean + control indicator. |
| `game/camera/broadcast_camera.gd` | Side/end-on broadcast camera, look-ahead, critically-damped follow. |
| `ui/hud/match_hud.gd` | Player label, stamina bar, speed, controls hint. |
| `game/debug/debug_overlay.gd` | F1 overlay: state text + world vectors. |
| `game/match/match_bootstrap.gd` | Builds the M01 scene and dev hotkeys. |
| `tests/*` | Headless test runner + suites. |
| `tools/capture_screenshots.gd` | Scripted run that saves screenshots (visual regression aid). |

## Per-tick order (60 Hz physics)

1. `HumanController` (priority −10): read input → `player.set_intent()`.
2. `RugbyPlayer._physics_process`: stamina → stats → `LocomotionModel.step` →
   facing → `move_and_slide` (Jolt) → velocity read back.
3. Render frame (`_process`): camera, visual, HUD, debug read interpolated state.

Physics interpolation is on, so motion is smooth at any display refresh rate
while gameplay stays fixed-step and deterministic.

## Planned layout (folders created when their milestone starts)

```
game/ball/  game/passing/  game/tackling/  game/rucks/  game/scrums/
game/lineouts/  game/kicking/  game/ai/  game/referee/  game/rules/
teams/{players,tactics,formations}/  competitions/  career/  audio/  animations/  assets/
```

Empty placeholder folders are deliberately **not** created now.

## Known architectural seams for upcoming milestones

- **Ball (M03):** `RigidBody3D` (Jolt) when loose/in flight; attached to a
  player socket when held. `RugbyPlayer.Role.BALL_CARRIER` already modifies
  movement.
- **Multiple players (M05):** `HumanController.player` becomes switchable;
  `BroadcastCamera.target` becomes a focus solver (ball + nearby players).
- **AI (M06):** an `AIController` sets intents through the same
  `set_intent()` API.
