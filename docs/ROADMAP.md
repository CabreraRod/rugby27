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
| 08 | Rucks | ✅ | Rugby 08 rucks: commit with X, hold with □, turnovers, ball to the 9 |
| 09 | Kicking | ✅ | Rugby 08 kicks: ✕ long, □ high, △ grubber / box kick, ○ drop; blue arrow; chase and fielding |
| 10 | Scoring | ⏭ next | Tries, conversions, drop goals, penalty goals |
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

## Milestone 08 — Rucks ✅

Design goal (user decision, 2026-10-15): rucks play like Rugby 08. Fast,
readable, no mini-game, but a real contest both teams can bid on.

Delivered:
- **Ruck at the tackle** (`RuckSystem`): a held tackle (no spill) forms
  a ruck over the placed ball. The nearest support within 9 m and a
  defender on his feet within 3.5 m join on their own. Replaces the 2.5 s
  placement protection (TD-027): nobody picks the ball up off the floor
  while a ruck is on.
- **Commit with X (both teams)**: each tap sends the nearest free player
  running in (cap 4 a side). He binds when he gets there and only counts
  if he is bound before the contest is decided (1.4 s). Committed players
  are out of the line until the ruck ends (+0.5 s to get up).
- **Contest** (`RuckModel`, pure): bodies weighted by weight and strength,
  a jackal bonus for a defender over the ball first, and an attack bias
  (equal numbers ≈ 8 % turnover). Turnover → the nearest bound defender
  picks the ball up and runs.
- **Hold with □ (defence)**: needs a defender bound; while held the ball
  can't come out. Penalty hazard rises with seconds held (1 s ≈ 25 %,
  2 s ≈ 60 %, 3.5 s always). Placeholder until the referee (M11):
  PENALTY notice, ball to the attack's 9.
- **Ball out**: the attack's 9 (or the nearest free player if the 9 is
  down/committed) waits behind the ball and takes it out as soon as it is
  available; on the human's team you control the 9. The defence lines up
  2 m on its side of the ball (offside line) and marks only free attackers.
- **AI with the same tools**: the defence bids by aggression, isolated
  carrier and own-line proximity (2 players on an isolated carrier, 3–4
  otherwise) and sometimes holds; the attack answers a bid to stay one
  body ahead (misses the read 12 % of the time).
- New player state RUCKING (bound, no collisions, placeholder bent-over
  pose), RUCK phase in TeamControl/HUD ("RUCK 2 v 1 · X commit · □ hold"),
  debug readout, `data/tuning/ruck.json`, `tools/ruck_soak.gd`.
- Receivers bound in a ruck can't be passed to.
- Tests and soaks run with `--fixed-fps 60` (no real-time pacing: the
  suite takes ~30 s instead of ~3 min). 138 automated tests (+15).

Measured (`tools/ruck_soak.gd -- 16`):

AI vs AI, 32 attacks of 20 s: 139 rucks; ball out in 1.8 s on average.

| | result |
|---|---|
| retention with normal support | 81 / 84 (96 %) |
| isolated carrier (no support could bind in time) | lost 11 / 49 (22 %) |
| AI defence bids | 47, won 13 (28 %) |
| AI holds / penalties | 6 / 0 |
| all rucks | 14 turnovers in 139 (90 % kept) |

Scripted contests (48 per cell, ruck AI off; support 3–9 m away, defence
4–12 m; "isolated": support 14+ m away, a defender on the ball):

| scenario | defence taps | attack taps 0 | 2 | 4 |
|---|---|---|---|---|
| normal | 0 | 0 % | 0 % | 0 % |
| normal | 4 | 66 % | 6 % | 12 % |
| isolated | 0 | 54 % | 45 % | 45 % |
| isolated | 4 | 87 % | 91 % | 97 % |

Bodies that arrive late don't count: 4 attacking taps put 3 bodies in
(the 4th is too far), and an isolated carrier's support can't get there
however often you press X.

Holding the ball in, penalised: 0.5 s 10 %, 1 s 25 %, 1.5 s 42 %,
2 s 62 %, 3 s 85 %.

Effect on open play (`tools/ai_soak.gd`, NEW vs NEW, 10 s attacks):
43 m / 8 tries → 13 m / 0 tries, 28 → 47 passes, 15 → 43 tackles. M07's
numbers came partly from the placement window: a support player picked
the ball up instantly while the tacklers were still on the floor and the
defence out of shape. Now each tackle costs ~1.8 s and the defence
reforms onside, so attacks go phase by phase. Watch this at 15 v 15
(M12) and in the playtest.

Not done (by design / next):
- the 9's box kick over the ruck (△) comes with kicking (M09);
- real penalties, offside and sealing off are refereed in M11;
- the score doesn't change AI commits yet (no score until M10);
- ruck animation is a placeholder pose (TD on animation sourcing stands);
- 6 v 6 leaves support far away: 35 % of rucks were "isolated". Expect
  fewer at 15 v 15 with forwards.

