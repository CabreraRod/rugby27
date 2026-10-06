extends Node3D
## Development match scene: builds the world, one team from data, the ball
## and the systems that connect them. Composition only — no gameplay rules.
##
## Two modes:
##   * Team (default): the lineup from data/teams/dev_team.json, ball in the
##     scrum-half's hands, passing live, against the AI opponents from
##     data/teams/dev_opponents.json (set with_opponents = false to drop them).
##   * Sandbox (F2 / D-pad up): one player and a loose ball — for movement
##     tuning and pickup practice. F2 reloads the scene in the other mode.
##
## Later, a MatchDirector (phases, clock, score, restarts) replaces this.

const SQUAD_PATH := "res://data/players/dev_squad.json"
const TEAM_PATH := "res://data/teams/dev_team.json"
const OPP_PATH := "res://data/teams/dev_opponents.json"
const SANDBOX_SPOT := Vector3(0.0, 0.0, 0.0)
const SANDBOX_BALL_SPOT := Vector3(6.0, 0.11, 0.0)
const SANDBOX_NUMBER := 10

## Survives scene reloads so F2 toggles between modes.
static var sandbox_mode := false

## Set before adding to the tree to force a mode (tests). Defaults to sandbox_mode.
var solo := sandbox_mode
## Team mode only: spawn the AI opponents (tests of M04 behaviour turn it off).
var with_opponents := true

var tuning: MovementTuning
var ball_tuning: BallTuning
var pass_tuning: PassingTuning
var support_tuning: SupportTuning
var defence_tuning: DefenceTuning
var tackle_tuning: TackleTuning
var ai_tuning: AITuning
## M07: 1 = basic AI, 0 = M04-M06 placeholders (A/B soaks). Set before _ready.
var ai_level := 1
## Opponents' AI level if >= 0 (A/B soaks), else ai_level. Set before _ready.
var opp_ai_level := -1
## Both teams AI-controlled (soaks, attract mode). Set before _ready.
var autoplay := false
var squad: Array[PlayerProfile] = []
var team := Team.new()
var team_data := {}
var opp := Team.new()
var opp_data := {}
## Start positions per player.
var lineup_spots := {}

var ball: RugbyBall
var possession: PossessionController
var passing: PassingSystem
var tackles: TackleSystem
var team_control: TeamControl
var opp_control: TeamControl
var camera: BroadcastCamera
var human: HumanController
var hud: MatchHud
var debug_overlay: DebugOverlay

var _profile_index := 0
var _possession_team: Team
var _restart_timer: SceneTreeTimer


