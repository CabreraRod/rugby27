# Rugby 27 — Roadmap

Every milestone ends in a playable build, passing tests, updated docs, and a
stop for review. No skipping ahead.

| # | Milestone | Status | Done when |
|---|---|---|---|
| 01 | Empty field + camera | ✅ | Pitch, posts, lighting, broadcast camera |
| 02 | One controllable player | ✅ (joystick playtest pending) | Movement passes feel targets and feels good in hand |
| 03 | Ball + possession | ✅ | Ball is a physics object; pick up, carry, drop, bounce, out of bounds |
| 04 | Passing | ⏭ next | A→B→C→D chain without fighting controls; forward pass detection |
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

## Milestone 03 — Ball + possession ✅

Delivered: Jolt ball with controlled oval bounce, rolling, posts/boards
collisions; LOOSE/HELD/DEAD; automatic pickup with handling/speed risk and
fumbles; carry socket + carry pose; drop and ground placement; touch,
touch-in-goal and dead-ball detection (ball in the air over touch stays
live); HUD notices; debug flight prediction. 53 automated tests.

Not done (by design): passing, kicking, knock-on rulings, restarts.

## Milestone 04 — Passing (next)

**Ordering problem to decide first:** passing needs receivers, but
multiple players are M05 and AI is M06.

- Option A — M04 adds *receiver dummies*: teammates that hold a simple
  attacking line and run straight at a set depth (no decision-making).
  Control switches to the catcher. Minimal overlap with M05.
- Option B — swap M04 and M05 (multiple players + switching first).
- Option C — pass to fixed targets/cones only (tests the mechanic, not the
  feel of A→B→C→D).

**Recommendation: A.** It's the smallest thing that lets the
"A→B→C→D without fighting the controls" goal be felt, and the dummies are
replaced by real AI in M06 through the same `set_intent()` API.

Scope (with A):
- Pass left / pass right buttons (LB/RB), tap = quick pass, hold = longer.
- Target selection: nearest sensible receiver on that side (depth/width),
  with a debug view of the choice.
- Pass flight: release velocity solved to meet the receiver's predicted run;
  accuracy from passing attribute, pressure-free for now.
- Catching: catch chance from handling, ball speed and body angle; drops
  become loose balls (knock-on detection logged, ruling in M11).
- Forward-pass detection relative to the passer's motion (logged + notice).
- Tests: pass reaches a running receiver, chain of 3 passes, forward pass
  detected, catch failure produces a loose ball.
