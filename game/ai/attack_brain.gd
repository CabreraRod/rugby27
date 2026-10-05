class_name AttackBrain
extends RefCounted
## Placeholder AI ball carrier (opponents in possession) — M06 replaces it.
##
## Runs at the try line, veers away from close defenders, and passes to the
## side with more room when a defender presses. Just enough to make
## turnovers meaningful in M05.


## Movement intent for an AI carrier.
static func carry(carrier: RugbyPlayer, defenders: Array[RugbyPlayer], attack: Vector2, t: DefenceTuning) -> SupportRunner.Intent:
	var it := SupportRunner.Intent.new()
	var dir := attack
	var push := Vector2.ZERO
	for d in defenders:
		var rel := carrier.planar_position() - d.planar_position()
		var dist := rel.length()
		if dist < t.avoid_dist and dist > 0.01 and (-rel).dot(attack) > -0.5:
			push += rel.normalized() * (1.0 - dist / t.avoid_dist)
	# Only the sideways part of the push: keep going forward.
	var side := Vector2(-attack.y, attack.x)
	dir = (attack + side * push.dot(side) * t.avoid_weight).normalized()
	# Stay in the field.
	var z := carrier.global_position.z
	if absf(z) > FieldDimensions.HALF_WIDTH - 3.0:
		dir = (dir + Vector2(0.0, -signf(z)) * 0.6).normalized()
	it.dir = dir
	it.mag = 1.0
	it.sprint = true
	return it


## Side to pass to (PassTargeting.LEFT/RIGHT) or -1 to keep running.
static func choose_pass(carrier: RugbyPlayer, passing: PassingSystem, defenders: Array[RugbyPlayer], held_time: float, t: DefenceTuning) -> int:
	if held_time < t.ai_pass_cooldown or carrier.team == null:
		return -1
	if DefensiveLine.pressure(carrier, defenders, carrier.team.attack(), t) == null:
		return -1
	var best_side := -1
	var best_room := -INF
	for side in [PassTargeting.LEFT, PassTargeting.RIGHT]:
		var r := passing.preview(carrier, side, false)
		if r == null:
			continue
		var room := INF
		for d in defenders:
			room = minf(room, d.planar_position().distance_to(r.planar_position()))
		if room > best_room:
			best_room = room
			best_side = side
	return best_side
