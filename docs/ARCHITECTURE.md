# Rugby 27 — Architecture

Status: Milestone 06 — tackling (6 v 6, human vs AI team, passing, tackling, turnovers; placeholder AI).

## Principles

1. **Gameplay first.** Systems exist only when they plug into the playable loop.
2. **Simulation ≠ presentation.** Gameplay state lives in plain objects and
   physics bodies; visuals, HUD and camera only *read* it.
3. **Controllers drive bodies.** A `RugbyPlayer` never reads input.
   `TeamControl` sets an *intent* on every player every physics tick — from
   the human for the controlled player, from `SupportRunner` for the rest
   (M06 AI later). Human and AI players obey identical movement rules.
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
match/        composition: bootstrap, Team, TeamControl (later MatchDirector)
  ├─ ui/, debug/, camera/, presentation/   read-only views
  ├─ tackling/ TackleSystem → TackleModel core
  ├─ passing/  PassingSystem → targeting / solver / catch cores
  ├─ ai/       SupportRunner, DefensiveLine, AttackBrain (placeholders; M06 AI)
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
| `game/players/rugby_player.gd` | `CharacterBody3D`: state machine, role, facing, physics integration; `set_intent(dir, mag, sprint, speed?)`; team, `is_controlled`, cosmetic action cues. |
| `game/players/human_controller.gd` | Camera-relative device input → intent (`read_intent()`); `scripted` override for tests/captures. |
| `game/players/player_visual.gd` | Procedural body, run cycle/lean, carry/pass/catch poses, shirt number, control ring. |
| `game/camera/broadcast_camera.gd` | Side/end-on broadcast camera, look-ahead, critically-damped follow. |
| `game/ball/ball_tuning.gd` | Ball + possession parameters (from `data/tuning/ball.json`). |
| `game/ball/bounce_model.gd` | Pure, seeded oval-ball bounce + rolling friction. |
| `game/ball/pickup_model.gd` | Pure pickup reach, chance and fumble velocity. |
| `game/ball/rugby_ball.gd` | `RigidBody3D` (Jolt): LOOSE / HELD / DEAD, carry socket, bounce, out-of-bounds. |
| `game/ball/possession_controller.gd` | Who gets the ball: pickups (ground) and catches (air, at closest approach), fumbles/knock-ons, drops, placing; owns the BALL_CARRIER role. |
| `game/passing/passing_tuning.gd` | Passing + catching parameters (`data/tuning/passing.json`). |
| `game/passing/pass_targeting.gd` | Pure receiver selection (side, quick/skip, range, ahead limit). |
| `game/passing/pass_solver.gd` | Pure lead-the-receiver intercept, ballistic release velocity, aim error, forward-pass speed. |
| `game/passing/catch_model.gd` | Pure catch reach, closest-approach timing, chance, knock-on velocity. |
| `game/passing/passing_system.gd` | Charge/release, throw, pass-in-flight tracking, forward detection. |
| `game/ai/support_tuning.gd` | Support line parameters (`data/tuning/support.json`). |
| `game/ai/support_runner.gd` | Receiver dummies: staggered slots around the anchor, steering, receiver pace assist. |
| `game/tackling/tackle_tuning.gd` | Tackle + carrier-move parameters (`data/tuning/tackle.json`). |
| `game/tackling/tackle_model.gd` | Pure tackle resolution: power vs. resistance, outcomes, spills, carrier velocity after. |
| `game/tackling/tackle_system.gd` | Contact detection (incl. dive reach), applies outcomes, placement protection, dive-miss tracking. |
| `game/ai/defence_tuning.gd` | Defence + AI-carrier parameters (`data/tuning/defence.json`). |
| `game/ai/defensive_line.gd` | Pure defensive assignment: pursuer, man-for-man drift, sweepers, line speed, own-line clamp; with AI tuning: intercept-based pursuer, chase when beaten, cover, engage + dive decision. |
| `game/ai/attack_brain.gd` | M05 placeholder AI carrier (kept as AI level 0 for A/B soaks). |
| `game/ai/ai_tuning.gd` | M07 AI parameters (`data/tuning/ai.json`). |
| `game/ai/team_style.gd` | Tempo / width / aggression / passing (0–100) → support scale, decision speed, defence shape, passing appetite. |
| `game/ai/space_eval.gd` | Pure spatial reasoning: ray space, best line, space at a point, lane clearance, gaps, intercept time. |
| `game/ai/attack_ai.gd` | M07 attacking AI: carrier running line + carry/pass decision + reflexes; style-scaled support slots, flattening, gap seeking, inside support. |
| `game/match/team.gd` | Players + attack direction; attacker-relative left/right. |
| `game/match/team_control.gd` | One per team (human or AI): phase (attack/defend/loose), per-tick intents, pass/switch buttons, control follows the ball and turnovers. |
| `game/presentation/pass_markers.gd` | Floating Q·LB / RB·E labels over the current pass targets (yellow = charging, red = forward risk). |
| `game/ball/ball_visual.gd` | Oval mesh, cosmetic tumble, ground marker. |
| `ui/hud/match_hud.gd` | Player label, stamina bar, speed, possession tag, centre notices. |
| `game/debug/debug_overlay.gd` | F1 overlay: player, ball and pass state; vectors, pickup reach, predicted flight, support slots, pass aim + release line. |
| `game/match/match_bootstrap.gd` | Builds the scene (team mode or single-player sandbox), wires systems, dev hotkeys. |
| `tests/*` | Headless test runner + suites. |
| `tools/capture_screenshots.gd` | Scripted run that saves screenshots (visual regression aid). |
| `tools/pass_soak.gd` | 48 seeded backline moves (no defenders; `-- --opponents` to add them); completion / drops / forward passes. |
| `tools/tackle_soak.gd` | 24+24 seeded phases with tackling: broken / dominant rates, spills, metres, by matchup (`-- --verbose` lists every contact). |
| `tools/ai_soak.gd` | AI vs AI A/B matrix (placeholder vs M07 attack × defence): metres, tries, breaks, passes, tackles, turnovers. |
| `tools/defence_soak.gd` | 24+24 seeded phases (we attack / they attack): pressure, line breaks, turnovers, completion, metres (`-- --verbose` lists failures). |

