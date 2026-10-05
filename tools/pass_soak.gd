extends SceneTree
## Soak: many seeded 9-10-12-13 chains (quick and long passes, jogging and
## sprinting). Prints completion stats. Usage:
##   godot --headless --path . --script res://tools/pass_soak.gd

const RUNS := 24

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var thrown := 0
	var completed := 0
	var drops := 0
	var forward := 0
	var full_chains := 0
	for run in RUNS:
		var scene: Node3D = load("res://game/match/match.tscn").instantiate()
		scene.solo = false
		root.add_child(scene)
		scene.passing.rng.seed = 1000 + run
		scene.possession.rng.seed = 2000 + run
		var it := SupportRunner.Intent.new()
		it.dir = Vector2.RIGHT
		it.mag = 1.0
		it.sprint = run % 2 == 1
		scene.human.scripted = it
		var counts := [0, 0]
		scene.possession.catch_failed.connect(func(pl, c, _k):
			counts[0] += 1
			print("  drop #%d chance %.2f | %s" % [pl.profile.number, c, _why(scene, pl)]))
		scene.passing.pass_thrown.connect(func(_a, _b, f): if f: counts[1] += 1)
		for i in 50: await physics_frame
		var ok := 0
		for n in 3:
			for i in 20: await physics_frame
			var passer: RugbyPlayer = scene.ball.carrier
			if passer == null: break
			var long := run % 3 == 2 and n == 0
			var target: RugbyPlayer = scene.passing.preview(passer, PassTargeting.LEFT, long)
			if target == null:
				ok = 3   # nobody left outside: the move is complete
				break
			scene.passing.throw(passer, PassTargeting.LEFT, long)
			thrown += 1
			var got: RugbyPlayer = null
			for i in 150:
				await physics_frame
				if scene.ball.state == RugbyBall.State.HELD:
					got = scene.ball.carrier
					break
			if got != target:
				print("  run %d pass %d: wanted #%s got %s, ball %s at %s" % [run, n, str(target.profile.number) if target else "-", str(got.profile.number) if got else "nobody", RugbyBall.State.keys()[scene.ball.state], scene.ball.global_position])
			if got == target and target != null:
				completed += 1
				ok += 1
			else:
				break
		if ok == 3: full_chains += 1
		drops += counts[0]
		forward += counts[1]
		scene.queue_free()
		await process_frame
	print("(a run is a full move when every available receiver on the left got the ball)")
	print("passes thrown %d, completed %d (%.0f%%), drops %d, forward %d, full moves %d/%d" % [thrown, completed, 100.0 * completed / maxi(thrown, 1), drops, forward, full_chains, RUNS])
	quit(0)


func _why(scene, pl: RugbyPlayer) -> String:
	var bpos: Vector3 = scene.ball.global_position
	var bv: Vector3 = scene.ball.ball_velocity()
	var rel := (bv - Vector3(pl.planar_velocity.x, 0, pl.planar_velocity.y)).length()
	var to_ball := Vector2(bpos.x, bpos.z) - pl.planar_position()
	var behind := -to_ball.dot(pl.facing)
	return "rel %.1f m/s behind %.2f m height %.2f m dist %.2f" % [rel, behind, bpos.y - pl.global_position.y, to_ball.length()]
