class_name PassingSystem
extends Node
## Executes passes: charge (tap/hold), receiver selection, flight solving,
## accuracy, forward-pass detection. Tracks the pass in flight.
##
## It never decides catches — PossessionController does, using
## `intended_receiver` for a slightly larger catch reach.
## Input lives in TeamControl; this node has a plain API (begin/release/
## throw_to) so tests and, later, AI can pass the same way.

signal charge_started(passer: RugbyPlayer, side: int)
signal pass_thrown(passer: RugbyPlayer, receiver: RugbyPlayer, forward: bool)
signal pass_completed(passer: RugbyPlayer, receiver: RugbyPlayer)
signal pass_ended(passer: RugbyPlayer)

var tuning: PassingTuning
var ball: RugbyBall
var possession: PossessionController
var rng := RandomNumberGenerator.new()

# Charging (button held).
var charging := false
var charge_side := PassTargeting.LEFT
var charge_time := 0.0
var charge_passer: RugbyPlayer

# Pass in flight.
var in_flight := false
var flight_passer: RugbyPlayer
var flight_receiver: RugbyPlayer
var flight_forward := false
var flight_forward_speed := 0.0
var flight_release_pos := Vector3.ZERO
var flight_aim := Vector3.ZERO
var flight_time := 0.0
var _flight_timer := 0.0

var _gravity := 9.8


func setup(p_ball: RugbyBall, p_possession: PossessionController, p_tuning: PassingTuning, seed_value: int = 4) -> void:
	ball = p_ball
	possession = p_possession
	tuning = p_tuning
	rng.seed = seed_value
	ball.carrier_changed.connect(_on_carrier_changed)
	ball.bounced.connect(func(_s, _d, _u): _end_flight())
	ball.went_dead.connect(func(_z, _p): _end_flight())


func _ready() -> void:
	process_physics_priority = -9   # right after TeamControl reads input
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _physics_process(delta: float) -> void:
	if charging:
		if ball.carrier != charge_passer or not charge_passer.is_controllable():
			charging = false
		else:
			charge_time += delta
			if charge_time >= tuning.max_hold_time:
				release()
	if in_flight:
		possession.pass_age += delta
		_flight_timer -= delta
		if _flight_timer <= 0.0:
			_end_flight()


# --- Input-level API ---------------------------------------------------------

func begin(passer: RugbyPlayer, side: int) -> void:
	if charging or ball.carrier != passer or not passer.is_controllable():
		return
	charging = true
	charge_side = side
	charge_time = 0.0
	charge_passer = passer
	charge_started.emit(passer, side)


## Button released (or max hold reached): throw.
func release() -> void:
	if not charging:
		return
	charging = false
	if ball.carrier != charge_passer:
		return
	throw(charge_passer, charge_side, is_long_charge())


## True once the current (or last) charge was held long enough for a skip pass.
func is_long_charge() -> bool:
	return charge_time >= tuning.skip_hold_time


# --- Pass API ------------------------------------------------------------------

## The receiver a pass to `side` would go to right now (null = into space).
func preview(passer: RugbyPlayer, side: int, long: bool) -> RugbyPlayer:
	if passer.team == null:
		return null
	var mates := passer.team.teammates_of(passer)
	var pos: Array[Vector2] = []
	for m in mates:
		pos.append(m.planar_position())
	var sv := PassTargeting.side_vector(passer.team.left(), side)
	var i := PassTargeting.select(passer.planar_position(), passer.team.attack(), sv, pos, long, tuning)
	return mates[i] if i >= 0 else null


func throw(passer: RugbyPlayer, side: int, long: bool) -> void:
	if passer == null:
		return
	throw_to(passer, preview(passer, side, long), side, long)


## Core: throw to a specific receiver (or into space when null).
func throw_to(passer: RugbyPlayer, receiver: RugbyPlayer, side: int, long: bool) -> void:
	if passer == null or ball.carrier != passer:
		return
	var team := passer.team
	var attack := team.attack() if team else Vector2.RIGHT
	var left := team.left() if team else Vector2(0, -1)
	var sv := PassTargeting.side_vector(left, side)
	var skill := passer.profile.attributes.norm("passing")
	var speed := lerpf(tuning.long_speed_min, tuning.long_speed_max, skill) if long else lerpf(tuning.quick_speed_min, tuning.quick_speed_max, skill)
	var p0 := ball.global_position

	var plan: PassSolver.Plan
	if receiver:
		plan = PassSolver.intercept(p0, receiver.planar_position(), receiver.planar_velocity, speed, tuning)
	else:
		var spot := passer.planar_position() + sv * tuning.space_pass_lateral - attack * tuning.space_pass_back
		plan = PassSolver.intercept(p0, spot, passer.planar_velocity, speed, tuning)

	var speed_ratio := passer.current_speed() / maxf(passer.stats.sprint_top, 0.1)
	var sd := PassSolver.error_sd(skill, long, speed_ratio, tuning)
	var aim := plan.aim + PassSolver.error_offset(rng, sd, attack, sv)
	var v := PassSolver.ballistic(p0, aim, plan.flight_time, ball.tuning.air_damp, _gravity)

	flight_forward_speed = PassSolver.forward_speed(v, passer.planar_velocity, attack)
	flight_forward = flight_forward_speed > tuning.forward_tolerance
	flight_passer = passer
	flight_receiver = receiver
	flight_release_pos = p0
	flight_aim = aim
	flight_time = plan.flight_time

	possession.set_cooldown(passer, tuning.passer_cooldown)
	possession.intended_receiver = receiver
	possession.pass_age = 0.0
	passer.play_action(&"pass_left" if side == PassTargeting.LEFT else &"pass_right", 0.3)
	ball.release(v, &"pass")
	# Set after release(): release() clears any previous flight via carrier_changed.
	in_flight = true
	_flight_timer = plan.flight_time + tuning.pass_timeout_margin
	pass_thrown.emit(passer, receiver, flight_forward)


func is_receiver_in_flight(p: RugbyPlayer) -> bool:
	return in_flight and flight_receiver == p


func _on_carrier_changed(_old: RugbyPlayer, new: RugbyPlayer) -> void:
	if new == null or not in_flight:
		return
	if new == flight_receiver:
		pass_completed.emit(flight_passer, new)
	_end_flight()


func _end_flight() -> void:
	if not in_flight:
		return
	in_flight = false
	possession.intended_receiver = null
	pass_ended.emit(flight_passer)