## Milestone 09 — Kicking ✅

Design (user, 2026-10-16, from how Rugby 08 played): every kick is held
to charge and released; a blue arrow on the pitch shows where it goes.

| Button (PS · Xbox · keys) | Kick |
|---|---|
| ✕ · A · Space | long kick: clearances, touch-finders; range grows with the kicker |
| □ · X · V | high kick: a parabola, higher and further the more you charge |
| △ · Y · F | grubber along the ground; **the 9 at the base of a ruck: box kick** |
| ○ · B · G | drop goal at the posts: release in the green; too little falls short, too much flies wide |

Delivered:
- `KickModel` (pure): flights simulated with the ball's gravity and air
  damping (the arrow and the AI see the real landing; measured within
  ~0.7 m of the physics), a launch-speed solver, charge → distance by
  kick type and kicking attribute, accuracy by kicking attribute, the drop
  goal's sweet spot (window widens with skill, narrows with distance;
  range limit by skill), kick-catch chance (handling, running, contested).
- `KickSystem`: hold/aim/release API used by the human and the AI,
  overhold auto-kick, cancelled if tackled, kicker can't catch his own
  kick off the boot, flight tracking (catch point, landing), drop goal
  detection through the posts.
- `KickArrow`: Rugby 08's blue arrow while charging; a yellow ring where a
  kick in the air comes down. HUD kick meter (type, metres; the drop goal
  shows its green zone).
- KICK phase: the receiving team's best-placed player goes under the ball
  (the human gets him), the rest support; the kicking team's onside
  players chase (two sprint at it) and the rest come up as a line.
- AI kicking (team style gains a fifth number, `kicking`): box kicks from
  the base of a ruck in its own half, clearances to touch from its own 22
  under pressure, grubbers in behind a flat line, the odd up and under.
- Fend moved to LT + ✕ (Rugby 08's skill-move modifier) because □ kicks.
  Dev keys moved off the face buttons (F6 drop ball, F7 go to ground).
- Notices: DROP GOAL! / DROP MISSED / REGATHERED; catching a kick is not
  a "turnover".
- 153 automated tests (+15).

Measured (`tools/kick_soak.gd -- 16`):

Range and spread (first landing, 200 kicks each):

| kick (charge) | kicking 30 | kicking 60 | kicking 90 |
|---|---|---|---|
| long (full) | 48 m (sd 4.6, lateral 4.6) | 54 m (4.0, 3.5) | 61 m (2.9, 2.3) |
| long (half) | 32 m (3.1, 2.9) | 35 m (2.5, 2.4) | 38 m (1.8, 1.2) |
| high (60 %) | 23 m (1.9, 2.1) | 25 m (1.8, 1.6) | 27 m (1.2, 0.9) |
| box (60 %) | 18 m (1.7, 1.6) | 20 m (1.4, 1.4) | 21 m (0.9, 0.7) |
| grubber (60 %) | 11 m (2.1, 1.0) | 13 m (1.8, 0.8) | 14 m (1.4, 0.5) |

Drop goals in front of the posts, kicking 88, by charge error:

| distance | window | exact | ±0.05 | ±0.10 | ±0.20 |
|---|---|---|---|---|---|
| 20 m | ±0.15 | 100 % | 100 % | 100 % | 0 % |
| 30 m | ±0.10 | 100 % | 100 % | 84 % | 0 % |
| 38 m | ±0.08 | 100 % | 100 % | 1 % | 0 % |
| 44 m | ±0.07 | 100 % | 100 % | 0 % | 0 % |

A weak kicker (30) can't reach 35 m at all; a great one tops out ~45 m.

Fielding a high kick: uncontested, the receivers catch 19/20 (1 knock-on).
Kicked into space with the receivers 50 m away and the chase level with
the kicker: 12 caught, 1 dropped, 7 bounced before anyone got there; the
kickers never regathered (they chase from a standstill).

AI vs AI (32 attacks of 20 s): 13 box kicks, 2 grubbers; 10 kicks caught
by the receivers. Open play is unchanged (ai_soak NEW vs NEW 14 m, 40
tackles; ruck retention 95 %).

Not done (by design / next):
- drop goals are detected but score nothing until M10; conversions and
  penalty goals (with Rugby 08's goal-kick meter) come with scoring;
- kicking to touch from a penalty, 50:22, kick-offs and restarts need the
  referee and set pieces (M11/M13/M14); out of touch is still a dev restart;
- offside at kicks (players in front of the kicker) is refereed in M11;
- chasers rarely regather an up and under: watch in the playtest;
- the AI doesn't attempt drop goals yet (needs the score, M10).

