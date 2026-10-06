extends SceneTree
## Tackle soak: seeded 6v6 phases with real tackling.
##   godot --headless --path . --script res://tools/tackle_soak.gd
## A — we attack (scripted run, a pass every ~1 s while we have it).
## B — they attack; our controlled defender chases the ball.
## Reports tackle outcomes (vs. pro rugby: ~85-90 % of tackles hold),
## spills, metres per carry before the first tackle.

const RUNS := 24
const TICKS := 360

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for scenario in ["A (we attack)", "B (they attack)"]:
		var S := {"n": 0, "broken": 0, "dominant": 0, "spills": 0, "metres": 0.0, "firsts": 0}
		var by_matchup := {}
		for run in RUNS:
			var scene: Node3D = load("res://game/match/match.tscn").instantiate()
			scene.solo = false
			root.add_child(scene)
			scene.passing.rng.seed = hash("pass-%d" % run)
			scene.possession.rng.seed = hash("poss-%d" % run)
			scene.tackles.rng.seed = hash("tackle-%d" % run)
			var attackers: Team = scene.team
			if scenario.begins_with("B"):
				attackers = scene.opp
				scene.ball.attach(scene.opp.players[0])
			await physics_frame
			var start_x: float = scene.ball.global_position.x
			var st := {"first": false}
			scene.tackles.tackle_made.connect(func(d, c, r):
				if c.team != attackers:
					return
				S["n"] += 1
				if OS.get_cmdline_user_args().has("--verbose"):
					var nrm: Vector2 = (c.planar_position() - d.planar_position()).normalized()
					print("   %s closing %.1f carrier %.1f appr %.1f fend %s side %s dive %s score %.2f p_break %.2f -> %s" % [d.profile.position, maxf(0.0, d.momentum_velocity.dot(nrm)), c.momentum_velocity.length(), r.approach, c.fend_timer > 0, c.sidestep_timer > 0, d.is_diving(), r.score, r.p_break, TackleModel.Outcome.keys()[r.outcome]])
				if r.outcome == TackleModel.Outcome.BROKEN: S["broken"] += 1
				if r.outcome == TackleModel.Outcome.DOMINANT: S["dominant"] += 1
				if r.spill: S["spills"] += 1
				var key := "%s on %s" % [d.profile.position, c.profile.position]
				if not by_matchup.has(key): by_matchup[key] = [0, 0]
				by_matchup[key][0] += 1
				if r.outcome == TackleModel.Outcome.BROKEN: by_matchup[key][1] += 1
				if not st["first"] and r.outcome != TackleModel.Outcome.BROKEN:
					st["first"] = true
					S["firsts"] += 1
					S["metres"] += (c.global_position.x - start_x) * attackers.attack_dir)
			var it := SupportRunner.Intent.new()
			it.mag = 1.0
			scene.human.scripted = it
			for tick in TICKS:
				if scenario.begins_with("A"):
					it.dir = Vector2.RIGHT
					var c: RugbyPlayer = scene.ball.carrier
					if tick % 60 == 50 and c and c.team == attackers and c == scene.team_control.controlled:
						scene.passing.throw(c, PassTargeting.LEFT if (tick / 60) % 2 == 0 else PassTargeting.RIGHT, false)
				else:
					var me: RugbyPlayer = scene.team_control.controlled
					var b: Vector3 = scene.ball.global_position
					it.dir = (Vector2(b.x, b.z) - me.planar_position()).normalized()
					it.sprint = true
				await physics_frame
				if scene.ball.state == RugbyBall.State.DEAD:
					break
			scene.queue_free()
			await process_frame
		var n: int = S["n"]
		print("%s: tackles %d, broken %d (%.0f%%), dominant %d (%.0f%%), spills %d, metres before first tackle %.1f (%d runs)" % [scenario, n, S["broken"], 100.0 * S["broken"] / maxi(n, 1), S["dominant"], 100.0 * S["dominant"] / maxi(n, 1), S["spills"], S["metres"] / maxi(S["firsts"], 1), S["firsts"]])
		var keys := by_matchup.keys()
		keys.sort()
		for k in keys:
			print("    %-28s %3d tackles, %2d broken" % [k, by_matchup[k][0], by_matchup[k][1]])
	quit(0)
