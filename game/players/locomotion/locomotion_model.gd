class_name LocomotionModel
extends RefCounted
## Pure planar locomotion: (velocity, intent) -> new velocity.
##
## No nodes, no input, no randomness. Used by human- and (later) AI-driven
## players alike, and unit-tested headlessly.
##
## Velocity is a Vector2 on the ground plane: x = world X (pitch length),
## y = world Z (pitch width).
##
## Feel model:
##   * Acceleration fades with speed -> punchy first steps, weighty top end.
##   * Turn rate shrinks with speed -> slow players pivot, sprinters carve.
##   * Reversals beyond plant_angle at speed must brake ("plant") before
##     turning -> momentum matters, but it's quick and readable.
##   * Being misaligned with the desired direction costs some speed.

## Debug info from the most recent step.
var last_planted := false
var last_turn_angle := 0.0
var last_target_speed := 0.0


func step(velocity: Vector2, intent_dir: Vector2, target_speed: float, s: LocomotionStats, t: MovementTuning, dt: float) -> Vector2:
	last_planted = false
	last_target_speed = target_speed
	var speed := velocity.length()

	# No input: brake to a stop along the current direction.
	if target_speed <= 0.01 or intent_dir.length_squared() < 1e-6:
		last_turn_angle = 0.0
		if speed <= 1e-4:
			return Vector2.ZERO
		var stopped_speed := maxf(0.0, speed - t.coast_decel * dt)
		return velocity * (stopped_speed / speed)

	var want := intent_dir.normalized()
	var cur := velocity / speed if speed > 0.05 else want
	var angle := cur.angle_to(want)
	var abs_angle := absf(angle)
	last_turn_angle = angle

	var speed_t := clampf(speed / s.sprint_top, 0.0, 1.0)
	var turn_rate := deg_to_rad(lerpf(t.turn_rate_slow_deg, t.turn_rate_fast_deg, speed_t)) * s.turn_mult

	# Plant-and-cut: shed speed hard while barely turning, then pivot.
	if abs_angle > deg_to_rad(t.plant_angle_deg) and speed > t.plant_min_speed:
		last_planted = true
		speed = maxf(0.0, speed - t.plant_decel * dt)
		var plant_dir := cur.rotated(signf(angle) * minf(abs_angle, turn_rate * 0.3 * dt))
		return plant_dir * speed

	var new_dir := cur.rotated(signf(angle) * minf(abs_angle, turn_rate * dt))

	var misalign := clampf(abs_angle / (PI * 0.5), 0.0, 1.0)
	var effective_target := target_speed * lerpf(1.0, t.turn_speed_retention, misalign)

	if speed < effective_target:
		var ratio := clampf(speed / s.sprint_top, 0.0, 1.0)
		var a := s.accel * maxf(1.0 - pow(ratio, t.accel_curve_power), 0.0) + t.accel_floor
		speed = minf(effective_target, speed + a * dt)
	else:
		speed = maxf(effective_target, speed - t.overspeed_decel * dt)

	return new_dir * speed


## Rotates a facing vector toward a target direction at a speed-dependent rate.
static func turn_facing(facing: Vector2, toward: Vector2, speed: float, sprint_top: float, t: MovementTuning, dt: float) -> Vector2:
	if toward.length_squared() < 1e-6:
		return facing
	var target := toward.normalized()
	var angle := facing.angle_to(target)
	var rate := deg_to_rad(lerpf(t.facing_rate_slow_deg, t.facing_rate_fast_deg, clampf(speed / sprint_top, 0.0, 1.0)))
	return facing.rotated(signf(angle) * minf(absf(angle), rate * dt)).normalized()
