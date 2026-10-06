extends TestSuite
## M07 basic AI: spatial reasoning, team styles, attack decisions and the
## smarter defence (intercept-based chase, cover, dives).

var no_def: Array[Vector2] = []


# --- SpaceEval (pure) -----------------------------------------------------------------

func test_open_ray_has_full_range() -> void:
	check_between(SpaceEval.ray_space(Vector2.ZERO, Vector2.RIGHT, no_def, 20.0), 19.99, 20.01, "no defenders → max range")
	var d: Array[Vector2] = [Vector2(5, 0)]
	check_between(SpaceEval.ray_space(Vector2.ZERO, Vector2.RIGHT, d, 20.0), 2.4, 2.6, "defender on the line 5 m ahead → 2.5")
	var behind: Array[Vector2] = [Vector2(-4, 0)]
	check_between(SpaceEval.ray_space(Vector2.ZERO, Vector2.RIGHT, behind, 20.0), 19.99, 20.01, "defender behind ignored")


func test_best_line_runs_around_a_defender() -> void:
	var d: Array[Vector2] = [Vector2(4, 0)]
	var r := SpaceEval.best_line(Vector2.ZERO, Vector2.RIGHT, d, 45.0, 7, 20.0, 0.6, 5.0)
	var dir: Vector2 = r[0]
	check(absf(dir.angle()) > deg_to_rad(10.0), "angles away from a defender straight ahead (%.0f°)" % rad_to_deg(dir.angle()))
	var open := SpaceEval.best_line(Vector2.ZERO, Vector2.RIGHT, no_def, 45.0, 7, 20.0, 0.6, 5.0)
	check((open[0] as Vector2).is_equal_approx(Vector2.RIGHT), "open field → straight")


func test_best_line_avoids_touch() -> void:
	var near_touch := Vector2(0, FieldDimensions.HALF_WIDTH - 2.0)
	var r := SpaceEval.best_line(near_touch, Vector2.RIGHT, no_def, 45.0, 7, 20.0, 0.0, 5.0)
	check((r[0] as Vector2).y <= 0.01, "does not run into touch (dir %s)" % [r[0]])


func test_lane_clearance() -> void:
	var on_lane: Array[Vector2] = [Vector2(-1, 5)]
	check(SpaceEval.lane_clearance(Vector2.ZERO, Vector2(-2, 10), on_lane) < 0.5, "defender in the lane")
	var on_passer: Array[Vector2] = [Vector2(0.3, 0.3)]
	check(SpaceEval.lane_clearance(Vector2.ZERO, Vector2(-2, 10), on_passer) > 1.0, "the tackler on the passer doesn't block the lane")


func test_gap_near_finds_widest_gap() -> void:
	var line: Array[Vector2] = [Vector2(5, 0), Vector2(5, 2), Vector2(5, 10)]
	var g := SpaceEval.gap_near(4.0, Vector2(0, 1), line, 5.0)
	check_between(g, 5.9, 6.1, "gap between z=2 and z=10 → centre 6")
	check(is_nan(SpaceEval.gap_near(40.0, Vector2(0, 1), line, 5.0)), "no gap within the window → NAN")


func test_intercept_time() -> void:
	check_between(SpaceEval.intercept_time(Vector2.ZERO, 8.0, Vector2(16, 0), Vector2.ZERO), 1.99, 2.01, "standing runner: d / s")
	check(SpaceEval.intercept_time(Vector2.ZERO, 7.0, Vector2(5, 0), Vector2(9, 0)) < 0.0, "faster runner running away can't be caught")
	var t_across := SpaceEval.intercept_time(Vector2(0, -10), 9.0, Vector2(0, 0), Vector2(6, 0))
	check(t_across > 0.0 and t_across < 2.0, "faster chaser cuts across (%.2f s)" % t_across)


# --- TeamStyle ---------------------------------------------------------------------

func test_style_parsing_and_mapping() -> void:
	var s := TeamStyle.from_dict({"tempo": 150, "width": -5, "aggression": 100})
	check(s.tempo == 100.0 and s.width == 0.0 and s.passing == 50.0, "clamped, missing = 50")
	var wide := TeamStyle.from_dict({"width": 100})
	var narrow := TeamStyle.from_dict({"width": 0})
	check(wide.width_factor() > narrow.width_factor(), "width widens support")
	var rush := TeamStyle.from_dict({"aggression": 100}).defence_shape()
	var sit := TeamStyle.from_dict({"aggression": 0}).defence_shape()
	check(rush[1] < sit[1] and rush[2] > sit[2], "aggressive defence retreats less and engages earlier")


func test_style_scales_support_and_tempo() -> void:
	var base := SupportTuning.new()
	var wide := AttackAI.styled_support(base, TeamStyle.from_dict({"width": 100, "tempo": 100}))
	var narrow := AttackAI.styled_support(base, TeamStyle.from_dict({"width": 0, "tempo": 0}))
	check(wide.spacing > narrow.spacing * 1.3, "spacing %.1f vs %.1f" % [wide.spacing, narrow.spacing])
	check(wide.depth_first < narrow.depth_first, "high tempo stands flatter")
	check(base.spacing == SupportTuning.new().spacing, "base tuning untouched")


# --- in match (AI vs AI) -------------------------------------------------------------

