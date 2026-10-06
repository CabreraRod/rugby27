extends TestSuite
## M06 tackling: pure model calibration + in-game tackle flow.

var t: TackleTuning
var rng: RandomNumberGenerator


func before_each() -> void:
	t = TackleTuning.new()
	rng = RandomNumberGenerator.new()
	rng.seed = hash("tackle-tests")


func _contact(t_mass: float, t_vel: Vector2, tackling: float, c_mass: float, c_vel: Vector2, strength: float) -> TackleModel.Contact:
	var c := TackleModel.Contact.new()
	c.tackler_mass = t_mass
	c.tackler_vel = t_vel
	c.tackler_pos = Vector2(1.0, 0.0)
	c.tackling = tackling
	c.carrier_mass = c_mass
	c.carrier_vel = c_vel
	c.carrier_pos = Vector2.ZERO
	c.strength = strength
	return c


# Carrier runs +X into a tackler standing 1 m ahead and closing at -X.
func _typical() -> TackleModel.Contact:
	return _contact(95, Vector2(-3, 0), 0.84, 88, Vector2(6, 0), 0.71)


func test_typical_tackle_holds_most_of_the_time() -> void:
	var r := TackleModel.evaluate(_typical(), t)
	check_between(r.p_break, 0.05, 0.15, "typical back-on-back break chance")


func test_speed_helps_the_carrier() -> void:
	var slow := TackleModel.evaluate(_typical(), t)
	var c := _typical()
	c.carrier_vel = Vector2(9, 0)
	var fast := TackleModel.evaluate(c, t)
	check(fast.p_break > slow.p_break + 0.05, "a sprinting carrier breaks more (%.2f vs %.2f)" % [fast.p_break, slow.p_break])


func test_forwards_matter() -> void:
	var prop_carrying := TackleModel.evaluate(_contact(90, Vector2(-2, 0), 0.64, 120, Vector2(5, 0), 0.95), t)
	var back_carrying := TackleModel.evaluate(_contact(90, Vector2(-2, 0), 0.64, 86, Vector2(5, 0), 0.71), t)
	check(prop_carrying.p_break > back_carrying.p_break + 0.1, "a prop is much harder to bring down (%.2f vs %.2f)" % [prop_carrying.p_break, back_carrying.p_break])
	var prop_tackling := TackleModel.evaluate(_contact(120, Vector2(-3, 0), 0.82, 86, Vector2(5, 0), 0.71), t)
	check(prop_tackling.p_dominant > back_carrying.p_dominant, "big men make more dominant tackles")


func test_hit_with_momentum_is_dominant() -> void:
	var r := TackleModel.evaluate(_contact(100, Vector2(-5, 0), 0.88, 86, Vector2(4, 0), 0.71), t)
	check(r.p_break < 0.06, "a committed hit rarely gets broken (%.2f)" % r.p_break)
	check(r.p_dominant > 0.25, "and is often dominant (%.2f)" % r.p_dominant)


func test_fend_helps_only_from_front_or_side() -> void:
	var base := TackleModel.evaluate(_typical(), t)
	var c := _typical()
	c.fend = true
	var fend := TackleModel.evaluate(c, t)
	check(fend.p_break > base.p_break * 1.8, "fend makes a front tackle much easier to break (%.2f vs %.2f)" % [fend.p_break, base.p_break])
	var behind := _typical()
	behind.tackler_pos = Vector2(-1, 0)   # chasing from behind
	behind.tackler_vel = Vector2(8, 0)
	var b0 := TackleModel.evaluate(behind, t)
	behind.fend = true
	var b1 := TackleModel.evaluate(behind, t)
	check(is_equal_approx(b0.p_break, b1.p_break), "a fend does nothing against a tackle from behind")


func test_sidestep_and_dive() -> void:
	var base := TackleModel.evaluate(_typical(), t)
	var side := _typical()
	side.sidestep = true
	check(TackleModel.evaluate(side, t).p_break > base.p_break * 1.8, "a sidestep wrong-foots the tackler")
	var dive := _typical()
	dive.dive = true
	check(TackleModel.evaluate(dive, t).p_break < base.p_break, "a dive tackle is stronger once it connects")


func test_approach_classification() -> void:
	var head := _typical()
	check(TackleModel.approach(head) < -0.9, "carrier running into the tackler = head-on")
	var side := _typical()
	side.tackler_pos = Vector2(0, 1)
	check(absf(TackleModel.approach(side)) < 0.1, "tackler to the side = side-on")


func test_resolve_distribution_matches_probability() -> void:
	var broken := 0
	for i in 2000:
		if TackleModel.resolve(_typical(), rng, t).outcome == TackleModel.Outcome.BROKEN:
			broken += 1
	var p := TackleModel.evaluate(_typical(), t).p_break
	check(absf(broken / 2000.0 - p) < 0.025, "sampled break rate %.3f ≈ model %.3f" % [broken / 2000.0, p])


func test_carrier_falls_forward_or_is_driven_back() -> void:
	var held := TackleModel.carrier_velocity_after(TackleModel.Outcome.HELD, Vector2(6, 0), Vector2(-3, 0), t)
	check(held.x > 0.0, "a normal tackle: the carrier falls forward over the gain line")
	var dom := TackleModel.carrier_velocity_after(TackleModel.Outcome.DOMINANT, Vector2(6, 0), Vector2(-3, 0), t)
	check(dom.x < 0.0, "a dominant tackle drives the carrier back")


