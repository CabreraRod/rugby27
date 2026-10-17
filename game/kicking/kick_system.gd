class_name KickSystem
extends Node
## Executes kicks (Rugby 08 style) and tracks the ball they put in the air.
##
## Charge: hold the button, the charge fills over charge_time (the blue
## arrow on the pitch shows direction and length), release to kick. A full
## charge held overhold seconds longer kicks by itself. The left stick aims
## (within aim_max_deg of straight ahead); the drop goal aims itself at the
## posts. Tackled while charging = no kick.
##
## Flight: from the boot until the first bounce, a catch or the ball going
## dead. TeamControl's KICK phase reads `in_flight`, `kick_team` and
## `catch_point` to chase and field the kick; PossessionController uses
## KickModel.catch_chance for a kick coming down.
##
## Input lives in TeamControl and AttackAI; this node has a plain API
## (begin / set_aim / release, begin_ai, kick) for both. Runs right after
## TeamControl and PassingSystem (physics priority -8).

signal charge_started(kicker: RugbyPlayer, type: KickModel.Type)
signal kicked(kicker: RugbyPlayer, type: KickModel.Type, landing: Vector2)
signal kick_caught(catcher: RugbyPlayer, by_kicking_team: bool)
signal drop_result(kicker: RugbyPlayer, good: bool)

var tuning: KickTuning
var ball: RugbyBall
var possession: PossessionController
var passing: PassingSystem
var rucks: RuckSystem
var rng := RandomNumberGenerator.new()

# Charging.
var charging := false
var charge_type: KickModel.Type = KickModel.Type.LONG
var charge_time := 0.0
var charge_kicker: RugbyPlayer
var aim := Vector2.RIGHT
## AI: auto-release at this charge (-1 = human, wait for release).
var ai_target := -1.0

# Kick in flight.
var in_flight := false
var kick_team: Team
var kick_type: KickModel.Type = KickModel.Type.LONG
var kicker: RugbyPlayer
var kick_from := Vector2.ZERO
var landing := Vector2.ZERO
var catch_point := Vector2.ZERO
var flight_time := 0.0
var flight_age := 0.0
## Last kick, for the debug overlay / soaks.
var last_strike: KickModel.Strike

# Drop goal tracking (until the ball crosses the goal line or stops).
var drop_live := false
var _drop_plane := 0.0
var _drop_prev := Vector3.ZERO

var _gravity := 9.8


func setup(p_ball: RugbyBall, p_possession: PossessionController, p_passing: PassingSystem, p_tuning: KickTuning, seed_value: int = 19) -> void:
	ball = p_ball
	possession = p_possession
	passing = p_passing
	tuning = p_tuning
	rng.seed = seed_value
	possession.kicks = self
	ball.carrier_changed.connect(_on_carrier_changed)
	ball.bounced.connect(func(_s, _d, _u): _end_flight())
	ball.went_dead.connect(func(_z, _p):
		_end_flight()
		if drop_live:
			_finish_drop(false))


func _ready() -> void:
	process_physics_priority = -8
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _physics_process(delta: float) -> void:
	if charging:
		if ball.carrier != charge_kicker or not charge_kicker.is_controllable():
			cancel()
		else:
			charge_time += delta
			var full := KickModel.charge_time_of(charge_type, tuning)
			if ai_target >= 0.0 and charge() >= ai_target:
				release()
			elif charge_time >= full + tuning.overhold:
				release()
	if in_flight:
		flight_age += delta
	if drop_live:
		_track_drop()


# --- input-level API ----------------------------------------------------------------

## Start charging a kick (button pressed).
func begin(p_kicker: RugbyPlayer, type: KickModel.Type) -> bool:
	if charging or p_kicker == null or ball.carrier != p_kicker or not p_kicker.is_controllable():
		return false
	if passing and passing.charging:
		return false
	charging = true
	charge_type = type
	charge_time = 0.0
	charge_kicker = p_kicker
	ai_target = -1.0
	aim = p_kicker.team.attack() if p_kicker.team else p_kicker.facing
	charge_started.emit(p_kicker, type)
	return true


