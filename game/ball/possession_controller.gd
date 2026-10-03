class_name PossessionController
extends Node
## Decides who has the ball: pickups, fumbled pickups, releases.
##
## Runs after players moved and before the ball updates (physics priority 5),
## so a pickup on tick N puts the ball in hand on tick N.
## Owns the BALL_CARRIER role: whoever holds the ball gets it, nobody else.

signal pickup(player: RugbyPlayer, chance: float)
signal pickup_failed(player: RugbyPlayer, chance: float)

var ball: RugbyBall
var tuning: BallTuning
var players: Array[RugbyPlayer] = []
var rng := RandomNumberGenerator.new()
## For debug: last computed chance for each player id.
var last_chance := {}

var _cooldown := {}   # instance id -> seconds


func setup(p_ball: RugbyBall, p_tuning: BallTuning, p_players: Array[RugbyPlayer], seed_value: int = 8) -> void:
	ball = p_ball
	tuning = p_tuning
	players = p_players
	rng.seed = seed_value
	ball.carrier_changed.connect(_on_carrier_changed)
	for p in players:
		p.state_changed.connect(_on_player_state_changed.bind(p))


func _ready() -> void:
	process_physics_priority = 5


func _physics_process(delta: float) -> void:
	for id in _cooldown.keys():
		_cooldown[id] -= delta
		if _cooldown[id] <= 0.0:
			_cooldown.erase(id)
	if ball == null or not ball.is_loose():
		return
	var best: RugbyPlayer = null
	var best_d := INF
	for p in players:
		if not p.is_controllable() or _cooldown.has(p.get_instance_id()):
			continue
		if not PickupModel.in_reach(p.global_position, ball.global_position, tuning):
			continue
		var d := p.global_position.distance_squared_to(ball.global_position)
		if d < best_d:
			best_d = d
			best = p
	if best:
		attempt_pickup(best)


func pickup_chance(p: RugbyPlayer) -> float:
	var bv := ball.ball_velocity()
	var rel := Vector2(bv.x, bv.z) - p.planar_velocity
	return PickupModel.chance(p.profile.attributes.norm("handling"), p.current_speed(), p.stats.sprint_top, rel.length(), tuning)


func attempt_pickup(p: RugbyPlayer) -> bool:
	var c := pickup_chance(p)
	last_chance[p.get_instance_id()] = c
	if rng.randf() < c:
		if p.current_speed() > p.stats.jog_top:
			p.apply_stumble(tuning.pickup_stumble)
		ball.attach(p)
		pickup.emit(p, c)
		return true
	var v := PickupModel.fumble_velocity(p.planar_velocity, p.facing, rng, tuning)
	ball.knock(v, p)
	p.apply_stumble(tuning.fumble_stumble)
	_cooldown[p.get_instance_id()] = tuning.pickup_retry_cooldown
	pickup_failed.emit(p, c)
	return false


## Dev / future knock-on: carrier loses the ball forward.
func drop(p: RugbyPlayer) -> void:
	if ball.carrier != p:
		return
	var f := p.facing
	var v := Vector3(p.planar_velocity.x * 0.9 + f.x * 1.0, 1.5, p.planar_velocity.y * 0.9 + f.y * 1.0)
	_cooldown[p.get_instance_id()] = tuning.pickup_retry_cooldown
	ball.release(v, &"drop")


func _on_carrier_changed(old: RugbyPlayer, new: RugbyPlayer) -> void:
	if old and old.role == RugbyPlayer.Role.BALL_CARRIER:
		old.set_role(RugbyPlayer.Role.NEUTRAL)
	if new:
		new.set_role(RugbyPlayer.Role.BALL_CARRIER)


## A carrier who goes to ground places the ball behind them (the M08 ruck
## will build on this).
func _on_player_state_changed(_old: RugbyPlayer.State, new_state: RugbyPlayer.State, p: RugbyPlayer) -> void:
	if new_state == RugbyPlayer.State.GROUNDED and ball.carrier == p:
		var back := -p.facing * 0.9
		_cooldown[p.get_instance_id()] = tuning.pickup_retry_cooldown * 3.0
		ball.place(p.global_position + Vector3(back.x, 0, back.y), &"placed")