# --- in game -----------------------------------------------------------------------

var scene: Node3D


func _make_scene() -> void:
	scene = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	tree.root.add_child(scene)
	await tree.physics_frame


func after_each() -> void:
	if scene:
		scene.queue_free()
		scene = null


func _stick(dir: Vector2) -> void:
	var it := SupportRunner.Intent.new()
	it.dir = dir
	it.mag = 1.0 if dir != Vector2.ZERO else 0.0
	scene.human.scripted = it


func _p(team: Team, n: int) -> RugbyPlayer:
	for p in team.players:
		if p.profile.number == n:
			return p
	return null


## Our 9 carries straight at their 9; everyone else switched off.
func _head_on_setup() -> Array:
	await _make_scene()
	scene.team_control.active = false
	scene.opp_control.active = false
	var c := _p(scene.team, 9)
	var d := _p(scene.opp, 9)
	c.reset_to(Vector3(0, 0, 0))
	d.reset_to(Vector3(6, 0, 0), Vector2(-1, 0))
	for p in scene.team.players + scene.opp.players:
		if p != c and p != d:
			p.reset_to(Vector3(-30, 0, p.global_position.z))
	scene.ball.attach(c)
	await tree.physics_frame
	return [c, d]


func test_running_into_a_defender_tackles() -> void:
	var cd := await _head_on_setup()
	var c: RugbyPlayer = cd[0]
	var d: RugbyPlayer = cd[1]
	var got := [null]
	scene.tackles.tackle_made.connect(func(_a, _b, r): if got[0] == null: got[0] = r)
	for i in 90:
		c.set_intent(Vector2.RIGHT, 1.0, true)
		d.set_intent(Vector2.LEFT, 1.0, false)
		await tree.physics_frame
		if got[0] != null:
			break
	check(got[0] != null, "contact produced a tackle")
	if got[0] != null and got[0].outcome != TackleModel.Outcome.BROKEN:
		check(c.state == RugbyPlayer.State.GROUNDED, "tackled carrier goes to ground")
		check(scene.ball.is_loose() or scene.ball.carrier != c, "the carrier no longer holds the ball")
		check(scene.possession.protected_team == scene.team or got[0].spill, "tackled team gets the placement window")


func test_tackled_ball_protected_then_open() -> void:
	var cd := await _head_on_setup()
	var c: RugbyPlayer = cd[0]
	var d: RugbyPlayer = cd[1]
	scene.tackles.rng.seed = 1   # any seed; force a held tackle below
	scene.tackles.tuning.break_max = 0.0
	scene.tackles.tuning.break_min = 0.0
	scene.tackles.tuning.spill_normal = 0.0
	scene.tackles.tuning.spill_dominant = 0.0
	for i in 90:
		c.set_intent(Vector2.RIGHT, 1.0, true)
		d.set_intent(Vector2.LEFT, 1.0, false)
		await tree.physics_frame
		if c.state == RugbyPlayer.State.GROUNDED:
			break
	check(scene.ball.is_loose(), "ball placed")
	# An opponent standing on the ball can't take it during the window.
	var thief := _p(scene.opp, 10)
	thief.reset_to(scene.ball.global_position + Vector3(0.2, 0, 0.2))
	await tree.physics_frame
	await tree.physics_frame
	check(scene.ball.carrier != thief, "opponent can't pick up inside the protection window")


func test_dive_reaches_further_but_miss_costs() -> void:
	await _make_scene()
	scene.team_control.active = false
	scene.opp_control.active = false
	var diver := _p(scene.team, 10)
	diver.reset_to(Vector3(0, 0, 10))
	await tree.physics_frame
	check(diver.try_dive(), "can dive when not carrying")
	var t0 := 0
	while diver.state != RugbyPlayer.State.GETTING_UP and t0 < 200:
		await tree.physics_frame
		t0 += 1
	var down := t0 / 60.0
	check(down > scene.tackle_tuning.dive_window + scene.tackle_tuning.dive_miss_ground - 0.1, "a missed dive leaves you on the floor (%.2f s)" % down)


func test_carrier_moves_have_cooldowns() -> void:
	var cd := await _head_on_setup()
	var c: RugbyPlayer = cd[0]
	check(c.try_fend(), "carrier can fend")
	check(not c.try_fend(), "fend has a cooldown")
	var v0 := c.planar_velocity
	check(c.try_sidestep(1.0), "carrier can sidestep")
	check((c.planar_velocity - v0).length() > 3.0, "sidestep is a real lateral burst")
	check(not c.try_sidestep(-1.0), "sidestep has a cooldown")
	var non_carrier := _p(scene.team, 10)
	check(not non_carrier.try_fend(), "only the carrier can fend")


func test_human_dive_button_on_defence() -> void:
	await _make_scene()
	scene.ball.attach(_p(scene.opp, 9))
	_stick(Vector2.ZERO)
	await tree.physics_frame
	await tree.physics_frame
	var me: RugbyPlayer = scene.team_control.controlled
	Input.action_press("dive_tackle")
	await tree.physics_frame
	Input.action_release("dive_tackle")
	await tree.physics_frame
	check(me.is_diving() or me.state == RugbyPlayer.State.GROUNDED, "A / Space dives on defence")
