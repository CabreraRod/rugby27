extends TestSuite
## M08 rucks: pure contest / hold / AI maths + the in-game ruck flow.

var t: RuckTuning


func before_each() -> void:
	t = RuckTuning.new()


func _bodies(n: int, bound_at: float = 0.5, units: float = 1.0) -> Array[RuckModel.Body]:
	var out: Array[RuckModel.Body] = []
	for i in n:
		out.append(RuckModel.Body.make(units, bound_at + i * 0.1))
	return out


# --- pure model ------------------------------------------------------------------------

func test_nobody_contests_the_attack_keeps_it() -> void:
	var r := RuckModel.evaluate(_bodies(1), _bodies(0), t.contest_time, t)
	check(r.p_turnover == 0.0, "no defender in the ruck = no turnover")


func test_equal_numbers_favour_the_attack() -> void:
	var r := RuckModel.evaluate(_bodies(2, 0.3), _bodies(2, 0.6), t.contest_time, t)
	check_between(r.p_turnover, 0.05, 0.12, "2 v 2, attack first")


func test_heavy_bid_against_no_commit_is_likely_to_win() -> void:
	var r := RuckModel.evaluate(_bodies(1, 0.4), _bodies(4, 0.5), t.contest_time, t)
	check(r.p_turnover > 0.6, "4 defenders v 1 attacker usually wins it (%.2f)" % r.p_turnover)
	var secured := RuckModel.evaluate(_bodies(3, 0.4), _bodies(4, 0.5), t.contest_time, t)
	check(secured.p_turnover < 0.3, "two extra taps mostly secure it (%.2f)" % secured.p_turnover)
	var matched := RuckModel.evaluate(_bodies(4, 0.4), _bodies(4, 0.5), t.contest_time, t)
	check(matched.p_turnover < secured.p_turnover, "matching the bid is safer still")


func test_isolated_carrier_vs_a_jackal_is_a_real_contest() -> void:
	var r := RuckModel.evaluate(_bodies(0), _bodies(1, 0.3), t.contest_time, t)
	check(r.jackal, "a defender over the ball first is a jackal")
	check_between(r.p_turnover, 0.35, 0.7, "isolated carrier v one jackal")


func test_only_bodies_bound_in_time_count() -> void:
	var late := RuckModel.evaluate(_bodies(1, 0.3), _bodies(4, t.contest_time + 0.2), t.contest_time, t)
	check(late.def_bodies == 0 and late.p_turnover == 0.0, "defenders arriving after the contest don't count")
	var first := RuckModel.evaluate(_bodies(1, 0.8), _bodies(1, 0.3), t.contest_time, t)
	var second := RuckModel.evaluate(_bodies(1, 0.3), _bodies(1, 0.8), t.contest_time, t)
	check(first.p_turnover > second.p_turnover, "arriving first matters (%.2f vs %.2f)" % [first.p_turnover, second.p_turnover])


func test_weight_and_strength_count() -> void:
	var prop := RuckModel.body_units(120, 0.95, t)
	var nine := RuckModel.body_units(78, 0.6, t)
	check(prop > nine * 1.4, "a prop is worth much more than a scrum-half (%.2f vs %.2f)" % [prop, nine])
	check_between(RuckModel.body_units(90, 0.5, t), 0.99, 1.01, "a 90 kg average player is one unit")


func test_holding_risks_a_penalty_that_grows() -> void:
	var p05 := RuckModel.hold_penalty_cdf(0.5, t)
	var p1 := RuckModel.hold_penalty_cdf(1.0, t)
	var p2 := RuckModel.hold_penalty_cdf(2.0, t)
	check(p05 < p1 and p1 < p2, "longer holds are riskier")
	check_between(p1, 0.15, 0.35, "1 s held")
	check(p2 > 0.5, "2 s held is more likely penalised than not (%.2f)" % p2)
	check(RuckModel.hold_penalty_cdf(t.hold_max, t) == 1.0, "holding to the limit is always penalised")
	check(RuckModel.hold_hazard(2.0, t) > RuckModel.hold_hazard(0.5, t), "the hazard rises with time held")


