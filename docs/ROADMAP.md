# Rugby 27 — Roadmap

Every milestone ends in a playable build, passing tests, updated docs, and a
stop for review. No skipping ahead.

| # | Milestone | Status | Done when |
|---|---|---|---|
| 01 | Empty field + camera | ✅ | Pitch, posts, lighting, broadcast camera |
| 02 | One controllable player | ✅ (joystick playtest pending) | Movement passes feel targets and feels good in hand |
| 03 | Ball + possession | ✅ | Ball is a physics object; pick up, carry, drop, bounce, out of bounds |
| 04 | Passing | ✅ | A→B→C→D chain without fighting controls; forward pass detection |
| 05 | Multiple players | ✅ | Second team, switching on defence, camera focus solver |
| 06 | Basic AI | ⏭ next | Real attacking/defensive decisions replacing the placeholders |
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

## Milestone 05 — Multiple players ✅

Delivered: 6 v 6 from data (second squad + team file, attack −X); the
human always controls the same team; placeholder defence that moves as a
structure (pursuer on the carrier, man-for-man drift on the inside
shoulder, sweeper, line speed, never behind its own try line); placeholder
AI carrier that runs, veers and passes under pressure; loose-ball chasing;
interceptions (harder than a normal catch, not at the release, occasional
knock-downs); turnovers flip phases and move control to our player nearest
the ball; LB/RB switch player on defence; camera frames ball + controlled
player; HUD phase tag; debug view of marks. 96 automated tests.

Measured (tools/defence_soak.gd, 24 runs each, no tackling yet):
- We attack: carrier pressured 74 % of the time, 0 line breaks, 66/70
  passes completed, 1 turnover.
- They attack: 0 line breaks, 38/44 passes completed, 3 turnovers.
Passing without defenders (tools/pass_soak.gd, 48 runs): 92 %, mostly
long skip passes dropped by the 12.

Known placeholder behaviour: without tackles the pursuer stops a
carrier who runs straight into him (body contact). Go round him; M07
replaces this with tackles.

## Milestone 06 — Basic AI (next)

Scope proposal:
- Attacking AI with decisions: run lines into space (not just slots),
  pass/carry choice from space and defenders, depth, inside/outside
  support, and a simple kick decision placeholder until M09.
- Defensive AI decisions on top of the M05 structure: rush vs. drift
  choice by situation, inside cover, retreat when broken, pursuit angles.
- Team-style parameters plumbed in (tempo, width) so M15 can tune them.
- Soaks: AI vs AI matches measuring metres, breaks, turnovers, pass
  completion — the numbers must move when the AI improves.

Open question: M06 before M07 (tackling) means the AI can't yet tackle,
and attacking decisions depend heavily on contact. Option: swap M06 and
M07 so the AI is built against real contact. **Recommendation: swap**
(tackling first). Decision for the user.
