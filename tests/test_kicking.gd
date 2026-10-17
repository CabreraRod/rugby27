extends TestSuite
## M09 kicking: pure flight / charge / drop / catch maths + in-game kicks.

var t: KickTuning
const G := 9.8
const DAMP := 0.03
const R := 0.11


func before_each() -> void:
	t = KickTuning.new()


# --- pure model ---------------------------------------------------------------------------

func test_solver_lands_where_asked() -> void:
	var p0 := Vector3(0, t.contact_height, 0)
	for d in [12.0, 30.0, 55.0]:
		var sp := KickModel.solve_speed(p0, Vector2.RIGHT, t.long_angle, d, DAMP, G, R)
		var f := KickModel.simulate(p0, KickModel.launch(Vector2.RIGHT, t.long_angle, sp), DAMP, G, R)
		check(absf(f.landing.x - d) < 0.3, "long kick asked %.0f m lands at %.1f" % [d, f.landing.x])


func test_charge_sets_distance_and_skill_sets_range() -> void:
	check(is_equal_approx(KickModel.distance_for(KickModel.Type.LONG, 0.0, 0.9, t), t.long_min), "no charge = minimum")
	var weak := KickModel.distance_for(KickModel.Type.LONG, 1.0, 0.3, t)
	var great := KickModel.distance_for(KickModel.Type.LONG, 1.0, 0.95, t)
	check(great > weak + 12.0, "a great kicker kicks much further (%.0f vs %.0f m)" % [great, weak])
	check_between(great, 55.0, 65.0, "a great kicker's full long kick")
	var c := KickModel.charge_for(KickModel.Type.HIGH, 25.0, 0.7, t)
	check(absf(KickModel.distance_for(KickModel.Type.HIGH, c, 0.7, t) - 25.0) < 0.01, "charge_for inverts distance_for")


func test_high_kick_goes_higher_than_long() -> void:
	var p0 := Vector3(0, t.contact_height, 0)
	var sl := KickModel.solve_speed(p0, Vector2.RIGHT, t.long_angle, 30.0, DAMP, G, R)
	var sh := KickModel.solve_speed(p0, Vector2.RIGHT, t.high_angle, 30.0, DAMP, G, R)
	var long := KickModel.simulate(p0, KickModel.launch(Vector2.RIGHT, t.long_angle, sl), DAMP, G, R)
	var high := KickModel.simulate(p0, KickModel.launch(Vector2.RIGHT, t.high_angle, sh), DAMP, G, R)
	check(high.apex > long.apex * 1.8, "same distance, the high kick goes much higher (%.1f vs %.1f m)" % [high.apex, long.apex])
	check(high.flight_time > long.flight_time + 1.0, "and hangs longer for the chase (%.1f vs %.1f s)" % [high.flight_time, long.flight_time])
	check(high.has_catch and absf(high.catch_point.x - high.landing.x) < 2.0, "the catch point is just short of the landing")


func test_drop_sweet_spot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var dist := 25.0
	var p0 := Vector3(50.0 - dist, t.drop_contact_height, 0)
	var need := KickModel.drop_needed_speed(p0, Vector2.RIGHT, 50.0, DAMP, G, R, t)
	var res := {}
	for e in [-0.3, 0.0, 0.3]:
		var good := 0
		for i in 100:
			var sy := KickModel.drop_strike(t.drop_sweet + e, 0.8, dist, need, rng, t)
			var h := KickModel.height_at_plane(p0, KickModel.launch(Vector2.RIGHT.rotated(deg_to_rad(sy.y)), t.drop_angle, sy.x), DAMP, G, R, 50.0)
			if KickModel.drop_good(h.x, h.y):
				good += 1
		res[e] = good
	check(res[0.0] >= 95, "released in the sweet spot: over (%d/100)" % res[0.0])
	check(res[-0.3] <= 5, "too little: doesn't make it (%d/100)" % res[-0.3])
	check(res[0.3] <= 5, "too much: flies wide (%d/100)" % res[0.3])
	check(KickModel.drop_window(0.9, 25.0, t) > KickModel.drop_window(0.3, 25.0, t), "better kickers have a wider sweet spot")
	check(KickModel.drop_window(0.8, 40.0, t) < KickModel.drop_window(0.8, 20.0, t), "and it narrows further out")