func test_ai_bid_and_counter() -> void:
	var calm := RuckModel.bid_chance(0.2, false, false, t)
	var rush := RuckModel.bid_chance(0.9, false, false, t)
	var iso := RuckModel.bid_chance(0.5, true, false, t)
	check(rush > calm, "aggressive teams bid more")
	check(iso > 0.5, "an isolated carrier invites a bid (%.2f)" % iso)
	check(RuckModel.bid_chance(0.5, false, true, t) > RuckModel.bid_chance(0.5, false, false, t), "defending the own line raises the bid")
	check(RuckModel.attack_extra(1, 4, t) == 3, "the attack answers a bid up to the cap")
	check(RuckModel.attack_extra(1, 1, t) == 1, "and stays one ahead")
	check(RuckModel.attack_extra(2, 0, t) == 0, "no defenders, no extra commits")


# --- in game ------------------------------------------------------------------------------

var scene: Node3D


func after_each() -> void:
	if scene:
		scene.queue_free()
		scene = null
	for a in ["ruck_commit", "ruck_hold"]:
		Input.action_release(a)


func _make_scene(autoplay: bool = false) -> void:
	scene = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	scene.autoplay = autoplay
	tree.root.add_child(scene)
	await tree.physics_frame
	scene.tackles.set_physics_process(false)


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


## Attack (blue, +X) around a ruck at the origin: support 3-9 m behind,
## defence 4-12 m ahead. `jackal` puts a defender right over the ball.
func _stage(jackal: bool = false) -> void:
	var att: Array[RugbyPlayer] = scene.team.players
	for k in att.size():
		att[k].reset_to(Vector3(-(3.0 + k * 1.5), 0, (k - 2.5) * 3.0), Vector2.RIGHT)
	var def: Array[RugbyPlayer] = scene.opp.players
	for k in def.size():
		var pos := Vector3(4.0 + k * 1.6, 0, (k - 2.5) * 2.5)
		if jackal and k == 0:
			pos = Vector3(1.5, 0, 0.5)
		def[k].reset_to(pos, Vector2.LEFT)
	scene.ball.spawn_loose(Vector3(0.0, 0.11, 0.0), Vector3.ZERO)


func _wait_ruck_end(max_ticks: int = 480) -> void:
	for i in max_ticks:
		await tree.physics_frame
		if not scene.rucks.is_active():
			return


func test_held_tackle_forms_a_ruck_and_the_nine_gets_it() -> void:
	await _make_scene()
	scene.tackles.set_physics_process(true)
	scene.tackles.tuning.break_max = 0.0
	scene.tackles.tuning.break_min = 0.0
	scene.tackles.tuning.spill_normal = 0.0
	scene.tackles.tuning.spill_dominant = 0.0
	scene.rucks.ai_enabled = false
	var c := _p(scene.team, 12)
	var d := _p(scene.opp, 12)
	scene.ball.attach(c)
	await tree.physics_frame
	scene.team_control.active = false
	scene.opp_control.active = false
	c.reset_to(Vector3(0, 0, 0))
	d.reset_to(Vector3(6, 0, 0), Vector2(-1, 0))
	_p(scene.team, 9).reset_to(Vector3(-4, 0, 2))
	await tree.physics_frame
	for i in 90:
		c.set_intent(Vector2.RIGHT, 1.0, true)
		d.set_intent(Vector2.LEFT, 1.0, false)
		await tree.physics_frame
		if scene.rucks.is_active():
			break
	check(scene.rucks.is_active(), "a held tackle forms a ruck")
	check(scene.rucks.attack == scene.team, "the tackled team is the attack")
	check(scene.rucks.nine == _p(scene.team, 9), "the 9 is the man to take it out")
	# Nobody can just pick it up off the floor: an opponent standing on it.
	var thief := _p(scene.opp, 10)
	thief.reset_to(scene.ball.global_position + Vector3(0.2, 0, 0.2))
	scene.team_control.active = true
	scene.opp_control.active = true
	await tree.physics_frame
	await tree.physics_frame
	check(scene.ball.carrier != thief, "no pickups while the ruck is on")
	await _wait_ruck_end()
	check(not scene.rucks.is_active(), "the ruck ends")
	check(scene.ball.carrier == _p(scene.team, 9), "the ball comes out to the 9 (%s)" % (scene.ball.carrier.name if scene.ball.carrier else "nobody"))
	check(scene.team_control.controlled == _p(scene.team, 9), "and the human has the 9")