## AI: charge to `target` (0..1) aiming `dir`, then kick by itself.
func begin_ai(p_kicker: RugbyPlayer, type: KickModel.Type, dir: Vector2, target: float) -> bool:
	if not begin(p_kicker, type):
		return false
	ai_target = clampf(target, 0.0, 1.0)
	set_aim(dir)
	return true


## Left stick while charging (world ground direction). Zero = straight ahead.
func set_aim(dir: Vector2) -> void:
	if not charging or charge_kicker == null or charge_kicker.team == null:
		return
	aim = KickModel.clamp_aim(dir, charge_kicker.team.attack(), tuning)


## Charge 0..1 (drop: 1 = held to the end of the meter).
func charge() -> float:
	if not charging:
		return 0.0
	return clampf(charge_time / KickModel.charge_time_of(charge_type, tuning), 0.0, 1.0)


func release() -> void:
	if not charging:
		return
	var c := charge()
	var k := charge_kicker
	charging = false
	ai_target = -1.0
	if ball.carrier != k:
		return
	kick(k, charge_type, aim, c)


func cancel() -> void:
	charging = false
	ai_target = -1.0


## The 9 with the ball at the base of a ruck: △ is a box kick, not a grubber.
func low_or_box(p: RugbyPlayer) -> KickModel.Type:
	if rucks and rucks.at_base(p, tuning.box_window, tuning.box_radius):
		return KickModel.Type.BOX
	return KickModel.Type.LOW


# --- core ------------------------------------------------------------------------------

## Kick now. Returns the strike (null if `p` can't kick).
func kick(p: RugbyPlayer, type: KickModel.Type, dir: Vector2, charge_value: float) -> KickModel.Strike:
	if p == null or ball.carrier != p:
		return null
	var team := p.team
	var attack := team.attack() if team else p.facing
	var skill := p.profile.attributes.norm("kicking")
	var s := KickModel.Strike.new()
	var d := KickModel.clamp_aim(dir, attack, tuning)
	var damp := ball.tuning.air_damp
	var radius := ball.tuning.radius
	var pos := p.planar_position()
	match type:
		KickModel.Type.DROP:
			var plane := FieldDimensions.HALF_LENGTH * signf(attack.x)
			var posts := Vector2(plane, 0.0)
			s.contact = Vector3(pos.x, tuning.drop_contact_height, pos.y) + Vector3(attack.x, 0, attack.y) * tuning.contact_ahead
			d = (posts - Vector2(s.contact.x, s.contact.z)).normalized()
			var dist := Vector2(s.contact.x, s.contact.z).distance_to(posts)
			var needed := KickModel.drop_needed_speed(s.contact, d, plane, damp, _gravity, radius, tuning)
			var sy := KickModel.drop_strike(charge_value, skill, dist, needed, rng, tuning)
			s.aim = d.rotated(deg_to_rad(sy.y))
			s.velocity = KickModel.launch(s.aim, tuning.drop_angle, sy.x)
			s.planned = dist
			s.drop_error = charge_value - tuning.drop_sweet
		KickModel.Type.LOW:
			s.contact = Vector3(pos.x, tuning.contact_height, pos.y) + Vector3(d.x, 0, d.y) * tuning.contact_ahead
			s.aim = d.rotated(deg_to_rad(rng.randfn(0.0, KickModel.dir_error_sd(skill, tuning))))
			var sp := KickModel.low_speed(charge_value, skill, tuning) * (1.0 + rng.randfn(0.0, KickModel.dist_error_sd(skill, tuning)))
			s.velocity = Vector3(s.aim.x * sp, -tuning.low_down, s.aim.y * sp)
			s.planned = KickModel.low_distance(sp, ball.tuning.roll_decel)
		_:
			s.contact = Vector3(pos.x, tuning.contact_height, pos.y) + Vector3(d.x, 0, d.y) * tuning.contact_ahead
			s.planned = KickModel.distance_for(type, charge_value, skill, tuning)
			var dist := s.planned * (1.0 + rng.randfn(0.0, KickModel.dist_error_sd(skill, tuning)))
			s.aim = d.rotated(deg_to_rad(rng.randfn(0.0, KickModel.dir_error_sd(skill, tuning))))
			var speed := KickModel.solve_speed(s.contact, s.aim, KickModel.angle_of(type, tuning), maxf(dist, 3.0), damp, _gravity, radius)
			s.velocity = KickModel.launch(s.aim, KickModel.angle_of(type, tuning), speed)
	last_strike = s

	cancel()
	if passing:
		passing.charging = false
	possession.intended_receiver = null
	possession.set_cooldown(p, tuning.kicker_cooldown)
	p.play_action(&"kick", 0.4)
	ball.kick(s.contact, s.velocity, p)
	# Flight state is set after kick(): kick() clears any flight via carrier_changed.
	var f := KickModel.simulate(s.contact, s.velocity, damp, _gravity, radius, tuning.catch_height)
	kicker = p
	kick_team = team
	kick_type = type
	kick_from = pos
	landing = f.landing
	catch_point = f.catch_point
	flight_time = f.flight_time
	flight_age = 0.0
	in_flight = type != KickModel.Type.LOW
	if type == KickModel.Type.DROP:
		drop_live = true
		_drop_plane = FieldDimensions.HALF_LENGTH * signf(attack.x)
		_drop_prev = s.contact
	kicked.emit(p, type, landing)
	return s


