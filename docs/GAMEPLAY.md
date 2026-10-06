# Rugby 27 — Gameplay Design

## North star

After five minutes the player should think *"I'm actually playing rugby"*,
not *"I'm controlling animations"*. Input → simulation → visual feedback
must happen in the same tick, every time.

## Movement (Milestone 01)

### Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move (camera-relative) | WASD / arrows | Left stick (analog: walk → jog) |
| Sprint | Shift | RT / R2 |
| Pass to the attacker's left (tap quick, hold long) | Q | LB / L1 |
| Pass to the attacker's right (tap quick, hold long) | E | RB / R1 |
| Defending: switch to the teammate nearest the ball | Q or E | LB or RB |
| Defending: tackle | run into the carrier | run into the carrier |
| Defending: dive tackle | Space | A / Cross |
| Carrying: fend (hand-off) | V | X / Square |
| Carrying: sidestep left / right | Z / X | right stick flick |
| Toggle camera (side / end-on) | C | Back/View |
| Debug overlay | F1 | — |
| Toggle single-player sandbox / team mode | F2 | D-pad up |
| Dev: go to ground | G | B / Circle |
| Dev: toggle neutral/defender (when not carrying) | B | — |
| Dev: drop the ball (forward, knock-on style) | F | — |
| Dev: toss a bouncing ball toward you | T | D-pad down |
| Dev: next profile for the controlled player | N | Y / Triangle |
| Dev: reset lineup + ball | R | Start |
| Dev: hot-reload all `data/tuning/*.json` | F5 | — |

Sprint moved from RB to RT only in M04 (RB passes).

### Feel model

- **Instant first step.** From standstill the player moves on the very first
  tick in exactly the stick direction. No wind-up animation.
- **Punchy start, weighty top end.** Acceleration fades as
  `(speed / top)^1.6`; jog reached in ~0.8 s, 90 % sprint in ~1.5 s.
- **Speed-dependent turning.** 900 °/s when slow, 230 °/s at full sprint.
  Joggers step; sprinters carve.
- **Plant-and-cut.** Reversing (>115°) above 3.2 m/s brakes hard first
  (26 m/s²) and then pivots. Momentum matters, but it resolves in < 1 s.
- **Turning costs speed.** Up to 22 % while the body is 90° off target.
- **Releasing sprint eases down** (6 m/s²) — it doesn't feel like a brake.
- **Letting go stops you** in ~0.7 s / ~3.5 m from full sprint.
- **Facing is separate from velocity** (needed later for passing/tackling),
  rate-limited and turns on the spot when stationary.

### Feel targets (enforced by `tests/test_locomotion.gd`)

| Target | Value (fly-half: spd 82, acc 84) |
|---|---|
| First tick direction | exactly the input direction |
| Time to jog speed | 0.4 – 0.9 s |
| Time to 90 % sprint | 1.4 – 3.2 s |
| Sprint top speed | 9.0 – 9.8 m/s (≈ 34 km/h) |
| Stop from sprint | 0.5 – 0.9 s, 2.0 – 4.5 m |
| 90° cut at jog | ≤ 0.35 s |
| Sprint reversal | plants, recovers in 0.4 – 1.4 s |
| Wing vs prop top speed | > 1.5 m/s apart |

Changing a target is a design decision — update this table in the same commit.

### Attributes used so far

- `speed` → sprint top speed (6.4 – 10.2 m/s across 0–100).
- `acceleration` → standstill acceleration (7.0 – 10.5 m/s²).
- `stamina` → sprint drain (13 → 7 per second).
- Others (`strength`, `passing`, …) are loaded but unused until their systems exist.

### Stamina

- 100 points; full sprint lasts ~8–14 s depending on the attribute.
- Regen starts 0.7 s after sprinting; faster when standing (18/s) than moving (9/s).
- Below 35, top speed and acceleration fade smoothly (down to 84 %). The
  player never loses control.
- Empty → sprint locks until 18 is recovered (prevents sprint flicker).

### States and roles

