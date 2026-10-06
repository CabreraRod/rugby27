class_name AttackAI
extends RefCounted
## M07 attacking AI for one team (replaces AttackBrain + plain support slots).
##
## Ball carrier (AI team only), re-thinking every think interval:
##   * running line = the ray with the most space (SpaceEval.best_line),
##     with hysteresis so it doesn't twitch,
##   * carry vs. pass: carry score = space on the line + P(break) bonus
##     (TackleModel.evaluate against the defender about to make contact);
##     pass score = space around the receiver − lane risk − forward risk.
##     Passing appetite and decision speed come from TeamStyle; weaker
##     decision makers get noisier scores,
##   * reflexes every tick: sidestep into space when a defender is closing
##     head-on, fend at contact.
## Support runners (both teams, human or AI): staggered slots scaled by
## style (width, depth), flattening onto the ball as the defence nears,
## sliding toward defensive gaps, and one inside-support runner.

var t: AITuning
var style: TeamStyle
var support: SupportTuning      ## already scaled by style
var tackle_t: TackleTuning
var rng := RandomNumberGenerator.new()

## Debug.
var last_decision := ""
var current_line := Vector2.ZERO
var inside_runner: RugbyPlayer

var _think := 0.0
var _carrier_id := 0
var _line_score := -INF


func _init(p_t: AITuning, p_style: TeamStyle, p_support: SupportTuning, p_tackle: TackleTuning, seed_value: int = 77) -> void:
	t = p_t
	style = p_style
	support = p_support
	tackle_t = p_tackle
	rng.seed = seed_value


## Scales the shared support tuning by a team's style.
static func styled_support(base: SupportTuning, s: TeamStyle) -> SupportTuning:
	var out := SupportTuning.new()
	for k in base.property_names().keys():
		out.set(k, base.get(k))
	out.spacing = base.spacing * s.width_factor()
	out.depth_first = base.depth_first * s.depth_factor()
	out.depth_step = base.depth_step * s.depth_factor()
	return out


func think_interval(carrier: RugbyPlayer) -> float:
	var dm := carrier.profile.attributes.norm("decision_making")
	return lerpf(t.think_slow, t.think_fast, style.n("tempo")) * lerpf(1.3, 0.8, dm)


# --- ball carrier ------------------------------------------------------------------

func carrier_intent(carrier: RugbyPlayer, team: Team, opponents: Team, passing: PassingSystem, held_time: float, dt: float) -> SupportRunner.Intent:
	var attack := team.attack()
	var defenders: Array[Vector2] = []
	if opponents:
		defenders = SpaceEval.positions(opponents.players)
	if carrier.get_instance_id() != _carrier_id:
		_carrier_id = carrier.get_instance_id()
		current_line = attack
		_line_score = -INF
		_think = 0.0
	_reflexes(carrier, attack, opponents)
	_think -= dt
	if _think <= 0.0:
		_think = think_interval(carrier)
		_decide(carrier, team, opponents, defenders, passing, held_time)
	var it := SupportRunner.Intent.new()
	it.dir = current_line
	it.mag = 1.0
	it.sprint = true
	return it


func _decide(carrier: RugbyPlayer, team: Team, opponents: Team, defenders: Array[Vector2], passing: PassingSystem, held_time: float) -> void:
	var attack := team.attack()
	var pos := carrier.planar_position()
	var noise := t.decision_noise * (1.0 - carrier.profile.attributes.norm("decision_making"))

	# Running line with hysteresis.
	var line := SpaceEval.best_line(pos, attack, defenders, t.ray_angles_deg, int(t.ray_steps), t.ray_range, t.straight_bias, t.touch_avoid)
	var cur_score := SpaceEval.ray_space(pos, current_line, defenders, t.ray_range) + t.straight_bias * current_line.dot(attack) * 2.0
	if line[1] > cur_score + t.line_hysteresis or current_line == Vector2.ZERO:
		current_line = line[0]
		cur_score = line[1]

	# Who makes contact, and how likely we beat him.
	var threat: RugbyPlayer = null
	var threat_d := INF
	if opponents:
		for d in opponents.players:
			if not d.is_controllable():
				continue
			var rel := d.planar_position() - pos
			if rel.dot(attack) > -0.5 and rel.length() < threat_d:
				threat_d = rel.length()
				threat = d
	var p_break := 0.0
	if threat and tackle_t:
		var c := TackleModel.Contact.new()
		c.tackler_mass = threat.profile.weight_kg
		c.tackler_vel = threat.planar_velocity
		c.tackler_pos = threat.planar_position()
		c.tackling = threat.profile.attributes.norm("tackling")
		c.carrier_mass = carrier.profile.weight_kg
		c.carrier_vel = current_line * carrier.stats.sprint_top
		c.carrier_pos = pos
		c.strength = carrier.profile.attributes.norm("strength")
		p_break = TackleModel.evaluate(c, tackle_t).p_break
	# Carry and pass are compared on the same scale: metres of room. The
	# carrier's room is the space down his line, but never more than the gap
	# to the man about to tackle him; the break chance only counts as
	# contact actually nears.
	var line_space := SpaceEval.ray_space(pos, current_line, defenders, t.ray_range)
	var carry_space := minf(minf(line_space, threat_d * 1.2), t.receiver_space_cap)
	var closeness := 1.0 - clampf(threat_d / maxf(t.pass_consider_dist, 0.1), 0.0, 1.0)
	var carry := carry_space + t.carry_break_bonus * p_break * closeness + rng.randf_range(-1.0, 1.0) * noise * 4.0
	last_decision = "carry %.1f (break %.0f%%)" % [carry, p_break * 100.0]

	if threat_d > t.pass_consider_dist or held_time < 0.3 or passing.charging or passing.in_flight:
		return
	var best_side := -1
	var best_long := false
	var best := -INF
	for side in [PassTargeting.LEFT, PassTargeting.RIGHT]:
		for long in [false, true]:
			var r := passing.preview(carrier, side, long)
			if r == null:
				continue
			var s := receiver_score(pos, r, attack, defenders) + rng.randf_range(-1.0, 1.0) * noise * 4.0
			if long:
				s -= 0.8   # a skip pass is harder; it must be worth it
			if s > best:
				best = s
				best_side = side
				best_long = long
	if best_side < 0:
		return
	var margin := t.pass_margin * lerpf(1.6, 0.4, style.n("passing"))
	var must := threat_d < t.pass_must_dist and best > 2.0
	if best > carry + margin or must:
		last_decision = "pass %s%s %.1f > carry %.1f" % ["L" if best_side == PassTargeting.LEFT else "R", " long" if best_long else "", best, carry]
		passing.throw(carrier, best_side, best_long)