## Per-tick order (60 Hz physics)

1. `TeamControl` ×2 (priority −10): each team's phase and intents (human /
   support runner / AttackAI slots + carrier decision / defensive line /
   loose-ball chaser) →
   `set_intent()`; human pass/switch buttons → `PassingSystem`.
2. `PassingSystem` (−9): charge timer, auto-release, throw (ball released
   this tick), pass-in-flight timeout.
3. `RugbyPlayer._physics_process` (0): stamina → stats → `LocomotionModel.step` →
   facing → `momentum_velocity` saved → `move_and_slide` (Jolt) → velocity read back.
3b. `TackleSystem` (3): carrier in contact with an opponent → TackleModel →
   ground players / place or spill the ball.
4. `PossessionController` (5): ball near the ground within reach → pickup;
   in the air at catch height → catch at closest approach.
5. `RugbyBall._physics_process` (10): held ball follows the carry socket;
   out-of-bounds check. Jolt then integrates the loose ball, and
   `_integrate_forces` resolves bounces/rolling with `BounceModel`.
6. Render frame (`_process`): camera, visuals, HUD, debug read interpolated state.

Physics interpolation is on, so motion is smooth at any display refresh rate
while gameplay stays fixed-step and deterministic.

## Planned layout (folders created when their milestone starts)

```
game/tackling/  game/rucks/  game/scrums/
game/lineouts/  game/kicking/  game/referee/  game/rules/
teams/{players,tactics,formations}/  competitions/  career/  audio/  animations/  assets/
```

Empty placeholder folders are deliberately **not** created now.

## Known architectural seams for upcoming milestones

- **Rules (M11):** `RugbyBall.released(by, velocity, reason)` and
  `went_dead(zone, point)` are the events the referee will consume
  (knock-on = forward release by hands; touch → lineout).
- **Rucks (M08):** `PossessionController.protect()` is the placeholder;
  a RuckSystem replaces it (bodies arriving at the tackle, contest, quick
  vs. slow ball).
- **AI (M07):** replaces `SupportRunner`/`DefensiveLine`/`AttackBrain`
  behind the same `set_intent()` API; can pass via `PassingSystem.throw_to()`
  and query `TackleModel.evaluate()` to judge contact.