- States: `LOCOMOTION`, `GROUNDED`, `GETTING_UP` (~1 s total down time).
- Roles: `NEUTRAL`, `BALL_CARRIER` (−3 % speed, −10 % turn), `DEFENDER`
  (+8 % turn). `BALL_CARRIER` is set automatically by possession.
- A `TACKLING` state is **not** implemented yet — it arrives with Milestone 07.

## Ball (Milestone 03)

### Possession

- **Pickup is automatic:** run over a loose ball (within 0.85 m, ball below
  1.3 m) and you try to gather it. No button — accessibility first; a
  "dive on the ball" action can come later.
- **Pickup chance** (`PickupModel`):
  - base 80 % → 99.5 % by handling,
  - minus up to 40 % (bad hands) / 15 % (good hands) as speed rises from
    half pace to full sprint,
  - minus up to 35 % when the ball is moving fast relative to you.
  - Walking onto a still ball ≈ 92–97 %; full-sprint scoop of a moving ball
    with average hands ≈ 35–45 %.
- **Fumble:** the ball is knocked forward (with spread and a pop up), you
  lose 20 % of your speed, and you can't retry for 0.5 s. Readable cause →
  effect, no animation lock.
- **Pickup at pace** costs 12 % of your speed (the stoop).
- **Going to ground with the ball** places it 0.9 m behind you (the seed of
  the M08 ruck).

### Ball physics

- Real gravity (9.8 m/s²), light air damping, 0.11 m collision sphere.
- **Bounce** (`BounceModel`): random restitution 0.38–0.62, horizontal
  deflection from a peaked distribution scaled by impact speed (max 35°),
  occasional "sit up", sideways scatter on vertical drops. Soft impacts are
  tame; hard ones are wild. Never bounces backwards.
- **Rolling:** 2.4 m/s² until it stops; it settles lying on its side.
- Hits posts and boards; passes through players (contact = gameplay rules).
- Oval shape and tumbling are cosmetic, so they can't make outcomes unfair.

### Out of play

- Carrier touching/crossing the touchline → **TOUCH**.
- Loose ball touching the ground on/over the line → **TOUCH**. A ball in the
  air above touch is still live until it lands.
- Touch-in-goal and dead-ball line handled the same way.
- Dev restart: the ball reappears 5 m infield after 1.6 s. Real restarts
  (lineout, 22 drop-out, scrum) come with M11/M13/M14.

### Readability

- White ring on the grass under any loose ball (grows with height).
- "● BALL" in the HUD when you carry; centre notices for TOUCH / FUMBLED /
  KNOCK-ON / DROPPED / FORWARD PASS.
- Debug (F1): ball state, carrier, last touch, bounce count/deflection,
  live pickup chance, pickup reach circle, predicted flight + landing spot.

## Passing (Milestone 04)

### Controls and targeting

- **Left / right are the attacker's**, never the screen's (consistent with
  any camera). Attacking right on the side camera, "left" is the far side.
- **Tap** (released before 0.16 s) → quick pass to the nearest receiver on
  that side. **Hold** → long/skip pass to the next one out; auto-releases
  at 0.45 s. If there is only one receiver, the long pass goes to them.
- Receivers must be at least 1.5 m to that side, within 26 m, and no more
  than 4 m ahead. A receiver ahead is still an option — the player is
  allowed to make that mistake — but their label turns **red**.
- No receiver on that side → pass into space (8 m out, 2 m back).
- Floating labels over each side's current target: white = quick target,
  yellow = the pass being charged (moves out on a long hold), red = likely
  forward.

### Flight

- Passes **lead the receiver**: flight time solved so the ball meets their
  predicted run at chest height (1.15 m). Real Jolt flight — no homing.
- Speed by passing attribute: quick 12.5–15.5 m/s, long 15.5–19.5 m/s.
- Accuracy: aim error SD 1.3 m (passing 0) → 0.15 m (passing 100), ×1.5 for
  long passes, up to ×1.5 at full sprint. Errors go long/short, high/low or
  **behind** the receiver — never forward (forward passes come from choices,
  not dice).

