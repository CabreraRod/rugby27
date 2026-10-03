extends Node3D
## Development match scene: builds the world and wires one human-controlled
## player and the ball. Composition only — no gameplay rules live here.
##
## Later, a MatchDirector (phases, clock, score, restarts) replaces this.

const SQUAD_PATH := "res://data/players/dev_squad.json"
const TEAM_PATH := "res://data/teams/dev_team.json"
const KICKOFF_SPOT := Vector3(0.0, 0.0, 0.0)
const BALL_SPOT := Vector3(6.0, 0.11, 0.0)

var tuning: MovementTuning
var ball_tuning: BallTuning
var squad: Array[PlayerProfile] = []
var player: RugbyPlayer
var ball: RugbyBall
var possession: PossessionController
var camera: BroadcastCamera
var controller: HumanController
var hud: MatchHud
var debug_overlay: DebugOverlay

var _profile_index := 0
var _restart_timer: SceneTreeTimer


func _ready() -> void:
	tuning = MovementTuning.load_default()
	ball_tuning = BallTuning.load_default()
	squad = PlayerProfile.load_squad(SQUAD_PATH)
	if squad.is_empty():
		squad.append(PlayerProfile.from_dict({"name": "Fallback", "number": 1}))

	StadiumEnvironment.build(self)
	FieldBuilder.build(self)

	player = RugbyPlayer.new()
	player.name = "Player"
	player.setup(squad[_profile_index], tuning)
	_apply_kit(player)
	add_child(player)
	var visual := PlayerVisual.new()
	visual.name = "Visual"
	visual.player = player
	player.add_child(visual)
	player.reset_to(KICKOFF_SPOT)

	ball = RugbyBall.new()
	ball.name = "Ball"
	ball.setup(ball_tuning)
	add_child(ball)
	var ball_visual := BallVisual.new()
	ball_visual.name = "Visual"
	ball_visual.ball = ball
	ball.add_child(ball_visual)
	ball.spawn_loose(BALL_SPOT, Vector3.ZERO)
	ball.went_dead.connect(_on_ball_dead)

	possession = PossessionController.new()
	possession.name = "Possession"
	var roster: Array[RugbyPlayer] = [player]
	possession.setup(ball, ball_tuning, roster)
	add_child(possession)

	camera = BroadcastCamera.new()
	camera.name = "BroadcastCamera"
	add_child(camera)
	camera.target = player
	camera.ball = ball
	camera.current = true
	camera.snap()

	controller = HumanController.new()
	controller.name = "HumanController"
	controller.player = player
	controller.camera = camera
	add_child(controller)

	hud = MatchHud.new()
	hud.player = player
	hud.ball = ball
	add_child(hud)
	possession.pickup_failed.connect(func(_p, _c): hud.notify("FUMBLED", Color("#f5a524"), 0.9))

	debug_overlay = DebugOverlay.new()
	debug_overlay.player = player
	debug_overlay.ball = ball
	debug_overlay.possession = possession
	add_child(debug_overlay)
	debug_overlay.attach_world(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle"):
		camera.toggle_mode()
	elif event.is_action_pressed("dev_debug_overlay"):
		debug_overlay.toggle()
	elif event.is_action_pressed("dev_reset_player"):
		player.reset_to(KICKOFF_SPOT, player.facing)
		ball.spawn_loose(BALL_SPOT, Vector3.ZERO)
		camera.snap()
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
		tuning = MovementTuning.load_default()
		player.set_tuning(tuning)
		ball_tuning = BallTuning.load_default()
		ball.set_tuning(ball_tuning)
		possession.tuning = ball_tuning
		print("Tuning reloaded (movement + ball)")


## Dev: bounce a loose ball toward the player from ~12 m ahead (pickup practice).
func toss_ball_to_player() -> void:
	var f := player.facing
	var from := Vector2(player.global_position.x, player.global_position.z) + f * 12.0
	from.x = clampf(from.x, -FieldDimensions.HALF_LENGTH + 3.0, FieldDimensions.HALF_LENGTH - 3.0)
	from.y = clampf(from.y, -FieldDimensions.HALF_WIDTH + 3.0, FieldDimensions.HALF_WIDTH - 3.0)
	var to := Vector2(player.global_position.x, player.global_position.z)
	var dir := (to - from).normalized()
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
	var team := JsonLoader.load_dict(TEAM_PATH)
	var kit: Dictionary = team.get("kit", {})
	for key in ["jersey", "shorts", "socks", "indicator"]:
		if kit.has(key):
			p.team_colors[key] = Color(String(kit[key]))
