class_name DefensiveLine
extends RefCounted
## Placeholder defence for Milestone 05 (M06 AI builds on it).
##
## Defenders behave as ONE structure, not as independent ball-chasers:
##   * one pursuer goes at the ball carrier (unless the human is already on him),
##   * the rest pair with attackers in lateral order (a man-for-man drift),
##     sitting on their mark's inside shoulder and between them and the
##     try line — tight near the ball, deeper out wide,
##   * spares sweep behind the ball.
## Line speed: defenders mirror their mark's SIDEWAYS movement (the drift)
## but not its forward progress, so the line comes up to meet the attack
## instead of backpedalling in front of it. The carrier's defender gives at
## most pursuer_retreat of the carrier's pace. A faster attacker can still
## beat a slower mark on the outside — pace matters, but so do angles.
## This addresses Rugby 08's most cited flaw (defence giving fast backs
## free space). No target is ever behind the defenders' own try line.


class Assignment:
	var defender: RugbyPlayer
	var role := &"mark"        ## &"pursue", &"mark", &"sweep"
	var mark: RugbyPlayer       ## null for sweepers
	var target := Vector2.ZERO
	var feed := Vector2.ZERO


## defenders: AI defenders (excluding the human-controlled one).
## human: the human defender or null. attack: the ATTACKING team's direction.
static func assign(defenders: Array[RugbyPlayer], human: RugbyPlayer, attackers: Array[RugbyPlayer], carrier: RugbyPlayer, ball_pos: Vector2, attack: Vector2, t: DefenceTuning) -> Array[Assignment]:
	var out: Array[Assignment] = []
	var free: Array[RugbyPlayer] = defenders.duplicate()
	var marks: Array[RugbyPlayer] = attackers.duplicate()

	# 1. Pursuer on the carrier.
	if carrier and marks.has(carrier):
		marks.erase(carrier)
		var human_on_it := human != null and human.planar_position().distance_to(carrier.planar_position()) < t.human_marks_carrier_dist
		if not human_on_it and not free.is_empty():
			var best := _nearest(free, carrier.planar_position())
			free.erase(best)
			var a := Assignment.new()
			a.defender = best
			a.role = &"pursue"
			a.mark = carrier
			var to_c := carrier.planar_position() - best.planar_position()
			if to_c.length() < t.engage_dist:
				# Commit to the tackle: drive through the carrier.
				a.role = &"tackle"
				a.target = carrier.planar_position() + carrier.planar_velocity * 0.15
				# Track the carrier sideways, but go INTO him — never back off.
				a.feed = split_feed(carrier.planar_velocity, attack, 0.0) + to_c.normalized() * t.engage_speed
			else:
				var lead := carrier.planar_position() + carrier.planar_velocity * t.pursue_lead
				a.target = clamp_to_own_line(lead + attack * t.shadow_gap, attack)
				a.feed = split_feed(carrier.planar_velocity, attack, t.pursuer_retreat)
			out.append(a)

	# 2. Lateral pairing: cover the attackers nearest the ball first.
	marks.sort_custom(func(x, y): return absf(x.global_position.z - ball_pos.y) < absf(y.global_position.z - ball_pos.y))
	if marks.size() > free.size():
		marks.resize(free.size())
	var defs_sorted := free.duplicate()
	defs_sorted.sort_custom(func(x, y): return x.global_position.z < y.global_position.z)
	var marks_sorted := marks.duplicate()
	marks_sorted.sort_custom(func(x, y): return x.global_position.z < y.global_position.z)
	# Extras beyond the marks become sweepers: take the deepest defenders.
	var n := marks_sorted.size()
	var sweepers: Array[RugbyPlayer] = []
	if defs_sorted.size() > n:
		var by_depth := defs_sorted.duplicate()
		by_depth.sort_custom(func(x, y): return x.planar_position().dot(attack) > y.planar_position().dot(attack))
		for i in defs_sorted.size() - n:
			sweepers.append(by_depth[i])
		for s in sweepers:
			defs_sorted.erase(s)
	for i in n:
		var a := Assignment.new()
		a.defender = defs_sorted[i]
		a.mark = marks_sorted[i]
		a.target = mark_target(a.mark.planar_position(), ball_pos, attack, t)
		a.feed = split_feed(a.mark.planar_velocity, attack, t.mark_retreat)
		out.append(a)

	for s in sweepers:
		var a := Assignment.new()
		a.defender = s
		a.role = &"sweep"
		var p := ball_pos + attack * t.sweeper_depth
		a.target = clamp_to_own_line(Vector2(p.x, ball_pos.y * 0.5), attack)
		out.append(a)
	return out


## Where a defender stands against an attacker at `mark` (not the carrier).
static func mark_target(mark: Vector2, ball_pos: Vector2, attack: Vector2, t: DefenceTuning) -> Vector2:
	var lat := absf(mark.y - ball_pos.y)
	var gap := lerpf(t.gap_near, t.gap_far, clampf(lat / t.gap_falloff, 0.0, 1.0))
	var inward := signf(ball_pos.y - mark.y)
	var p := mark + attack * gap + Vector2(0.0, inward * t.inside_offset)
	var max_z := FieldDimensions.HALF_WIDTH - 0.5
	return clamp_to_own_line(Vector2(p.x, clampf(p.y, -max_z, max_z)), attack)


## Velocity to mirror: all of the sideways part, `retreat` of the part
## toward the defenders' own line (0 = hold/come up, 1 = backpedal along).
static func split_feed(v: Vector2, attack: Vector2, retreat: float) -> Vector2:
	var along := v.dot(attack)
	var side := v - attack * along
	return side + attack * along * retreat


## Defenders defend from their own try line, never from behind it.
static func clamp_to_own_line(p: Vector2, attack: Vector2) -> Vector2:
	var line := FieldDimensions.HALF_LENGTH - 0.5
	var along := p.dot(attack)
	if along > line:
		p -= attack * (along - line)
	return p


static func _nearest(players: Array[RugbyPlayer], to: Vector2) -> RugbyPlayer:
	var best: RugbyPlayer = null
	var best_d := INF
	for p in players:
		var d := p.planar_position().distance_squared_to(to)
		if d < best_d:
			best_d = d
			best = p
	return best


## Is a defender pressing the carrier (close, in front, roughly in line)?
static func pressure(carrier: RugbyPlayer, defenders: Array[RugbyPlayer], attack: Vector2, t: DefenceTuning) -> RugbyPlayer:
	for d in defenders:
		var rel := d.planar_position() - carrier.planar_position()
		var ahead := rel.dot(attack)
		if ahead > -0.3 and ahead < t.press_dist and absf(rel.dot(Vector2(-attack.y, attack.x))) < t.press_lateral:
			return d
	return null
