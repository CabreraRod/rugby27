# Rugby 27 — Technical Decisions

Format: decision · why · trade-off.

## TD-001 Engine: Godot 4.4 (standard, GDScript)

- **Why:** spec default; free/open-source (no royalties or asset-licence
  issues); full 3D, physics, animation tree, navigation, input, UI and audio;
  text-based scenes/resources diff well and are friendly to AI-assisted work;
  runs headless for automated tests.
- **Environment found:** Linux x86_64, no engine pre-installed. Godot 4.4.1
  official binary used for headless import, tests and screenshots.
- **Trade-off:** smaller sports-game ecosystem than Unreal/Unity; animation
  retargeting and crowd rendering will need more custom work.
- **Minimum version:** 4.4 (built-in Jolt, 3D physics interpolation).

## TD-002 Language: GDScript (typed)

- **Why:** fast iteration, hot-reload, no build step; typed GDScript catches
  most errors at parse time.
- **Trade-off:** slower than C#/C++. If AI for 30 players becomes a
  bottleneck, hot paths move to C# or a GDExtension — the pure-core design
  (`LocomotionModel`) makes that a contained change.

## TD-003 Physics: Jolt, 60 Hz fixed step, physics interpolation on

- **Why:** Jolt is more stable/performant than GodotPhysics, which will matter
  for the ball and many bodies. Fixed 60 Hz keeps gameplay deterministic;
  interpolation keeps rendering smooth on 120/144 Hz displays.
- **Trade-off:** Jolt is flagged experimental in 4.4. Fallback: switch
  `physics/3d/physics_engine` to `DEFAULT` — no code depends on Jolt APIs.

## TD-004 Players are `CharacterBody3D`, not rigid bodies

- **Why:** responsive, predictable control needs kinematic movement we
  fully own. Physical "weight" comes from the acceleration/turn/plant model.
- **Trade-off:** contact physics (tackles, rucks, scrums) won't come for free;
  they will be designed systems that resolve contact explicitly. That is
  intentional: it keeps gameplay readable and tunable (spec §9).

## TD-005 Movement maths is a pure, node-free model

- **Why:** deterministic, unit-testable feel targets; shared by human and AI;
  portable to C# if needed.
- **Trade-off:** one small indirection layer between node and maths.

## TD-006 Movement tuning in JSON with hot-reload (F5)

- **Why:** feel is iterated by playing, not by recompiling. Code defaults
  mirror the JSON, and a test fails if they drift.
- **Trade-off:** two places hold the defaults (guarded by that test).

## TD-007 Procedural everything (no third-party assets yet)

- Pitch markings are drawn analytically in a shader (crisp, no textures).
- Player body is primitive meshes with a procedural run cycle and lean.
- **Why:** zero licensing risk, fast iteration, and it forces gameplay to be
  good before art makes it look good.
- **Trade-off:** placeholder look. A skinned character + `AnimationTree`
  replaces `PlayerVisual` later behind the same read-only contract.

## TD-008 Input actions registered in code

- **Why:** reviewable diffs, both keyboard and gamepad from day one; user
  remaps in project settings are respected (existing actions aren't touched).

## TD-009 No unit-test framework dependency

- **Why:** a ~50-line runner (`tests/run_tests.gd`) runs headlessly in CI
  with no addons.
- **Trade-off:** fewer features than GUT/gdUnit4; can migrate later.

## TD-010 Field geometry: World Rugby Law 1 maxima

100 m × 70 m field of play, 10 m in-goals, posts 5.6 m apart, crossbar 3 m.
5 m / 15 m lines are drawn as continuous dashes (real pitches use short
marks) — readability over pedantry; revisit for set pieces.

## TD-011 Ball = Jolt RigidBody3D + scripted bounce response

- **Why:** the spec asks for a physical ball, not teleportation. Jolt gives
  flight, collisions with posts/boards and CCD for free.
- **How:** sphere collision, friction/bounce 0 in the physics material,
  rotation locked; `_integrate_forces` detects ground impacts and applies
  `BounceModel` (seeded RNG) and rolling friction.
- **Trade-off:** the bounce isn't "true" ellipsoid physics. That's
  deliberate: controlled randomness is readable and fair, and every
  parameter is data. Seeded RNG keeps tests (and future replays) deterministic.

## TD-012 Ball does not physically collide with players

- **Why:** physical pushes from kinematic players make the ball erratic and
  unreadable. Pickups, fumbles and (later) catches/interceptions are
  gameplay decisions with clear causes.
- **Trade-off:** no accidental "ball hits shin" physics. It can be faked
  deliberately later (e.g. a charge-down) as a rule.

## TD-013 Automatic pickup with attribute-based risk

- **Why:** classic console rugby keeps pickups button-free so play flows;
  risk comes from speed/handling instead of an extra input.
- **Trade-off:** less player agency over *when* to gather. Revisit with
  playtesting (a "secure/dive" button is cheap to add).

## TD-014 Sun from the camera side

Broadcast-style front lighting: players read better, and the far stand's
shadow stays off the pitch (the original back-lit setup put a dark band
over the near touchline).

## Open questions / risks

- **Movement playtest still pending.** M03 started at the user's request
  before the joystick feel test; movement numbers are unchanged since M02.

- **Feel can only be partly verified by tests.** Numbers guarantee
  consistency; "satisfying" needs hands-on playtesting with keyboard and pad.
- **Animation:** procedural limbs will not scale to tackles/rucks/scrums.
  Needs a decision on animation sourcing (mocap packs with suitable licence
  vs. hand-keyed vs. procedural + physical animation) before Milestone 07.
