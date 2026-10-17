class_name RuckSystem
extends Node
## M08 rucks, Rugby 08 style: fast, readable, no mini-game, a real contest.
##
## Flow:
##   1. A held tackle (no spill) places the ball and FORMS a ruck there. The
##      nearest attacking support (within auto_support_range) and the
##      nearest defender on his feet (within auto_jackal_range) join on
##      their own. Who binds first and how isolated the carrier is set the
##      starting balance.
##   2. CONTEST (contest_time): both teams COMMIT players (human: X taps;
##      AI: by team aggression and situation). Each commit sends the nearest
##      free player running in; he only counts once bound. Committed players
##      are out of the line until the ruck ends: a defence that bids and
##      loses leaves gaps, an attack that over-commits has fewer runners.
##   3. RuckModel decides: turnover (a defender picks it up) or AVAILABLE.
##   4. AVAILABLE: the 9 takes the ball out as soon as he reaches it —
##      unless the defence HOLDS it in (□, needs a defender bound). Every
##      second held raises the penalty hazard; until the referee exists
##      (M11) a penalty is a placeholder: PENALTY notice, ball to the 9.
##
## Replaces the M06 placement protection (TD-027). Runs after tackles,
## before possession (physics priority 4).

signal formed(attack: Team)
signal decided(attack: Team, turnover: bool, result: RuckModel.Result)
signal penalised(defence: Team, held_for: float)
signal ended(attack: Team, outcome: StringName)

enum Phase { NONE, CONTEST, AVAILABLE }

var tuning: RuckTuning
var ball: RugbyBall
var possession: PossessionController
var controls: Array[TeamControl] = []
var rng := RandomNumberGenerator.new()
## Soaks/tests: let the AI decide commits and holds (per side).
var ai_enabled := true

var phase: Phase = Phase.NONE
var attack: Team
var defence: Team
var pos := Vector2.ZERO          ## ball position (ground)
var dir := Vector2.RIGHT         ## the attacking team's direction
var time := 0.0
var tackled: RugbyPlayer
var nine: RugbyPlayer
var holding := false
var held_time := 0.0
var result: RuckModel.Result
## The 9 who just took the ball out, where and how long ago (box kicks, M09).
var base_player: RugbyPlayer
var base_pos := Vector2.ZERO
var base_time := INF
## The AI defence bid for the ball in this ruck (debug / soaks).
var ai_bid := false
## Stats for the debug overlay / soaks: last outcome (&"out", &"turnover", &"penalty", &"cancelled").
var last_outcome: StringName = &""

var _committed := {}   # Team -> Array[RugbyPlayer] (en route + bound)
var _bound_at := {}    # player id -> seconds since formation
var _think := {}       # Team -> seconds to next AI decision
var _ai_hold_until := -1.0
var _ai_bid_done := false
var _ai_hold_decided := false


func setup(p_ball: RugbyBall, p_possession: PossessionController, p_controls: Array[TeamControl], p_tuning: RuckTuning, seed_value: int = 31) -> void:
	ball = p_ball
	possession = p_possession
	controls = p_controls
	tuning = p_tuning
	rng.seed = seed_value
	ball.went_dead.connect(func(_z, _p): cancel())
	ball.carrier_changed.connect(_on_carrier_changed)


func _ready() -> void:
	process_physics_priority = 4


func is_active() -> bool:
	return phase != Phase.NONE


# --- forming ------------------------------------------------------------------------

## A tackled carrier placed the ball: form a ruck there.
func form(p_tackled: RugbyPlayer) -> bool:
	if p_tackled == null or p_tackled.team == null or not ball.is_loose():
		return false
	var b := ball.global_position
	return form_at(Vector2(b.x, b.z), p_tackled.team, p_tackled)


