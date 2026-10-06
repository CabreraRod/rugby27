extends SceneTree
## Dev tool: runs the match scene with a scripted sequence and saves screenshots.
##   godot --path . --script res://tools/capture_screenshots.gd -- <out_dir>
## Needs a real (or virtual, e.g. xvfb-run) display; not --headless.

var _out := "user://screenshots"
var scene: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	scene = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	root.add_child(scene)
	var ball: RugbyBall = scene.ball
	await _frames(20)

	# 1. Run at the line: the moment of contact, then the tackled player down.
	var shot := {"taken": false}
	scene.tackles.tackle_made.connect(func(_d, _c, _r): shot["taken"] = true)
	_stick(Vector2.RIGHT)
	for i in 240:
		await physics_frame
		if shot["taken"]:
			break
	await _ticks(2)
	await _shot("01_tackle_contact")
	await _ticks(25)
	await _shot("02_tackled_ball_placed")

	# 2. Defence: their 9 carries, our controlled defender dives.
	scene.reset_play()
	scene.possession.clear_cooldowns()
	var o9: RugbyPlayer = scene.opp.players[0]
	ball.attach(o9)
	await _ticks(30)
	var me: RugbyPlayer = scene.team_control.controlled
	me.reset_to(o9.global_position + Vector3(-3.5, 0, 0.6), Vector2(1, -0.15).normalized())
	await _ticks(1)
	me.try_dive()
	await _ticks(6)
	await _shot("03_dive_tackle")
	scene.debug_overlay.toggle()
	await _ticks(20)
	await _shot("04_debug_tackle_info")
	quit(0)


func _stick(dir: Vector2) -> void:
	var it := SupportRunner.Intent.new()
	it.dir = dir
	it.mag = 1.0 if dir != Vector2.ZERO else 0.0
	scene.human.scripted = it


func _ticks(n: int) -> void:
	for i in n:
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