## Where the current charge would land (for the arrow): [landing, planned distance].
func preview() -> Array:
	if not charging or charge_kicker == null:
		return [Vector2.ZERO, 0.0]
	var p := charge_kicker
	var pos := p.planar_position()
	var skill := p.profile.attributes.norm("kicking")
	match charge_type:
		KickModel.Type.DROP:
			var posts := Vector2(FieldDimensions.HALF_LENGTH * signf(p.team.attack().x), 0.0)
			return [posts, pos.distance_to(posts)]
		KickModel.Type.LOW:
			var dist := KickModel.low_distance(KickModel.low_speed(charge(), skill, tuning), ball.tuning.roll_decel)
			return [pos + aim * dist, dist]
	var dist := KickModel.distance_for(charge_type, charge(), skill, tuning)
	return [pos + aim * dist, dist]


func is_kicked_ball() -> bool:
	return in_flight


# --- tracking --------------------------------------------------------------------------

func _on_carrier_changed(_old: RugbyPlayer, new: RugbyPlayer) -> void:
	if new == null:
		return
	if in_flight:
		kick_caught.emit(new, new.team == kick_team)
	_end_flight()
	if drop_live:
		_finish_drop(false)


func _end_flight() -> void:
	in_flight = false


func _track_drop() -> void:
	if ball.state != RugbyBall.State.LOOSE:
		return
	var p := ball.global_position
	var side := signf(_drop_plane - _drop_prev.x)
	if side != 0.0 and signf(_drop_plane - p.x) != side:
		var k := (_drop_plane - _drop_prev.x) / maxf(absf(p.x - _drop_prev.x), 1e-6) * side
		var c := _drop_prev.lerp(p, clampf(k, 0.0, 1.0))
		_finish_drop(KickModel.drop_good(c.y, c.z))
		return
	if ball.on_ground:
		_finish_drop(false)
		return
	_drop_prev = p


func _finish_drop(good: bool) -> void:
	if not drop_live:
		return
	drop_live = false
	drop_result.emit(kicker, good)


func clear() -> void:
	cancel()
	in_flight = false
	drop_live = false
