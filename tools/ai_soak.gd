extends SceneTree
## AI vs AI soak (M07). Both teams AI; the blue team attacks from the
## lineup for up to 10 s or until the ball is lost / dead / carried into
## the in-goal. Compares the M04-M06 placeholder AI (level 0) with the M07
## basic AI (level 1) in all four attack x defence pairings.
##   godot --headless --path . --script res://tools/ai_soak.gd [-- runs]

const TICKS := 600

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 16
	print("attack vs defence | metres  tries  breaks  passes(compl)  tackles(broken)  turnovers  carries")
	for pair in [[0, 0], [1, 0], [0, 1], [1, 1]]:
		var S := {"metres": 0.0, "tries": 0, "breaks": 0, "passes": 0, "compl": 0, "tackles": 0, "broken": 0, "turnovers": 0, "carries": 0}
		for run in runs:
			var scene: Node3D = load("res://game/match/match.tscn").instantiate()
			scene.solo = false
			scene.autoplay = true
			scene.ai_level = pair[0]
			scene.opp_ai_level = pair[1]
			root.add_child(scene)
			scene.passing.rng.seed = hash("pass-%d" % run)
			scene.possession.rng.seed = hash("poss-%d" % run)
			scene.tackles.rng.seed = hash("tackle-%d" % run)
			scene.team_control.attack_ai.rng.seed = hash("atk-%d" % run)
			scene.opp_control.attack_ai.rng.seed = hash("datk-%d" % run)
			var team: Team = scene.team
			var st := {"best": -INF, "broke": false}
			scene.passing.pass_thrown.connect(func(p, _r, _f): if p.team == team: S["passes"] += 1)
			scene.passing.pass_completed.connect(func(p, _r): if p.team == team: S["compl"] += 1)
			scene.tackles.tackle_made.connect(func(_d, c, r):
				if c.team == team:
					S["tackles"] += 1
					if r.outcome == TackleModel.Outcome.BROKEN: S["broken"] += 1)
			scene.ball.carrier_changed.connect(func(_o, n): if n and n.team == team: S["carries"] += 1)
			await physics_frame
			var start_x: float = scene.ball.global_position.x
			for tick in TICKS:
				await physics_frame
				var c: RugbyPlayer = scene.ball.carrier
				if c and c.team != team:
					S["turnovers"] += 1
					break
				if c:
					st["best"] = maxf(st["best"], c.global_position.x)
					if c.global_position.x >= FieldDimensions.HALF_LENGTH:
						S["tries"] += 1
						break
					if not st["broke"]:
						var all_behind := true
						for d in scene.opp.players:
							if d.is_controllable() and d.global_position.x > c.global_position.x - 3.0:
								all_behind = false
								break
						if all_behind:
							st["broke"] = true
							S["breaks"] += 1
				if scene.ball.state == RugbyBall.State.DEAD:
					break
			S["metres"] += maxf(st["best"], start_x) - start_x
			scene.queue_free()
			await process_frame
		var lv := ["old", "NEW"]
		print("%s vs %s      | %5.1f  %4d  %5d  %5d(%d)  %7d(%d)  %8d  %6d" % [lv[pair[0]], lv[pair[1]], S["metres"] / runs, S["tries"], S["breaks"], S["passes"], S["compl"], S["tackles"], S["broken"], S["turnovers"], S["carries"]])
	quit(0)
