extends SceneTree
## Ruck soak (M08).
##   godot --headless --path . --script res://tools/ruck_soak.gd [-- runs]
##
## 1. AI vs AI play: both teams attack from the lineup for 20 s with the M07
##    AI and ruck AI on. Retention with normal support (target ~90-95 %),
##    turnovers when the carrier was isolated, AI bids / holds / penalties,
##    how long the ball takes to come out.
## 2. Scripted contests at a fixed spot (ruck AI off): the defence commits
##    0 or 4 against 0 / 2 / 4 attacking taps, with support close (normal)
##    or far away (isolated carrier, one defender on the ball).
## 3. Holding the ball in: penalty rate by seconds held.

const PLAY_TICKS := 1200

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 16
	if runs > 0:
		await _play(runs)
	await _matrix(maxi(runs * 3, 30))
	_hold()
	quit(0)


func _scene(autoplay: bool) -> Node3D:
	var scene: Node3D = load("res://game/match/match.tscn").instantiate()
	scene.solo = false
	scene.autoplay = autoplay
	root.add_child(scene)
	return scene


# --- 1. AI vs AI -------------------------------------------------------------------------

func _play(runs: int) -> void:
	var S := {"rucks": 0, "normal": 0, "normal_kept": 0, "iso": 0, "iso_lost": 0, "turnovers": 0, "penalties": 0,
		"bids": 0, "bids_won": 0, "holds": 0, "out_time": 0.0, "outs": 0, "att_bodies": 0, "def_bodies": 0}
	for run in runs:
		for side in 2:
			var scene := _scene(true)
			scene.passing.rng.seed = hash("pass-%d-%d" % [run, side])
			scene.possession.rng.seed = hash("poss-%d-%d" % [run, side])
			scene.tackles.rng.seed = hash("tackle-%d-%d" % [run, side])
			scene.rucks.rng.seed = hash("ruck-%d-%d" % [run, side])
			scene.team_control.attack_ai.rng.seed = hash("atk-%d-%d" % [run, side])
			scene.opp_control.attack_ai.rng.seed = hash("datk-%d-%d" % [run, side])
			await physics_frame
			if side == 1:
				scene.ball.attach(scene.opp.players[0])
			var r: RuckSystem = scene.rucks
			var st := {"iso": false, "bid": false}
			r.formed.connect(func(_a):
				S["rucks"] += 1
				st["iso"] = r.isolated()
				st["bid"] = false)
			r.decided.connect(func(_a, turnover: bool, res: RuckModel.Result):
				st["bid"] = r.ai_bid
				S["att_bodies"] += res.att_bodies
				S["def_bodies"] += res.def_bodies
				if st["bid"]:
					S["bids"] += 1
					if turnover: S["bids_won"] += 1
				if st["iso"]:
					S["iso"] += 1
					if turnover: S["iso_lost"] += 1
				else:
					S["normal"] += 1
					if not turnover: S["normal_kept"] += 1
				if turnover: S["turnovers"] += 1)
			r.penalised.connect(func(_d, _h): S["penalties"] += 1)
			r.ended.connect(func(_a, outcome: StringName):
				if outcome == &"out":
					S["outs"] += 1
					S["out_time"] += r.time
				if r.held_time > 0.0: S["holds"] += 1)
			for tick in PLAY_TICKS:
				await physics_frame
				var c: RugbyPlayer = scene.ball.carrier
				if scene.ball.state == RugbyBall.State.DEAD:
					break
				if c and absf(c.global_position.x) >= FieldDimensions.HALF_LENGTH:
					break
			scene.queue_free()
			await process_frame
	print("== 1. AI vs AI (%d x 2 attacks of %d s)" % [runs, PLAY_TICKS / 60])
	print("rucks %d   bodies per ruck: attack %.1f, defence %.1f" % [S["rucks"], float(S["att_bodies"]) / maxi(S["normal"] + S["iso"], 1), float(S["def_bodies"]) / maxi(S["normal"] + S["iso"], 1)])
	print("normal support: kept %d / %d (%.0f%%)" % [S["normal_kept"], S["normal"], 100.0 * S["normal_kept"] / maxi(S["normal"], 1)])
	print("isolated carrier: lost %d / %d (%.0f%%)" % [S["iso_lost"], S["iso"], 100.0 * S["iso_lost"] / maxi(S["iso"], 1)])
	print("AI defence bids %d, won %d;  holds %d, penalties %d;  turnovers %d" % [S["bids"], S["bids_won"], S["holds"], S["penalties"], S["turnovers"]])
	print("ball out in %.2f s on average (%d rucks)" % [S["out_time"] / maxi(S["outs"], 1), S["outs"]])


