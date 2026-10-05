extends Node3D
## Development match scene: builds the world, one team from data, the ball
## and the systems that connect them. Composition only — no gameplay rules.
##
## Two modes:
##   * Team (default): the lineup from data/teams/dev_team.json, ball in the
##     scrum-half's hands, passing live.
##   * Sandbox (F2 / D-pad up): one player and a loose ball — for movement
##     tuning and pickup practice. F2 reloads the scene in the other mode.
##
## Later, a MatchDirector (phases, clock, score, restarts) replaces this.

const SQUAD_PATH := "res://data/players/dev_squad.json"
const TEAM_PATH := "res://data/teams/dev_team.json"
const SANDBOX_SPOT := Vector3(0.0, 0.0, 0.0)
const SANDBOX_BALL_SPOT := Vector3(6.0, 0.11, 0.0)
const SANDBOX_NUMBER := 10

## Survives scene reloads so F2 toggles between modes.
static var sandbox_mode := false

## Set before adding to the tree to force a mode (tests). Defaults to sandbox_mode.
var solo := sandbox_mode

var tuning: MovementTuning
var ball_tuning: BallTuning
var pass_tuning: PassingTuning
var support_tuning: SupportTuning
var squad: Array[PlayerProfile] = []
var team := Team.new()
var team_data := {}
## Start positions, parallel to team.players.
var lineup_spots: Array[Vector3] = []

var ball: RugbyBall
var possession: PossessionController
var passing: PassingSystem
var team_control: TeamControl
var camera: BroadcastCamera
var human: HumanController
var hud: MatchHud
var debug_overlay: DebugOverlay

var _profile_index := 0
var _restart_timer: SceneTreeTimer


func _ready() -> void:
	tuning = MovementTuning.load_default()
	ball_tuning = BallTuning.load_default()
	pass_tuning = PassingTuning.load_default()
	support_tuning = SupportTuning.load_default()
	squad = PlayerProfile.load_squad(SQUAD_PATH)
	if squad.is_empty():
		squad.append(PlayerProfile.from_dict({"name": "Fallback", "number": 1}))
	team_data = JsonLoader.load_dict(TEAM_PATH)
	team.name = String(team_data.get("name", "Team"))
	team.attack_dir = signf(float(team_data.get("attack_dir", 1.0)))
	if team.attack_dir == 0.0:
		team.attack_dir = 1.0

	StadiumEnvironment.build(self)
	FieldBuilder.build(self)
	_spawn_players()

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
	possession.setup(ball, ball_tuning, team.players)
	possession.pass_tuning = pass_tuning
	add_child(possession)

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

	team_control = TeamControl.new()
	team_control.name = "TeamControl"
	team_control.setup(team, ball, passing, human, support_tuning)
	add_child(team_control)

	hud = MatchHud.new()
	hud.ball = ball
	add_child(hud)

	debug_overlay = DebugOverlay.new()
	debug_overlay.ball = ball
	debug_overlay.possession = possession
	debug_overlay.passing = passing
	debug_overlay.team_control = team_control
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
	passing.pass_thrown.connect(func(_p, _r, forward: bool):
		if forward:
			hud.notify("FORWARD PASS", Color("#ff5a5f"), 1.2))

	reset_play()


## Player node for the old single-player API (sandbox mode / tests).
func controlled_player() -> RugbyPlayer:
	return team_control.controlled


func reset_play() -> void:
	possession.clear_cooldowns()
	for i in team.players.size():
		team.players[i].reset_to(lineup_spots[i], team.attack())
	if solo:
		ball.spawn_loose(SANDBOX_BALL_SPOT, Vector3.ZERO)
	else:
		ball.attach(team.players[0])
	team_control.set_controlled(team.players[0])
	camera.snap()


func _spawn_players() -> void:
	var entries: Array = []
	if solo:
		entries = [{"number": SANDBOX_NUMBER, "pos": [SANDBOX_SPOT.x, SANDBOX_SPOT.z]}]
	else:
		entries = team_data.get("lineup", [])
		if entries.is_empty():
			entries = [{"number": SANDBOX_NUMBER, "pos": [0.0, 0.0]}]
	for e in entries:
		var profile := _profile_by_number(int(e.get("number", 0)))
		var p := RugbyPlayer.new()
		p.name = "Player" if solo else "P%d" % profile.number
		p.setup(profile, tuning)
		p.team = team
		_apply_kit(p)
		add_child(p)
		var visual := PlayerVisual.new()
		visual.name = "Visual"
		visual.player = p
		p.add_child(visual)
		var pos: Array = e.get("pos", [0.0, 0.0])
		lineup_spots.append(Vector3(float(pos[0]), 0.0, float(pos[1])))
		team.players.append(p)


func _profile_by_number(n: int) -> PlayerProfile:
	for i in squad.size():
		if squad[i].number == n:
			_profile_index = i
			return squad[i]
	push_warning("No squad player with number %d; using %s" % [n, squad[0].display_name])
	return squad[0]


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
	for p in team.players:
		p.set_tuning(tuning)
	ball.set_tuning(ball_tuning)
	possession.tuning = ball_tuning
	possession.pass_tuning = pass_tuning
	passing.tuning = pass_tuning
	team_control.support = support_tuning
	print("Tuning reloaded (movement, ball, passing, support)")


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


func _apply_kit(p: RugbyPlayer) -> void:
	var kit: Dictionary = team_data.get("kit", {})
	for key in ["jersey", "shorts", "socks", "indicator"]:
		if kit.has(key):
			p.team_colors[key] = Color(String(kit[key]))