### Control and the receiver

- **Control switches to the receiver the moment the ball leaves the
  passer's hands**, so you can run onto it and chain passes.
- **Receiver pace assist:** while the ball is in the air to you, your run is
  held (same speed and direction it was aimed at) unless you push the stick
  more than 45° away from it. Without this, simply holding "forward" without
  sprint would slow a sprinting receiver and the pass would fly past.
- The passer's other teammates let a pass through to the intended receiver.

### Catching

- Judged at the ball's **closest approach** to the receiver (or when it's
  within 0.45 m), inside a reach of 1.0 m (1.25 m for the intended receiver)
  between 0.35 m and 2.4 m high.
- Chance: 82 % → 99 % by handling, minus up to 20 % for very fast balls
  (> 18 m/s relative — a normal pass to a runner crosses at 15–21 m/s), up
  to 20 % for balls more than 0.4 m behind the body, up to 15 % outside
  chest height.
- Drop: ~70 % knocked forward (**KNOCK-ON**), ~30 % backwards (**DROPPED**).
  The ball is loose; rulings come with M11.

### Forward pass

- Forward if the ball's velocity **relative to the passer** points toward
  the opponents' line faster than 0.6 m/s. Momentum carrying the ball forward
  over the ground is legal. Detected at release; **FORWARD PASS** notice.
  The scrum/penalty consequence comes with M11.

### Measured (tools/pass_soak.gd, 48 seeded moves, no defenders)

92 % of passes caught by the intended receiver (mostly long skip passes
dropped by the 12), 0 forward passes. An earlier "97 %" came from
correlated test seeds (neighbouring PCG seeds); soaks now use hashed seeds.

### Receiver dummies (placeholder for M06)

Non-controlled teammates hold a staggered line around the anchor (carrier,
pass receiver, or loose ball): first receiver 2.5 m deep and 7 m wide, each
further one 1 m deeper and 7 m wider, kept 2 m inside touch. They run with
the carrier and reform after every pass. No decisions.

## Opponents and defence (Milestone 05)

- The human always controls the same team. Opponents are AI.
- **Phases** per team: ATTACK (we have it or our pass is in the air),
  DEFEND (they have it), LOOSE (nobody: the nearest player of each team
  chases it, the rest hold shape around it).
- **Turnover:** control jumps to our player nearest the ball. On defence
  LB/RB switch to the teammate nearest the ball (repeat to cycle).
- **Placeholder defence** (one structure, not 6 ball-chasers):
  - one pursuer on the carrier (unless the human is already on him),
  - the rest pair with attackers in lateral order (man-for-man drift),
    on the mark's inside shoulder, 3 m in front near the ball, 6 m wide,
  - spares sweep 18 m behind the ball,
  - **line speed:** they copy their mark's sideways movement but not its
    forward progress, so the line comes up to meet the attack; the
    pursuer gives at most 30 % of the carrier's pace,
  - never behind their own try line.
- **Placeholder AI carrier:** runs at the line, veers from defenders
  within 4 m, passes to the side with more room when a defender is within
  2.6 m in front (after holding the ball at least 0.7 s).
- **Interceptions:** a defender reaching for the other team's pass uses
  15 % of the normal catch chance with a 0.8 m reach, not in the first
  0.15 s of flight; a miss knocks it down 8 % of the time, otherwise the
  ball flies on. Notices: INTERCEPTED / TURNOVER / TURNOVER WON.
- Measurements: see ROADMAP (tools/defence_soak.gd).

## Tackling (Milestone 06)

- **Contact is the tackle:** a defender who reaches the carrier (0.85 m
  centre to centre) tackles. No button needed (accessible, Rugby 08 style).
- **Outcome** (TackleModel): tackler power vs. carrier resistance —
  - power = (kg/100)^0.7 × (4 + 0.6 × closing speed) × tackling skill × angle
  - resistance = (kg/100)^0.7 × (4 + 0.6 × carrier speed) × strength
  - angle: head-on 1.0, side 1.05, from behind 0.85
  - P(break) is a logistic of ln(power/resistance); P(dominant) grows
    when the tackler clearly wins.
  - Calibration: typical back-on-back ~9 % broken, carrier sprinting ~17 %,
    prop carrying into a wing ~30 %, a committed hit by a big defender
    almost never broken and often dominant.
