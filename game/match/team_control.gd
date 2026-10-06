class_name TeamControl
extends Node
## Drives one team every physics tick (before players move).
##
## Phase (from this team's point of view):
##   ATTACK — we have the ball (or our pass is in the air): controlled
##            player from the human (or AttackBrain for the AI team), the
##            rest run support lines (SupportRunner).
##   DEFEND — they have it: the human keeps their defender, the rest form
##            the DefensiveLine.
##   LOOSE  — nobody has it: nearest non-controlled player chases it, the
##            rest hold support slots around the ball.
##
## Human team only: pass buttons pass when you carry and switch player when
## you defend; control follows the ball on our side and jumps to the
## nearest player to the ball on a turnover. A team with human == null is
## fully AI.

signal controlled_changed(old: RugbyPlayer, new: RugbyPlayer)

enum Phase { ATTACK, DEFEND, LOOSE }

## Tests switch this off to drive players directly.
var active := true
var team: Team
var opponents: Team
var ball: RugbyBall
var passing: PassingSystem
var possession: PossessionController
var human: HumanController
var support: SupportTuning
var defence: DefenceTuning
var controlled: RugbyPlayer
var phase: Phase = Phase.LOOSE

## Debug views.
var slots := {}
var assignments: Array[DefensiveLine.Assignment] = []
var chaser: RugbyPlayer

## True while a pass charge was started by a button press (only those are
## released by letting go; charges started from code keep their own timing).
var _input_charge := false
var _held_time := 0.0

const PASS_ACTIONS := ["pass_left", "pass_right"]


func setup(p_team: Team, p_opponents: Team, p_ball: RugbyBall, p_passing: PassingSystem, p_possession: PossessionController, p_human: HumanController, p_support: SupportTuning, p_defence: DefenceTuning) -> void:
	team = p_team
	opponents = p_opponents
	ball = p_ball
	passing = p_passing
	possession = p_possession
	human = p_human
	support = p_support
	defence = p_defence
	ball.carrier_changed.connect(_on_carrier_changed)
	passing.pass_thrown.connect(_on_pass_thrown)


func _ready() -> void:
	process_physics_priority = -10


func is_human() -> bool:
	return human != null


func set_controlled(p: RugbyPlayer) -> void:
	if p == controlled or not is_human():
		return
	var old := controlled
	if old:
		old.is_controlled = false
	controlled = p
	if p:
		p.is_controlled = true
	controlled_changed.emit(old, p)


func _physics_process(delta: float) -> void:
	if not active or team == null:
		return
	phase = _phase()
	if ball.carrier and team.has(ball.carrier):
		_held_time += delta
	else:
		_held_time = 0.0
	match phase:
		Phase.ATTACK:
			_drive_attack()
		Phase.DEFEND:
			_drive_defence()
		Phase.LOOSE:
			_drive_loose()
	if is_human():
		_read_buttons()


func _phase() -> Phase:
	if passing.in_flight and passing.flight_passer:
		return Phase.ATTACK if team.has(passing.flight_passer) else Phase.DEFEND
	if ball.carrier:
		return Phase.ATTACK if team.has(ball.carrier) else Phase.DEFEND
	return Phase.LOOSE


# --- Attack ----------------------------------------------------------------------

func _drive_attack() -> void:
	assignments.clear()
	chaser = null
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
		if p.role == RugbyPlayer.Role.DEFENDER:
			p.set_role(RugbyPlayer.Role.NEUTRAL)
		var it: SupportRunner.Intent
		if p == controlled:
			it = human.read_intent()
			if passing.is_receiver_in_flight(p):
				it = SupportRunner.receiver_assist(it, p.planar_velocity, p.stats.jog_top, support)
		elif p == anchor_player:
			if p == ball.carrier and not is_human():
				it = _ai_carry(p)
			else:
				it = SupportRunner.hold_course(p.planar_velocity, p.stats.jog_top)
		elif slots.has(p):
			it = SupportRunner.steer(p.planar_position(), slots[p], anchor_vel, p.stats.jog_top, support)
		else:
			it = SupportRunner.Intent.new()
		_apply(p, it)


func _ai_carry(p: RugbyPlayer) -> SupportRunner.Intent:
	var defenders: Array[RugbyPlayer] = []
	if opponents:
		defenders = opponents.players
	if p.contact and AttackBrain.wants_fend(p, defenders, team.attack(), p.contact.ai_fend_dist):
		p.try_fend()
	var side := AttackBrain.choose_pass(p, passing, defenders, _held_time, defence)
	if side >= 0 and not passing.charging:
		passing.throw(p, side, false)
	return AttackBrain.carry(p, defenders, team.attack(), defence)


## [position, velocity, player-or-null] the support line forms around.
func _anchor() -> Array:
	if passing.in_flight and passing.flight_receiver and team.has(passing.flight_receiver):
		var r := passing.flight_receiver
		return [r.planar_position(), r.planar_velocity, r]
	if ball.carrier and team.has(ball.carrier):
		return [ball.carrier.planar_position(), ball.carrier.planar_velocity, ball.carrier]
	var b := ball.global_position
	return [Vector2(b.x, b.z), Vector2.ZERO, null]


# --- Defence ---------------------------------------------------------------------

