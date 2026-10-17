extends SceneTree
## Kick soak (M09).
##   godot --headless --fixed-fps 60 --path . --script res://tools/kick_soak.gd [-- runs]
##
## 1. Range and accuracy by kicker (kicking 30 / 60 / 90) and kick type.
## 2. Fielding high kicks in game: uncontested vs. chased.
## 3. Drop goals: success by distance and how far from the sweet spot.
## 4. AI vs AI: what the AI kicks, touch finds, kicks caught / regathered.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 16
	await _accuracy()
	await _fielding(maxi(runs * 2, 20))
	_drops()
	if runs > 0:
		await _play(runs)
	quit(0)


func _scene(autoplay: bool) -> Node3D:
	var scene: Node3D = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	scene.autoplay = autoplay
	root.add_child(scene)
	return scene


# --- 1 ------------------------------------------------------------------------------------

func _accuracy() -> void:
	print("== 1. Range and accuracy (predicted first landing, 200 kicks each, kicker at x = -30 kicking +X)")
	print("type        charge | kicking 30: mean m (sd, lateral sd) | kicking 60 | kicking 90")
	var scene := _scene(true)
	await physics_frame
	scene.team_control.active = false
	scene.opp_control.active = false
	scene.tackles.set_physics_process(false)
	var k: RugbyPlayer = scene.team.players[1]
	var saved := k.profile.attributes.rating("kicking")
	for spec in [[KickModel.Type.LONG, 1.0], [KickModel.Type.LONG, 0.5], [KickModel.Type.HIGH, 0.6], [KickModel.Type.BOX, 0.6], [KickModel.Type.LOW, 0.6]]:
		var line := "%-10s  %5.1f |" % [KickModel.type_name(spec[0]), spec[1]]
		for rating in [30, 60, 90]:
			k.profile.attributes._values["kicking"] = rating
			var ds := []
			var lats := []
			for i in 200:
				k.reset_to(Vector3(-30, 0, 0))
				scene.ball.attach(k)
				scene.kicks.kick(k, spec[0], Vector2.RIGHT, spec[1])
				var land: Vector2 = scene.kicks.landing if spec[0] != KickModel.Type.LOW else Vector2(-30, 0) + scene.kicks.last_strike.aim * scene.kicks.last_strike.planned
				ds.append(land.x + 30.0)
				lats.append(land.y)
			line += "  %5.1f (%4.1f, %4.1f) |" % [_mean(ds), _sd(ds), _sd(lats)]
		print(line)
	k.profile.attributes._values["kicking"] = saved
	scene.queue_free()
	await process_frame


# --- 2 ------------------------------------------------------------------------------------

func _fielding(trials: int) -> void:
	print("\n== 2. Fielding a high kick (□, %d trials each). uncontested: receivers 35 m upfield, kickers' team 30 m back;" % trials)
	print("   chased: kick into space, receivers 50 m upfield and the kickers' team level with the kicker")
	for spec in [[false, 0.6], [true, 0.6]]:
		var chased: bool = spec[0]
		var charge: float = spec[1]
		var S := {"caught": 0, "regathered": 0, "dropped": 0, "bounced": 0}
		for i in trials:
			var scene := _scene(true)
			scene.possession.rng.seed = hash("field-%d-%s-%f" % [i, chased, charge])
			scene.kicks.rng.seed = hash("fk-%d-%s-%f" % [i, chased, charge])
			await physics_frame
			scene.tackles.set_physics_process(false)
			var k: RugbyPlayer = scene.team.players[1]
			for p in scene.team.players:
				var x := -12.0 if chased else -40.0
				p.reset_to(Vector3(x if p != k else -10.0, 0, p.global_position.z * 0.4), Vector2.RIGHT)
			for p in scene.opp.players:
				p.reset_to(Vector3(40.0 if chased else 25.0, 0, p.global_position.z * 0.5), Vector2.LEFT)
			scene.ball.attach(k)
			await physics_frame
			scene.kicks.kick(k, KickModel.Type.HIGH, Vector2.RIGHT, charge)
			var res := [""]
			scene.kicks.kick_caught.connect(func(c: RugbyPlayer, own: bool): if res[0] == "": res[0] = "regathered" if own else "caught")
			scene.possession.catch_failed.connect(func(_p, _c, _k): if res[0] == "": res[0] = "dropped")
			scene.ball.bounced.connect(func(_a, _b, _c): if res[0] == "": res[0] = "bounced")
			for t in 360:
				await physics_frame
				if res[0] != "":
					break
			if res[0] != "":
				S[res[0]] += 1
			scene.queue_free()
			await process_frame
		print("%-12s charge %.1f: caught by the receivers %d, regathered by the kickers %d, dropped %d, bounced %d" % ["chased" if chased else "uncontested", charge, S["caught"], S["regathered"], S["dropped"], S["bounced"]])