func test_commit_sends_the_nearest_free_player_who_binds() -> void:
	await _make_scene()
	scene.rucks.ai_enabled = false
	_stage()
	await tree.physics_frame
	check(scene.rucks.form_at(Vector2.ZERO, scene.team), "ruck forms")
	var auto: Array = scene.rucks.committed(scene.team).duplicate()
	check(auto.size() == 1, "the nearest support joins on his own (%d)" % auto.size())
	check(not auto.has(scene.rucks.nine), "but never the 9")
	check(scene.rucks.commit(scene.team), "X sends one more")
	var second: RugbyPlayer = scene.rucks.committed(scene.team)[1]
	for i in 120:
		await tree.physics_frame
		if second.is_rucking():
			break
	check(second.is_rucking(), "a committed player runs in and binds")
	check(second.collision_layer == 0, "bound players don't collide")
	for i in 10:
		scene.rucks.commit(scene.team)
	check(scene.rucks.count(scene.team) <= int(scene.rucks.tuning.max_commit), "commits are capped at %d" % int(scene.rucks.tuning.max_commit))
	await _wait_ruck_end()
	await tree.physics_frame
	check(not second.is_rucking(), "bound players leave when the ruck ends")


func test_human_commits_with_x_on_defence() -> void:
	await _make_scene()
	scene.rucks.ai_enabled = false
	_stage()
	scene.ball.attach(_p(scene.opp, 9))   # the human team defends
	await tree.physics_frame
	scene.ball.spawn_loose(Vector3(0.0, 0.11, 0.0), Vector3.ZERO)
	# The opposition attacks toward -X: put the ruck where they are (behind it).
	for k in scene.opp.players.size():
		scene.opp.players[k].reset_to(Vector3(3.0 + k * 1.5, 0, (k - 2.5) * 3.0), Vector2.LEFT)
	for k in scene.team.players.size():
		scene.team.players[k].reset_to(Vector3(-(4.0 + k * 1.6), 0, (k - 2.5) * 2.5), Vector2.RIGHT)
	_stick(Vector2.ZERO)
	await tree.physics_frame
	scene.rucks.form_at(Vector2.ZERO, scene.opp)
	var before: int = scene.rucks.count(scene.team)
	Input.action_press("ruck_commit")
	await tree.physics_frame
	Input.action_release("ruck_commit")
	await tree.physics_frame
	Input.action_press("ruck_commit")
	await tree.physics_frame
	Input.action_release("ruck_commit")
	await tree.physics_frame
	await tree.physics_frame   # the line is recomputed on the next tick
	check(scene.rucks.count(scene.team) == before + 2, "two taps of X = two more defenders (%d -> %d)" % [before, scene.rucks.count(scene.team)])
	check(not scene.rucks.is_committed(scene.team_control.controlled), "never the human's own player")
	check(scene.team_control.phase == TeamControl.Phase.RUCK, "phase is RUCK")
	# The rest of the defence stays onside.
	for a in scene.team_control.assignments:
		check((a.target - scene.rucks.pos).dot(scene.rucks.dir) >= scene.rucks.tuning.offside_gap - 0.01, "defender %s lines up onside" % a.defender.name)
		check(not scene.rucks.is_committed(a.defender), "committed defenders are out of the line (%s, phase %s, active %s)" % [a.defender.name, scene.team_control.phase, scene.rucks.is_active()])