func _drive_defence() -> void:
	slots.clear()
	chaser = null
	var ai_defenders: Array[RugbyPlayer] = []
	for p in team.players:
		if p != controlled:
			ai_defenders.append(p)
	var attack := opponents.attack() if opponents else -team.attack()
	var carrier: RugbyPlayer = null
	if ball.carrier and opponents.has(ball.carrier):
		carrier = ball.carrier
	elif passing.in_flight and passing.flight_receiver and opponents.has(passing.flight_receiver):
		carrier = passing.flight_receiver   # mark the receiver as the new carrier
	var b := ball.global_position
	assignments = DefensiveLine.assign(ai_defenders, controlled, opponents.players, carrier, Vector2(b.x, b.z), attack, defence)
	for a in assignments:
		var it := SupportRunner.steer_to(a.defender.planar_position(), a.target, a.feed, a.defender.stats.jog_top, defence.gain, defence.settle_dist)
		_apply(a.defender, it)
		a.defender.set_role(RugbyPlayer.Role.DEFENDER)
	if controlled:
		_apply(controlled, human.read_intent())
		controlled.set_role(RugbyPlayer.Role.DEFENDER)
		# Don't leave the human on a player lying on the floor.
		if controlled.state == RugbyPlayer.State.GROUNDED and controlled.planar_position().distance_to(Vector2(b.x, b.z)) > 3.0:
			switch_to_nearest_ball(true)


# --- Loose ball --------------------------------------------------------------------

func _drive_loose() -> void:
	assignments.clear()
	var b := Vector2(ball.global_position.x, ball.global_position.z)
	# Nearest non-controlled player chases the ball.
	chaser = null
	var best_d := INF
	for p in team.players:
		if p == controlled or not p.is_controllable():
			continue
		var d := p.planar_position().distance_to(b)
		if d < best_d:
			best_d = d
			chaser = p
	var runners: Array[RugbyPlayer] = []
	for p in team.players:
		if p != controlled and p != chaser:
			runners.append(p)
	slots = SupportRunner.assign_slots(b, team, runners, support)
	# Our tackled player can't play the ball: give the human the nearest
	# player on their feet (the M08 ruck will bring the scrum-half in).
	if is_human() and controlled and not controlled.is_controllable() and possession.protected_team == team:
		switch_to_nearest_ball(true)
	for p in team.players:
		if p.role == RugbyPlayer.Role.DEFENDER:
			p.set_role(RugbyPlayer.Role.NEUTRAL)
		var it: SupportRunner.Intent
		if p == controlled:
			it = human.read_intent()
		elif p == chaser:
			var bv := ball.ball_velocity()
			it = SupportRunner.steer_to(p.planar_position(), b, Vector2(bv.x, bv.z), p.stats.jog_top, 3.0, 0.0)
			it.sprint = true
			it.mag = 1.0
		elif slots.has(p):
			it = SupportRunner.steer(p.planar_position(), slots[p], Vector2.ZERO, p.stats.jog_top, support)
		else:
			it = SupportRunner.Intent.new()
		_apply(p, it)


func _apply(p: RugbyPlayer, it: SupportRunner.Intent) -> void:
	p.set_intent(it.dir, it.mag, it.sprint, it.speed)


# --- Human buttons -------------------------------------------------------------------

func _read_buttons() -> void:
	if controlled == null:
		return
	if ball.carrier == controlled:
		_read_pass_input()
		if Input.is_action_just_pressed("fend"):
			controlled.try_fend()
		if Input.is_action_just_pressed("sidestep_left"):
			controlled.try_sidestep(-1.0)
		elif Input.is_action_just_pressed("sidestep_right"):
			controlled.try_sidestep(1.0)
		return
	_input_charge = false
	if Input.is_action_just_pressed("dive_tackle") and phase == Phase.DEFEND:
		controlled.try_dive()
	# Not carrying: the pass buttons switch to the teammate nearest the ball.
	for i in PASS_ACTIONS.size():
		if Input.is_action_just_pressed(PASS_ACTIONS[i]):
			switch_to_nearest_ball(true)
			return


func _read_pass_input() -> void:
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


## Gives control to the teammate nearest the ball (optionally never the
## current one, so repeated presses cycle outward).
func switch_to_nearest_ball(exclude_current: bool) -> void:
	var b := Vector2(ball.global_position.x, ball.global_position.z)
	var best: RugbyPlayer = null
	var best_d := INF
	for p in team.players:
		if exclude_current and p == controlled:
			continue
		if p.state == RugbyPlayer.State.GROUNDED or p.state == RugbyPlayer.State.GETTING_UP:
			continue
		var d := p.planar_position().distance_to(b)
		if d < best_d:
			best_d = d
			best = p
	if best:
		set_controlled(best)


func _on_pass_thrown(_passer: RugbyPlayer, receiver: RugbyPlayer, _forward: bool) -> void:
	if receiver and team.has(receiver):
		set_controlled(receiver)


func _on_carrier_changed(_old: RugbyPlayer, new: RugbyPlayer) -> void:
	if new == null:
		return
	if team.has(new):
		set_controlled(new)
	elif is_human() and opponents and opponents.has(new):
		# Turnover (interception, they gathered a loose ball): defend with
		# whoever is closest to the ball.
		switch_to_nearest_ball(false)
