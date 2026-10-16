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
##   RUCK   — a ruck is on (M08): committed players run in and bind; the
##            attack's 9 goes to the ball and the rest form a line around
##            him; the defence lines up behind the offside line. Human: X
##            commits a player, □ (defence) holds the ball in; on attack
##            the human controls the 9.
##
## Human team only: pass buttons pass when you carry and switch player when
## you defend; control follows the ball on our side and jumps to the
## nearest player to the ball on a turnover. A team with human == null is
## fully AI.

signal controlled_changed(old: RugbyPlayer, new: RugbyPlayer)

enum Phase { ATTACK, DEFEND, LOOSE, RUCK }

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
## M08: the match's ruck system (null in tests without one).
var ruck: RuckSystem
var controlled: RugbyPlayer
var phase: Phase = Phase.LOOSE

## 0 = the M04-M06 placeholders (kept for A/B soaks), 1 = M07 basic AI.
var ai_level := 0
var style := TeamStyle.new()
var ai: AITuning
var attack_ai: AttackAI
var tackle_t: TackleTuning
var _dive_cd := {}

## Debug views.
var slots := {}
var assignments: Array[DefensiveLine.Assignment] = []
var chaser: RugbyPlayer

## True while a pass charge was started by a button press (only those are
## released by letting go; charges started from code keep their own timing).
var _input_charge := false
var _held_time := 0.0
var _dt := 1.0 / 60.0

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


## Turns on the M07 AI with this team's style. Support and defence tunings
## become per-team copies scaled by the style.
func configure_ai(p_style: TeamStyle, p_ai: AITuning, p_tackle: TackleTuning, level: int = 1, seed_value: int = 77) -> void:
	style = p_style
	ai = p_ai
	tackle_t = p_tackle
	ai_level = level
	if level >= 1:
		support = AttackAI.styled_support(support, style)
		defence = _styled_defence(defence, style)
	attack_ai = AttackAI.new(ai, style, support, tackle_t, seed_value)


static func _styled_defence(base: DefenceTuning, s: TeamStyle) -> DefenceTuning:
	var out := DefenceTuning.new()
	for k in base.property_names().keys():
		out.set(k, base.get(k))
	var shape := s.defence_shape()
	out.gap_near = shape[0]
	out.mark_retreat = shape[1]
	out.engage_dist = shape[2]
	return out


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
	for k in _dive_cd.keys():
		_dive_cd[k] -= delta
		if _dive_cd[k] <= 0.0:
			_dive_cd.erase(k)
	_dt = delta
	match phase:
		Phase.ATTACK:
			_drive_attack()
		Phase.DEFEND:
			_drive_defence()
		Phase.LOOSE:
			_drive_loose()
		Phase.RUCK:
			_drive_ruck()
	if is_human():
		_read_buttons()


func _phase() -> Phase:
	if ruck and ruck.is_active():
		return Phase.RUCK
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
	if ai_level >= 1 and attack_ai:
		slots = attack_ai.support_slots(anchor_pos, team, runners, opponents)
	else:
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
				if ai_level >= 1 and attack_ai:
					it = attack_ai.carrier_intent(p, team, opponents, passing, _held_time, _dt)
				else:
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
	var smart: AITuning = ai if ai_level >= 1 else null
	var reach := (tackle_t.contact_radius + tackle_t.dive_reach) if tackle_t else 2.85
	assignments = DefensiveLine.assign(ai_defenders, controlled, opponents.players, carrier, Vector2(b.x, b.z), attack, defence, smart, reach)
	for a in assignments:
		var it := SupportRunner.steer_to(a.defender.planar_position(), a.target, a.feed, a.defender.stats.jog_top, defence.gain, defence.settle_dist)
		if a.role == &"chase":
			it.sprint = true
			it.mag = 1.0
		_apply(a.defender, it)
		a.defender.set_role(RugbyPlayer.Role.DEFENDER)
		if a.dive and not _dive_cd.has(a.defender.get_instance_id()):
			if a.defender.try_dive():
				_dive_cd[a.defender.get_instance_id()] = ai.dive_cooldown
	if controlled:
		_apply(controlled, human.read_intent())
		controlled.set_role(RugbyPlayer.Role.DEFENDER)
		# Don't leave the human on a player lying on the floor.
		if controlled.state == RugbyPlayer.State.GROUNDED and controlled.planar_position().distance_to(Vector2(b.x, b.z)) > 3.0:
			switch_to_nearest_ball(true)