## Forms a ruck at `at` for `p_attack` (tests and soaks call this directly).
func form_at(at: Vector2, p_attack: Team, p_tackled: RugbyPlayer = null) -> bool:
	if is_active():
		cancel()
	var other := _other(p_attack)
	if other == null:
		return false
	attack = p_attack
	defence = other
	pos = at
	dir = attack.attack()
	tackled = p_tackled
	time = 0.0
	holding = false
	held_time = 0.0
	result = null
	last_outcome = &""
	_committed = {attack: [] as Array[RugbyPlayer], defence: [] as Array[RugbyPlayer]}
	_bound_at.clear()
	_think = {attack: tuning.ai_think, defence: tuning.ai_think * rng.randf_range(0.8, 1.4)}
	_ai_hold_until = -1.0
	_ai_bid_done = false
	_ai_hold_decided = false
	ai_bid = false
	phase = Phase.CONTEST
	possession.ruck_lock = true
	_pick_nine()
	# The first arrivals: nearest support and a close defender join by themselves.
	var s := _nearest_free(attack)
	if s and s.planar_position().distance_to(pos) <= tuning.auto_support_range:
		_send(attack, s)
	var j := _nearest_free(defence)
	if j and j.planar_position().distance_to(pos) <= tuning.auto_jackal_range:
		_send(defence, j)
	formed.emit(attack)
	return true


# --- commands (human buttons and AI) -----------------------------------------------

## Send one more player into the ruck (one X tap). False if none can go.
func commit(team: Team) -> bool:
	if not is_active() or not _committed.has(team):
		return false
	if _committed[team].size() >= int(tuning.max_commit):
		return false
	var p := _nearest_free(team)
	if p == null:
		return false
	_send(team, p)
	return true


## Defence holds the ball in while `on` (□).
func set_hold(team: Team, on: bool) -> void:
	if team != defence:
		return
	holding = on and is_active() and bound_count(defence) > 0


func committed(team: Team) -> Array:
	return _committed.get(team, [])


func count(team: Team) -> int:
	return _committed.get(team, []).size()


func bound_count(team: Team) -> int:
	var n := 0
	for p: RugbyPlayer in _committed.get(team, []):
		if p.is_rucking():
			n += 1
	return n


func is_committed(p: RugbyPlayer) -> bool:
	return p.team != null and _committed.get(p.team, []).has(p)


func is_en_route(p: RugbyPlayer) -> bool:
	return is_committed(p) and not p.is_rucking()


## Where a committed player binds (attackers behind the ball, defenders over it).
func bind_slot(p: RugbyPlayer) -> Vector2:
	var list: Array = _committed.get(p.team, [])
	var i := maxi(list.find(p), 0)
	var lat := Vector2(-dir.y, dir.x)
	var row := float(i / 2)
	var side := -1.0 if i % 2 == 0 else 1.0
	var back := 0.75 + 0.5 * row
	if p.team == attack:
		return pos - dir * back + lat * side * 0.4
	return pos + dir * (back + 0.35) + lat * side * 0.4


## Where the 9 waits for the ball (behind it, to one side).
func nine_spot() -> Vector2:
	var lat := Vector2(-dir.y, dir.x)
	var side := 1.0 if pos.y < 0.0 else -1.0   # open side: toward the middle
	return pos - dir * tuning.nine_back + lat * side * tuning.nine_side


## The offside line for defenders not in the ruck (they stay on their side of it).
func offside_clamp(p: Vector2) -> Vector2:
	var along := (p - pos).dot(dir)
	if along < tuning.offside_gap:
		p += dir * (tuning.offside_gap - along)
	return p


## `p` has the ball at the base of the ruck it just came out of.
func at_base(p: RugbyPlayer, window: float, radius: float) -> bool:
	return p != null and p == base_player and ball.carrier == p and base_time <= window and p.planar_position().distance_to(base_pos) <= radius


func ball_available() -> bool:
	return phase == Phase.AVAILABLE and not holding


