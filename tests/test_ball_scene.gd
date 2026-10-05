extends TestSuite
## Integration: the real ball (Jolt RigidBody3D) + possession in the match scene.

var scene: Node3D
var player: RugbyPlayer
var ball: RugbyBall
var possession: PossessionController


func before_each() -> void:
	scene = load("res://game/match/match.tscn").instantiate()
	scene.solo = true   # single-player sandbox: M01-M03 behaviour
	tree.root.add_child(scene)
	player = scene.get_node("Player")
	ball = scene.get_node("Ball")
	possession = scene.get_node("Possession")
	scene.get_node("TeamControl").active = false
	# Park the player away from the ball unless a test says otherwise.
	player.reset_to(Vector3(-20, 0, 0))


func after_each() -> void:
	scene.queue_free()


func _ticks(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _run(dir: Vector2, sprint: bool, n: int) -> void:
	for i in n:
		player.set_intent(dir, 1.0, sprint)
		await tree.physics_frame


func test_dropped_ball_bounces_then_rests() -> void:
	ball.spawn_loose(Vector3(0, 2.0, 0), Vector3.ZERO)
	var max_after_first := 0.0
	var first_seen := false
	for i in 300:
		await tree.physics_frame
		if ball.bounce_count >= 1:
			first_seen = true
			max_after_first = maxf(max_after_first, ball.global_position.y)
	check(first_seen, "ball should bounce at least once")
	check(max_after_first < 1.6, "bounce apex %.2f m should be below the 2 m drop" % max_after_first)
	check(ball.ball_velocity().length() < 0.05, "ball should be at rest after 5 s (%.2f m/s)" % ball.ball_velocity().length())
	check(absf(ball.global_position.y - ball.tuning.radius) < 0.05, "resting on the grass (y %.3f)" % ball.global_position.y)


func test_rolling_ball_travels_forward_and_stops() -> void:
	ball.spawn_loose(Vector3(-10, 1.0, 0), Vector3(8, 0, 0))
	await _ticks(420)
	var x := ball.global_position.x
	check_between(x, -2.0, 18.0, "ball resting x after 8 m/s throw")
	check(ball.ball_velocity().length() < 0.05, "ball stopped")


func test_walking_onto_ball_picks_it_up() -> void:
	ball.spawn_loose(Vector3(-17, 0.11, 0), Vector3.ZERO)
	await _ticks(10)
	await _run(Vector2.RIGHT, false, 90)
	check(ball.carrier == player, "player should have the ball")
	check(player.role == RugbyPlayer.Role.BALL_CARRIER, "carrier role set automatically")
	check(ball.state == RugbyBall.State.HELD, "ball held")
	var socket := ball.carry_socket_position(player)
	check(ball.global_position.distance_to(socket) < 0.05, "ball sits in the carry socket")


func test_carried_ball_follows_player() -> void:
	ball.spawn_loose(Vector3(-19.5, 0.11, 0), Vector3.ZERO)
	await _ticks(5)
	await _run(Vector2.RIGHT, false, 10)
	check(ball.carrier == player, "picked up")
	await _run(Vector2(0, 1), true, 60)
	check(ball.global_position.distance_to(ball.carry_socket_position(player)) < 0.05, "ball still in hand while running")


func test_drop_releases_ball_forward() -> void:
	ball.spawn_loose(Vector3(-19.5, 0.11, 0), Vector3.ZERO)
	await _ticks(5)
	await _run(Vector2.RIGHT, false, 30)
	possession.drop(player)
	check(ball.state == RugbyBall.State.LOOSE, "ball loose after drop")
	check(player.role == RugbyPlayer.Role.NEUTRAL, "role cleared after drop")
	await _ticks(3)
	check(ball.ball_velocity().x > 0.5, "dropped ball travels forward")
	await _run(Vector2.ZERO, false, 10)
	check(ball.carrier == null, "pickup cooldown prevents instant re-grab")


func test_going_to_ground_places_ball() -> void:
	ball.spawn_loose(Vector3(-19.5, 0.11, 0), Vector3.ZERO)
	await _ticks(5)
	await _run(Vector2.RIGHT, false, 20)
	check(ball.carrier == player, "picked up")
	player.go_to_ground()
	check(ball.state == RugbyBall.State.LOOSE, "ball released when grounded")
	var behind := (ball.global_position.x - player.global_position.x) < 0.0
	check(behind, "ball placed behind the player")


func test_carrier_running_into_touch_kills_ball() -> void:
	var dead := [false, -1]
	ball.went_dead.connect(func(zone, _p): dead[0] = true; dead[1] = zone)
	player.reset_to(Vector3(0, 0, -31), Vector2(0, -1))
	ball.spawn_loose(Vector3(0, 0.11, -31.5), Vector3.ZERO)
	await _ticks(3)
	await _run(Vector2(0, -1), false, 120)
	check(dead[0], "ball should go dead in touch")
	check(dead[1] == FieldDimensions.Zone.TOUCH, "zone should be TOUCH")
	check(ball.state == RugbyBall.State.DEAD, "ball state DEAD")
	check(player.role == RugbyPlayer.Role.NEUTRAL, "carrier role cleared")


func test_rolling_ball_into_touch() -> void:
	var dead := [false]
	ball.went_dead.connect(func(_z, _p): dead[0] = true)
	ball.spawn_loose(Vector3(10, 0.11, 30), Vector3(0, 0, 7))
	await _ticks(240)
	check(dead[0], "rolling ball crossing the touchline is out")


func test_ball_over_touch_in_the_air_is_still_live() -> void:
	# Lobbed across the touchline: not out while it's in the air above touch,
	# out as soon as it lands beyond the line.
	var dead := [false]
	ball.went_dead.connect(func(_z, _p): dead[0] = true)
	ball.spawn_loose(Vector3(10, 4.0, 34.8), Vector3(0, 6, 1.5))
	await _ticks(25)   # ~0.4 s: still climbing, beyond the line
	check(ball.global_position.z > FieldDimensions.HALF_WIDTH, "ball is over touch")
	check(not dead[0], "a ball in flight over touch is still in play")
	await _ticks(200)
	check(dead[0], "it is out once it lands beyond the line")


func test_ball_bounces_off_posts() -> void:
	var post_z := FieldDimensions.POST_GAP * 0.5 + FieldDimensions.POST_RADIUS
	ball.spawn_loose(Vector3(FieldDimensions.HALF_LENGTH - 5.0, 1.0, post_z), Vector3(10, 0, 0))
	await _ticks(60)
	check(ball.global_position.x < FieldDimensions.HALF_LENGTH, "ball rebounds from the post protector (x %.2f)" % ball.global_position.x)


func test_fumble_at_sprint_happens_sometimes() -> void:
	# Many seeded attempts at full speed: a mix of clean takes and fumbles.
	var ok := 0
	var fumbles := 0
	player.reset_to(Vector3(0, 0, 0))
	player.set_profile(PlayerProfile.from_dict({"attributes": {"handling": 62, "speed": 82}}))
	for i in 40:
		player.planar_velocity = Vector2(9.0, 0)
		ball.spawn_loose(player.global_position + Vector3(0.3, 0.11, 0), Vector3(-6, 0, 0))
		if possession.attempt_pickup(player):
			ok += 1
		else:
			fumbles += 1
	check(ok > 5 and fumbles > 5, "sprint pickups should be a real risk (ok %d, fumbles %d)" % [ok, fumbles])
