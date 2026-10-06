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
	# M07: AI vs AI (autoplay). Blue's AI attacks from the lineup.
	scene = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	scene.autoplay = true
	root.add_child(scene)
	scene.passing.rng.seed = hash("pass-3")
	scene.team_control.attack_ai.rng.seed = hash("atk-3")
	scene.tackles.rng.seed = hash("tackle-3")
	var ev := {"pass": false, "tackle": false}
	scene.passing.pass_thrown.connect(func(_p, _r, _f): ev["pass"] = true)
	scene.tackles.tackle_made.connect(func(_d, _c, _r): ev["tackle"] = true)

	# 1. Support line shaping up as the defence comes up.
	await _ticks(40)
	await _shot("01_ai_attack_shape")

	# 2. First AI pass in flight.
	for i in 300:
		await physics_frame
		if ev["pass"]:
			break
	await _ticks(10)
	await _shot("02_ai_pass")

	# 3. Debug view: running line, inside support, chase / cover, decisions.
	scene.debug_overlay.toggle()
	await _ticks(20)
	await _shot("03_ai_debug")

	# 4. Contact.
	for i in 400:
		await physics_frame
		if ev["tackle"]:
			break
	await _ticks(3)
	await _shot("04_ai_tackle")
	quit(0)


func _stick(dir: Vector2) -> void:
	var it := SupportRunner.Intent.new()
	it.dir = dir
	it.mag = 1.0 if dir != Vector2.ZERO else 0.0
	scene.human.scripted = it


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Freezes the game while the frame is rendered (software GL in xvfb is slow;
## without the pause several physics ticks would pass before the capture).
func _shot(shot_name: String) -> void:
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := _out.path_join(shot_name + ".png")
	img.save_png(path)
	print("saved ", path)
	paused = false
