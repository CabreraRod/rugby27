extends TestSuite
## Movement "feel targets" expressed as numbers. If tuning changes break one
## of these, it should be a deliberate decision recorded in GAMEPLAY.md.

const DT := 1.0 / 60.0

var t: MovementTuning
var model: LocomotionModel
var flyhalf: PlayerAttributes


func before_each() -> void:
	t = MovementTuning.new()  # code defaults == shipped JSON (checked in test_data)
	model = LocomotionModel.new()
	flyhalf = PlayerAttributes.from_dict({"speed": 82, "acceleration": 84, "stamina": 85})


func _stats(attrs: PlayerAttributes = null, speed_mult := 1.0, turn_mult := 1.0) -> LocomotionStats:
	return LocomotionStats.derive(t, attrs if attrs else flyhalf, speed_mult, turn_mult, 1.0)


## Runs until predicate(v) or timeout; returns elapsed seconds (or -1).
func _time_until(v0: Vector2, dir: Vector2, target: float, s: LocomotionStats, pred: Callable, timeout := 6.0) -> float:
	var v := v0
	var time := 0.0
	while time < timeout:
		v = model.step(v, dir, target, s, t, DT)
		time += DT
		if pred.call(v):
			return time
	return -1.0


func test_first_step_is_immediate_in_any_direction() -> void:
	var s := _stats()
	var dir := Vector2(-0.6, 0.8)
	var v := model.step(Vector2.ZERO, dir, s.jog_top, s, t, DT)
	check(v.length() > 0.0, "player should move on the very first tick")
	check(v.normalized().dot(dir) > 0.999, "first step should go exactly where the stick points")


func test_reaches_jog_quickly() -> void:
	var s := _stats()
	var tt := _time_until(Vector2.ZERO, Vector2.RIGHT, s.jog_top, s, func(v): return v.length() >= s.jog_top - 0.01)
	check_between(tt, 0.4, 0.9, "time to jog speed (s)")


func test_sprint_has_weighty_top_end() -> void:
	var s := _stats()
	var t90 := _time_until(Vector2.ZERO, Vector2.RIGHT, s.sprint_top, s, func(v): return v.length() >= s.sprint_top * 0.9)
	check_between(t90, 1.4, 3.2, "time to 90% sprint (s)")
	check_between(s.sprint_top, 9.0, 9.8, "fly-half sprint top speed (m/s)")


func test_stop_from_sprint_is_short_but_not_instant() -> void:
	var s := _stats()
	var v := Vector2(s.sprint_top, 0)
	var dist := 0.0
	var time := 0.0
	while v.length() > 0.0 and time < 3.0:
		v = model.step(v, Vector2.ZERO, 0.0, s, t, DT)
		dist += v.length() * DT
		time += DT
	check_between(time, 0.5, 0.9, "stop time from sprint (s)")
	check_between(dist, 2.0, 4.5, "stop distance from sprint (m)")


func test_ninety_degree_cut_at_jog_is_crisp() -> void:
	var s := _stats()
	var v0 := Vector2(s.jog_top, 0)
	var up := Vector2(0, -1)
	var tt := _time_until(v0, up, s.jog_top, s, func(v): return v.normalized().dot(up) > cos(deg_to_rad(8.0)))
	check_between(tt, 0.05, 0.35, "90° cut at jog (s)")


func test_sprinter_turns_wider_than_jogger() -> void:
	var s := _stats()
	var up := Vector2(0, -1)
	var pred := func(v): return v.normalized().dot(up) > cos(deg_to_rad(8.0))
	var jog_t := _time_until(Vector2(s.jog_top, 0), up, s.jog_top, s, pred)
	var sprint_t := _time_until(Vector2(s.sprint_top, 0), up, s.sprint_top, s, pred)
	check(sprint_t > jog_t, "sprinting cut (%.2fs) should take longer than jogging cut (%.2fs)" % [sprint_t, jog_t])


func test_reversal_at_sprint_plants_then_goes() -> void:
	var s := _stats()
	var v := Vector2(s.sprint_top, 0)
	var back := Vector2.LEFT
	var planted_seen := false
	var min_speed := INF
	var time := 0.0
	var done_at := -1.0
	while time < 3.0:
		v = model.step(v, back, s.sprint_top, s, t, DT)
		time += DT
		planted_seen = planted_seen or model.last_planted
		min_speed = minf(min_speed, v.length())
		if v.normalized().dot(back) > 0.95 and v.length() > s.jog_top * 0.6:
			done_at = time
			break
	check(planted_seen, "reversal at sprint should trigger a plant")
	check(min_speed < t.plant_min_speed + 0.5, "speed should drop during the plant (min %.2f)" % min_speed)
	check_between(done_at, 0.4, 1.4, "reversal recovery time (s)")


func test_low_speed_reversal_does_not_plant() -> void:
	var s := _stats()
	model.step(Vector2(1.5, 0), Vector2.LEFT, s.jog_top, s, t, DT)
	check(not model.last_planted, "walking reversal should just pivot")


func test_releasing_sprint_eases_down_not_brakes() -> void:
	var s := _stats()
	var v := model.step(Vector2(s.sprint_top, 0), Vector2.RIGHT, s.jog_top, s, t, DT)
	var drop := s.sprint_top - v.length()
	check_between(drop, 0.01, 0.2, "speed lost in one tick after releasing sprint")


func test_attributes_separate_players() -> void:
	var wing := PlayerAttributes.from_dict({"speed": 96, "acceleration": 93})
	var prop := PlayerAttributes.from_dict({"speed": 52, "acceleration": 60})
	var sw := _stats(wing)
	var sp := _stats(prop)
	check(sw.sprint_top - sp.sprint_top > 1.5, "wing should be clearly faster than prop (%.2f vs %.2f)" % [sw.sprint_top, sp.sprint_top])
	check(sw.accel > sp.accel, "wing should accelerate harder")


func test_ball_carrier_slightly_slower_and_stiffer() -> void:
	var base := _stats()
	var carrier := _stats(null, t.carrier_speed_mult, t.carrier_turn_mult)
	check(carrier.sprint_top < base.sprint_top, "carrier top speed should be lower")
	check(carrier.sprint_top > base.sprint_top * 0.93, "carrier penalty should be small")
	check(carrier.turn_mult < base.turn_mult, "carrier should turn slightly slower")


func test_deterministic() -> void:
	var s := _stats()
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var m2 := LocomotionModel.new()
	for i in 240:
		var dir := Vector2.RIGHT.rotated(sin(i * 0.1) * 2.0)
		a = model.step(a, dir, s.sprint_top, s, t, DT)
		b = m2.step(b, dir, s.sprint_top, s, t, DT)
	check(a == b, "same inputs must give identical results")


func test_facing_turns_on_the_spot() -> void:
	var f := Vector2.RIGHT
	for i in 30:
		f = LocomotionModel.turn_facing(f, Vector2.LEFT, 0.0, 9.0, t, DT)
	check(f.dot(Vector2.LEFT) > 0.99, "standing player should face new direction within 0.5 s")
