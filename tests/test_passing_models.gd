extends TestSuite
## Pure passing rules: targeting, flight solving, accuracy, forward rule,
## catching, support slots.

const ATTACK := Vector2(1, 0)
const LEFT_VEC := Vector2(0, -1)   # attacker's left when attacking +X

var t: PassingTuning
var rng: RandomNumberGenerator
var g := 9.8


func before_each() -> void:
	t = PassingTuning.new()
	rng = RandomNumberGenerator.new()
	rng.seed = 77


# --- targeting -------------------------------------------------------------------

func _mates() -> Array[Vector2]:
	# Passer at origin. Two left, one right, one far ahead on the left.
	return [Vector2(-3, -7), Vector2(-6, -14), Vector2(-3, 7), Vector2(12, -6)]


func test_left_tap_picks_nearest_left() -> void:
	var i := PassTargeting.select(Vector2.ZERO, ATTACK, LEFT_VEC, _mates(), false, t)
	check(i == 0, "tap left should pick the first receiver on the left (got %d)" % i)


func test_left_hold_skips_one() -> void:
	var i := PassTargeting.select(Vector2.ZERO, ATTACK, LEFT_VEC, _mates(), true, t)
	check(i == 1, "hold left should skip to the second receiver (got %d)" % i)


func test_right_picks_right_side_only() -> void:
	var i := PassTargeting.select(Vector2.ZERO, ATTACK, -LEFT_VEC, _mates(), false, t)
	check(i == 2, "right pass should pick the right-side receiver (got %d)" % i)
	var skip := PassTargeting.select(Vector2.ZERO, ATTACK, -LEFT_VEC, _mates(), true, t)
	check(skip == 2, "skip with only one option falls back to it (got %d)" % skip)


func test_far_ahead_and_out_of_range_excluded() -> void:
	var c := PassTargeting.candidates(Vector2.ZERO, ATTACK, LEFT_VEC, _mates(), t)
	check(not c.has(3), "a receiver 12 m ahead is not an option")
	var far: Array[Vector2] = [Vector2(-5, -30)]
	check(PassTargeting.select(Vector2.ZERO, ATTACK, LEFT_VEC, far, false, t) == -1, "beyond max range -> pass into space")


func test_targeting_respects_attack_direction() -> void:
	# Same geometry mirrored for a team attacking -X: their left is +Z.
	var mates: Array[Vector2] = [Vector2(3, 7)]
	var i := PassTargeting.select(Vector2.ZERO, Vector2(-1, 0), Vector2(0, 1), mates, false, t)
	check(i == 0, "attacking -X, the receiver at +Z is on the left")


# --- flight -----------------------------------------------------------------------

func _simulate_flight(p0: Vector3, v: Vector3, time: float, damp: float) -> Vector3:
	var p := p0
	var vel := v
	var dt := 1.0 / 240.0
	var tt := 0.0
	while tt < time:
		vel.y -= g * dt
		vel *= maxf(0.0, 1.0 - damp * dt)
		p += vel * dt
		tt += dt
	return p


func test_pass_leads_a_running_receiver() -> void:
	var p0 := Vector3(0, 1.08, 0)
	var r_pos := Vector2(-3, -8)
	var r_vel := Vector2(7, 0)
	var plan := PassSolver.intercept(p0, r_pos, r_vel, 14.0, t)
	var v := PassSolver.ballistic(p0, plan.aim, plan.flight_time, 0.03, g)
	var arrive := _simulate_flight(p0, v, plan.flight_time, 0.03)
	var receiver_then := r_pos + r_vel * plan.flight_time
	var miss := Vector2(arrive.x, arrive.z).distance_to(receiver_then)
	check(miss < 0.25, "ball should meet the receiver's run (miss %.2f m)" % miss)
	check(absf(arrive.y - t.catch_height) < 0.2, "at chest height (%.2f)" % arrive.y)
	check_between(plan.flight_time, 0.4, 0.9, "flight time for an 8 m pass (s)")


func test_long_pass_is_quicker_per_metre() -> void:
	var p0 := Vector3(0, 1.08, 0)
	var quick := PassSolver.intercept(p0, Vector2(-5, -15), Vector2.ZERO, t.quick_speed_max, t)
	var long := PassSolver.intercept(p0, Vector2(-5, -15), Vector2.ZERO, t.long_speed_max, t)
	check(long.flight_time < quick.flight_time, "a long (hard) pass gets there sooner")


func test_error_never_forward() -> void:
	for i in 500:
		var e := PassSolver.error_offset(rng, 1.3, ATTACK, LEFT_VEC)
		check(Vector2(e.x, e.z).dot(ATTACK) <= 0.0001, "aim error must never push the ball forward")


