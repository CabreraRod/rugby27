extends Node3D
## Milestone 01 match scene: builds the world and wires one human-controlled
## player. This is composition only — no gameplay rules live here.
##
## Later, a MatchDirector (phases, clock, score) replaces this bootstrap.

const SQUAD_PATH := "res://data/players/dev_squad.json"
const TEAM_PATH := "res://data/teams/dev_team.json"
const KICKOFF_SPOT := Vector3(0.0, 0.0, 0.0)

var tuning: MovementTuning
var squad: Array[PlayerProfile] = []
var player: RugbyPlayer
var camera: BroadcastCamera
var controller: HumanController
var hud: MatchHud
var debug_overlay: DebugOverlay

var _profile_index := 0


func _ready() -> void:
	tuning = MovementTuning.load_default()
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

	camera = BroadcastCamera.new()
	camera.name = "BroadcastCamera"
	add_child(camera)
	camera.target = player
	camera.current = true
	camera.snap()

	controller = HumanController.new()
	controller.name = "HumanController"
	controller.player = player
	controller.camera = camera
	add_child(controller)

	hud = MatchHud.new()
	hud.player = player
	add_child(hud)

	debug_overlay = DebugOverlay.new()
	debug_overlay.player = player
	add_child(debug_overlay)
	debug_overlay.attach_world(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle"):
		camera.toggle_mode()
	elif event.is_action_pressed("dev_debug_overlay"):
		debug_overlay.toggle()
	elif event.is_action_pressed("dev_reset_player"):
		player.reset_to(KICKOFF_SPOT, player.facing)
		camera.snap()
	elif event.is_action_pressed("dev_go_to_ground"):
		player.go_to_ground()
	elif event.is_action_pressed("dev_cycle_role"):
		player.set_role(((player.role + 1) % RugbyPlayer.Role.size()) as RugbyPlayer.Role)
	elif event.is_action_pressed("dev_next_profile"):
		_profile_index = (_profile_index + 1) % squad.size()
		player.set_profile(squad[_profile_index])
	elif event.is_action_pressed("dev_reload_tuning"):
		tuning = MovementTuning.load_default()
		player.set_tuning(tuning)
		print("Movement tuning reloaded from %s" % MovementTuning.DEFAULT_PATH)


func _apply_kit(p: RugbyPlayer) -> void:
	var team := JsonLoader.load_dict(TEAM_PATH)
	var kit: Dictionary = team.get("kit", {})
	for key in ["jersey", "shorts", "socks", "indicator"]:
		if kit.has(key):
			p.team_colors[key] = Color(String(kit[key]))
