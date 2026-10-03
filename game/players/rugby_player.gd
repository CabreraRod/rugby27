class_name RugbyPlayer
extends CharacterBody3D
## A rugby player body: owns physical state and movement.
##
## It does not read input. A controller (HumanController now, AI later) calls
## set_intent() every physics tick before this node simulates. That keeps the
## same movement rules for every player on the pitch.

signal state_changed(old_state: State, new_state: State)
signal role_changed(new_role: Role)

enum State {
	LOCOMOTION,   ## Running / standing, fully controllable.
	GROUNDED,     ## On the ground (dive now; tackled from Milestone 07).
	GETTING_UP,   ## Recovering to feet, no control.
}

## Situational role. Affects movement; later drives ball/tackle systems.
enum Role {
	NEUTRAL,
	BALL_CARRIER,
	DEFENDER,
}

const CAPSULE_RADIUS := 0.36
const CAPSULE_HEIGHT := 1.86

var profile: PlayerProfile
var tuning: MovementTuning
var stamina: StaminaModel
var stats: LocomotionStats

var state: State = State.LOCOMOTION
var role: Role = Role.NEUTRAL

## Ground-plane velocity (x = world X, y = world Z).
var planar_velocity := Vector2.ZERO
## Ground-plane acceleration measured last tick (for visuals/debug).
var planar_accel := Vector2.ZERO
## Body facing on the ground plane (unit). Starts facing +X (attacking right).
var facing := Vector2(1.0, 0.0)
var is_sprinting := false

var team_colors := {
	"jersey": Color("#1f4fa3"),
	"shorts": Color("#f2f2f2"),
	"socks": Color("#1f4fa3"),
	"indicator": Color("#ffd23f"),
}

var _model := LocomotionModel.new()
var _intent_dir := Vector2.ZERO
var _intent_mag := 0.0
var _intent_sprint := false
var _state_timer := 0.0


func setup(p_profile: PlayerProfile, p_tuning: MovementTuning) -> void:
	profile = p_profile
	tuning = p_tuning
	stamina = StaminaModel.new(tuning.stamina_max)
	_refresh_stats()


func _ready() -> void:
	if tuning == null:
		setup(PlayerProfile.from_dict({}), MovementTuning.new())
	floor_snap_length = 0.3
	floor_stop_on_slope = true
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = CAPSULE_RADIUS
	cap.height = CAPSULE_HEIGHT
	col.shape = cap
	col.position.y = CAPSULE_HEIGHT * 0.5
	add_child(col)


## Called by the controller each physics tick.
## dir: desired ground direction (any length, normalized here), magnitude 0..1.
func set_intent(dir: Vector2, magnitude: float, sprint: bool) -> void:
	_intent_dir = dir.normalized() if dir.length_squared() > 1e-6 else Vector2.ZERO
	_intent_mag = clampf(magnitude, 0.0, 1.0)
	_intent_sprint = sprint


func _physics_process(delta: float) -> void:
	simulate(delta)


## One simulation tick. Public so tests can drive it deterministically.
func simulate(dt: float) -> void:
	var prev := planar_velocity
	match state:
		State.LOCOMOTION:
			_tick_locomotion(dt)
		State.GROUNDED:
			_tick_grounded(dt)
		State.GETTING_UP:
			_tick_getting_up(dt)

	# Vertical: simple gravity, players do not jump.
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= tuning.gravity * dt
	velocity.x = planar_velocity.x
	velocity.z = planar_velocity.y
	move_and_slide()
	# Collisions may have changed our velocity; keep the simulation honest.
	planar_velocity = Vector2(velocity.x, velocity.z)
	planar_accel = (planar_velocity - prev) / dt if dt > 0.0 else Vector2.ZERO


func _tick_locomotion(dt: float) -> void:
	var has_input := _intent_mag > 0.05
	var speed := planar_velocity.length()
	var wants_sprint := _intent_sprint and has_input and stamina.can_sprint()
	is_sprinting = wants_sprint and speed > 1.0

	stamina.step(is_sprinting, speed > 0.5, stats.sprint_drain, tuning, dt)
	_refresh_stats()

	var target_speed := 0.0
	if has_input:
		# Analog stick scales jog speed (walk -> jog). Sprint is full speed.
		target_speed = stats.sprint_top if wants_sprint else stats.jog_top * _intent_mag

	planar_velocity = _model.step(planar_velocity, _intent_dir, target_speed, stats, tuning, dt)

	# Face where we run; when (almost) stationary, turn on the spot toward input.
	var face_toward := planar_velocity if planar_velocity.length() > 0.4 else (_intent_dir if has_input else Vector2.ZERO)
	facing = LocomotionModel.turn_facing(facing, face_toward, planar_velocity.length(), stats.sprint_top, tuning, dt)


func _tick_grounded(dt: float) -> void:
	is_sprinting = false
	stamina.step(false, false, 0.0, tuning, dt)
	var speed := planar_velocity.length()
	if speed > 0.0:
		planar_velocity *= maxf(0.0, speed - tuning.ground_slide_decel * dt) / speed
	_state_timer -= dt
	if _state_timer <= 0.0:
		_set_state(State.GETTING_UP)
		_state_timer = tuning.get_up_time


func _tick_getting_up(dt: float) -> void:
	is_sprinting = false
	stamina.step(false, false, 0.0, tuning, dt)
	planar_velocity = Vector2.ZERO
	_state_timer -= dt
	if _state_timer <= 0.0:
		_set_state(State.LOCOMOTION)


## Puts the player on the ground (dev action now; tackles/rucks later).
func go_to_ground() -> void:
	if state != State.LOCOMOTION:
		return
	_set_state(State.GROUNDED)
	_state_timer = tuning.ground_time


func set_role(r: Role) -> void:
	if r == role:
		return
	role = r
	_refresh_stats()
	role_changed.emit(role)


func reset_to(pos: Vector3, face: Vector2 = Vector2(1, 0)) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	planar_velocity = Vector2.ZERO
	planar_accel = Vector2.ZERO
	facing = face.normalized()
	stamina.refill()
	_set_state(State.LOCOMOTION)
	reset_physics_interpolation()


func set_tuning(t: MovementTuning) -> void:
	tuning = t
	_refresh_stats()


func set_profile(p: PlayerProfile) -> void:
	profile = p
	_refresh_stats()


func current_speed() -> float:
	return planar_velocity.length()


func intent_dir() -> Vector2:
	return _intent_dir * _intent_mag


func locomotion_debug() -> LocomotionModel:
	return _model


func state_name() -> String:
	return State.keys()[state]


func role_name() -> String:
	return Role.keys()[role]


func _set_state(s: State) -> void:
	if s == state:
		return
	var old := state
	state = s
	state_changed.emit(old, s)


func _refresh_stats() -> void:
	var speed_mult := 1.0
	var turn_mult := 1.0
	match role:
		Role.BALL_CARRIER:
			speed_mult = tuning.carrier_speed_mult
			turn_mult = tuning.carrier_turn_mult
		Role.DEFENDER:
			turn_mult = tuning.defender_turn_mult
	stats = LocomotionStats.derive(tuning, profile.attributes, speed_mult, turn_mult, stamina.fatigue_multiplier(tuning))
