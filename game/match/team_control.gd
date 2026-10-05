class_name TeamControl
extends Node
## Each physics tick (before players move): gives every player of the human
## team an intent — the controlled one from the HumanController, the others
## from SupportRunner — and turns pass button presses into PassingSystem calls.
##
## Control follows the ball: it moves to the intended receiver the moment a
## pass is released (so you can run onto it), and to anyone in the team who
## gathers the ball.

signal controlled_changed(old: RugbyPlayer, new: RugbyPlayer)

## Tests switch this off to drive players directly.
var active := true
var team: Team
var ball: RugbyBall
var passing: PassingSystem
var human: HumanController
var support: SupportTuning
var controlled: RugbyPlayer
## Debug: current slot of every runner.
var slots := {}
## True while a pass charge was started by a button press (only those are
## released by letting go; charges started from code keep their own timing).
var _input_charge := false

const PASS_ACTIONS := ["pass_left", "pass_right"]


func setup(p_team: Team, p_ball: RugbyBall, p_passing: PassingSystem, p_human: HumanController, p_support: SupportTuning) -> void:
	team = p_team
	ball = p_ball
	passing = p_passing
	human = p_human
	support = p_support
	ball.carrier_changed.connect(_on_carrier_changed)
	passing.pass_thrown.connect(_on_pass_thrown)


func _ready() -> void:
	process_physics_priority = -10


func set_controlled(p: RugbyPlayer) -> void:
	if p == controlled:
		return
	var old := controlled
	if old:
		old.is_controlled = false
	controlled = p
	if p:
		p.is_controlled = true
	controlled_changed.emit(old, p)


func _physics_process(_delta: float) -> void:
	if not active or team == null:
		return
	_drive_players()
	_read_pass_input()


func _drive_players() -> void:
	var anchor := _anchor()
	var anchor_pos: Vector2 = anchor[0]
	var anchor_vel: Vector2 = anchor[1]
	var anchor_player: RugbyPlayer = anchor[2]

	var runners: Array[RugbyPlayer] = []
	for p in team.players:
		if p != controlled and p != anchor_player:
			runners.append(p)
	slots = SupportRunner.assign_slots(anchor_pos, team, runners, support)

	for p in team.players:
		var it: SupportRunner.Intent
		if p == controlled:
			it = human.read_intent() if human else SupportRunner.Intent.new()
			if passing.is_receiver_in_flight(p):
				it = SupportRunner.receiver_assist(it, p.planar_velocity, p.stats.jog_top, support)
		elif p == anchor_player:
			it = SupportRunner.hold_course(p.planar_velocity, p.stats.jog_top)
		elif slots.has(p):
			it = SupportRunner.steer(p.planar_position(), slots[p], anchor_vel, p.stats.jog_top, support)
		else:
			it = SupportRunner.Intent.new()
		p.set_intent(it.dir, it.mag, it.sprint, it.speed)


## [position, velocity, player-or-null] the support line forms around.
func _anchor() -> Array:
	if passing.in_flight and passing.flight_receiver and team.has(passing.flight_receiver):
		var r := passing.flight_receiver
		return [r.planar_position(), r.planar_velocity, r]
	if ball.carrier and team.has(ball.carrier):
		return [ball.carrier.planar_position(), ball.carrier.planar_velocity, ball.carrier]
	var b := ball.global_position
	return [Vector2(b.x, b.z), Vector2.ZERO, null]


func _read_pass_input() -> void:
	if controlled == null or ball.carrier != controlled:
		return
	for i in PASS_ACTIONS.size():
		if Input.is_action_just_pressed(PASS_ACTIONS[i]) and not passing.charging:
			passing.begin(controlled, i)
			_input_charge = passing.charging
	if not passing.charging:
		_input_charge = false
	elif _input_charge and passing.charge_passer == controlled:
		if not Input.is_action_pressed(PASS_ACTIONS[passing.charge_side]):
			_input_charge = false
			passing.release()


func _on_pass_thrown(_passer: RugbyPlayer, receiver: RugbyPlayer, _forward: bool) -> void:
	if receiver and team.has(receiver):
		set_controlled(receiver)


func _on_carrier_changed(_old: RugbyPlayer, new: RugbyPlayer) -> void:
	if new and team.has(new):
		set_controlled(new)
