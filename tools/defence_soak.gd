extends SceneTree
## Defence soak: seeded 6v6 phases, no tackling (M07). Measures how well the
## placeholder defence pressures the carrier and how often it is broken.
##   godot --headless --path . --script res://tools/defence_soak.gd
##
## Scenario A — we attack: run forward, pass left every ~1 s (3 passes).
## Scenario B — they attack: the AI carrier (opponents) vs our AI defence.
##
## Pressure: share of ticks with a defender within 3 m in front of the carrier.
## Line break: the carrier gets 3 m past every defender (along attack).

const RUNS := 24
const TICKS := 300

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for scenario in ["A (we attack)", "B (they attack)"]:
		var pressure_ticks := 0
		var carried_ticks := 0
		var breaks := 0
		var turnovers := 0
		var passes := 0
		var completed := 0
		var metres := 0.0
		for run in RUNS:
			var scene: Node3D = load("res://game/match/match.tscn").instantiate()
			scene.solo = false
			root.add_child(scene)
			scene.passing.rng.seed = hash("pass-%d" % run)  # well-spread seeds: PCG seeds next to each other correlate early draws
			scene.possession.rng.seed = hash("poss-%d" % run)
			scene.tackles.rng.seed = hash("tackle-%d" % run)
			var counts := [0, 0, 0]  # thrown, completed, intercepted
			scene.passing.pass_thrown.connect(func(_a, _b, _f): counts[0] += 1)
			scene.passing.pass_completed.connect(func(_a, _b): counts[1] += 1)
			if OS.get_cmdline_user_args().has("--verbose"):
				scene.possession.caught.connect(func(p, c):
					var r: RugbyPlayer = scene.passing.flight_receiver
					if r and p.team != r.team:
						print("  run %d INTERCEPT by #%d chance %.2f, %.1f m from the receiver" % [run, p.profile.number, c, p.planar_position().distance_to(r.planar_position())]))
				scene.possession.catch_failed.connect(func(p, c, k):
					print("  run %d failed catch #%d (%s) chance %.2f knock_on %s" % [run, p.profile.number, "def" if scene.passing.flight_receiver and p.team != scene.passing.flight_receiver.team else "att", c, k]))
				scene.passing.pass_ended.connect(func(_p):
					if scene.ball.is_loose():
						print("  run %d pass ended loose (bounced/missed), receiver #%s" % [run, str(scene.passing.flight_receiver.profile.number) if scene.passing.flight_receiver else "-"]))
			var attackers: Team = scene.team
			var defenders: Team = scene.opp
			var it := SupportRunner.Intent.new()
			if scenario.begins_with("B"):
				attackers = scene.opp
				defenders = scene.team
				scene.ball.attach(scene.opp.players[0])
				# Human defender: idle stick (AI marks the rest).
				scene.human.scripted = it
			else:
				it.dir = Vector2.RIGHT
				it.mag = 1.0
				it.sprint = run % 2 == 1
				scene.human.scripted = it
			await physics_frame
			var start_x: float = scene.ball.global_position.x
			var broke := false
			var last_owner_team: Team = attackers
			for tick in TICKS:
				await physics_frame
				if scenario.begins_with("A") and tick in [50, 110, 170]:
					var c: RugbyPlayer = scene.ball.carrier
					if c and c.team == attackers:
						scene.passing.throw(c, PassTargeting.LEFT, false)
				var carrier: RugbyPlayer = scene.ball.carrier
				if carrier:
					if carrier.team != last_owner_team and carrier.team == defenders:
						turnovers += 1
						last_owner_team = defenders
						break
					if carrier.team == attackers:
						carried_ticks += 1
						var atk: Vector2 = attackers.attack()
						var pressed := false
						var min_ahead := INF
						for d in defenders.players:
							var rel: Vector2 = d.planar_position() - carrier.planar_position()
							var ahead := rel.dot(atk)
							min_ahead = minf(min_ahead, -ahead) if ahead < 0 else min_ahead
							if ahead > -0.5 and rel.length() < 3.0:
								pressed = true
						if pressed:
							pressure_ticks += 1
						var all_behind := true
						for d in defenders.players:
							if (d.planar_position() - carrier.planar_position()).dot(atk) > -3.0:
								all_behind = false
								break
						if all_behind and not broke:
							broke = true
							breaks += 1
				if scene.ball.state == RugbyBall.State.DEAD:
					break
			metres += (scene.ball.global_position.x - start_x) * attackers.attack_dir
			passes += counts[0]
			completed += counts[1]
			scene.queue_free()
			await process_frame
		print("%s: pressure %.0f%% of carry time, line breaks %d/%d runs, turnovers %d, passes %d (completed %d), avg metres %.1f" % [scenario, 100.0 * pressure_ticks / maxi(carried_ticks, 1), breaks, RUNS, turnovers, passes, completed, metres / RUNS])
	quit(0)