func test_error_shrinks_with_skill() -> void:
	var bad := PassSolver.error_sd(0.4, false, 0.0, t)
	var good := PassSolver.error_sd(0.94, false, 0.0, t)
	var good_long_sprint := PassSolver.error_sd(0.94, true, 1.0, t)
	check(good < bad * 0.5, "good passer much tighter (%.2f vs %.2f)" % [good, bad])
	check(good_long_sprint > good * 1.8, "long + sprinting is riskier (%.2f vs %.2f)" % [good_long_sprint, good])


func test_forward_rule_is_relative_to_passer() -> void:
	# Passer sprinting at 8 m/s, ball released flat (relative) at 7 m/s:
	# moves forward over the ground but NOT a forward pass.
	var v_ball := Vector3(8.0, 2.0, -7.0)
	check(PassSolver.forward_speed(v_ball, Vector2(8, 0), ATTACK) < t.forward_tolerance, "momentum carrying the ball forward is legal")
	var thrown_forward := Vector3(10.5, 2.0, -7.0)
	check(PassSolver.forward_speed(thrown_forward, Vector2(8, 0), ATTACK) > t.forward_tolerance, "hands sending it forward is a forward pass")
	check(PassSolver.forward_speed(Vector3(-2, 2, -8), Vector2.ZERO, ATTACK) < 0.0, "a backward pass is backward")


# --- catching ------------------------------------------------------------------------

func test_catch_easy_pass_sticks() -> void:
	# A quick pass to a runner crosses at ~17 m/s relative: that is normal.
	var c := CatchModel.chance(0.89, 17.0, 0.0, 1.2, t)
	check(c > 0.95, "flat chest-high pass to good hands (%.2f)" % c)
	var long := CatchModel.chance(0.82, 21.0, 0.0, 1.2, t)
	check(long > 0.88, "a clean skip pass to decent hands mostly sticks (%.2f)" % long)


func test_catch_hard_cases_are_riskier() -> void:
	var base := CatchModel.chance(0.8, 10.0, 0.0, 1.2, t)
	check(CatchModel.chance(0.8, 28.0, 0.0, 1.2, t) < base - 0.15, "rocket pass is harder")
	check(CatchModel.chance(0.8, 10.0, 0.8, 1.2, t) < base - 0.15, "ball behind the body is harder")
	check(CatchModel.chance(0.8, 10.0, 0.0, 0.4, t) < base - 0.1, "bootlaces is harder")
	check(CatchModel.chance(0.8, 10.0, 0.0, 2.35, t) < base - 0.1, "overhead is harder")


func test_catch_reach_band() -> void:
	check(CatchModel.in_reach(Vector3.ZERO, Vector3(0.6, 1.2, 0.3), 1.0, t), "chest height near the body")
	check(not CatchModel.in_reach(Vector3.ZERO, Vector3(0.3, 2.8, 0), 1.0, t), "too high")
	check(not CatchModel.in_reach(Vector3.ZERO, Vector3(0.2, 0.2, 0), 1.0, t), "too low (that's a pickup)")
	check(not CatchModel.in_reach(Vector3.ZERO, Vector3(1.4, 1.2, 0), 1.0, t), "too far")


func test_dropped_catch_usually_knock_on() -> void:
	var forward := 0
	for i in 400:
		var v := CatchModel.knock_velocity(Vector3(0, -1, -12), ATTACK, rng, t)
		if CatchModel.is_knock_on(v, ATTACK):
			forward += 1
	check_between(forward, 230.0, 330.0, "knock-ons per 400 drops (≈70%)")


# --- support slots -------------------------------------------------------------------

func test_support_slots_are_behind_and_staggered() -> void:
	var team := Team.new()
	var st := SupportTuning.new()
	var a := SupportRunner.slot_position(Vector2.ZERO, team, 1.0, 1, st)
	var b := SupportRunner.slot_position(Vector2.ZERO, team, 1.0, 2, st)
	var r := SupportRunner.slot_position(Vector2.ZERO, team, -1.0, 1, st)
	check(a.x < 0.0 and b.x < a.x, "slots are behind the ball and deeper further out")
	check(a.y < 0.0 and b.y < a.y, "left slots go to -Z (attacker's left)")
	check(r.y > 0.0, "right slot goes to +Z")
	check(is_equal_approx(absf(a.y), st.spacing), "first slot one spacing out")


func test_support_slots_stay_in_field() -> void:
	var team := Team.new()
	var st := SupportTuning.new()
	var s := SupportRunner.slot_position(Vector2(0, -30), team, 1.0, 3, st)
	check(absf(s.y) <= FieldDimensions.HALF_WIDTH - st.touch_margin + 0.001, "slot clamped inside touch (%.1f)" % s.y)
