class_name RuckModel
extends RefCounted
## Pure ruck maths (no nodes, deterministic, unit-tested).
##
## Rugby 08 style: the attack keeps the ball unless the defence wins the
## numbers game. Each bound player is worth "units" (weight and strength);
## only bodies bound before the contest is decided count. A defender over
## the ball before any attacker (a jackal) gets a bonus. The attack has a
## built-in advantage through contest_bias: equal numbers is ~8 % turnover.
##
## Holding the ball in (□) has a rising penalty hazard: the longer you hold,
## the likelier the referee blows.


class Body:
	var units := 1.0
	## Seconds after the ruck formed that this body bound (INF = not yet).
	var bound_at := INF

	static func make(p_units: float, p_bound_at: float) -> Body:
		var b := Body.new()
		b.units = p_units
		b.bound_at = p_bound_at
		return b


class Result:
	var att_units := 0.0
	var def_units := 0.0
	var att_bodies := 0
	var def_bodies := 0
	var jackal := false
	var x := 0.0
	var p_turnover := 0.0


## A player's weight in the ruck.
static func body_units(mass_kg: float, strength: float, t: RuckTuning) -> float:
	return pow(maxf(mass_kg, 1.0) / t.mass_ref, t.mass_exp) * lerpf(t.strength_min, t.strength_max, clampf(strength, 0.0, 1.0))


## Contest at time `at` (seconds since formation).
static func evaluate(att: Array[Body], def: Array[Body], at: float, t: RuckTuning) -> Result:
	var r := Result.new()
	var att_first := INF
	var def_first := INF
	for b in att:
		if b.bound_at <= at:
			r.att_units += b.units
			r.att_bodies += 1
			att_first = minf(att_first, b.bound_at)
	for b in def:
		if b.bound_at <= at:
			r.def_units += b.units
			r.def_bodies += 1
			def_first = minf(def_first, b.bound_at)
	if r.def_bodies == 0:
		return r   # nobody contests: the attack keeps it
	r.jackal = def_first < att_first
	r.x = r.def_units - r.att_units + (t.jackal_bonus if r.jackal else 0.0)
	r.p_turnover = p_turnover(r.x, t)
	return r


static func p_turnover(x: float, t: RuckTuning) -> float:
	var z := t.contest_bias + t.contest_slope * x
	return clampf(1.0 / (1.0 + exp(-z)), t.p_min, t.p_max)


## Penalty hazard (per second) after holding for `held` seconds.
static func hold_hazard(held: float, t: RuckTuning) -> float:
	return t.hold_rate + t.hold_rate_slope * maxf(held, 0.0)


## P(penalised within `held` seconds of holding) — for docs and tests.
static func hold_penalty_cdf(held: float, t: RuckTuning) -> float:
	if held >= t.hold_max:
		return 1.0
	var h := t.hold_rate * held + 0.5 * t.hold_rate_slope * held * held
	return 1.0 - exp(-h)


## P(this tick is the one the referee blows), holding from `held` to held+dt.
static func hold_tick_chance(held: float, dt: float, t: RuckTuning) -> float:
	return 1.0 - exp(-hold_hazard(held + dt * 0.5, t) * dt)


## Estimated seconds for a player to bind (run + reaction).
static func eta(dist: float, sprint_top: float, t: RuckTuning) -> float:
	return t.reaction + maxf(dist - t.bind_reach, 0.0) / maxf(sprint_top, 1.0)


# --- AI ---------------------------------------------------------------------------

## Chance the AI defence bids for the ball (aggression 0..1).
static func bid_chance(aggression: float, isolated: bool, near_own_line: bool, t: RuckTuning) -> float:
	var p := t.bid_base + aggression * t.bid_aggression
	if isolated:
		p += t.bid_isolated
	if near_own_line:
		p += t.bid_near_line
	return clampf(p, 0.0, 1.0)


static func bid_size(isolated: bool, rng: RandomNumberGenerator, t: RuckTuning) -> int:
	if isolated:
		return int(t.isolated_bid)
	return rng.randi_range(int(t.bid_min), int(t.bid_max))


## Extra players the AI attack sends to stay ahead in numbers.
static func attack_extra(att_count: int, def_count: int, t: RuckTuning) -> int:
	if def_count == 0:
		return 0
	return clampi(def_count + int(t.att_margin) - att_count, 0, int(t.max_commit) - att_count)


static func hold_chance(aggression: float, near_own_line: bool, t: RuckTuning) -> float:
	return clampf(t.hold_base + aggression * t.hold_aggression + (t.hold_near_line if near_own_line else 0.0), 0.0, 1.0)
