# Rugby 27 — Architecture

Status: Milestone 03 (field, camera, one controllable player, ball + possession).

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
  ├─ ball/     PossessionController → RugbyBall → bounce/pickup cores
  ├─ players/  controllers → RugbyPlayer → locomotion cores
  ├─ field/    pitch geometry, zones, builder
  └─ core/     input setup, JSON loading, tuning base, physics layers
data/          JSON (tuning, players, teams)
```

## Current files

| Path | Responsibility |
|---|---|
| `game/core/input_setup.gd` | Autoload. Registers input actions in code (keyboard + gamepad). |
| `game/core/json_loader.gd` | JSON reading with clear errors. |
| `game/core/tuning_data.gd` | Base for JSON-backed tuning (unknown-key warnings). |
| `game/core/physics_layers.gd` | Collision layers: WORLD, PLAYERS, BALL. |
| `game/field/field_dimensions.gd` | Single source of truth for pitch geometry + `zone_of()` (field of play, in-goal, touch, touch-in-goal, dead). |
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
| `game/ball/ball_tuning.gd` | Ball + possession parameters (from `data/tuning/ball.json`). |
| `game/ball/bounce_model.gd` | Pure, seeded oval-ball bounce + rolling friction. |
| `game/ball/pickup_model.gd` | Pure pickup reach, chance and fumble velocity. |
| `game/ball/rugby_ball.gd` | `RigidBody3D` (Jolt): LOOSE / HELD / DEAD, carry socket, bounce, out-of-bounds. |
| `game/ball/possession_controller.gd` | Who gets the ball: pickups, fumbles, drops, placing; owns the BALL_CARRIER role. |
| `game/ball/ball_visual.gd` | Oval mesh, cosmetic tumble, ground marker. |
| `ui/hud/match_hud.gd` | Player label, stamina bar, speed, possession tag, centre notices. |
| `game/debug/debug_overlay.gd` | F1 overlay: player + ball state, vectors, pickup reach, predicted ball flight. |
| `game/match/match_bootstrap.gd` | Builds the M01 scene and dev hotkeys. |
| `tests/*` | Headless test runner + suites. |
| `tools/capture_screenshots.gd` | Scripted run that saves screenshots (visual regression aid). |

## Per-tick order (60 Hz physics)

1. `HumanController` (priority −10): read input → `player.set_intent()`.
2. `RugbyPlayer._physics_process` (0): stamina → stats → `LocomotionModel.step` →
   facing → `move_and_slide` (Jolt) → velocity read back.
3. `PossessionController` (5): loose ball within reach → pickup or fumble.
4. `RugbyBall._physics_process` (10): held ball follows the carry socket;
   out-of-bounds check. Jolt then integrates the loose ball, and
   `_integrate_forces` resolves bounces/rolling with `BounceModel`.
5. Render frame (`_process`): camera, visuals, HUD, debug read interpolated state.

Physics interpolation is on, so motion is smooth at any display refresh rate
while gameplay stays fixed-step and deterministic.

## Planned layout (folders created when their milestone starts)

```
game/passing/  game/tackling/  game/rucks/  game/scrums/
game/lineouts/  game/kicking/  game/ai/  game/referee/  game/rules/
teams/{players,tactics,formations}/  competitions/  career/  audio/  animations/  assets/
```

Empty placeholder folders are deliberately **not** created now.

## Known architectural seams for upcoming milestones

- **Passing (M04):** `RugbyBall.release(velocity, &"pass")` already exists;
  M04 adds pass targeting, an IN_FLIGHT flavour of LOOSE with an intended
  receiver, and catching (a sibling of `PickupModel`).
- **Rules (M11):** `RugbyBall.released(by, velocity, reason)` and
  `went_dead(zone, point)` are the events the referee will consume
  (knock-on = forward release by hands; touch → lineout).
- **Multiple players (M05):** `HumanController.player` becomes switchable;
  `BroadcastCamera.target` becomes a focus solver (ball + nearby players).
- **AI (M06):** an `AIController` sets intents through the same
  `set_intent()` API.