func test_drop_range_depends_on_the_kicker() -> void:
	var p0 := Vector3(50.0 - 40.0, t.drop_contact_height, 0)
	var need := KickModel.drop_needed_speed(p0, Vector2.RIGHT, 50.0, DAMP, G, R, t)
	var rng := RandomNumberGenerator.new()
	var weak := KickModel.drop_strike(t.drop_sweet, 0.3, 40.0, need, rng, t)
	var great := KickModel.drop_strike(t.drop_sweet, 0.95, 40.0, need, rng, t)
	check(weak.x < need, "40 m is out of a weak kicker's range")
	check(great.x >= need - 0.01, "but in a great kicker's")


func test_kick_catch_chance() -> void:
	var clean := KickModel.catch_chance(0.85, 0.0, false, t)
	var contested := KickModel.catch_chance(0.85, 0.0, true, t)
	var running := KickModel.catch_chance(0.85, 7.0, false, t)
	check_between(clean, 0.9, 0.99, "a good fullback under a high ball, alone")
	check(contested < clean - 0.2, "a chaser in his face makes it a contest (%.2f)" % contested)
	check(running < clean, "taking it on the run is harder")


func test_aim_and_touch_aim() -> void:
	var a := KickModel.clamp_aim(Vector2(-1, 0.1), Vector2.RIGHT, t)
	check(rad_to_deg(absf(Vector2.RIGHT.angle_to(a))) <= t.aim_max_deg + 0.1, "can't kick backwards")
	var pos := Vector2(-40, 10)
	var dir := KickModel.touch_aim(pos, Vector2.RIGHT, 45.0, 4.0)
	var land := pos + dir * 45.0
	check(land.y > FieldDimensions.HALF_WIDTH, "touch aim lands beyond the touchline (%.1f)" % land.y)
	check(land.x > pos.x + 25.0, "and gains ground (%.1f m)" % (land.x - pos.x))


# --- in game -------------------------------------------------------------------------------

var scene: Node3D


func after_each() -> void:
	if scene:
		scene.queue_free()
		scene = null
	for a in ["kick_long", "kick_high", "kick_low", "kick_drop", "skill_mod"]:
		Input.action_release(a)


func _make_scene(autoplay: bool = false) -> void:
	scene = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	scene.autoplay = autoplay
	tree.root.add_child(scene)
	await tree.physics_frame


func _p(team: Team, n: int) -> RugbyPlayer:
	for p in team.players:
		if p.profile.number == n:
			return p
	return null


func _stick(dir: Vector2) -> void:
	var it := SupportRunner.Intent.new()
	it.dir = dir
	it.mag = 1.0 if dir != Vector2.ZERO else 0.0
	scene.human.scripted = it


## Our 10 with the ball at (x, 0); opponents far away.
func _kicker_setup(x: float = -10.0) -> RugbyPlayer:
	await _make_scene()
	scene.tackles.set_physics_process(false)
	for p in scene.opp.players:
		p.reset_to(Vector3(45, 0, p.global_position.z), Vector2.LEFT)
	var k := _p(scene.team, 10)
	k.reset_to(Vector3(x, 0, 0))
	scene.ball.attach(k)
	_stick(Vector2.ZERO)
	await tree.physics_frame
	return k


