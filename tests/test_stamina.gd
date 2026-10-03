extends TestSuite

const DT := 1.0 / 60.0

var t: MovementTuning


func before_each() -> void:
	t = MovementTuning.new()


func test_full_sprint_lasts_a_believable_time() -> void:
	var st := StaminaModel.new(t.stamina_max)
	var time := 0.0
	while st.can_sprint() and time < 60.0:
		st.step(true, true, 10.0, t, DT)
		time += DT
	check_between(time, 8.0, 12.0, "sprint duration at drain 10/s (s)")
	check(st.sprint_locked, "sprint should lock when empty")


func test_lockout_hysteresis() -> void:
	var st := StaminaModel.new(t.stamina_max)
	st.value = 0.0
	st.step(true, true, 10.0, t, DT)
	check(not st.can_sprint(), "locked at zero")
	var time := 0.0
	while not st.can_sprint() and time < 10.0:
		st.step(false, false, 0.0, t, DT)
		time += DT
	check(st.value >= t.sprint_unlock - 0.5, "should unlock only after recovering to sprint_unlock")
	check_between(time, 0.8, 2.5, "unlock time from empty while idle (s)")


func test_regen_waits_after_sprint() -> void:
	var st := StaminaModel.new(t.stamina_max)
	st.value = 50.0
	st.step(true, true, 10.0, t, DT)
	var after_sprint := st.value
	st.step(false, false, 0.0, t, DT)
	check(is_equal_approx(st.value, after_sprint), "no regen immediately after sprinting")


func test_fatigue_is_soft() -> void:
	var st := StaminaModel.new(t.stamina_max)
	check(is_equal_approx(st.fatigue_multiplier(t), 1.0), "fresh player has no fatigue")
	st.value = 0.0
	check(is_equal_approx(st.fatigue_multiplier(t), t.fatigue_min_mult), "exhausted player at min multiplier")
	st.value = t.fatigue_threshold * 0.5
	var m := st.fatigue_multiplier(t)
	check(m > t.fatigue_min_mult and m < 1.0, "fatigue fades smoothly")


func test_high_stamina_attribute_drains_slower() -> void:
	var fit := LocomotionStats.derive(t, PlayerAttributes.from_dict({"stamina": 95}), 1, 1, 1)
	var unfit := LocomotionStats.derive(t, PlayerAttributes.from_dict({"stamina": 40}), 1, 1, 1)
	check(fit.sprint_drain < unfit.sprint_drain, "stamina attribute should reduce drain")
