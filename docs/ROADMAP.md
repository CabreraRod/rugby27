# Rugby 27 — Roadmap

Every milestone ends in a playable build, passing tests, updated docs, and a
stop for review. No skipping ahead.

| # | Milestone | Status | Done when |
|---|---|---|---|
| 01 | Empty field + camera | ✅ | Pitch, posts, lighting, broadcast camera |
| 02 | One controllable player | ✅ (joystick playtest pending) | Movement passes feel targets and feels good in hand |
| 03 | Ball + possession | ✅ | Ball is a physics object; pick up, carry, drop, bounce, out of bounds |
| 04 | Passing | ✅ | A→B→C→D chain without fighting controls; forward pass detection |
| 05 | Multiple players | ⏭ next | Second team, switching on defence, camera focus solver |
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

## Milestone 04 — Passing ✅

Delivered (option A — receiver dummies): six-player backline from data;
support lines that reform after every pass; tap/hold passing to the
attacker's left/right with lead solving, accuracy and pass-into-space;
control switch at release with receiver pace assist; catching at closest
approach with knock-ons; forward-pass detection; pass target labels; shirt
numbers; pass/catch poses; F2 single-player sandbox. 85 automated tests;
soak: 97 % completion, 0 forward passes.

Not done (by design): rulings for knock-on/forward pass (M11), opponents
and interceptions (M05), real support AI (M06), manual player switching.

## Milestone 05 — Multiple players (next)

Scope proposal:
- A second team from data (attack_dir −1, other kit), 6 v 6 to start.
- Opponents controlled by simple placeholder defenders: a flat line that
  holds the gain line and drifts with the ball (no tackling yet — M07).
- Interceptions: opponents can catch passes (the existing catch rules).
- Manual switching when your team doesn't have the ball (nearest to ball /
  cycle), and the "possession changes team" flow.
- Camera focus solver: frames ball + carrier + nearest defenders instead of
  only the controlled player.
- Debug: defensive line, which player each defender marks.

Decided (2026-10-05): **the human always controls the same team** and
switches players within it on turnovers.

From the Rugby 08 research (docs/RESEARCH_RUGBY08.md): the most common
"too easy" complaint was weak AI defence giving fast backs space. M05's
placeholder defence should already drift and track speed, and a soak
should measure line breaks.
