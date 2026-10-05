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
	var passing: PassingSystem = scene.passing
	var ball: RugbyBall = scene.ball
	await _frames(20)
	await _shot("01_lineup_markers")

	# Run forward with the line, then 9 -> 10 -> 12 -> 13.
	_stick(Vector2.RIGHT)
	await _ticks(60)
	await _shot("02_running_line")
	scene.debug_overlay.toggle()
	passing.throw(ball.carrier, PassTargeting.LEFT, false)
	await _ticks(14)
	await _shot("03_pass_in_flight_debug")
	scene.debug_overlay.toggle()
	await _wait_held()
	await _ticks(20)
	passing.begin(ball.carrier, PassTargeting.LEFT)
	await _ticks(12)
	await _shot("04_charging_long")
	passing.release()
	await _ticks(8)
	await _shot("05_catch_pose")
	await _wait_held()
	await _ticks(20)
	# Nobody further out: the 13 gives it back inside to the 12.
	passing.throw(ball.carrier, PassTargeting.RIGHT, false)
	await _wait_held()
	await _ticks(10)
	await _shot("06_back_inside")
	quit(0)


func _stick(dir: Vector2) -> void:
	var it := SupportRunner.Intent.new()
	it.dir = dir
	it.mag = 1.0
	scene.human.scripted = it


func _wait_held() -> void:
	for i in 150:
		await physics_frame
		if scene.ball.state == RugbyBall.State.HELD:
			return


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
