class_name CatchModel
extends RefCounted
## Pure catching rules for a ball in the air.
##
## Feel goals:
##   * a flat, chest-high pass to a good handler sticks almost always,
##   * fast passes, balls at the bootlaces / overhead and balls arriving
##     behind the body are where drops happen,
##   * a drop forward off the hands is a knock-on.


static func in_reach(player_pos: Vector3, ball_pos: Vector3, reach: float, t: PassingTuning) -> bool:
	var h := ball_pos.y - player_pos.y
	if h < t.catch_min_height or h > t.catch_max_height:
		return false
	return Vector2(ball_pos.x - player_pos.x, ball_pos.z - player_pos.z).length() <= reach


## True when the ball is as close as it is going to get (or already "in the
## hands"): catching is judged then, with the best height/angle on offer.
static func at_closest_approach(player_pos: Vector3, player_vel: Vector2, ball_pos: Vector3, ball_vel: Vector3, dt: float, t: PassingTuning) -> bool:
	var rel := Vector2(ball_pos.x - player_pos.x, ball_pos.z - player_pos.z)
	if rel.length() <= t.catch_sure_dist:
		return true
	var rel_next := rel + (Vector2(ball_vel.x, ball_vel.z) - player_vel) * dt
	return rel_next.length() >= rel.length()


## handling 0..1; rel_speed = |ball - receiver| (m/s); behind = how far the
## ball is behind the receiver's body along their facing (m, >0 = behind);
## height = ball height above the receiver's feet (m).
static func chance(handling: float, rel_speed: float, behind: float, height: float, t: PassingTuning) -> float:
	var p := lerpf(t.catch_base_min, t.catch_base_max, handling)
	var sp := clampf((rel_speed - t.catch_speed_free) / maxf(t.catch_speed_full - t.catch_speed_free, 0.01), 0.0, 1.0)
	p -= t.catch_speed_pen * sp
	p -= t.catch_behind_pen * clampf((behind - 0.2) / 0.6, 0.0, 1.0)
	var off := 0.0
	if height < t.catch_comfort_low:
		off = (t.catch_comfort_low - height) / maxf(t.catch_comfort_low - t.catch_min_height, 0.01)
	elif height > t.catch_comfort_high:
		off = (height - t.catch_comfort_high) / maxf(t.catch_max_height - t.catch_comfort_high, 0.01)
	p -= t.catch_height_pen * clampf(off, 0.0, 1.0)
	return clampf(p, 0.05, 0.995)


## Ball off the hands after a dropped catch. Usually forward (knock-on),
## sometimes it squirts backwards.
static func knock_velocity(ball_v: Vector3, attack: Vector2, rng: RandomNumberGenerator, t: PassingTuning) -> Vector3:
	var dir := attack if rng.randf() >= t.knock_back_chance else -attack
	dir = dir.rotated(deg_to_rad(40.0) * (rng.randf() * 2.0 - 1.0))
	var h := Vector2(ball_v.x, ball_v.z) * 0.2 + dir * t.knock_speed * rng.randf_range(0.7, 1.3)
	return Vector3(h.x, t.knock_up * rng.randf_range(0.6, 1.2), h.y)


static func is_knock_on(v: Vector3, attack: Vector2) -> bool:
	return Vector2(v.x, v.z).dot(attack) > 0.0
