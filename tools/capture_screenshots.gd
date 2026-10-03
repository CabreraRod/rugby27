extends SceneTree
## Dev tool: runs the match scene with a scripted sequence and saves screenshots.
##   godot --path . --script res://tools/capture_screenshots.gd -- <out_dir>
## Needs a real (or virtual, e.g. xvfb-run) display; not --headless.

var _out := "user://screenshots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://game/match/match.tscn").instantiate()
	root.add_child(scene)
	var player: RugbyPlayer = scene.get_node("Player")
	var ball: RugbyBall = scene.get_node("Ball")
	scene.get_node("HumanController").player = null
	await _frames(20)
	await _shot("01_kickoff_ball")

	# Jog onto the ball, pick it up and sprint with it.
	await _drive(player, Vector2.RIGHT, false, 70)
	await _drive(player, Vector2(1, -0.4), true, 50)
	await _shot("02_carrying")

	# Dev toss: ball bounces toward the player; debug shows predicted flight.
	scene.possession.drop(player)
	await _drive(player, Vector2.ZERO, false, 60)
	player.reset_to(Vector3(-10, 0, 5))
	scene.camera.snap()
	scene.toss_ball_to_player()
	scene.debug_overlay.toggle()
	await _drive(player, Vector2.ZERO, false, 14)
	await _shot("03_toss_debug_prediction")
	scene.debug_overlay.toggle()
	await _drive(player, Vector2.ZERO, false, 30)
	await _shot("04_loose_ball_bounce")

	# Carry it over the touchline.
	player.reset_to(Vector3(5, 0, 26), Vector2(0, 1))
	ball.spawn_loose(Vector3(5, 0.11, 26.4), Vector3.ZERO)
	scene.camera.snap()
	await _drive(player, Vector2(0.2, 1), true, 125)
	await _shot("05_touch")
	quit(0)


func _drive(p: RugbyPlayer, dir: Vector2, sprint: bool, frames: int) -> void:
	for i in frames:
		p.set_intent(dir, 1.0 if dir != Vector2.ZERO else 0.0, sprint)
		await physics_frame
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := _out.path_join(shot_name + ".png")
	img.save_png(path)
	print("saved ", path)