func test_hold_x_charges_and_release_kicks_long() -> void:
	var k := await _kicker_setup()
	check(scene.team_control.controlled == k, "the 10 is ours")
	Input.action_press("kick_long")
	await tree.physics_frame
	await tree.physics_frame
	check(scene.kicks.charging and scene.kicks.charge_type == KickModel.Type.LONG, "✕ starts charging a long kick")
	var d0: float = scene.kicks.preview()[1]
	for i in 36:
		await tree.physics_frame
	var d1: float = scene.kicks.preview()[1]
	check(d1 > d0 + 8.0, "the arrow grows while held (%.0f -> %.0f m)" % [d0, d1])
	check(scene.ball.carrier == k, "no kick until release")
	Input.action_release("kick_long")
	await tree.physics_frame
	await tree.physics_frame
	check(scene.ball.carrier == null and scene.kicks.in_flight, "release kicks")
	check(scene.team_control.phase == TeamControl.Phase.KICK, "phase is KICK while it's in the air")
	check(scene.kicks.landing.x > k.global_position.x + 20.0, "a long kick lands well upfield (%.1f)" % scene.kicks.landing.x)
	await tree.physics_frame
	check(scene.ball.carrier != k, "the kicker doesn't catch his own kick off the boot")


func test_fend_is_lt_plus_x_not_a_kick() -> void:
	var k := await _kicker_setup()
	Input.action_press("skill_mod")
	await tree.physics_frame
	Input.action_press("kick_long")
	await tree.physics_frame
	await tree.physics_frame
	check(not scene.kicks.charging, "LT + ✕ doesn't kick")
	check(k.fend_timer > 0.0, "it fends")


func test_stick_aims_the_kick() -> void:
	var k := await _kicker_setup()
	_stick(Vector2(1, 1).normalized())
	Input.action_press("kick_high")
	for i in 20:
		await tree.physics_frame
	check(scene.kicks.charge_type == KickModel.Type.HIGH, "□ is the high kick")
	check(scene.kicks.aim.y > 0.5, "aimed with the stick (%s)" % str(scene.kicks.aim))
	Input.action_release("kick_high")
	await tree.physics_frame
	check(scene.kicks.landing.y > k.global_position.z + 3.0, "the kick goes where it was aimed")


func test_grubber_runs_along_the_ground() -> void:
	var k := await _kicker_setup()
	for p in scene.team.players:
		if p != k:
			p.reset_to(Vector3(-40, 0, p.global_position.z))
	scene.kicks.kick(k, KickModel.Type.LOW, Vector2.RIGHT, 0.8)
	var apex := 0.0
	for i in 150:
		await tree.physics_frame
		apex = maxf(apex, scene.ball.global_position.y)
	check(apex < 2.0, "a grubber stays low (apex %.1f m)" % apex)
	check(scene.ball.global_position.x > k.global_position.x + 6.0, "and travels (%.1f m)" % (scene.ball.global_position.x - k.global_position.x))


func test_drop_goal_sweet_spot_in_game() -> void:
	var k := await _kicker_setup(28.0)   # 22 m out, in front of the posts
	var res := [null]
	scene.kicks.drop_result.connect(func(_k, good: bool): res[0] = good)
	scene.kicks.kick(k, KickModel.Type.DROP, Vector2.RIGHT, scene.kicks.tuning.drop_sweet)
	for i in 240:
		await tree.physics_frame
		if res[0] != null:
			break
	check(res[0] == true, "a drop released in the sweet spot goes over (%s)" % str(res[0]))
	scene.reset_play()
	k.reset_to(Vector3(28.0, 0, 0))
	scene.ball.attach(k)
	await tree.physics_frame
	res[0] = null
	scene.kicks.kick(k, KickModel.Type.DROP, Vector2.RIGHT, 0.1)
	for i in 240:
		await tree.physics_frame
		if res[0] != null:
			break
	check(res[0] == false, "an under-charged drop misses")