# --- tick ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	base_time += delta
	if not is_active():
		return
	time += delta
	if ball.state == RugbyBall.State.DEAD or (ball.carrier != null):
		cancel()
		return
	_update_binding()
	if nine == null or not nine.is_on_feet() or is_committed(nine):
		_pick_nine()
	if ai_enabled:
		_ai(delta)
	match phase:
		Phase.CONTEST:
			if time >= tuning.contest_time:
				_decide()
		Phase.AVAILABLE:
			_tick_available(delta)
	if is_active() and time >= tuning.timeout:
		_give_to_nine(&"out")


func _update_binding() -> void:
	for team in _committed.keys():
		var list: Array = _committed[team]
		for p: RugbyPlayer in list.duplicate():
			if p.is_rucking():
				continue
			if p.state == RugbyPlayer.State.GROUNDED or p.state == RugbyPlayer.State.GETTING_UP:
				list.erase(p)   # knocked over on the way: he doesn't arrive
				continue
			if p.state == RugbyPlayer.State.LOCOMOTION and p.planar_position().distance_to(pos) <= tuning.bind_reach:
				var face := dir if team == attack else -dir
				if p.bind_ruck(bind_slot(p), face):
					_bound_at[p.get_instance_id()] = time


func _decide() -> void:
	var att: Array[RuckModel.Body] = []
	var def: Array[RuckModel.Body] = []
	for p: RugbyPlayer in _committed[attack]:
		att.append(_body(p))
	for p: RugbyPlayer in _committed[defence]:
		def.append(_body(p))
	result = RuckModel.evaluate(att, def, time, tuning)
	var turnover := rng.randf() < result.p_turnover
	decided.emit(attack, turnover, result)
	if turnover:
		_turnover()
	else:
		phase = Phase.AVAILABLE


func _tick_available(delta: float) -> void:
	var dctl := control_of(defence)
	if ai_enabled and _ai_hold_until > 0.0 and dctl and not dctl.is_human():
		holding = held_time < _ai_hold_until
	if holding and bound_count(defence) == 0:
		holding = false
	if holding:
		if rng.randf() < RuckModel.hold_tick_chance(held_time, delta, tuning) or held_time + delta >= tuning.hold_max:
			held_time += delta
			var held := held_time
			penalised.emit(defence, held)
			_give_to_nine(&"penalty")
			return
		held_time += delta
		return
	if nine and nine.is_on_feet() and nine.planar_position().distance_to(pos) <= tuning.pickup_reach:
		_give_to_nine(&"out")


func _body(p: RugbyPlayer) -> RuckModel.Body:
	var units := RuckModel.body_units(p.profile.weight_kg, p.profile.attributes.norm("strength"), tuning)
	return RuckModel.Body.make(units, _bound_at.get(p.get_instance_id(), INF))


# --- endings ------------------------------------------------------------------------

func _turnover() -> void:
	# The defender nearest the ball picks it up and runs.
	var picker: RugbyPlayer = null
	var best := INF
	for p: RugbyPlayer in _committed[defence]:
		if p.is_rucking():
			var d := p.planar_position().distance_to(pos)
			if d < best:
				best = d
				picker = p
	if picker == null:
		phase = Phase.AVAILABLE
		return
	var att := attack
	picker.leave_ruck(0.0)
	_finish(&"turnover")
	possession.last_gain = &"ruck"
	ball.attach(picker)
	ended.emit(att, &"turnover")


func _give_to_nine(outcome: StringName) -> void:
	var att := attack
	var n := nine
	_finish(outcome)
	if n and n.is_on_feet():
		possession.last_gain = &"ruck"
		base_player = n
		base_pos = pos
		base_time = 0.0
		ball.attach(n)
	ended.emit(att, outcome)


## Ends the ruck without a result (ball went dead, reset, someone took it).
func cancel() -> void:
	if not is_active():
		return
	var att := attack
	_finish(&"cancelled")
	ended.emit(att, &"cancelled")


func _finish(outcome: StringName) -> void:
	last_outcome = outcome
	phase = Phase.NONE
	holding = false
	possession.ruck_lock = false
	for team in _committed.keys():
		for p: RugbyPlayer in _committed[team]:
			if p.is_rucking():
				p.leave_ruck(tuning.unbind_recover)
	_committed.clear()
	_bound_at.clear()