## How good a pass to `r` looks: space around where he'll be, minus a risky
## lane and any forward-pass risk.
func receiver_score(from: Vector2, r: RugbyPlayer, attack: Vector2, defenders: Array[Vector2]) -> float:
	var where := r.planar_position() + r.planar_velocity * 0.5
	var s := minf(SpaceEval.space_at(where, defenders), t.receiver_space_cap)
	var lane := SpaceEval.lane_clearance(from, where, defenders)
	if lane < t.lane_risk_dist:
		s -= t.lane_risk_penalty * (1.0 - lane / t.lane_risk_dist)
	var ahead := (r.planar_position() - from).dot(attack)
	if ahead > -0.3:
		s -= t.ahead_penalty * (ahead + 0.3)
	elif ahead < -t.deep_receiver:
		s -= (-ahead - t.deep_receiver) * 0.8   # giving back too much ground
	if not r.is_controllable():
		s -= 100.0
	return s


func _reflexes(carrier: RugbyPlayer, attack: Vector2, opponents: Team) -> void:
	if opponents == null:
		return
	var pos := carrier.planar_position()
	for d in opponents.players:
		if not (d.is_controllable() or d.is_diving()):
			continue
		var rel := d.planar_position() - pos
		var dist := rel.length()
		if dist > t.sidestep_trigger or rel.dot(attack) < 0.3:
			continue
		# Head-on threat: sidestep toward the side with more room, else fend.
		var right := Vector2(-carrier.facing.y, carrier.facing.x)
		var side := -signf(rel.dot(right))
		if side == 0.0:
			side = 1.0
		var room := FieldDimensions.HALF_WIDTH - absf(pos.y + right.y * side * 3.0)
		if room > t.sidestep_space and carrier.try_sidestep(side):
			return
		if dist < (tackle_t.ai_fend_dist if tackle_t else 1.6):
			carrier.try_fend()
		return


# --- support runners ------------------------------------------------------------------

## Slot for every runner: style-scaled staggered line, flattened near the
## defence, nudged toward gaps; the nearest runner becomes inside support.
func support_slots(anchor: Vector2, team: Team, runners: Array[RugbyPlayer], opponents: Team) -> Dictionary:
	var slots := SupportRunner.assign_slots(anchor, team, runners, support)
	inside_runner = null
	if opponents == null or runners.is_empty():
		return slots
	var attack := team.attack()
	var side_axis := team.left()
	var defenders := SpaceEval.positions(opponents.players)

	# How close is the defensive line (along attack) to the ball?
	var line_gap := INF
	for d in defenders:
		var ahead := (d - anchor).dot(attack)
		if ahead > -1.0:
			line_gap = minf(line_gap, ahead)
	var flatten := clampf(1.0 - (line_gap - t.flat_depth) / maxf(t.flat_trigger - t.flat_depth, 0.1), 0.0, 1.0)

	for r in slots.keys():
		var slot: Vector2 = slots[r]
		var depth := (anchor - slot).dot(attack)
		var lat := slot.dot(side_axis)
		var flat_d := lerpf(depth, minf(depth, t.flat_depth + 0.15 * absf(lat - anchor.dot(side_axis)) / maxf(support.spacing, 0.1)), flatten)
		var gap := SpaceEval.gap_near(lat, side_axis, defenders, t.gap_window)
		if not is_nan(gap):
			lat = lerpf(lat, gap, t.gap_seek * flatten)
		var along := anchor.dot(attack) - flat_d
		var p := attack * along + side_axis * lat
		var max_z := FieldDimensions.HALF_WIDTH - support.touch_margin
		slots[r] = Vector2(p.x, clampf(p.y, -max_z, max_z))

	# Inside support: the runner nearest a point just behind and inside the
	# ball (inside = toward the middle of the pitch).
	var inside := Vector2(0.0, -signf(anchor.y)) if absf(anchor.y) > 1.0 else side_axis
	var spot := anchor - attack * t.inside_support_back + inside * t.inside_support_side
	var best := INF
	for r in runners:
		var dd := r.planar_position().distance_to(spot)
		if dd < best:
			best = dd
			inside_runner = r
	if inside_runner and best < support.spacing * 1.2:
		slots[inside_runner] = spot
	else:
		inside_runner = null
	return slots
