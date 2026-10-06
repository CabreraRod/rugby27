extends TestSuite
## M05: opponents, placeholder defence, turnovers and switching.

var scene: Node3D
var team: Team
var opp: Team
var ball: RugbyBall
var passing: PassingSystem
var control: TeamControl
var opp_control: TeamControl
var possession: PossessionController
var dt := DefenceTuning.new()


func before_each() -> void:
	scene = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	tree.root.add_child(scene)
	team = scene.team
	opp = scene.opp
	ball = scene.ball
	passing = scene.passing
	control = scene.team_control
	opp_control = scene.opp_control
	possession = scene.possession


func after_each() -> void:
	scene.queue_free()


func _ticks(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _stick(dir: Vector2, sprint := false) -> void:
	var it := SupportRunner.Intent.new()
	it.dir = dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO
	it.mag = 1.0 if dir != Vector2.ZERO else 0.0
	it.sprint = sprint
	scene.human.scripted = it


func _p(t: Team, number: int) -> RugbyPlayer:
	for p in t.players:
		if p.profile.number == number:
			return p
	return null


# --- scene -----------------------------------------------------------------------

func test_six_v_six_spawns() -> void:
	await _ticks(2)
	check(team.players.size() == 6 and opp.players.size() == 6, "6 v 6 (%d v %d)" % [team.players.size(), opp.players.size()])
	check(opp.attack_dir == -1.0, "opponents attack toward -X")
	check(opp_control != null and not opp_control.is_human(), "opponents are AI-controlled")
	check(_p(opp, 9).team_colors["jersey"] != _p(team, 9).team_colors["jersey"], "different kits")
	check(control.phase == TeamControl.Phase.ATTACK and opp_control.phase == TeamControl.Phase.DEFEND, "we attack, they defend")


# --- defence ---------------------------------------------------------------------

func test_line_comes_up_to_meet_the_attack() -> void:
	await _ticks(2)
	var start_gap := _mean_x(opp) - _mean_x(team)
	_stick(Vector2.ZERO)
	await _ticks(90)
	var gap := _mean_x(opp) - _mean_x(team)
	check(gap < start_gap - 3.0, "defence advances (gap %.1f -> %.1f m)" % [start_gap, gap])
	for d in opp.players:
		check(d.global_position.x > _p(team, 9).global_position.x - 1.0, "O%d stays on its side of the carrier" % d.profile.number)


func test_carrier_running_straight_gets_tackled() -> void:
	var tackled := [null]
	scene.tackles.tackle_made.connect(func(_d, c, r): if tackled[0] == null: tackled[0] = r)
	_stick(Vector2.RIGHT)
	await _ticks(180)
	check(tackled[0] != null, "running straight at the defence ends in a tackle within 3 s")


func test_line_drifts_with_the_attack() -> void:
	# The whole attack shifts toward its left (-Z): the carrier runs on a
	# diagonal and the support line follows. Defenders must slide with it.
	# (Structure only: tackling is switched off for this test.)
	scene.tackles.set_physics_process(false)
	_stick(Vector2.RIGHT)
	await _ticks(30)
	var team_before := _mean_z(team)
	var opp_before := _mean_z(opp)
	_stick(Vector2(0.6, -1.0))
	await _ticks(150)
	var team_shift := _mean_z(team) - team_before
	var opp_shift := _mean_z(opp) - opp_before
	check(team_shift < -4.0, "attack moved left (%.1f m)" % team_shift)
	check(opp_shift < team_shift * 0.6, "defence slid with it (attack %.1f m, defence %.1f m)" % [team_shift, opp_shift])


func test_defence_never_behind_own_try_line() -> void:
	_stick(Vector2.RIGHT, true)
	for i in 600:
		await tree.physics_frame
		if ball.state == RugbyBall.State.DEAD:
			break
	for asg in opp_control.assignments:
		# The line holds its try line; only the defender making the tackle
		# follows the carrier into the in-goal (stopping the try).
		if asg.role == &"tackle":
			continue
		check(asg.target.x <= FieldDimensions.HALF_LENGTH, "O%d (%s) target x %.1f beyond its try line" % [asg.defender.profile.number, asg.role, asg.target.x])


# --- turnovers ---------------------------------------------------------------------

func _force_interception() -> RugbyPlayer:
	# A defender standing on the receiver's line with certain hands.
	possession.pass_tuning.intercept_mult = 10.0
	possession.pass_tuning.intercept_min_time = 0.0
	control.active = false
	opp_control.active = false
	var p9 := _p(team, 9)
	var p10 := _p(team, 10)
	p10.reset_to(p9.global_position + Vector3(-2, 0, -10))
	var thief := _p(opp, 10)
	thief.reset_to(p9.global_position + Vector3(-1, 0, -5))
	await _ticks(2)
	passing.throw_to(p9, p10, PassTargeting.LEFT, false)
	control.active = true
	opp_control.active = true
	for i in 90:
		await tree.physics_frame
		if ball.state == RugbyBall.State.HELD:
			break
	return ball.carrier


func test_interception_flips_phases_and_control() -> void:
	_stick(Vector2.ZERO)
	await _ticks(5)
	var got := await _force_interception()
	check(got == _p(opp, 10), "the defender in the lane intercepts (got %s)" % (got.name if got else "nobody"))
	await _ticks(2)
	check(control.phase == TeamControl.Phase.DEFEND, "we now defend")
	check(opp_control.phase == TeamControl.Phase.ATTACK, "they now attack")
	# Human now controls our player nearest the ball.
	var b := Vector2(ball.global_position.x, ball.global_position.z)
	var nearest: RugbyPlayer = null
	var best := INF
	for p in team.players:
		var d := p.planar_position().distance_to(b)
		if d < best:
			best = d
			nearest = p
	check(control.controlled == nearest, "control jumps to our player nearest the ball")


func test_ai_carrier_runs_at_our_line() -> void:
	_stick(Vector2.ZERO)
	await _ticks(5)
	await _force_interception()
	var x0 := ball.global_position.x
	await _ticks(60)
	check(ball.global_position.x < x0 - 2.0 or ball.carrier != _p(opp, 10), "AI carrier attacks toward -X (moved %.1f m)" % (x0 - ball.global_position.x))


func test_switch_player_on_defence() -> void:
	_stick(Vector2.ZERO)
	await _ticks(5)
	await _force_interception()
	await _ticks(5)
	var before := control.controlled
	Input.action_press("pass_right")
	await _ticks(2)
	Input.action_release("pass_right")
	await _ticks(1)
	check(control.controlled != before, "LB/RB on defence switches player")
	check(control.controlled.team == team, "to one of ours")


# --- pure rules --------------------------------------------------------------------

func test_split_feed_keeps_drift_drops_retreat() -> void:
	var f := DefensiveLine.split_feed(Vector2(6, 3), Vector2(1, 0), 0.0)
	check(f.is_equal_approx(Vector2(0, 3)), "marks copy the sideways part only (%s)" % f)
	var half := DefensiveLine.split_feed(Vector2(6, 3), Vector2(1, 0), 0.5)
	check(half.is_equal_approx(Vector2(3, 3)), "pursuer gives half the forward pace")


func test_mark_target_inside_shoulder_and_in_front() -> void:
	var t := DefenceTuning.new()
	var target := DefensiveLine.mark_target(Vector2(0, -14), Vector2(0, 0), Vector2(1, 0), t)
	check(target.x > 0.0, "in front of the mark (toward the defenders' line)")
	check(target.y > -14.0, "on the inside shoulder (toward the ball)")
	var near := DefensiveLine.mark_target(Vector2(0, -2), Vector2(0, 0), Vector2(1, 0), t)
	check(near.x < target.x, "tighter near the ball, deeper out wide")


func test_clamp_to_own_line() -> void:
	var p := DefensiveLine.clamp_to_own_line(Vector2(58, 3), Vector2(1, 0))
	check(p.x <= FieldDimensions.HALF_LENGTH, "never behind the try line (%.1f)" % p.x)
	var q := DefensiveLine.clamp_to_own_line(Vector2(-58, 3), Vector2(-1, 0))
	check(q.x >= -FieldDimensions.HALF_LENGTH, "mirrored for the other team (%.1f)" % q.x)


func _mean_x(t: Team) -> float:
	var s := 0.0
	for p in t.players:
		s += p.global_position.x
	return s / t.players.size()


func _mean_z(t: Team) -> float:
	var s := 0.0
	for p in t.players:
		s += p.global_position.z
	return s / t.players.size()