func _ready() -> void:
	tuning = MovementTuning.load_default()
	ball_tuning = BallTuning.load_default()
	pass_tuning = PassingTuning.load_default()
	support_tuning = SupportTuning.load_default()
	defence_tuning = DefenceTuning.load_default()
	tackle_tuning = TackleTuning.load_default()
	ai_tuning = AITuning.load_default()
	squad = PlayerProfile.load_squad(SQUAD_PATH)
	if squad.is_empty():
		squad.append(PlayerProfile.from_dict({"name": "Fallback", "number": 1}))
	team_data = _load_team(team, TEAM_PATH)

	StadiumEnvironment.build(self)
	FieldBuilder.build(self)
	if solo:
		_spawn_team(team, team_data, squad, [{"number": SANDBOX_NUMBER, "pos": [SANDBOX_SPOT.x, SANDBOX_SPOT.z]}], "Player")
	else:
		_spawn_team(team, team_data, squad, team_data.get("lineup", []), "P")
		if with_opponents:
			opp_data = _load_team(opp, OPP_PATH)
			var opp_squad := PlayerProfile.load_squad(String(opp_data.get("squad", SQUAD_PATH)))
			_spawn_team(opp, opp_data, opp_squad, opp_data.get("lineup", []), "O")
	var everyone: Array[RugbyPlayer] = []
	everyone.append_array(team.players)
	everyone.append_array(opp.players)

	ball = RugbyBall.new()
	ball.name = "Ball"
	ball.setup(ball_tuning)
	add_child(ball)
	var ball_visual := BallVisual.new()
	ball_visual.name = "Visual"
	ball_visual.ball = ball
	ball.add_child(ball_visual)
	ball.went_dead.connect(_on_ball_dead)

	possession = PossessionController.new()
	possession.name = "Possession"
	possession.setup(ball, ball_tuning, everyone)
	possession.pass_tuning = pass_tuning
	add_child(possession)

	tackles = TackleSystem.new()
	tackles.name = "Tackles"
	tackles.setup(ball, possession, everyone, tackle_tuning)
	add_child(tackles)

	passing = PassingSystem.new()
	passing.name = "Passing"
	passing.setup(ball, possession, pass_tuning)
	add_child(passing)

	camera = BroadcastCamera.new()
	camera.name = "BroadcastCamera"
	add_child(camera)
	camera.ball = ball
	camera.current = true

	human = HumanController.new()
	human.name = "HumanController"
	human.camera = camera
	add_child(human)

	var opp_ref: Team = opp if not opp.players.is_empty() else null
	team_control = TeamControl.new()
	team_control.name = "TeamControl"
	team_control.setup(team, opp_ref, ball, passing, possession, null if autoplay else human, support_tuning, defence_tuning)
	team_control.configure_ai(TeamStyle.from_dict(team_data.get("style", {})), ai_tuning, tackle_tuning, ai_level, 77)
	add_child(team_control)
	if opp_ref:
		opp_control = TeamControl.new()
		opp_control.name = "OppControl"
		opp_control.setup(opp, team, ball, passing, possession, null, support_tuning, defence_tuning)
		opp_control.configure_ai(TeamStyle.from_dict(opp_data.get("style", {})), ai_tuning, tackle_tuning, ai_level if opp_ai_level < 0 else opp_ai_level, 78)
		add_child(opp_control)

	hud = MatchHud.new()
	hud.ball = ball
	add_child(hud)

	debug_overlay = DebugOverlay.new()
	debug_overlay.ball = ball
	debug_overlay.possession = possession
	debug_overlay.passing = passing
	debug_overlay.team_control = team_control
	debug_overlay.opp_control = opp_control
	debug_overlay.tackles = tackles
	add_child(debug_overlay)
	debug_overlay.attach_world(self)

	if not solo:
		var markers := PassMarkers.new()
		markers.name = "PassMarkers"
		markers.passing = passing
		markers.control = team_control
		add_child(markers)

	team_control.controlled_changed.connect(_on_controlled_changed)
	possession.pickup_failed.connect(func(_p, _c): hud.notify("FUMBLED", Color("#f5a524"), 0.9))
	possession.catch_failed.connect(func(_p, _c, knock_on: bool):
		hud.notify("KNOCK-ON" if knock_on else "DROPPED", Color("#f5a524"), 1.0))
	ball.carrier_changed.connect(_on_carrier_changed_notice)
	if autoplay:
		# Nobody is controlled: the camera follows whoever has the ball.
		ball.carrier_changed.connect(func(_o, n: RugbyPlayer):
			if n:
				camera.target = n
				hud.player = n
				debug_overlay.player = n)
	tackles.tackle_made.connect(_on_tackle)
	tackles.dive_missed.connect(func(p: RugbyPlayer):
		if p.team == team:
			hud.notify("MISSED", Color("#f5a524"), 0.8))
	hud.team_control = team_control
	passing.pass_thrown.connect(func(_p, _r, forward: bool):
		if forward:
			hud.notify("FORWARD PASS", Color("#ff5a5f"), 1.2))

	# Launched as the game: every match gets its own luck. Embedded in tests
	# or tools (not the current scene) the fixed seeds keep runs reproducible.
	if get_tree().current_scene == self:
		randomize_seeds()
	reset_play()


func randomize_seeds() -> void:
	for r in [ball.rng, possession.rng, passing.rng, tackles.rng]:
		r.randomize()
	for c in [team_control, opp_control]:
		if c and c.attack_ai:
			c.attack_ai.rng.randomize()


## Player node for the old single-player API (sandbox mode / tests).
func controlled_player() -> RugbyPlayer:
	return team_control.controlled


