extends TestSuite
## Pure ball rules: bounce distribution, pickup chances, field zones.

var t: BallTuning
var rng: RandomNumberGenerator


func before_each() -> void:
	t = BallTuning.new()
	rng = RandomNumberGenerator.new()
	rng.seed = 1234


func test_bounce_loses_height() -> void:
	for i in 200:
		var r := BounceModel.resolve(Vector3(4, -7, 0), rng, t)
		check(r.velocity.y > 0.0, "a hard impact must bounce up")
		check(r.velocity.y < 7.0 * 0.95, "bounce must lose energy (vy %.2f)" % r.velocity.y)


func test_bounce_is_unpredictable_but_bounded() -> void:
	var angles: Array[float] = []
	for i in 400:
		var r := BounceModel.resolve(Vector3(8, -8, 0), rng, t)
		angles.append(rad_to_deg(r.deflection))
	var mean := 0.0
	for a in angles:
		mean += a
	mean /= angles.size()
	var var_sum := 0.0
	var max_abs := 0.0
	for a in angles:
		var_sum += (a - mean) * (a - mean)
		max_abs = maxf(max_abs, absf(a))
	var sd := sqrt(var_sum / angles.size())
	check(sd > 6.0, "bounces should vary (sd %.1f°)" % sd)
	check(max_abs <= t.max_deflect_deg + 0.01, "deflection never exceeds max (%.1f°)" % max_abs)
	check(absf(mean) < 3.0, "no directional bias (mean %.1f°)" % mean)


func test_soft_bounce_is_tamer_than_hard_bounce() -> void:
	var soft := 0.0
	var hard := 0.0
	for i in 300:
		soft += absf(BounceModel.resolve(Vector3(3, -2, 0), rng, t).deflection)
		hard += absf(BounceModel.resolve(Vector3(3, -9, 0), rng, t).deflection)
	check(hard > soft * 1.8, "hard impacts should deflect more (soft %.1f, hard %.1f)" % [soft, hard])


func test_bounce_mostly_keeps_travel_direction() -> void:
	var forward := 0
	for i in 300:
		var v := BounceModel.resolve(Vector3(8, -6, 0), rng, t).velocity
		if v.x > 0.0:
			forward += 1
	check(forward == 300, "a travelling ball should never bounce backwards (%d/300 forward)" % forward)


func test_vertical_drop_scatters_sideways() -> void:
	var moved := 0
	for i in 100:
		var v := BounceModel.resolve(Vector3(0, -6, 0), rng, t).velocity
		if Vector2(v.x, v.z).length() > 0.1:
			moved += 1
	check(moved > 50, "a dropped ball should usually kick sideways (%d/100)" % moved)


func test_sit_up_happens_sometimes() -> void:
	var sat := 0
	for i in 1000:
		if BounceModel.resolve(Vector3(6, -9, 0), rng, t).sat_up:
			sat += 1
	check_between(sat, 80.0, 230.0, "sit-up bounces per 1000 hard impacts")


func test_bounce_deterministic_with_seed() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	for i in 50:
		var va := BounceModel.resolve(Vector3(5, -6, 1), a, t).velocity
		var vb := BounceModel.resolve(Vector3(5, -6, 1), b, t).velocity
		check(va == vb, "same seed must give identical bounces")


func test_roll_slows_and_stops() -> void:
	var h := Vector2(6, 0)
	var time := 0.0
	var dist := 0.0
	while h.length() > 0.0 and time < 10.0:
		h = BounceModel.roll(h, t, 1.0 / 60.0)
		dist += h.length() / 60.0
		time += 1.0 / 60.0
	check_between(time, 1.2, 3.0, "roll-out time from 6 m/s (s)")
	check_between(dist, 3.5, 9.0, "roll-out distance from 6 m/s (m)")


func test_pickup_still_ball_walking_is_safe() -> void:
	var c := PickupModel.chance(0.62, 1.5, 9.0, 0.5, t)
	check(c > 0.9, "walking onto a still ball should be near-certain (%.2f)" % c)


func test_pickup_full_sprint_is_risky() -> void:
	var calm := PickupModel.chance(0.62, 2.0, 9.0, 1.0, t)
	var sprint := PickupModel.chance(0.62, 9.0, 9.0, 9.0, t)
	check(sprint < calm - 0.25, "sprint scoop on a moving ball should be much riskier (%.2f vs %.2f)" % [sprint, calm])
	check(sprint > 0.2, "but not hopeless (%.2f)" % sprint)


func test_pickup_good_hands_matter() -> void:
	var fly := PickupModel.chance(0.89, 9.0, 9.0, 3.0, t)
	var prop := PickupModel.chance(0.62, 9.0, 9.0, 3.0, t)
	check(fly > prop + 0.08, "handling should matter at pace (fly %.2f, prop %.2f)" % [fly, prop])


func test_pickup_reach() -> void:
	check(PickupModel.in_reach(Vector3.ZERO, Vector3(0.7, 0.11, 0), t), "ball at feet in reach")
	check(not PickupModel.in_reach(Vector3.ZERO, Vector3(1.2, 0.11, 0), t), "ball 1.2 m away out of reach")
	check(not PickupModel.in_reach(Vector3.ZERO, Vector3(0.2, 2.5, 0), t), "high ball not a pickup")


func test_fumble_goes_forward() -> void:
	for i in 50:
		var v := PickupModel.fumble_velocity(Vector2(8, 0), Vector2(1, 0), rng, t)
		check(v.x > 0.0, "a fumble at pace knocks the ball forward")
		check(v.y > 0.0, "and pops it up")


func test_field_zones() -> void:
	check(FieldDimensions.zone_of(Vector2(0, 0)) == FieldDimensions.Zone.FIELD_OF_PLAY, "centre in play")
	check(FieldDimensions.zone_of(Vector2(10, 35.0)) == FieldDimensions.Zone.TOUCH, "on the touchline is touch")
	check(FieldDimensions.zone_of(Vector2(10, 34.95), 0.11) == FieldDimensions.Zone.TOUCH, "ball touching the line is touch")
	check(FieldDimensions.zone_of(Vector2(10, 34.5), 0.11) == FieldDimensions.Zone.FIELD_OF_PLAY, "ball clear of the line in play")
	check(FieldDimensions.zone_of(Vector2(52, 0)) == FieldDimensions.Zone.IN_GOAL, "in-goal")
	check(FieldDimensions.zone_of(Vector2(50, 0)) == FieldDimensions.Zone.IN_GOAL, "try line belongs to in-goal")
	check(FieldDimensions.zone_of(Vector2(55, -36)) == FieldDimensions.Zone.TOUCH_IN_GOAL, "touch in goal")
	check(FieldDimensions.zone_of(Vector2(60, 0)) == FieldDimensions.Zone.DEAD, "dead-ball line is dead")
	check(not FieldDimensions.is_out(FieldDimensions.Zone.IN_GOAL), "in-goal is not out")