- **Held:** both go down; the carrier slides forward (35 % of speed), the
  ball is placed 0.9 m behind, and only the tackled team may pick it up
  for 2.5 s (placeholder until M08 rucks). 2 % chance of a spill
  (knock-on), 8 % on a dominant hit.
- **Dominant:** the carrier is driven back; the tackler is up sooner.
- **Broken:** the carrier stumbles on (65 % of speed); the tackler falls
  and can't re-tackle that carrier for 0.6 s.
- **Dive tackle (A/Space):** lunge along your facing; +2 m reach in front
  and +15 % power for 0.35 s. Miss = 1.1 s on the floor (anti-spam).
- **Fend (X/V):** 0.35 s window, ×1.35 resistance against front/side
  tackles only; 1.2 s cooldown. AI carriers fend too.
- **Sidestep (right-stick flick / Z, X):** 3.5 m/s lateral burst relative
  to your facing; tacklers are wrong-footed (×0.7 power) for 0.25 s;
  0.9 s cooldown, costs stamina.
- **Defenders commit:** within 3 m the carrier's defender drives into him
  (closing speed) instead of shadowing.
- After a tackle, control leaves a grounded player for the nearest
  teammate on their feet. Camera shake on impact (stronger on big hits).
- Real matches use random seeds; tests and tools use fixed/hashed seeds.

## Basic AI (Milestone 07)

The AI drives both teams; on yours it plays everyone you don't control.

- **AI carrier** thinks every 0.15–0.4 s (team tempo and decision
  making). It runs the line with the most room (7 rays, ±45°, avoids
  touch, doesn't twitch between lines). Carry or pass is judged on one
  scale, metres of room:
  - carry = room down his line (never more than the gap to the tackler,
    max 12) + up to 6 × P(break) as contact nears;
  - pass = room around the receiver (max 12) − up to 4 if a defender is
    within 1.6 m of the lane − forward risk − deep receivers − 0.8 for
    a skip pass;
  - he passes when the best pass beats carry by a margin (smaller for
    passing teams), or must pass when someone is within 2.8 m and the
    pass is decent;
  - noise scales with poor decision making;
  - reflexes: sidestep into room when someone closes head-on, fend at
    contact.
- **Support**: width spreads the line (×0.8–1.2), tempo flattens it
  (depth ×1.25–0.75); runners flatten onto the ball as the defence nears
  and slide toward gaps; one runner tracks inside the carrier.
- **Defence**:
  - the pursuer is whoever can intercept the carrier soonest;
  - beaten defenders chase on an intercept line;
  - a spare defender covers inside/behind;
  - the defender within engage range drives in at the ball and dives
    when the carrier is 1.3 m to dive range and getting away (2 s
    cooldown);
  - aggression sets line speed, retreat and engage distance.
- **Team styles** (data/teams/*.json, 0–100): tempo, width, aggression,
  passing. Development XV: 75/70/65/75 (quick, wide, passing).
  Opposition XV: 55/50/75/55 (rush defence).
- **Debug (F1)**: white running line for the AI carrier, green ring on
  the inside runner, orange chasers, teal cover, the AI's last decision
  in the panel.
- Measured: see ROADMAP (tools/ai_soak.gd).

## Camera

Side-on broadcast camera (default) and an end-on alternative. It frames the
space the player runs into (0.55 s look-ahead), follows with a critically
damped spring and widens slightly at sprint speed. When you aren't carrying
(defending, waiting for a pass) the focus sits 45 % toward the ball, rising
to 85 % when you're far from it, and the camera pulls back as ball and
player get further apart.

## Readability

- Yellow ring + pointer under the controlled player only; their shirt
  number turns yellow. Every player shows a shirt number.
- Stamina bar turns amber when fatigued, red when sprint is locked.