# --- 2. Scripted contests --------------------------------------------------------------------

func _matrix(trials: int) -> void:
	print("\n== 2. Scripted contests (%d trials per cell, ruck AI off)" % trials)
	print("scenario        def taps  att taps | bodies att v def | turnovers")
	var scene := _scene(true)
	await physics_frame
	scene.tackles.set_physics_process(false)
	var r: RuckSystem = scene.rucks
	r.ai_enabled = false
	for scenario in ["normal", "isolated"]:
		for def_taps in [0, 4]:
			for att_taps in [0, 2, 4]:
				var lost := 0
				var acc := {"ab": 0, "db": 0}
				var outcomes := {}
				for i in trials:
					r.rng.seed = hash("m-%s-%d-%d-%d" % [scenario, def_taps, att_taps, i])
					_stage(scene, scenario, i)
					await physics_frame
					r.form_at(Vector2.ZERO, scene.team)
					for k in def_taps:
						r.commit(scene.opp)
					for k in att_taps:
						r.commit(scene.team)
					var turnover := [false]
					var cb := func(_a, t: bool, res: RuckModel.Result):
						turnover[0] = t
						acc["ab"] += res.att_bodies
						acc["db"] += res.def_bodies
					r.decided.connect(cb)
					for tick in 480:
						await physics_frame
						if not r.is_active():
							break
					r.decided.disconnect(cb)
					outcomes[r.last_outcome] = outcomes.get(r.last_outcome, 0) + 1
					if turnover[0]:
						lost += 1
				print("%-14s  %8d  %8d | %5.1f v %-5.1f     | %3d%%   %s" % [scenario, def_taps, att_taps, float(acc["ab"]) / trials, float(acc["db"]) / trials, 100 * lost / trials, outcomes])
	scene.queue_free()
	await process_frame


## Puts both teams around a ruck at the origin (attack toward +X).
## normal: support 3-8 m behind; isolated: support 14+ m away, one defender
## 1.5 m from the ball. The rest of the defence 4-12 m ahead.
func _stage(scene: Node3D, scenario: String, i: int) -> void:
	scene.rucks.clear()
	scene.possession.clear_cooldowns()
	var jitter := float(i % 5) * 0.3
	var att: Array[RugbyPlayer] = scene.team.players
	for k in att.size():
		var back := (3.0 + k * 1.5 + jitter) if scenario == "normal" else (14.0 + k * 2.0)
		var side := (k - 2.5) * 3.0
		att[k].reset_to(Vector3(-back, 0, side), Vector2.RIGHT)
	var def: Array[RugbyPlayer] = scene.opp.players
	for k in def.size():
		var ahead := 4.0 + k * 1.6 + jitter
		var z := (k - 2.5) * 2.5
		if scenario == "isolated" and k == 0:
			ahead = 1.5   # a defender right over the ball
			z = 0.5
		def[k].reset_to(Vector3(ahead, 0, z), Vector2.LEFT)
	scene.ball.spawn_loose(Vector3(0.0, 0.11, 0.0), Vector3.ZERO)


# --- 3. Holding in ---------------------------------------------------------------------------

func _hold() -> void:
	var t := RuckTuning.load_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hold")
	print("\n== 3. Holding the ball in (2000 trials each, 60 Hz)")
	for secs in [0.5, 1.0, 1.5, 2.0, 3.0]:
		var pens := 0
		for trial in 2000:
			var held := 0.0
			var dt := 1.0 / 60.0
			while held < secs - 1e-6:
				if rng.randf() < RuckModel.hold_tick_chance(held, dt, t) or held + dt >= t.hold_max:
					pens += 1
					break
				held += dt
		print("held %.1f s: penalised %4.1f%%  (model %.1f%%)" % [secs, 100.0 * pens / 2000.0, 100.0 * RuckModel.hold_penalty_cdf(secs, t)])
