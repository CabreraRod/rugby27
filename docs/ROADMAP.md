# Rugby 27 — Roadmap

Every milestone ends in a playable build, passing tests, updated docs, and a
stop for review. No skipping ahead.

| # | Milestone | Status | Done when |
|---|---|---|---|
| 01 | Empty field + camera | ✅ | Pitch, posts, lighting, broadcast camera |
| 02 | One controllable player | ✅ (pending playtest sign-off) | Movement passes feel targets and feels good in hand |
| 03 | Ball + possession | ⏭ next | Ball is a physics object; pick up, carry, drop, bounce, out of bounds |
| 04 | Passing | | A→B→C→D chain without fighting controls; forward pass detection |
| 05 | Multiple players | | Switch control between teammates; camera focus solver |
| 06 | Basic AI | | AI controllers use `set_intent()`; support lines, simple defence |
| 07 | Tackling | | Tackle outcome from speed/angle/strength/timing; break tackles |
| 08 | Rucks | | Tackle → ground → ruck → ball available, contest, turnover |
| 09 | Kicking | | Punt, grubber, chip, high, touch-finder; kick chase |
| 10 | Scoring | | Tries, conversions, drop goals, penalty goals |
| 11 | Rules | | Referee: knock-on, forward pass, offside, advantage, touch |
| 12 | 15v15 match | | Two teams play a full match start to finish |
| 13 | Scrums | | Simplified engagement, push, stability, put-in |
| 14 | Lineouts | | Throw, jump, contest |
| 15 | Team tactics | | Style parameters measurably change AI behaviour |
| 16 | Match presentation | | Scoreboard, clock, try presentation, replays |
| 17 | Tournament | | Pools + knockouts, World Cup format |
| 18 | Career | | Squad, development, transfers, seasons |
| 19 | Editor | | Players/teams/kits/competitions via data, no code |
| 20 | Polish | | Audio, animation upgrade, performance, UX |

The first task bundled milestones 01 and 02 (field + one player).

## Milestone 03 — Ball + possession (next)

Scope:
- `game/ball/rugby_ball.gd`: `RigidBody3D` (Jolt) with prolate-spheroid
  collision approximation and believable, slightly random bounce.
- Possession states: `HELD`, `LOOSE`, `IN_FLIGHT`, `DEAD`.
- Held ball attaches to a carry socket (no physics while held).
- Pickup when a player runs over a loose ball (attribute-based success,
  slower at speed).
- Dev drop/fumble key to create loose ball situations.
- Out-of-bounds detection (touch / dead-ball) using `FieldDimensions`.
- `Role.BALL_CARRIER` set automatically by possession.
- Debug: possession owner, ball state, predicted bounce trajectory.
- Tests: bounce behaviour stays in plausible ranges, possession transitions,
  out-of-bounds detection.

Explicitly out of scope: passing, kicking, knock-on rulings (need M04/M11).

Hard problem to flag early: a rugby ball's bounce is erratic because of its
shape. A fully simulated ellipsoid looks chaotic and is hard to make *fair*;
a sphere looks fake. Plan: sphere-ish collision + controlled random spin and
bounce deflection, tuned in data, so it's unpredictable but readable.