func test_box_kick_at_the_base_of_a_ruck() -> void:
	await _make_scene()
	scene.tackles.set_physics_process(false)
	var r: RuckSystem = scene.rucks
	r.ai_enabled = false
	var att: Array[RugbyPlayer] = scene.team.players
	for i in att.size():
		att[i].reset_to(Vector3(-(3.0 + i * 1.5), 0, (i - 2.5) * 3.0), Vector2.RIGHT)
	for i in scene.opp.players.size():
		scene.opp.players[i].reset_to(Vector3(8.0 + i * 1.6, 0, (i - 2.5) * 2.5), Vector2.LEFT)
	scene.ball.spawn_loose(Vector3(0.0, 0.11, 0.0), Vector3.ZERO)
	_stick(Vector2.ZERO)
	await tree.physics_frame
	r.form_at(Vector2.ZERO, scene.team)
	for i in 480:
		await tree.physics_frame
		if not r.is_active():
			break
	var nine := _p(scene.team, 9)
	check(scene.ball.carrier == nine, "the 9 has it at the base")
	check(scene.kicks.low_or_box(nine) == KickModel.Type.BOX, "△ there is a box kick")
	Input.action_press("kick_low")
	await tree.physics_frame
	await tree.physics_frame
	check(scene.kicks.charging and scene.kicks.charge_type == KickModel.Type.BOX, "charging a box kick")
	Input.action_release("kick_low")
	await tree.physics_frame
	check(scene.kicks.in_flight and scene.kicks.kick_type == KickModel.Type.BOX, "box kick in the air")
	# Away from the ruck it's a grubber again.
	nine.reset_to(Vector3(-20, 0, 0))
	scene.ball.attach(nine)
	check(scene.kicks.low_or_box(nine) == KickModel.Type.LOW, "away from the ruck △ is a grubber")


func test_receiving_team_fields_a_high_kick() -> void:
	await _make_scene(true)
	scene.tackles.set_physics_process(false)
	scene.rucks.set_physics_process(false)
	var k := _p(scene.team, 10)
	for p in scene.team.players:
		p.reset_to(Vector3(-20 if p != k else -10, 0, p.global_position.z))
	for p in scene.opp.players:
		p.reset_to(Vector3(30, 0, p.global_position.z * 0.5), Vector2.LEFT)
	scene.ball.attach(k)
	await tree.physics_frame
	scene.kicks.kick(k, KickModel.Type.HIGH, Vector2.RIGHT, 0.6)
	var target: Vector2 = scene.kicks.catch_point
	var caught := [null]
	scene.kicks.kick_caught.connect(func(c, _own): caught[0] = c)
	for i in 300:
		await tree.physics_frame
		if caught[0] != null or not scene.kicks.in_flight:
			break
	check(caught[0] != null and caught[0].team == scene.opp, "the receiving team catches it (%s, target %s)" % [caught[0].name if caught[0] else "nobody", str(target)])
	check(scene.possession.last_gain == &"kick_catch", "gained from a kick")


func test_ai_clears_from_its_own_22_under_pressure() -> void:
	await _make_scene(true)
	scene.tackles.set_physics_process(false)
	scene.rucks.set_physics_process(false)
	var k := _p(scene.team, 10)
	k.reset_to(Vector3(-42, 0, -6))
	for p in scene.team.players:
		if p != k:
			p.reset_to(Vector3(-46, 0, p.global_position.z))
	for i in scene.opp.players.size():
		scene.opp.players[i].reset_to(Vector3(-36, 0, -6.0 + (i - 2.5) * 3.0), Vector2.LEFT)
	scene.team_control.attack_ai.kicks.tuning.ai_clear_p = 1.0
	scene.team_control.style.kicking = 100.0
	scene.ball.attach(k)
	var got := [null]
	scene.kicks.kicked.connect(func(_k, type, landing): got[0] = [type, landing])
	for i in 120:
		await tree.physics_frame
		if got[0] != null:
			break
	check(got[0] != null and got[0][0] == KickModel.Type.LONG, "the AI clears with a long kick (%s; %s)" % [str(got[0]), scene.team_control.attack_ai.last_decision])
	if got[0] != null:
		var land: Vector2 = got[0][1]
		check(land.x > -20.0, "a long way upfield (lands at x %.1f)" % land.x)
		check(absf(land.y) > FieldDimensions.HALF_WIDTH - 2.0, "toward touch (z %.1f)" % land.y)