# --- 3 ------------------------------------------------------------------------------------

func _drops() -> void:
	var t := KickTuning.load_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("drops")
	print("\n== 3. Drop goals in front of the posts (kicking 88, 300 each): success by charge error")
	print("dist | window | err 0    ±0.05  ±0.10  ±0.20")
	for dist in [20.0, 30.0, 38.0, 44.0]:
		var p0 := Vector3(50.0 - dist, t.drop_contact_height, 0)
		var need := KickModel.drop_needed_speed(p0, Vector2.RIGHT, 50.0, 0.03, 9.8, 0.11, t)
		var line := "%3.0f m | %.3f |" % [dist, KickModel.drop_window(0.88, dist, t)]
		for e in [0.0, 0.05, 0.1, 0.2]:
			var good := 0
			for i in 300:
				var sgn := 1.0 if i % 2 == 0 else -1.0
				var sy := KickModel.drop_strike(t.drop_sweet + e * sgn, 0.88, dist, need, rng, t)
				var h := KickModel.height_at_plane(p0, KickModel.launch(Vector2.RIGHT.rotated(deg_to_rad(sy.y)), t.drop_angle, sy.x), 0.03, 9.8, 0.11, 50.0)
				if KickModel.drop_good(h.x, h.y):
					good += 1
			line += "  %3d%%" % (100 * good / 300)
		print(line)


# --- 4 ------------------------------------------------------------------------------------

func _play(runs: int) -> void:
	var S := {"kicks": {}, "touch": 0, "caught": 0, "regathered": 0, "attacks": 0}
	for run in runs:
		for side in 2:
			var scene := _scene(true)
			for r in [scene.passing.rng, scene.possession.rng, scene.tackles.rng, scene.rucks.rng, scene.kicks.rng]:
				r.seed = hash("%d-%d-%d" % [run, side, r.get_instance_id() % 7])
			scene.team_control.attack_ai.rng.seed = hash("atk-%d-%d" % [run, side])
			scene.opp_control.attack_ai.rng.seed = hash("datk-%d-%d" % [run, side])
			await physics_frame
			if side == 1:
				scene.ball.attach(scene.opp.players[0])
			S["attacks"] += 1
			var st := {"kicked": false}
			scene.kicks.kicked.connect(func(k: RugbyPlayer, type, _l):
				var key := "%s %s" % [k.team.name.split(" ")[0], KickModel.type_name(type)]
				S["kicks"][key] = S["kicks"].get(key, 0) + 1
				st["kicked"] = true)
			scene.kicks.kick_caught.connect(func(_c, own: bool): S["regathered" if own else "caught"] += 1)
			scene.ball.went_dead.connect(func(zone, _p): if st["kicked"] and zone == FieldDimensions.Zone.TOUCH: S["touch"] += 1)
			for tick in 1200:
				await physics_frame
				var c: RugbyPlayer = scene.ball.carrier
				if scene.ball.state == RugbyBall.State.DEAD:
					break
				if c and absf(c.global_position.x) >= FieldDimensions.HALF_LENGTH:
					break
			scene.queue_free()
			await process_frame
	print("\n== 4. AI vs AI (%d attacks of 20 s)" % S["attacks"])
	var keys: Array = S["kicks"].keys()
	keys.sort()
	for key in keys:
		print("  %-30s %d" % [key, S["kicks"][key]])
	print("kicks into touch %d, caught by the receivers %d, regathered by the kickers %d" % [S["touch"], S["caught"], S["regathered"]])


static func _mean(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += x
	return s / maxf(a.size(), 1)


static func _sd(a: Array) -> float:
	var m := _mean(a)
	var s := 0.0
	for x in a:
		s += (x - m) * (x - m)
	return sqrt(s / maxf(a.size(), 1))