# --- Ruck (M08) ------------------------------------------------------------------------

func _drive_ruck() -> void:
	chaser = null
	var r := ruck
	var attacking := r.attack == team
	var free: Array[RugbyPlayer] = []
	for p in team.players:
		if r.is_committed(p):
			if r.is_en_route(p):
				var it := SupportRunner.steer_to(p.planar_position(), r.pos, Vector2.ZERO, p.stats.jog_top, 3.0, 0.0)
				it.sprint = true
				it.mag = 1.0
				_apply(p, it)
			else:
				_apply(p, SupportRunner.Intent.new())
		elif attacking and p == r.nine:
			# The 9 goes to the ball (human or AI: the ball comes out to him).
			if is_human() and controlled != p:
				set_controlled(p)
			var spot := r.nine_spot()
			var it := SupportRunner.steer_to(p.planar_position(), spot, Vector2.ZERO, p.stats.jog_top, 3.0, 0.15)
			it.sprint = p.planar_position().distance_to(spot) > 2.0
			_apply(p, it)
		else:
			free.append(p)
	if attacking:
		_ruck_attack_line(free)
	else:
		_ruck_defence_line(free)


func _ruck_attack_line(free: Array[RugbyPlayer]) -> void:
	assignments.clear()
	var anchor := ruck.nine_spot()
	var runners: Array[RugbyPlayer] = []
	for p in free:
		if p != controlled:
			runners.append(p)
	if ai_level >= 1 and attack_ai:
		slots = attack_ai.support_slots(anchor, team, runners, opponents)
	else:
		slots = SupportRunner.assign_slots(anchor, team, runners, support)
	for p in free:
		if p.role == RugbyPlayer.Role.DEFENDER:
			p.set_role(RugbyPlayer.Role.NEUTRAL)
		if p == controlled:
			_apply(p, human.read_intent())
		elif slots.has(p):
			_apply(p, SupportRunner.steer(p.planar_position(), slots[p], Vector2.ZERO, p.stats.jog_top, support))
		else:
			_apply(p, SupportRunner.Intent.new())


func _ruck_defence_line(free: Array[RugbyPlayer]) -> void:
	slots.clear()
	var ai_defenders: Array[RugbyPlayer] = []
	for p in free:
		if p != controlled:
			ai_defenders.append(p)
	# Mark only the attackers who are free to run (not the ones in the ruck).
	var marks: Array[RugbyPlayer] = []
	for p in opponents.players:
		if not ruck.is_committed(p) and p != ruck.tackled:
			marks.append(p)
	var attack := ruck.dir
	assignments = DefensiveLine.assign(ai_defenders, controlled, marks, null, ruck.pos, attack, defence)
	for a in assignments:
		a.target = ruck.offside_clamp(a.target)
		var it := SupportRunner.steer_to(a.defender.planar_position(), a.target, a.feed, a.defender.stats.jog_top, defence.gain, defence.settle_dist)
		_apply(a.defender, it)
		a.defender.set_role(RugbyPlayer.Role.DEFENDER)
	if controlled:
		if not controlled.is_on_feet() or ruck.is_committed(controlled):
			switch_to_nearest_ball(true)
		if controlled and not ruck.is_committed(controlled):
			_apply(controlled, human.read_intent())
			controlled.set_role(RugbyPlayer.Role.DEFENDER)


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
	if phase == Phase.RUCK:
		_read_ruck_input()
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


## X commits one more player; □ (defence) holds the ball in while pressed.
## On defence the pass buttons still switch player.
func _read_ruck_input() -> void:
	_input_charge = false
	if Input.is_action_just_pressed("ruck_commit"):
		ruck.commit(team)
	if ruck.defence == team:
		ruck.set_hold(team, Input.is_action_pressed("ruck_hold"))
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
		if not p.is_on_feet():
			continue
		if ruck and ruck.is_committed(p):
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
