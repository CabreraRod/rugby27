class_name PassSolver
extends RefCounted
## Pure pass-flight maths.
##
## The pass leads a moving receiver: we solve for a flight time T such that
## the ball, thrown at roughly `speed`, meets the receiver's predicted
## position (current velocity extrapolated) at chest height. Then the
## release velocity is the ballistic solution for that point and T.


class Plan:
	var aim := Vector3.ZERO     ## where the ball should arrive
	var flight_time := 0.5
	var velocity := Vector3.ZERO


static func intercept(p0: Vector3, target: Vector2, target_vel: Vector2, speed: float, t: PassingTuning) -> Plan:
	var from := Vector2(p0.x, p0.z)
	var time := clampf((target - from).length() / speed, t.min_flight, t.max_flight)
	var aim := target
	for i in 4:
		aim = target + target_vel * time
		time = clampf((aim - from).length() / speed, t.min_flight, t.max_flight)
	aim = target + target_vel * time
	var plan := Plan.new()
	plan.aim = Vector3(aim.x, t.catch_height, aim.y)
	plan.flight_time = time
	return plan


## Release velocity that reaches `aim` in `time` under gravity, compensating
## (approximately) for linear air damping.
static func ballistic(p0: Vector3, aim: Vector3, time: float, air_damp: float, gravity: float) -> Vector3:
	var comp := 1.0 + air_damp * time * 0.5
	var h := Vector2(aim.x - p0.x, aim.z - p0.z) / time * comp
	var vy := (aim.y - p0.y + 0.5 * gravity * time * time) / time * comp
	return Vector3(h.x, vy, h.y)


## Aim error. Bad passes go too long/short, low/high, or BEHIND the receiver
## — never forward (a forward pass should come from the player's choice,
## not from dice).
static func error_offset(rng: RandomNumberGenerator, sd: float, attack: Vector2, side_vec: Vector2) -> Vector3:
	var along := _gauss(rng) * sd
	var back := -absf(_gauss(rng)) * sd * 0.6
	var up := _gauss(rng) * sd * 0.35
	var h := side_vec * along + attack * back
	return Vector3(h.x, up, h.y)


static func error_sd(passing: float, long: bool, speed_ratio: float, t: PassingTuning) -> float:
	var sd := lerpf(t.err_max, t.err_min, passing)
	if long:
		sd *= t.err_long_mult
	return sd * (1.0 + t.err_speed_mult * clampf(speed_ratio, 0.0, 1.0))


## ~N(0, 1) from three uniforms (cheap, bounded at ±3).
static func _gauss(rng: RandomNumberGenerator) -> float:
	return (rng.randf() + rng.randf() + rng.randf() - 1.5) * 2.0


## Ball velocity component toward the opponents' line, relative to the
## passer's own motion. Momentum carrying the ball forward is legal; the
## hands sending it forward is not.
static func forward_speed(ball_v: Vector3, passer_v: Vector2, attack: Vector2) -> float:
	return (Vector2(ball_v.x, ball_v.z) - passer_v).dot(attack)
