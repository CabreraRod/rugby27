class_name PossessionController
extends Node
## Decides who has the ball: pickups and catches (and their failures),
## drops, placing.
##
## Runs after players moved and before the ball updates (physics priority 5),
## so a pickup/catch on tick N puts the ball in hand on tick N.
## Owns the BALL_CARRIER role: whoever holds the ball gets it, nobody else.
##
## A loose ball near the ground is a PICKUP (PickupModel); a ball in the air
## at catchable height is a CATCH (CatchModel).

signal pickup(player: RugbyPlayer, chance: float)
signal pickup_failed(player: RugbyPlayer, chance: float)
signal caught(player: RugbyPlayer, chance: float)
signal catch_failed(player: RugbyPlayer, chance: float, knock_on: bool)

var ball: RugbyBall
var tuning: BallTuning
var pass_tuning: PassingTuning
## Receiver of the pass in flight (set by PassingSystem): larger catch reach.
var intended_receiver: RugbyPlayer
## How the ball was last gained: &"pickup" or &"catch".
var last_gain: StringName = &""
var players: Array[RugbyPlayer] = []
var rng := RandomNumberGenerator.new()
## For debug: last computed chance for each player id.
var last_chance := {}

var _cooldown := {}   # instance id -> seconds
## After a tackle only this team may pick the ball up (placeholder for the
## M08 ruck), while _protect_timer > 0.
var protected_team: Team
var _protect_timer := 0.0


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
	if _protect_timer > 0.0:
		_protect_timer -= delta
		if _protect_timer <= 0.0:
			protected_team = null
	if ball == null or not ball.is_loose():
		return
	var airborne := pass_tuning != null and not ball.on_ground and ball.global_position.y > pass_tuning.catch_min_height
	var best: RugbyPlayer = null
	var best_d := INF
	for p in players:
		if not p.is_controllable() or _cooldown.has(p.get_instance_id()):
			continue
		if protected_team and p.team != protected_team and not airborne:
			continue
		if airborne:
			# A pass in flight: the passer's teammates let it through to the
			# intended receiver (opponents may intercept once they exist).
			if intended_receiver and p != intended_receiver and p.team and p.team == intended_receiver.team:
				continue
			var intercepting := _is_interception(p)
			# Nobody intercepts a ball still leaving the passer's hands.
			if intercepting and pass_age < pass_tuning.intercept_min_time:
				continue
			var reach := pass_tuning.catch_reach_intended if p == intended_receiver else (pass_tuning.intercept_reach if intercepting else pass_tuning.catch_reach)
			if not CatchModel.in_reach(p.global_position, ball.global_position, reach, pass_tuning):
				continue
			# Hands meet the ball at its closest approach, not at the edge of reach.
			if not CatchModel.at_closest_approach(p.global_position, p.planar_velocity, ball.global_position, ball.ball_velocity(), delta, pass_tuning):
				continue
		elif not PickupModel.in_reach(p.global_position, ball.global_position, tuning):
			continue
		var d := p.global_position.distance_squared_to(ball.global_position)
		if p == intended_receiver:
			d *= 0.25   # the intended receiver wins close calls
		if d < best_d:
			best_d = d
			best = p
	if best:
		if airborne:
			attempt_catch(best)
		else:
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
		last_gain = &"pickup"
		ball.attach(p)
		pickup.emit(p, c)
		return true
	var v := PickupModel.fumble_velocity(p.planar_velocity, p.facing, rng, tuning)
	ball.knock(v, p)
	p.apply_stumble(tuning.fumble_stumble)
	_cooldown[p.get_instance_id()] = tuning.pickup_retry_cooldown
	pickup_failed.emit(p, c)
	return false


func catch_chance(p: RugbyPlayer) -> float:
	var bpos := ball.global_position
	var bv := ball.ball_velocity()
	var rel := (bv - Vector3(p.planar_velocity.x, 0.0, p.planar_velocity.y)).length()
	var to_ball := Vector2(bpos.x, bpos.z) - p.planar_position()
	var behind := -to_ball.dot(p.facing)
	var height := bpos.y - p.global_position.y
	return CatchModel.chance(p.profile.attributes.norm("handling"), rel, behind, height, pass_tuning)


## A defender reaching for the other team's pass.
func _is_interception(p: RugbyPlayer) -> bool:
	return intended_receiver != null and p.team != null and intended_receiver.team != null and p.team != intended_receiver.team


## Seconds since the current pass left the hands (set by PassingSystem).
var pass_age := 0.0


func attempt_catch(p: RugbyPlayer) -> bool:
	var c := catch_chance(p)
	var intercepting := _is_interception(p)
	if intercepting:
		c *= pass_tuning.intercept_mult
	last_chance[p.get_instance_id()] = c
	if intercepting and rng.randf() >= c:
		# Missed interception: usually the ball goes past untouched; sometimes
		# a fingertip knocks it down. Either way this defender is done.
		_cooldown[p.get_instance_id()] = pass_tuning.catch_retry_cooldown
		if rng.randf() < pass_tuning.intercept_knockdown:
			var attack := p.team.attack()
			var v := CatchModel.knock_velocity(ball.ball_velocity(), attack, rng, pass_tuning)
			ball.knock(v, p, &"knock_on" if CatchModel.is_knock_on(v, attack) else &"deflected")
			catch_failed.emit(p, c, CatchModel.is_knock_on(v, attack))
		return false
	if rng.randf() < c:
		last_gain = &"catch"
		ball.attach(p)
		p.play_action(&"catch", 0.25)
		caught.emit(p, c)
		return true
	var attack := p.team.attack() if p.team else p.facing
	var v := CatchModel.knock_velocity(ball.ball_velocity(), attack, rng, pass_tuning)
	var knock_on := CatchModel.is_knock_on(v, attack)
	ball.knock(v, p, &"knock_on" if knock_on else &"dropped")
	_cooldown[p.get_instance_id()] = pass_tuning.catch_retry_cooldown
	catch_failed.emit(p, c, knock_on)
	return false


## Only `team` may gather the loose ball for `seconds` (tackle placement).
func protect(team: Team, seconds: float) -> void:
	protected_team = team
	_protect_timer = seconds


## The carrier loses the ball forward in a tackle (knock-on).
func spill(p: RugbyPlayer) -> void:
	if ball.carrier != p:
		return
	var f := p.team.attack() if p.team else p.facing
	var v := Vector3(f.x * 2.5 + p.planar_velocity.x * 0.4, 1.4, f.y * 2.5 + p.planar_velocity.y * 0.4)
	_cooldown[p.get_instance_id()] = pass_tuning.catch_retry_cooldown if pass_tuning else 0.5
	ball.release(v, &"knock_on")


func set_cooldown(p: RugbyPlayer, seconds: float) -> void:
	_cooldown[p.get_instance_id()] = seconds


func clear_cooldowns() -> void:
	_cooldown.clear()
	protected_team = null
	_protect_timer = 0.0


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
