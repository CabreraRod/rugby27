extends TestSuite


func test_shipped_tuning_matches_code_defaults() -> void:
	# Tests use code defaults; this keeps them honest about the shipped feel.
	var defaults := MovementTuning.new()
	var shipped := MovementTuning.load_default()
	for p in defaults.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var a: float = defaults.get(p.name)
			var b: float = shipped.get(p.name)
			check(is_equal_approx(a, b), "movement.json '%s' = %s but code default = %s" % [p.name, b, a])


func test_dev_squad_loads() -> void:
	var squad := PlayerProfile.load_squad("res://data/players/dev_squad.json")
	check(squad.size() >= 3, "dev squad should have at least 3 players")
	for p in squad:
		check(p.display_name != "Player", "player name parsed")
		check(p.attributes.rating("speed") != PlayerAttributes.DEFAULT_RATING, "%s speed parsed" % p.display_name)


func test_attributes_clamped() -> void:
	var a := PlayerAttributes.from_dict({"speed": 150, "strength": -3})
	check(a.rating("speed") == 99, "clamp high")
	check(a.rating("strength") == 1, "clamp low")
	check(a.rating("passing") == PlayerAttributes.DEFAULT_RATING, "missing -> default")


func test_field_geometry() -> void:
	check(is_equal_approx(FieldDimensions.line_22_x(), 28.0), "22 m line at x = ±28")
	check(is_equal_approx(FieldDimensions.dead_ball_x(), 60.0), "dead-ball line at x = ±60")
	check(FieldDimensions.in_field_of_play(Vector2(49.9, 34.9)), "inside corner is in play")
	check(not FieldDimensions.in_field_of_play(Vector2(50.1, 0)), "in-goal is not field of play")
	check(FieldDimensions.in_playing_area(Vector2(55, 0)), "in-goal is in playing area")
