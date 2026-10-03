class_name BounceModel
extends RefCounted
## Pure, seeded ground-bounce resolution for a rugby ball.
##
## The problem: a real oval ball bounces erratically. Fully simulating an
## ellipsoid looks chaotic and feels unfair; a sphere looks fake.
## The approach: sphere collision + a *controlled* random response:
##   * deflection angle drawn from a triangular distribution (mostly small,
##     occasionally big) and scaled by impact speed — soft bounces behave,
##     hard ones are wild,
##   * random restitution and horizontal speed loss,
##   * an occasional "sit up" (higher, slower bounce — the classic kind
##     bounce for the chaser),
##   * near-vertical drops scatter sideways instead of bouncing in place.
## Every number lives in BallTuning, every random draw comes from the given RNG
## (deterministic in tests and, later, replays).


class Result:
	var velocity := Vector3.ZERO
	var deflection := 0.0   ## radians applied to the horizontal direction
	var sat_up := false


static func resolve(v_in: Vector3, rng: RandomNumberGenerator, t: BallTuning) -> Result:
	var r := Result.new()
	var impact := maxf(-v_in.y, 0.0)
	var wild := clampf(impact / t.wild_impact_speed, 0.2, 1.0)

	var e := clampf(t.restitution + rng.randf_range(-t.restitution_var, t.restitution_var), 0.05, 0.9)
	var vy := impact * e
	# Soft impacts barely slow the ball; hard ones bleed speed.
	var keep := lerpf(0.97, rng.randf_range(t.horiz_keep_min, t.horiz_keep_max), wild)

	var h := Vector2(v_in.x, v_in.z)
	# Triangular distribution in [-1, 1], peaked at 0.
	var tri := rng.randf() + rng.randf() - 1.0
	r.deflection = deg_to_rad(t.max_deflect_deg) * wild * tri
	h = h.rotated(r.deflection) * keep

	# Near-vertical drop: scatter sideways in a random direction.
	var scatter := impact * t.drop_scatter * rng.randf()
	var weight := 1.0 - clampf(Vector2(v_in.x, v_in.z).length() / maxf(impact, 0.01), 0.0, 1.0)
	h += Vector2.RIGHT.rotated(rng.randf() * TAU) * scatter * weight

	if rng.randf() < t.sit_up_chance * wild:
		r.sat_up = true
		vy *= t.sit_up_vy_mult
		h *= t.sit_up_keep_mult

	r.velocity = Vector3(h.x, vy, h.y)
	return r


## Speed along the ground after rolling for dt.
static func roll(h: Vector2, t: BallTuning, dt: float) -> Vector2:
	var s := h.length()
	if s <= t.rest_speed:
		return Vector2.ZERO
	return h * (maxf(0.0, s - t.roll_decel * dt) / s)