func clear() -> void:
	cancel()


func _on_carrier_changed(_old: RugbyPlayer, new: RugbyPlayer) -> void:
	if new != null and is_active():
		cancel()


# --- choosing players ----------------------------------------------------------------

func _send(team: Team, p: RugbyPlayer) -> void:
	_committed[team].append(p)


## The nearest player of `team` who is free to join: on his feet, not
## committed, not the 9, not the tackled player, not the human's player.
func _nearest_free(team: Team) -> RugbyPlayer:
	var best: RugbyPlayer = null
	var best_d := INF
	var ctl := control_of(team)
	for p in team.players:
		if p.state != RugbyPlayer.State.LOCOMOTION or is_committed(p) or p == tackled:
			continue
		if team == attack and p == nine:
			continue
		if ctl and ctl.is_human() and p == ctl.controlled and not (team == attack and p == nine):
			continue
		var d := p.planar_position().distance_to(pos)
		if d < best_d:
			best_d = d
			best = p
	return best


func _pick_nine() -> void:
	if attack == null:
		return
	var best: RugbyPlayer = null
	var best_d := INF
	for p in attack.players:
		if not p.is_on_feet() or is_committed(p) or p == tackled:
			continue
		var d := p.planar_position().distance_to(pos)
		if p.profile.position == "ScrumHalf" or p.profile.number == 9:
			d -= 1000.0   # the real 9 if he can get there
		if d < best_d:
			best_d = d
			best = p
	nine = best


func control_of(team: Team) -> TeamControl:
	for c in controls:
		if c and c.team == team:
			return c
	return null


func _other(team: Team) -> Team:
	for c in controls:
		if c and c.team == team:
			return c.opponents
	return null


# --- AI --------------------------------------------------------------------------------

func _ai(delta: float) -> void:
	for team in [attack, defence]:
		var ctl := control_of(team)
		if ctl == null or ctl.is_human():
			continue
		_think[team] -= delta
		if _think[team] > 0.0:
			continue
		_think[team] = tuning.ai_think
		if team == defence:
			_ai_defence(ctl)
		else:
			_ai_attack()


func _ai_defence(ctl: TeamControl) -> void:
	var aggression := ctl.style.n("aggression")
	var near_line := _near_own_line(defence)
	if phase == Phase.CONTEST and not _ai_bid_done:
		_ai_bid_done = true
		var iso := isolated()
		if rng.randf() < RuckModel.bid_chance(aggression, iso, near_line, tuning):
			ai_bid = true
			var n := RuckModel.bid_size(iso, rng, tuning)
			for i in maxi(n - count(defence), 0):
				if not commit(defence):
					break
	# Decide early whether to slow the ball down if the attack wins it: the
	# 9 is usually waiting, so the hold has to be on as the ball becomes
	# available (applied every tick in _tick_available).
	if not _ai_hold_decided:
		_ai_hold_decided = true
		if rng.randf() < RuckModel.hold_chance(aggression, near_line, tuning):
			_ai_hold_until = rng.randf_range(tuning.ai_hold_min, tuning.ai_hold_max)


func _ai_attack() -> void:
	if phase != Phase.CONTEST:
		return
	var extra := RuckModel.attack_extra(count(attack), count(defence), tuning)
	if extra <= 0 or rng.randf() < tuning.att_miss:
		return
	for i in extra:
		if not commit(attack):
			break


## No attacker bound or able to bind before the contest is decided.
func isolated() -> bool:
	for p: RugbyPlayer in _committed.get(attack, []):
		if p.is_rucking():
			return false
		var e := RuckModel.eta(p.planar_position().distance_to(pos), p.stats.sprint_top, tuning)
		if time + e <= tuning.contest_time:
			return false
	return true


func _near_own_line(team: Team) -> bool:
	var own_line_x := -team.attack_dir * FieldDimensions.HALF_LENGTH
	return absf(pos.x - own_line_x) < tuning.near_line_dist
