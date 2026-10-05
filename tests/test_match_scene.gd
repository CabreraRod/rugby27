extends TestSuite
## Integration: load the real match scene, drive the player through the real
## CharacterBody3D + Jolt path (no input devices), check it behaves.

var scene: Node3D
var player: RugbyPlayer


func before_each() -> void:
	scene = load("res://game/match/match.tscn").instantiate()
	scene.solo = true   # single-player sandbox: M01-M03 behaviour
	tree.root.add_child(scene)
	player = scene.get_node("Player")
	# Switch off TeamControl so the test owns the intent.
	scene.get_node("TeamControl").active = false


func after_each() -> void:
	scene.queue_free()


func _ticks(n: int) -> void:
	for i in n:
		await tree.physics_frame


func test_scene_builds_world() -> void:
	await _ticks(2)
	check(scene.get_node_or_null("Field/Ground") != null, "pitch exists")
	check(scene.get_node_or_null("Field/Posts_East") != null, "east posts exist")
	check(scene.get_node_or_null("BroadcastCamera") is Camera3D, "camera exists")
	check(scene.get_node_or_null("Sun") is DirectionalLight3D, "sun exists")


func test_player_stands_on_pitch() -> void:
	await _ticks(30)
	check(player.is_on_floor(), "player should be grounded on the pitch")
	check(absf(player.global_position.y) < 0.05, "player height %.3f" % player.global_position.y)


func test_player_runs_through_physics() -> void:
	await _ticks(5)
	var start := player.global_position
	for i in 120:
		player.set_intent(Vector2.RIGHT, 1.0, true)
		await tree.physics_frame
	var moved := player.global_position.x - start.x
	check_between(moved, 9.0, 17.0, "distance covered in 2 s sprint from rest (m)")
	check(player.stamina.value < player.stamina.max_value, "sprinting should cost stamina")


func test_posts_block_the_player() -> void:
	await _ticks(2)
	var post_z := FieldDimensions.POST_GAP * 0.5 + FieldDimensions.POST_RADIUS
	player.reset_to(Vector3(FieldDimensions.HALF_LENGTH - 6.0, 0, post_z))
	for i in 150:
		player.set_intent(Vector2.RIGHT, 1.0, false)
		await tree.physics_frame
	var blocked := player.global_position.x < FieldDimensions.HALF_LENGTH or absf(player.global_position.z - post_z) > 0.5
	check(blocked, "player should not pass through the post protector")


func test_ground_and_get_up() -> void:
	await _ticks(2)
	player.go_to_ground()
	check(player.state == RugbyPlayer.State.GROUNDED, "grounded state entered")
	var time := 0.0
	while player.state != RugbyPlayer.State.LOCOMOTION and time < 3.0:
		player.set_intent(Vector2.RIGHT, 1.0, false)
		await tree.physics_frame
		time += 1.0 / 60.0
	check_between(time, 0.8, 1.3, "total time on the ground (s)")
