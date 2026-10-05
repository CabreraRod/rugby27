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
	await _shot("01_six_v_six")

	# Attack: the line comes up to meet us.
	_stick(Vector2.RIGHT)
	await _ticks(70)
	await _shot("02_defence_comes_up")
	scene.debug_overlay.toggle()
	passing.throw(ball.carrier, PassTargeting.LEFT, false)
	await _ticks(10)
	await _shot("03_debug_marks_and_pass")
	scene.debug_overlay.toggle()

	# Force a turnover: hand the ball to their 10 near our line.
	await _ticks(40)
	var o10: RugbyPlayer = null
	for p in scene.opp.players:
		if p.profile.number == 10:
			o10 = p
	scene.possession.clear_cooldowns()
	scene.possession.last_gain = &"pickup"   # staged turnover, not an interception
	ball.attach(o10)
	_stick(Vector2.ZERO)
	await _ticks(45)
	await _shot("04_turnover_we_defend")
	scene.debug_overlay.toggle()
	await _ticks(30)
	await _shot("05_defence_debug")
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
