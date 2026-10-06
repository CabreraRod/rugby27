class_name SupportRunner
extends RefCounted
## Receiver dummies for Milestone 04 — NOT the M06 AI.
##
## Each non-controlled teammate holds a slot in a staggered line beside and
## behind an anchor (the ball carrier, the intended receiver of a pass in
## flight, or a loose ball) and runs with it. No decisions, no reading of
## space or defenders: just enough to pass to. M06 replaces this behind the
## same set_intent() API.


class Intent:
	var dir := Vector2.ZERO
	var mag := 0.0
	var sprint := false
	## Exact target speed (m/s) or -1 for "from mag/sprint".
	var speed := -1.0


## Assigns slots for `runners` around the anchor. Returns {player: slot_pos}.
## Side is decided by which side of the anchor each runner currently is, and
## order by lateral distance, so lines reform naturally after every pass.
static func assign_slots(anchor: Vector2, team: Team, runners: Array[RugbyPlayer], t: SupportTuning) -> Dictionary:
	var left := team.left()
	var lefts: Array = []
	var rights: Array = []
	for r in runners:
		var lat := (r.planar_position() - anchor).dot(left)
		if lat >= 0.0:
			lefts.append([lat, r])
		else:
			rights.append([-lat, r])
	lefts.sort_custom(func(a, b): return a[0] < b[0])
	rights.sort_custom(func(a, b): return a[0] < b[0])
	var out := {}
	for i in lefts.size():
		out[lefts[i][1]] = slot_position(anchor, team, 1.0, i + 1, t)
	for i in rights.size():
		out[rights[i][1]] = slot_position(anchor, team, -1.0, i + 1, t)
	return out


## side: +1 = attacker's left, -1 = right. k: 1 = first receiver.
static func slot_position(anchor: Vector2, team: Team, side: float, k: int, t: SupportTuning) -> Vector2:
	var back := -team.attack()
	var depth := t.depth_first + t.depth_step * (k - 1)
	var p := anchor + back * depth + team.left() * side * t.spacing * k
	var max_z := FieldDimensions.HALF_WIDTH - t.touch_margin
	var max_x := FieldDimensions.dead_ball_x() - 1.0
	return Vector2(clampf(p.x, -max_x, max_x), clampf(p.y, -max_z, max_z))


## Steering toward a slot that moves with the anchor. A slot pinned at the
## touch limit doesn't inherit the anchor's drift toward touch (no running
## out of the field to keep pace with the ball).
static func steer(pos: Vector2, slot: Vector2, anchor_vel: Vector2, jog_top: float, t: SupportTuning) -> Intent:
	var feed := anchor_vel
	var max_z := FieldDimensions.HALF_WIDTH - t.touch_margin
	if absf(slot.y) >= max_z - 0.05 and signf(feed.y) == signf(slot.y):
		feed.y = 0.0
	return steer_to(pos, slot, feed, jog_top, t.gain, t.settle_dist)


## Generic: reach a moving target. feed = the target's own velocity
## (feed-forward), gain = how hard to close the remaining gap (1/s).
static func steer_to(pos: Vector2, target: Vector2, feed: Vector2, jog_top: float, gain: float, settle: float) -> Intent:
	var it := Intent.new()
	var to := target - pos
	if to.length() < settle and feed.length() < 0.3:
		return it
	var desired := feed + to * gain
	var speed := desired.length()
	if speed < 0.05:
		return it
	it.dir = desired / speed
	it.mag = clampf(speed / maxf(jog_top, 0.1), 0.0, 1.0)
	it.sprint = speed > jog_top * 1.02
	return it


## Keep running exactly as you are: same direction, same pace.
static func hold_course(vel: Vector2, jog_top: float) -> Intent:
	var it := Intent.new()
	var speed := vel.length()
	if speed < 0.3:
		return it
	it.dir = vel / speed
	it.mag = clampf(speed / maxf(jog_top, 0.1), 0.0, 1.0)
	it.sprint = speed > jog_top * 1.02
	it.speed = speed
	return it


## Receiving a pass the human now controls: the pass was aimed at where the
## receiver was going at release (velocity extrapolated). For the short
## flight (< 1 s) keep that exact run while the stick points roughly the same
## way or is idle, so the catch isn't lost to a correction the player never
## meant. A deliberate turn beyond receiver_assist_angle is respected (and
## may miss).
static func receiver_assist(stick: Intent, vel: Vector2, jog_top: float, t: SupportTuning) -> Intent:
	var hold := hold_course(vel, jog_top)
	if stick.mag < 0.05 or hold.mag == 0.0:
		return hold
	if absf(rad_to_deg(stick.dir.angle_to(vel))) > t.receiver_assist_angle:
		return stick
	return hold
