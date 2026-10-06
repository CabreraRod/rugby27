extends TestSuite


func test_shipped_tuning_matches_code_defaults() -> void:
	# Tests use code defaults; this keeps them honest about the shipped feel.
	_compare(MovementTuning.new(), MovementTuning.load_default(), "movement.json")
	_compare(BallTuning.new(), BallTuning.load_default(), "ball.json")
	_compare(PassingTuning.new(), PassingTuning.load_default(), "passing.json")
	_compare(SupportTuning.new(), SupportTuning.load_default(), "support.json")
	_compare(DefenceTuning.new(), DefenceTuning.load_default(), "defence.json")
	_compare(TackleTuning.new(), TackleTuning.load_default(), "tackle.json")
	_compare(AITuning.new(), AITuning.load_default(), "ai.json")


func test_shipped_tuning_has_every_key() -> void:
	for pair in [[MovementTuning.new(), MovementTuning.DEFAULT_PATH], [BallTuning.new(), BallTuning.DEFAULT_PATH],
			[PassingTuning.new(), PassingTuning.DEFAULT_PATH], [SupportTuning.new(), SupportTuning.DEFAULT_PATH],
			[DefenceTuning.new(), DefenceTuning.DEFAULT_PATH], [TackleTuning.new(), TackleTuning.DEFAULT_PATH], [AITuning.new(), AITuning.DEFAULT_PATH]]:
		var data := JsonLoader.load_dict(pair[1])
		for key in pair[0].property_names().keys():
			check(data.has(key), "%s is missing '%s'" % [pair[1].get_file(), key])


func _compare(defaults: TuningData, shipped: TuningData, label: String) -> void:
	for key in defaults.property_names().keys():
		var a: float = defaults.get(key)
		var b: float = shipped.get(key)
		check(is_equal_approx(a, b), "%s '%s' = %s but code default = %s" % [label, key, b, a])


func test_dev_lineup_numbers_exist_in_squad() -> void:
	var squad := PlayerProfile.load_squad("res://data/players/dev_squad.json")
	var numbers := []
	for p in squad:
		numbers.append(p.number)
	var team := JsonLoader.load_dict("res://data/teams/dev_team.json")
	for e in team.get("lineup", []):
		check(numbers.has(int(e["number"])), "lineup #%d has no squad entry" % int(e["number"]))
	var opp := JsonLoader.load_dict("res://data/teams/dev_opponents.json")
	var opp_numbers := []
	for p in PlayerProfile.load_squad(String(opp["squad"])):
		opp_numbers.append(p.number)
	for e in opp.get("lineup", []):
		check(opp_numbers.has(int(e["number"])), "opponent lineup #%d has no squad entry" % int(e["number"]))


func test_weights_loaded() -> void:
	var squad := PlayerProfile.load_squad("res://data/players/dev_squad.json")
	for p in squad:
		check(p.weight_kg > 60.0 and p.weight_kg < 140.0, "%s weight %.0f kg" % [p.display_name, p.weight_kg])
	var no_weight := PlayerProfile.from_dict({"position": "TightheadProp"})
	check(no_weight.weight_kg > 110.0, "missing weight falls back to a position default")


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
