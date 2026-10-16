class_name TackleSystem
extends Node
## Detects contact between the ball carrier and opponents and resolves the
## tackle with TackleModel. Runs after players moved, before possession
## (physics priority 3), so a tackle on tick N grounds the carrier and
## places the ball on tick N.
##
## Steering into the carrier IS the tackle (Rugby 08 style, accessible).
## A dive extends the reach in front of the diver; a fend or a sidestep
## changes the odds. Every outcome is immediate — no cinematic locks.

signal tackle_made(tackler: RugbyPlayer, carrier: RugbyPlayer, result: TackleModel.Result)
signal dive_missed(diver: RugbyPlayer)

var tuning: TackleTuning
var ball: RugbyBall
var possession: PossessionController
var players: Array[RugbyPlayer] = []
## M08: held tackles form a ruck here (null = the old placement protection).
var rucks: RuckSystem
var rng := RandomNumberGenerator.new()
## Debug: last tackle evaluation.
var last_result: TackleModel.Result
var last_tackler: RugbyPlayer

var _cooldown := {}     # tackler id -> s
var _immunity := {}     # "tackler:carrier" -> s
var _was_diving := {}   # id -> bool (to detect dive misses)


func setup(p_ball: RugbyBall, p_possession: PossessionController, p_players: Array[RugbyPlayer], p_tuning: TackleTuning, seed_value: int = 12) -> void:
	ball = p_ball
	possession = p_possession
	players = p_players
	tuning = p_tuning
	rng.seed = seed_value
	for p in players:
		p.contact = tuning


func _ready() -> void:
	process_physics_priority = 3


func _physics_process(delta: float) -> void:
	_tick_timers(_cooldown, delta)
	_tick_timers(_immunity, delta)
	_track_dive_misses()
	var carrier := ball.carrier if ball else null
	if carrier == null or carrier.state != RugbyPlayer.State.LOCOMOTION or carrier.team == null:
		return
	var best: RugbyPlayer = null
	var best_d := INF
	for d in players:
		if d.team == carrier.team or d.team == null:
			continue
		if not (d.state == RugbyPlayer.State.LOCOMOTION or d.state == RugbyPlayer.State.DIVING):
			continue
		if _cooldown.has(d.get_instance_id()) or _immunity.has(_key(d, carrier)):
			continue
		var dist := d.planar_position().distance_to(carrier.planar_position())
		if dist <= reach(d, carrier) and dist < best_d:
			best_d = dist
			best = d
	if best:
		tackle(best, carrier)


## Contact reach of `d` against `carrier` (a dive reaches further in front).
func reach(d: RugbyPlayer, carrier: RugbyPlayer) -> float:
	var r := tuning.contact_radius
	if d.is_diving():
		var to_c := (carrier.planar_position() - d.planar_position()).normalized()
		if to_c.dot(d.facing) > 0.5:
			r += tuning.dive_reach
	return r


func tackle(d: RugbyPlayer, carrier: RugbyPlayer) -> TackleModel.Result:
	var c := TackleModel.Contact.new()
	c.tackler_mass = d.profile.weight_kg
	c.tackler_vel = d.momentum_velocity
	c.tackler_pos = d.planar_position()
	c.tackling = d.profile.attributes.norm("tackling")
	c.carrier_mass = carrier.profile.weight_kg
	c.carrier_vel = carrier.momentum_velocity
	c.carrier_pos = carrier.planar_position()
	c.strength = carrier.profile.attributes.norm("strength")
	c.dive = d.is_diving()
	c.fend = carrier.fend_timer > 0.0
	c.sidestep = carrier.sidestep_timer > 0.0
	var r := TackleModel.resolve(c, rng, tuning)
	last_result = r
	last_tackler = d
	_cooldown[d.get_instance_id()] = tuning.tackler_cooldown
	_was_diving.erase(d.get_instance_id())
	var after := TackleModel.carrier_velocity_after(r.outcome, carrier.momentum_velocity, d.momentum_velocity, tuning)
	match r.outcome:
		TackleModel.Outcome.BROKEN:
			_immunity[_key(d, carrier)] = tuning.retackle_immunity
			carrier.planar_velocity = after
			d.go_to_ground(tuning.broken_tackler_ground, d.planar_velocity * 0.3, true)
			d.play_action(&"tackle", 0.4)
		_:
			var tackler_time := tuning.dominant_tackler_ground if r.outcome == TackleModel.Outcome.DOMINANT else tuning.tackler_ground
			d.play_action(&"tackle", 0.4)
			d.go_to_ground(tackler_time, d.planar_velocity * 0.2, true)
			if r.spill:
				possession.spill(carrier)
			carrier.play_action(&"tackled", 0.4)
			carrier.go_to_ground(tuning.tackled_ground, after)
			# Going to ground placed the ball: a ruck forms over it.
			if not r.spill:
				if rucks:
					rucks.form(carrier)
				else:
					possession.protect(carrier.team, tuning.placement_protect)
	tackle_made.emit(d, carrier, r)
	return r


func _track_dive_misses() -> void:
	for p in players:
		var id := p.get_instance_id()
		if p.is_diving():
			_was_diving[id] = true
		elif _was_diving.has(id):
			_was_diving.erase(id)
			if p.state == RugbyPlayer.State.GROUNDED:
				dive_missed.emit(p)


func clear() -> void:
	_cooldown.clear()
	_immunity.clear()
	_was_diving.clear()


static func _key(d: RugbyPlayer, c: RugbyPlayer) -> String:
	return "%d:%d" % [d.get_instance_id(), c.get_instance_id()]


static func _tick_timers(dict: Dictionary, delta: float) -> void:
	for k in dict.keys():
		dict[k] -= delta
		if dict[k] <= 0.0:
			dict.erase(k)
