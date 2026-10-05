extends TestSuite
## Integration: full team mode — passes through real Jolt ball physics,
## receiver dummies running their lines, catches and control switching.

var scene: Node3D
var team: Team
var ball: RugbyBall
var passing: PassingSystem
var control: TeamControl
var possession: PossessionController


func before_each() -> void:
	scene = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	scene.with_opponents = false   # M04 passing behaviour, no defenders
	tree.root.add_child(scene)
	team = scene.team
	ball = scene.ball
	passing = scene.passing
	control = scene.team_control
	possession = scene.possession


func after_each() -> void:
	scene.queue_free()


func _ticks(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Scripted "stick" for whoever the human controls (devices aren't read in tests).
func _stick(dir: Vector2, sprint := false) -> void:
	var it := SupportRunner.Intent.new()
	it.dir = dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO
	it.mag = 1.0 if dir != Vector2.ZERO else 0.0
	it.sprint = sprint
	scene.human.scripted = it


func _p(number: int) -> RugbyPlayer:
	for p in team.players:
		if p.profile.number == number:
			return p
	return null


## Throws to `side` and waits until the ball is held again (or timeout).
func _pass_and_wait(side: int, long := false) -> RugbyPlayer:
	var passer := ball.carrier
	passing.throw(passer, side, long)
	for i in 150:
		await tree.physics_frame
		if ball.state == RugbyBall.State.HELD:
			return ball.carrier
	return null


func test_team_spawns_with_ball_in_scrum_half_hands() -> void:
	await _ticks(2)
	check(team.players.size() == 6, "six players in the dev lineup (%d)" % team.players.size())
	check(ball.carrier == _p(9), "the 9 starts with the ball")
	check(control.controlled == _p(9), "the human controls the 9")
	check(_p(9).is_controlled and not _p(10).is_controlled, "exactly one controlled player")


func test_quick_pass_left_reaches_ten() -> void:
	await _ticks(30)
	var got := await _pass_and_wait(PassTargeting.LEFT)
	check(got == _p(10), "tap-left from the 9 should find the 10 (got %s)" % (got.profile.short_label() if got else "nobody"))


func test_control_switches_on_release() -> void:
	await _ticks(10)
	passing.throw(_p(9), PassTargeting.LEFT, false)
	check(control.controlled == _p(10), "control moves to the receiver as the ball leaves the hands")
	check(passing.in_flight, "pass is in flight")


func test_skip_pass_goes_to_twelve() -> void:
	await _ticks(30)
	var got := await _pass_and_wait(PassTargeting.LEFT, true)
	check(got == _p(12), "hold-left from the 9 should skip the 10 to the 12 (got %s)" % (got.profile.short_label() if got else "nobody"))


func test_chain_a_b_c_d_while_running() -> void:
	# The headline M04 goal: 9 -> 10 -> 12 -> 13, everyone running forward.
	_stick(Vector2.RIGHT)
	await _ticks(50)
	var chain: Array[RugbyPlayer] = [_p(9)]
	for n in 3:
		# Carrier keeps running while the line runs with them.
		await _ticks(25)
		var got := await _pass_and_wait(PassTargeting.LEFT)
		if got == null:
			break
		chain.append(got)
	var names := []
	for c in chain:
		names.append(c.profile.number)
	check(chain.size() == 4, "chain should complete 4 players (%s)" % str(names))
	if chain.size() == 4:
		check(chain[1] == _p(10) and chain[2] == _p(12) and chain[3] == _p(13), "order 9-10-12-13 (%s)" % str(names))
	check(not passing.flight_forward, "no forward passes in a normal backline move")


func test_support_line_stays_behind_running_carrier() -> void:
	await _ticks(5)
	var carrier := _p(9)
	_stick(Vector2.RIGHT, true)
	await _ticks(180)
	for p in team.players:
		if p == carrier:
			continue
		var ahead := p.global_position.x - carrier.global_position.x
		check(ahead < 0.5, "#%d must stay behind the ball (%.1f m ahead)" % [p.profile.number, ahead])
	# And they kept up: nobody left more than ~12 m behind their slot depth.
	for p in team.players:
		check(carrier.global_position.x - p.global_position.x < 14.0, "#%d keeps up with the carrier" % p.profile.number)


func test_pass_to_player_ahead_is_flagged_forward() -> void:
	await _ticks(5)
	control.active = false
	var r := _p(10)
	r.reset_to(_p(9).global_position + Vector3(3.5, 0, -6))
	var forward := [false]
	passing.pass_thrown.connect(func(_a, _b, f): forward[0] = f)
	passing.throw_to(_p(9), r, PassTargeting.LEFT, false)
	check(forward[0], "a pass to a receiver 3.5 m ahead is forward")


func test_no_receiver_passes_into_space() -> void:
	await _ticks(5)
	control.active = false
	# Move everyone far away on the right; pass left.
	for p in team.players:
		if p != _p(9):
			p.reset_to(_p(9).global_position + Vector3(-2, 0, 25))
	var start := _p(9).planar_position()
	passing.throw(_p(9), PassTargeting.LEFT, false)
	check(ball.is_loose(), "ball released into space")
	check(passing.flight_receiver == null, "no receiver")
	check(not passing.flight_forward, "a pass into space is not forward")
	check(control.controlled == _p(9), "control stays with the passer")
	await _ticks(40)
	var moved := ball.global_position
	check(moved.z < start.y - 3.0, "ball went to the attacker's left (-Z) (z %.1f)" % moved.z)


func test_dropped_pass_becomes_loose_ball() -> void:
	await _ticks(5)
	control.active = false
	var r := _p(10)
	r.set_profile(PlayerProfile.from_dict({"attributes": {"handling": 1}}))
	var counts := [0, 0]   # drops, knock-ons (arrays: lambdas capture by value)
	possession.catch_failed.connect(func(_p2, _c, k): counts[0] += 1; counts[1] += int(k))
	for i in 30:
		ball.spawn_loose(r.global_position + Vector3(0.4, 1.2, -0.3), Vector3(0, 0, 14))
		possession.clear_cooldowns()
		possession.attempt_catch(r)
	check(counts[0] > 3, "bad hands + rocket passes should drop some (%d/30)" % counts[0])
	check(counts[1] > 0, "and some drops are knock-ons")


func test_catch_by_receiver_sets_carrier_role() -> void:
	await _ticks(30)
	var got := await _pass_and_wait(PassTargeting.RIGHT)
	check(got == _p(11), "right pass from the 9 finds the 11")
	if got:
		check(got.role == RugbyPlayer.Role.BALL_CARRIER, "receiver becomes the carrier")
		check(_p(9).role == RugbyPlayer.Role.NEUTRAL, "passer is no longer the carrier")


func test_charge_and_release_api() -> void:
	await _ticks(30)
	passing.begin(_p(9), PassTargeting.LEFT)
	check(passing.charging, "charging after begin")
	await _ticks(3)
	passing.release()
	check(not passing.charging and passing.in_flight, "released quickly -> quick pass in flight")
	check(passing.flight_receiver == _p(10), "quick pass target is the 10")


func test_max_hold_auto_releases_long() -> void:
	await _ticks(30)
	passing.begin(_p(9), PassTargeting.LEFT)
	await _ticks(int(passing.tuning.max_hold_time * 60.0) + 3)
	check(passing.in_flight, "pass auto-releases at max hold")
	check(passing.flight_receiver == _p(12), "held -> skip pass to the 12")


func test_button_tap_and_hold_through_input_map() -> void:
	# Drive the real input path: InputMap action press/release.
	await _ticks(30)
	Input.action_press("pass_left")
	await _ticks(3)
	Input.action_release("pass_left")
	await _ticks(2)
	check(passing.in_flight and passing.flight_receiver == _p(10), "tapping LB passes to the 10")
	for i in 120:
		await tree.physics_frame
		if ball.state == RugbyBall.State.HELD:
			break
	check(ball.carrier == _p(10), "the 10 caught it")
	await _ticks(20)
	# From the 10, hold RB: the 9 is now inside on the right; skip goes beyond him.
	var right_quick := passing.preview(_p(10), PassTargeting.RIGHT, false)
	var right_long := passing.preview(_p(10), PassTargeting.RIGHT, true)
	Input.action_press("pass_right")
	await _ticks(int(passing.tuning.skip_hold_time * 60.0) + 4)
	Input.action_release("pass_right")
	await _ticks(2)
	check(passing.in_flight, "holding RB then releasing throws")
	check(passing.flight_receiver == right_long, "held -> long target (%s)" % (passing.flight_receiver.profile.short_label() if passing.flight_receiver else "space"))
	check(right_long != right_quick, "long and quick targets differ when two receivers exist")


func test_long_pass_caught_when_human_jogs_after_switch() -> void:
	# Regression: receiver sprinting to his slot at release, human then holds
	# "jog forward". The pace assist must keep him on the ball's line.
	_stick(Vector2.RIGHT)
	await _ticks(60)
	await _pass_and_wait(PassTargeting.LEFT)
	await _ticks(20)
	var r := passing.preview(ball.carrier, PassTargeting.LEFT, true)
	var got := await _pass_and_wait(PassTargeting.LEFT, true)
	check(got == r, "skip pass to the runner should be caught (got %s, wanted %s)" % [got.profile.short_label() if got else "nobody", r.profile.short_label() if r else "?"])


func test_hard_turn_away_is_respected() -> void:
	var st := SupportTuning.new()
	var stick := SupportRunner.Intent.new()
	stick.dir = Vector2(-1, 0)
	stick.mag = 1.0
	var out := SupportRunner.receiver_assist(stick, Vector2(8, 0), 6.0, st)
	check(out.dir == Vector2(-1, 0), "turning back on purpose is not overridden")
	stick.dir = Vector2(1, 0.3).normalized()
	out = SupportRunner.receiver_assist(stick, Vector2(8, 0), 6.0, st)
	check(out.sprint and out.mag == 1.0, "small steer keeps sprint pace")
	check(out.dir.is_equal_approx(Vector2(1, 0)), "and the run the pass was aimed at")