func reset_play() -> void:
	possession.clear_cooldowns()
	tackles.clear()
	for p in team.players + opp.players:
		p.reset_to(lineup_spots[p], p.team.attack())
		p.set_role(RugbyPlayer.Role.NEUTRAL)
	if solo:
		ball.spawn_loose(SANDBOX_BALL_SPOT, Vector3.ZERO)
	else:
		ball.attach(team.players[0])
	team_control.set_controlled(team.players[0])
	if autoplay:
		camera.target = team.players[0]
		hud.player = team.players[0]
		debug_overlay.player = team.players[0]
	_possession_team = team if not solo else null
	camera.snap()


func _load_team(t: Team, path: String) -> Dictionary:
	var data := JsonLoader.load_dict(path)
	t.name = String(data.get("name", "Team"))
	t.attack_dir = signf(float(data.get("attack_dir", 1.0)))
	if t.attack_dir == 0.0:
		t.attack_dir = 1.0
	return data


func _spawn_team(t: Team, data: Dictionary, roster: Array[PlayerProfile], entries: Array, prefix: String) -> void:
	if entries.is_empty():
		entries = [{"number": roster[0].number, "pos": [0.0, 0.0]}]
	for e in entries:
		var profile := _profile_by_number(roster, int(e.get("number", 0)))
		var p := RugbyPlayer.new()
		p.name = prefix if prefix == "Player" else "%s%d" % [prefix, profile.number]
		p.setup(profile, tuning)
		p.team = t
		_apply_kit(p, data)
		add_child(p)
		var visual := PlayerVisual.new()
		visual.name = "Visual"
		visual.player = p
		p.add_child(visual)
		var pos: Array = e.get("pos", [0.0, 0.0])
		lineup_spots[p] = Vector3(float(pos[0]), 0.0, float(pos[1]))
		t.players.append(p)


func _profile_by_number(roster: Array[PlayerProfile], n: int) -> PlayerProfile:
	for i in roster.size():
		if roster[i].number == n:
			if roster == squad:
				_profile_index = i
			return roster[i]
	push_warning("No squad player with number %d; using %s" % [n, roster[0].display_name])
	return roster[0]


func _on_tackle(_tackler: RugbyPlayer, carrier: RugbyPlayer, r: TackleModel.Result) -> void:
	match r.outcome:
		TackleModel.Outcome.BROKEN:
			hud.notify("TACKLE BROKEN", Color("#7cff6b") if carrier.team == team else Color("#ff8a8f"), 0.9)
		TackleModel.Outcome.DOMINANT:
			hud.notify("BIG HIT", Color("#ffd23f"), 0.9)
			camera.shake(0.6)
		_:
			camera.shake(0.25)
	if r.spill:
		hud.notify("KNOCK-ON", Color("#f5a524"), 1.0)


## Turnover notices (who had the ball last vs. who has it now).
func _on_carrier_changed_notice(_old: RugbyPlayer, new: RugbyPlayer) -> void:
	if new == null or new.team == null:
		return
	if _possession_team != null and new.team != _possession_team:
		if new.team == opp:
			hud.notify("INTERCEPTED" if possession.last_gain == &"catch" else "TURNOVER", Color("#ff5a5f"), 1.2)
		else:
			hud.notify("TURNOVER WON", Color("#7cff6b"), 1.2)
	_possession_team = new.team


func _on_controlled_changed(_old: RugbyPlayer, new: RugbyPlayer) -> void:
	camera.target = new
	hud.player = new
	debug_overlay.player = new


