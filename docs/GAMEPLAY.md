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
| Sprint | Shift | RT or RB |
| Toggle camera (side / end-on) | C | Back/View |
| Debug overlay | F1 | — |
| Dev: go to ground | G | B / Circle |
| Dev: cycle role (neutral/carrier/defender) | B | — |
| Dev: next player profile | N | Y / Triangle |
| Dev: reset to halfway | R | Start |
| Dev: hot-reload `movement.json` | F5 | — |

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
  (+8 % turn). Roles are switched by a dev key until the ball exists.
- A `TACKLING` state is **not** implemented yet — it arrives with Milestone 07.

## Camera

Side-on broadcast camera (default) and an end-on alternative. It frames the
space the player runs into (0.55 s look-ahead), follows with a critically
damped spring and widens slightly at sprint speed.

## Readability

- Yellow ring + pointer under the controlled player shows facing.
- Stamina bar turns amber when fatigued, red when sprint is locked.
