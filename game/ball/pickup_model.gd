class_name PickupModel
extends RefCounted
## Pure pickup rules: can a player reach a loose ball, and how likely is a
## clean pickup? Failure is a fumble (the ball is knocked on by the feet/hands).
##
## Feel goals:
##   * walking onto a still ball is (almost) always clean,
##   * scooping at full sprint is a real risk, smaller for good hands,
##   * a fast-moving / bouncing ball is harder than a dead one.


static func in_reach(player_pos: Vector3, ball_pos: Vector3, t: BallTuning) -> bool:
	if ball_pos.y > t.pickup_max_height:
		return false
	var d := Vector2(ball_pos.x - player_pos.x, ball_pos.z - player_pos.z)
	return d.length() <= t.pickup_reach


## handling: 0..1 normalized attribute. Speeds in m/s (ball speed relative to player).
static func chance(handling: float, player_speed: float, sprint_top: float, ball_rel_speed: float, t: BallTuning) -> float:
	var p := lerpf(t.pickup_base_min, t.pickup_base_max, handling)
	var half := sprint_top * 0.5
	var speed_t := clampf((player_speed - half) / maxf(half, 0.01), 0.0, 1.0)
	p -= lerpf(t.pickup_speed_pen_bad_hands, t.pickup_speed_pen_good_hands, handling) * speed_t
	var ball_t := clampf((ball_rel_speed - t.pickup_ball_speed_free) / maxf(t.pickup_ball_speed_full - t.pickup_ball_speed_free, 0.01), 0.0, 1.0)
	p -= t.pickup_ball_speed_pen * ball_t
	return clampf(p, 0.05, 0.99)


## Velocity the ball gets when a pickup is fumbled.
static func fumble_velocity(player_vel: Vector2, facing: Vector2, rng: RandomNumberGenerator, t: BallTuning) -> Vector3:
	var dir := player_vel.normalized() if player_vel.length() > 0.5 else facing
	dir = dir.rotated(deg_to_rad(t.fumble_spread_deg) * (rng.randf() * 2.0 - 1.0))
	var speed := t.fumble_kick_base + t.fumble_kick_per_speed * player_vel.length()
	var h := dir * speed
	return Vector3(h.x, t.fumble_kick_up * rng.randf_range(0.6, 1.2), h.y)