func test_hold_stops_the_ball_and_risks_a_penalty() -> void:
	await _make_scene()
	var r: RuckSystem = scene.rucks
	r.ai_enabled = false
	_stage(true)   # a defender over the ball
	await tree.physics_frame
	r.tuning = RuckTuning.new()
	r.tuning.contest_bias = -50.0   # the attack always keeps it ...
	r.tuning.p_min = 0.0
	r.tuning.hold_rate = 0.0        # ... and holding is safe for this check
	r.tuning.hold_rate_slope = 0.0
	r.form_at(Vector2.ZERO, scene.team)
	check(r.count(scene.opp) == 1, "the jackal joins on his own")
	r.set_hold(scene.opp, true)
	check(not r.holding, "can't hold without a defender bound")
	for i in 120:
		await tree.physics_frame
		if r.bound_count(scene.opp) > 0:
			break
	r.set_hold(scene.opp, true)
	check(r.holding, "□ holds the ball in")
	for i in 240:
		await tree.physics_frame
		if r.phase == RuckSystem.Phase.AVAILABLE:
			break
	for i in 60:
		await tree.physics_frame
	check(r.is_active() and scene.ball.carrier == null, "the 9 can't take it while it's held (%.1f s)" % r.held_time)
	# Now the referee is strict: the next tick is a penalty.
	r.tuning.hold_rate = 1000.0
	var pens := [0]
	r.penalised.connect(func(_d, _h): pens[0] += 1)
	await tree.physics_frame
	await tree.physics_frame
	check(pens[0] == 1, "holding is penalised")
	check(not r.is_active() and r.last_outcome == &"penalty", "penalty ends the ruck")
	check(scene.ball.carrier == _p(scene.team, 9), "placeholder: the ball goes back to the attack's 9")


func test_turnover_gives_the_ball_to_a_defender() -> void:
	await _make_scene()
	var r: RuckSystem = scene.rucks
	r.ai_enabled = false
	_stage(true)
	await tree.physics_frame
	r.tuning = RuckTuning.new()
	r.tuning.contest_bias = 50.0
	r.tuning.p_max = 1.0
	r.form_at(Vector2.ZERO, scene.team)
	await _wait_ruck_end()
	check(r.last_outcome == &"turnover", "defence wins the ruck (%s)" % r.last_outcome)
	check(scene.ball.carrier != null and scene.ball.carrier.team == scene.opp, "a defender has the ball")
	check(scene.possession.last_gain == &"ruck", "gained at the ruck (not an interception)")


func test_ai_defence_bids_on_an_isolated_carrier() -> void:
	await _make_scene(true)
	var r: RuckSystem = scene.rucks
	_stage(true)
	# Isolate the carrier: the attack's support is far away.
	for k in scene.team.players.size():
		scene.team.players[k].reset_to(Vector3(-(16.0 + k * 2.0), 0, (k - 2.5) * 4.0), Vector2.RIGHT)
	await tree.physics_frame
	r.tuning = RuckTuning.new()
	r.tuning.bid_isolated = 1.0
	r.form_at(Vector2.ZERO, scene.team)
	check(r.isolated(), "nobody can get there in time")
	for i in 40:
		await tree.physics_frame
	check(r.ai_bid, "the AI defence bids")
	check(r.count(scene.opp) >= int(r.tuning.isolated_bid), "with at least %d players (%d)" % [int(r.tuning.isolated_bid), r.count(scene.opp)])


func test_ai_attack_answers_a_bid() -> void:
	await _make_scene(true)
	var r: RuckSystem = scene.rucks
	_stage()
	await tree.physics_frame
	r.tuning = RuckTuning.new()
	r.tuning.att_miss = 0.0
	r.tuning.bid_base = 0.0
	r.tuning.bid_aggression = 0.0
	r.form_at(Vector2.ZERO, scene.team)
	for i in 3:
		r.commit(scene.opp)
	for i in 30:
		await tree.physics_frame
	check(r.count(scene.team) >= r.count(scene.opp), "the AI attack commits to match the bid (%d v %d)" % [r.count(scene.team), r.count(scene.opp)])
