extends SceneTree
## Dev tool: runs the match scene with a scripted run and saves screenshots.
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
	scene.get_node("HumanController").player = null
	await _frames(20)
	await _shot("01_kickoff_idle")

	# Sprint toward the right try line, cut infield, then plant and reverse.
	await _drive(player, Vector2.RIGHT, true, 70)
	await _shot("02_sprinting")
	await _drive(player, Vector2(1, -1), true, 18)
	await _shot("03_cutting")
	await _drive(player, Vector2.LEFT, true, 8)
	await _shot("04_planting")

	scene.debug_overlay.toggle()
	await _drive(player, Vector2(0.3, 1), false, 30)
	await _shot("05_debug_overlay")
	scene.debug_overlay.toggle()

	player.reset_to(Vector3(44, 0, 8))
	scene.camera.toggle_mode()
	scene.camera.snap()
	await _drive(player, Vector2.RIGHT, false, 60)
	await _shot("06_end_on_posts")
	quit(0)


func _drive(p: RugbyPlayer, dir: Vector2, sprint: bool, frames: int) -> void:
	for i in frames:
		p.set_intent(dir, 1.0, sprint)
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