## Runs `runs` seeded AI-vs-AI attacks (blue attacking from the lineup).
func _soak(runs: int, atk_level: int, def_level: int, ticks := 480) -> Dictionary:
	var S := {"metres": 0.0, "passes": 0, "compl": 0, "tackles": 0, "dives": 0}
	for run in runs:
		var scene: Node3D = load("res://game/match/match.tscn").instantiate()
		scene.solo = false
		scene.autoplay = true
		scene.ai_level = atk_level
		scene.opp_ai_level = def_level
		tree.root.add_child(scene)
		scene.passing.rng.seed = hash("pass-%d" % run)
		scene.possession.rng.seed = hash("poss-%d" % run)
		scene.tackles.rng.seed = hash("tackle-%d" % run)
		scene.team_control.attack_ai.rng.seed = hash("atk-%d" % run)
		scene.opp_control.attack_ai.rng.seed = hash("datk-%d" % run)
		var team: Team = scene.team
		scene.passing.pass_thrown.connect(func(p, _r, _f): if p.team == team: S["passes"] += 1)
		scene.passing.pass_completed.connect(func(p, _r): if p.team == team: S["compl"] += 1)
		scene.tackles.tackle_made.connect(func(_d, c, _r): if c.team == team: S["tackles"] += 1)
		await tree.physics_frame
		var start_x: float = scene.ball.global_position.x
		var best := start_x
		for i in ticks:
			await tree.physics_frame
			for d in scene.opp.players:
				if d.is_diving():
					S["dives"] += 1
					break
			var c: RugbyPlayer = scene.ball.carrier
			if c and c.team != team:
				break
			if c:
				best = maxf(best, c.global_position.x)
				if c.global_position.x >= FieldDimensions.HALF_LENGTH:
					break
			if scene.ball.state == RugbyBall.State.DEAD:
				break
		S["metres"] += best - start_x
		scene.queue_free()
		await tree.process_frame
	S["metres"] /= runs
	return S


func test_ai_attack_passes_and_gains_ground() -> void:
	var s: Dictionary = await _soak(4, 1, 1)
	check(s["passes"] >= 4, "AI attack moves the ball (%d passes in 4 attacks)" % s["passes"])
	check(s["compl"] >= int(s["passes"] * 0.6), "most passes go to hand (%d/%d)" % [s["compl"], s["passes"]])
	check(s["metres"] > 5.0, "gains ground (%.1f m)" % s["metres"])
	check(s["tackles"] > 0, "and gets tackled sometimes (%d)" % s["tackles"])


func test_new_defence_stops_the_placeholder_attack() -> void:
	var old: Dictionary = await _soak(4, 0, 0)
	var smart: Dictionary = await _soak(4, 0, 1)
	check(smart["metres"] < old["metres"], "M07 defence concedes less (%.1f vs %.1f m)" % [smart["metres"], old["metres"]])
	check(smart["tackles"] > old["tackles"], "and makes more tackles (%d vs %d)" % [smart["tackles"], old["tackles"]])


func test_ai_decision_under_pressure() -> void:
	# A defender right on the carrier and an unmarked receiver: pass.
	var scene: Node3D = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	scene.autoplay = true
	tree.root.add_child(scene)
	await tree.physics_frame
	var ctl: TeamControl = scene.team_control
	var carrier: RugbyPlayer = scene.ball.carrier
	check(carrier != null, "someone has the ball")
	if carrier:
		var ai: AttackAI = ctl.attack_ai
		# Drive the decision by hand: no team logic, no tackles.
		scene.tackles.set_physics_process(false)
		ctl.active = false
		scene.opp_control.active = false
		var pos := carrier.planar_position()
		# Park every defender just ahead of the carrier.
		for d in scene.opp.players:
			d.global_position = Vector3(pos.x + 2.4, d.global_position.y, pos.y + 0.3)
		await tree.physics_frame
		var passed := {"n": 0}
		scene.passing.pass_thrown.connect(func(p, _r, _f): if p == carrier: passed["n"] += 1)
		for i in 40:
			ai.carrier_intent(carrier, scene.team, scene.opp, scene.passing, 1.0, 1.0 / 60.0)
			if passed["n"] > 0 or scene.passing.charging or scene.passing.in_flight:
				break
			await tree.physics_frame
		check(passed["n"] > 0 or scene.passing.charging or scene.passing.in_flight, "passes when swamped (%s)" % ai.last_decision)
	scene.queue_free()
	await tree.process_frame


func test_chaser_is_the_fastest_to_intercept() -> void:
	var scene: Node3D = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	tree.root.add_child(scene)
	await tree.physics_frame
	var carrier: RugbyPlayer = scene.ball.carrier
	var a: RugbyPlayer = scene.opp.players[0]
	var b: RugbyPlayer = scene.opp.players[1]
	# a: slightly nearer but behind the runner; b: further but ahead of him.
	carrier.global_position = Vector3(0, carrier.global_position.y, 0)
	carrier.planar_velocity = Vector2(8, 0)
	a.global_position = Vector3(-5, a.global_position.y, 3)
	b.global_position = Vector3(9, b.global_position.y, 5)
	var pick := DefensiveLine._fastest_to([a, b] as Array[RugbyPlayer], carrier)
	check(pick == b, "the defender ahead of the runner chases, not the nearest one behind (%s)" % (pick.name if pick else "none"))
	scene.queue_free()
	await tree.process_frame
