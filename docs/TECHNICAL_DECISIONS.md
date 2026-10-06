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

## TD-015 Receiver dummies before real AI (roadmap option A)

- **Why:** passing needs receivers; the roadmap has multiple players in M05
  and AI in M06. The user chose option A: minimal support runners now.
- **How:** `SupportRunner` slots + steering, driven by `TeamControl` through
  `set_intent()` — the exact API M06 AI will use.
- **Trade-off:** some M05 work (a team, control switching) landed early.

## TD-016 Control switches at release + receiver pace assist

- **Why:** chaining A→B→C→D is only fluid if you steer the receiver while
  the ball travels. But the pass is aimed at the receiver's *current* run;
  any change of pace the player didn't mean (e.g. holding forward without
  sprint) made the ball miss. Measured: first soak 78 % completion.
- **How:** during the flight the receiver's exact speed and direction are
  held unless the stick turns > 45°. Required a `speed` parameter on
  `set_intent` (hold a pace between jog and sprint).
- **Trade-off:** < 1 s of reduced fine control on the receiver. A hard turn
  always wins, so it never feels like the game is fighting the player.

## TD-017 Catches judged at closest approach

- **Why:** judging on the first tick inside reach evaluated the catch at the
  edge (worst height/angle) and caused unfair drops.
- **Trade-off:** none found; it's also closer to how hands meet a ball.

## TD-018 Passes are pure physics after release (no homing)

- **Why:** spec ("don't fake ball movement"); misses must have readable
  causes. Accuracy and receiver behaviour are tuned instead.
- **Trade-off:** completion depends on good lead prediction — covered by
  `tools/pass_soak.gd` and regression tests.

## TD-019 Attacker-relative pass directions

- **Why:** screen-relative left/right breaks with the end-on camera and
  when attacking the other way.
- **Trade-off:** on the side camera "left" means the far side of the
  screen, which needs a moment to learn. Playtest; a setting is cheap.

## TD-020 One TeamControl per team, human or AI

- **Why:** both teams need the same phase logic (attack/defend/loose); the
  only difference is who drives the controlled player.
- **Trade-off:** TeamControl grows; M06 should split decision-making out
  into per-role brains so it stays a dispatcher.

## TD-021 Placeholder defence as one structure with line speed

- **Why:** research — Rugby 08's AI gave fast backs space. Copying a mark's
  full velocity made the line backpedal forever (measured: it retreated
  past its own dead-ball line); copying only the sideways part brings it
  up to meet the attack.
- **Trade-off:** without tackles the pursuer blocks the carrier bodily.

## TD-022 Interceptions are rare by design

- **Why:** with an advancing line, defenders are always near passing lanes.
  Same catch odds as receivers produced ~14 % turnovers per pass;
  interceptions now use 15 % of the catch chance, never at release.
- **Trade-off:** reading a pass and stepping in is less rewarding; M06/M07
  may add a deliberate "jump the pass" action with risk.

## TD-023 Soaks use hashed seeds

Neighbouring PCG seeds produced correlated first draws (5/12 runs hitting
an 8 % roll). All soaks now seed with `hash("…-%d" % run)`.

## TD-024 Tackling before AI (milestone swap)

User decision (2026-10-05): M06 tackling, M07 basic AI.

## TD-025 Tackle = contact + pure probabilistic model

- **Why:** accessible (Rugby 08's "steer into them"), readable causes
  (mass, speed, angle, skill, fend/sidestep/dive), tunable in data, and
  calibrated against real tackle success rates by a soak.
- **Trade-off:** outcomes are dice rolls on top of physics, not ragdoll
  physics. Gameplay speed stays high (spec §9).

## TD-026 Momentum read before collisions

`move_and_slide` clips the velocity of bodies pushing into each other, so
contact read ~0 m/s. Players store `momentum_velocity` before the slide;
tackles use it.

## TD-027 Placement protection as a ruck placeholder

Without rucks, opponents arriving at the placed ball won it back after
most tackles (seed bug aside, protection of 0.8 s was too short). 2.5 s
for the tackled team until M08.

## TD-028 Random seeds in real play

Fixed seeds made every match identical (the first tackle in a dev match
was always a knock-on). The match scene randomizes when it is the current
scene; tests/tools keep fixed or hashed seeds.

## Open questions / risks

- **Movement playtest still pending.** M03/M04 started at the user's
  request before the joystick feel test; movement numbers are unchanged
  since M02. F2 opens the single-player sandbox for that test.
- **Pass direction mapping** (attacker-relative) needs a playtest verdict.

- **Feel can only be partly verified by tests.** Numbers guarantee
  consistency; "satisfying" needs hands-on playtesting with keyboard and pad.
- **Animation:** procedural limbs now carry tackles (dive/wrap/fall poses)
  but will not scale to rucks/scrums. Animation sourcing (licensed mocap
  vs. hand-keyed vs. procedural + physical animation) must be decided
  before M08/M13.

## TD-029 AI decisions compare like with like (metres of room)
The AI carrier first scored carry on ray space (up to 20 m plus a straight
bonus) and passes on receiver space (capped 12 m, lane-penalised). The two
scales didn't match, and the carrier almost never passed (one-out
carries; the decision log showed carry 10–21 against pass −1–5). Now both
are "metres of room": carry room is capped by the distance to the
imminent tackler and by the same cap as receivers, and the break bonus
only counts as contact nears. This is simple and readable in the debug
overlay. The tradeoff: it is a heuristic, not a learned or searched
policy. That is enough for M07; patterns and set moves come in M15.

## TD-030 Pursuit by intercept time, not distance
The defender sent at the carrier is whoever can meet him soonest
(SpaceEval.intercept_time with his sprint speed), not the nearest man.
Nearest-distance selection flipped to slower defenders already behind
the carrier and let wings run 55 m. Beaten defenders keep chasing on an
intercept line.

## TD-031 Team style as four numbers with explicit mappings
TeamStyle (tempo, width, aggression, passing) maps to concrete parameters
(support spacing/depth, think interval, defensive line speed/retreat/
engage distance, pass margin), documented in team_style.gd and tested.
Each team gets its own styled copies of the shared tunings, so F5 reload
and tests still use one JSON source.

## TD-032 AI level switch kept for A/B soaks
TeamControl.ai_level 0 = M05 placeholders, 1 = M07 AI (default). Keeping
the old behaviour lets tools/ai_soak.gd prove the AI improved (spec:
"the numbers must move"), at the cost of some dead code until M15.