func _unhandled_input(event: InputEvent) -> void:
	var player := team_control.controlled
	if event.is_action_pressed("camera_toggle"):
		camera.toggle_mode()
	elif event.is_action_pressed("dev_debug_overlay"):
		debug_overlay.toggle()
	elif event.is_action_pressed("dev_sandbox"):
		sandbox_mode = not solo
		get_tree().reload_current_scene()
	elif event.is_action_pressed("dev_reset_player"):
		reset_play()
	elif event.is_action_pressed("dev_go_to_ground"):
		player.go_to_ground()
	elif event.is_action_pressed("dev_cycle_role"):
		# Possession owns BALL_CARRIER; this only toggles neutral <-> defender.
		if player.role != RugbyPlayer.Role.BALL_CARRIER:
			player.set_role(RugbyPlayer.Role.DEFENDER if player.role == RugbyPlayer.Role.NEUTRAL else RugbyPlayer.Role.NEUTRAL)
	elif event.is_action_pressed("dev_next_profile"):
		_profile_index = (_profile_index + 1) % squad.size()
		player.set_profile(squad[_profile_index])
	elif event.is_action_pressed("dev_drop_ball"):
		possession.drop(player)
	elif event.is_action_pressed("dev_toss_ball"):
		toss_ball_to_player()
	elif event.is_action_pressed("dev_reload_tuning"):
		reload_tuning()


func reload_tuning() -> void:
	tuning = MovementTuning.load_default()
	ball_tuning = BallTuning.load_default()
	pass_tuning = PassingTuning.load_default()
	support_tuning = SupportTuning.load_default()
	for p in team.players + opp.players:
		p.set_tuning(tuning)
	ball.set_tuning(ball_tuning)
	possession.tuning = ball_tuning
	possession.pass_tuning = pass_tuning
	passing.tuning = pass_tuning
	defence_tuning = DefenceTuning.load_default()
	tackle_tuning = TackleTuning.load_default()
	tackles.tuning = tackle_tuning
	ai_tuning = AITuning.load_default()
	for p in team.players + opp.players:
		p.contact = tackle_tuning
	for c in [team_control, opp_control]:
		if c:
			c.support = support_tuning
			c.defence = defence_tuning
			c.configure_ai(c.style, ai_tuning, tackle_tuning, c.ai_level)
	print("Tuning reloaded (movement, ball, passing, support, defence)")


## Dev: bounce a loose ball toward the controlled player from ~12 m ahead.
func toss_ball_to_player() -> void:
	var player := team_control.controlled
	var f := player.facing
	var from := player.planar_position() + f * 12.0
	from.x = clampf(from.x, -FieldDimensions.HALF_LENGTH + 3.0, FieldDimensions.HALF_LENGTH - 3.0)
	from.y = clampf(from.y, -FieldDimensions.HALF_WIDTH + 3.0, FieldDimensions.HALF_WIDTH - 3.0)
	var dir := (player.planar_position() - from).normalized()
	ball.spawn_loose(Vector3(from.x, 1.6, from.y), Vector3(dir.x * 5.0, 3.5, dir.y * 5.0))


func _on_ball_dead(zone: FieldDimensions.Zone, point: Vector3) -> void:
	var label := "TOUCH"
	match zone:
		FieldDimensions.Zone.TOUCH_IN_GOAL:
			label = "TOUCH IN GOAL"
		FieldDimensions.Zone.DEAD:
			label = "DEAD BALL"
	hud.notify(label, Color.WHITE, ball_tuning.dead_ball_restart_delay)
	# Dev restart: put the ball back in play near where it went out.
	# Real restarts (lineout, 22 drop-out, scrum) arrive in M11/M13/M14.
	_restart_timer = get_tree().create_timer(ball_tuning.dead_ball_restart_delay, true, true)
	_restart_timer.timeout.connect(func():
		if ball.state != RugbyBall.State.DEAD:
			return
		var x := clampf(point.x, -FieldDimensions.HALF_LENGTH + 5.0, FieldDimensions.HALF_LENGTH - 5.0)
		var z := clampf(point.z, -FieldDimensions.HALF_WIDTH + 5.0, FieldDimensions.HALF_WIDTH - 5.0)
		ball.spawn_loose(Vector3(x, ball_tuning.radius, z), Vector3.ZERO))


func _apply_kit(p: RugbyPlayer, data: Dictionary) -> void:
	var kit: Dictionary = data.get("kit", {})
	for key in ["jersey", "shorts", "socks", "indicator"]:
		if kit.has(key):
			p.team_colors[key] = Color(String(kit[key]))
