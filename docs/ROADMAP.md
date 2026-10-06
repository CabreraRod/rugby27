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
| 06 | Tackling (swapped with AI) | ✅ | Tackle outcome from speed/angle/strength/timing; break tackles |
| 07 | Basic AI (swapped with tackling) | ✅ | Real attacking/defensive decisions replacing the placeholders |
| 08 | Rucks | ⏭ next | Tackle → ground → ruck → ball available, contest, turnover |
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

## Milestone 06 — Tackling ✅ (swapped with Basic AI on 2026-10-05)

Swapped at the user's decision: AI decisions depend on contact, so the
AI is built against real tackling.

Delivered: data-driven player weights; pure TackleModel (mass^0.7,
bracing + closing speed, tackling skill vs. strength, head-on/side/behind,
dive, fend, sidestep) with outcomes HELD / DOMINANT / BROKEN and tackle
spills; contact = steering into the carrier (Rugby 08 style); dive tackle
(extra reach, a miss leaves you on the floor); fend (X) and sidestep
(right-stick flick) with cooldowns; tackled players go down sliding
forward (or driven back on a dominant hit); ball placed with a
protection window for the tackled team (placeholder until M08 rucks);
defenders commit into the tackle in the last 3 m; AI carriers fend;
control moves off a grounded player; camera shake on impact; poses for
dive/fend/tackle; notices (BIG HIT, TACKLE BROKEN, MISSED, KNOCK-ON);
debug tackle readout; real matches use random seeds. 111 tests.

Measured (tools/tackle_soak.gd, 24 + 24 phases):
- We attack: 54 tackles, 11 % broken, 11 % dominant, 4 spills.
- They attack: 55 tackles, 22 % broken, 0 % dominant, 3 spills. (Most
  of these are the soak's scripted human chasing the carrier from behind,
  which the model makes weaker by design; M07's AI defence will tell.)
Pro rugby misses ~10–15 % of tackles; dominant tackles ~10 %. Spills ran
above the designed 2–8 % in both scenarios (7 in 109): watch in M07.

Bugs found by measuring: tackle speeds were read after physics
collisions had clipped them (players in contact read 0 m/s); defenders
committing to the tackle were backing off with the carrier; soaks shared
one tackle seed (every first tackle was a knock-on).

## Milestone 07 — Basic AI ✅

Delivered:
- **Spatial reasoning** (`SpaceEval`, pure): space down a running line,
  best line among 7 rays (±45°, touch-avoiding), space around a point,
  passing-lane clearance, defensive gaps, intercept time.
- **Attacking AI** (`AttackAI`): the AI carrier re-thinks every
  0.15–0.4 s (team tempo × decision making). It picks a running line into
  space (with hysteresis) and weighs carry against pass on one scale,
  metres of room. Carry = room down his line, capped by the gap to the man
  about to tackle him, plus a P(break) bonus from `TackleModel.evaluate`
  that grows as contact nears. Pass = room around the receiver − risky
  lane − forward risk − giving back too much ground. Passing appetite
  comes from team style, and noise from the player's decision making.
  Reflexes: sidestep into room head-on, fend at contact.
- **Support play**: style-scaled support line (width → spacing, tempo →
  depth), flattening onto the ball as the defence nears, sliding toward
  defensive gaps, and one inside-support runner.
- **Smarter defence**: the pursuer is whoever can intercept the carrier
  soonest, not the nearest man. Beaten defenders chase on an intercept
  line. A spare defender covers inside and behind. The tackler engages
  at the ball and dives when the carrier is in reach and escaping
  (cooldown). Line speed, retreat and engage distance come from team
  aggression.
- **Team styles** (`TeamStyle`, data/teams/*.json): tempo, width,
  aggression and passing change behaviour now (spec §13; M15 tunes them).
- `data/tuning/ai.json`, debug overlay (running line, inside runner,
  chase/cover colours, AI decision text), `tools/ai_soak.gd`.
- 123 automated tests (+12).

AI vs AI soak (`tools/ai_soak.gd`, 16 seeded attacks of ≤10 s from the
lineup, 6 v 6):

| attack vs defence | metres | tries | breaks | passes (compl.) | tackles (broken) | turnovers |
|---|---|---|---|---|---|---|
| old vs old | 55.0 | 16 | 0 | 16 (15) | 2 (1) | 0 |
| NEW vs old | 16.8 | 1 | 1 | 37 (30) | 35 (15) | 2 |
| old vs NEW | 25.7 | 1 | 1 | 16 (15) | 67 (4) | 2 |
| NEW vs NEW | 43.3 | 8 | 3 | 28 (24) | 15 (3) | 2 |

The old placeholder defence let the wing run 55 m almost every time (its
pursuer flipped to a slower man behind the play), so "old vs old" scores
look good only because the defence was broken. The M07 defence stops the
old attack (16 → 1 tries); the M07 attack moves the ball (28 passes,
86 % to hand) and makes real breaks against it.

Not done (by design / next):
- kick decisions (M09);
- support arriving at the tackle (M08 rucks);
- tactical patterns and set moves (M15);
- tuning against human play (needs the joystick playtest).
- 6 v 6 on a full-width pitch leaves a lot of space, so try rates will
  drop at 15 v 15 (M12).

## Milestone 08 — Rucks (next)
Scope proposal: tackle → tackled player places the ball → nearest
support/defenders commit (AI decides how many) → contest from bodies,
weight and timing → ball available to the 9 (or turnover / penalty
placeholder) → play restarts from the ruck with a fresh defensive line.
Replaces the 2.5 s placement protection (TD-027).
