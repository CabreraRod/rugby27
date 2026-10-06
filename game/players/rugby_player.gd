class_name RugbyPlayer
extends CharacterBody3D
## A rugby player body: owns physical state and movement.
##
## It does not read input. TeamControl (human input or support runner) calls
## set_intent() every physics tick before this node simulates. That keeps the
## same movement rules for every player on the pitch.

signal state_changed(old_state: State, new_state: State)
signal role_changed(new_role: Role)

enum State {
	LOCOMOTION,   ## Running / standing, fully controllable.
	DIVING,       ## Dive tackle lunge: committed, no steering.
	GROUNDED,     ## On the ground (tackled, tackler, missed dive, dev key).
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
## Contact/move tuning (fend, sidestep, dive). Null in movement-only tests.
var contact: TackleTuning
var stamina: StaminaModel
var stats: LocomotionStats

var state: State = State.LOCOMOTION
var role: Role = Role.NEUTRAL

## Ground-plane velocity (x = world X, y = world Z).
var planar_velocity := Vector2.ZERO
## Velocity this tick BEFORE collisions clipped it: the momentum a player
## brings into contact (two players pushing into each other read ~0 after
## move_and_slide). Used by tackles.
var momentum_velocity := Vector2.ZERO
## Ground-plane acceleration measured last tick (for visuals/debug).
var planar_accel := Vector2.ZERO
## Body facing on the ground plane (unit). Starts facing +X (attacking right).
var facing := Vector2(1.0, 0.0)
var is_sprinting := false

## Team membership (attack direction, teammates). Null in isolated tests.
var team: Team
## True while the human controls this player (presentation reads it).
var is_controlled := false
## Short-lived action for presentation (e.g. &"pass_left", &"catch").
var action: StringName = &""
var action_timer := 0.0
var action_duration := 0.0

# Carrier moves / dive (timers in seconds).
var fend_timer := 0.0
var sidestep_timer := 0.0
var _fend_cd := 0.0
var _sidestep_cd := 0.0
var _dive_dir := Vector2.ZERO

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
var _intent_speed := -1.0
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
	collision_layer = PhysicsLayers.PLAYERS
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYERS
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
## speed: optional exact target speed (m/s, still capped by jog/sprint top
## and stamina) — used to hold a pace, e.g. a receiver running onto a pass.
func set_intent(dir: Vector2, magnitude: float, sprint: bool, speed: float = -1.0) -> void:
	_intent_dir = dir.normalized() if dir.length_squared() > 1e-6 else Vector2.ZERO
	_intent_mag = clampf(magnitude, 0.0, 1.0)
	_intent_sprint = sprint
	_intent_speed = speed


func _physics_process(delta: float) -> void:
	simulate(delta)


## One simulation tick. Public so tests can drive it deterministically.
func simulate(dt: float) -> void:
	var prev := planar_velocity
	if action_timer > 0.0:
		action_timer -= dt
		if action_timer <= 0.0:
			action = &""
	fend_timer = maxf(0.0, fend_timer - dt)
	sidestep_timer = maxf(0.0, sidestep_timer - dt)
	_fend_cd = maxf(0.0, _fend_cd - dt)
	_sidestep_cd = maxf(0.0, _sidestep_cd - dt)
	match state:
		State.LOCOMOTION:
			_tick_locomotion(dt)
		State.DIVING:
			_tick_diving(dt)
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
	momentum_velocity = planar_velocity
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
		if _intent_speed >= 0.0:
			target_speed = minf(_intent_speed, stats.sprint_top if stamina.can_sprint() else stats.jog_top)
			wants_sprint = target_speed > stats.jog_top
			is_sprinting = wants_sprint and speed > 1.0

	planar_velocity = _model.step(planar_velocity, _intent_dir, target_speed, stats, tuning, dt)

	# Face where we run; when (almost) stationary, turn on the spot toward input.
	var face_toward := planar_velocity if planar_velocity.length() > 0.4 else (_intent_dir if has_input else Vector2.ZERO)
	facing = LocomotionModel.turn_facing(facing, face_toward, planar_velocity.length(), stats.sprint_top, tuning, dt)


func _tick_diving(dt: float) -> void:
	is_sprinting = false
	var speed := planar_velocity.length()
	planar_velocity = _dive_dir * maxf(0.0, speed - tuning.ground_slide_decel * 0.5 * dt)
	_state_timer -= dt
	if _state_timer <= 0.0:
		# Lunge over without contact: you are on the floor.
		go_to_ground(contact.dive_miss_ground if contact else tuning.ground_time, planar_velocity * 0.4, true)


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


## Puts the player on the ground for `time` seconds (default: dev ground
## time) sliding with `slide`. `force` also interrupts a dive.
func go_to_ground(time: float = -1.0, slide: Variant = null, force: bool = false) -> void:
	if state != State.LOCOMOTION and not (force and state == State.DIVING):
		return
	if slide != null:
		planar_velocity = slide
	_set_state(State.GROUNDED)
	_state_timer = time if time >= 0.0 else tuning.ground_time


## Dive tackle: commit to a lunge along the current facing.
func try_dive() -> bool:
	if state != State.LOCOMOTION or contact == null or role == Role.BALL_CARRIER:
		return false
	_dive_dir = facing
	planar_velocity = facing * maxf(contact.dive_speed, planar_velocity.length())
	_set_state(State.DIVING)
	_state_timer = contact.dive_window
	play_action(&"dive", contact.dive_window + 0.2)
	return true


## Fend (hand-off): for a short window, front/side tackles meet more resistance.
func try_fend() -> bool:
	if contact == null or state != State.LOCOMOTION or role != Role.BALL_CARRIER or _fend_cd > 0.0:
		return false
	fend_timer = contact.fend_window
	_fend_cd = contact.fend_cooldown
	play_action(&"fend", contact.fend_window + 0.1)
	return true


## Sidestep: lateral burst relative to facing (side -1 = left, +1 = right).
## Wrong-foots tacklers for a short window. Costs stamina.
func try_sidestep(side: float) -> bool:
	if contact == null or state != State.LOCOMOTION or _sidestep_cd > 0.0:
		return false
	var right := Vector2(-facing.y, facing.x)
	planar_velocity += right * signf(side) * contact.sidestep_speed
	stamina.value = maxf(0.0, stamina.value - contact.sidestep_stamina)
	sidestep_timer = contact.sidestep_window
	_sidestep_cd = contact.sidestep_cooldown
	play_action(&"sidestep_left" if side < 0.0 else &"sidestep_right", 0.3)
	return true


func is_diving() -> bool:
	return state == State.DIVING


## Cosmetic action cue (pass, catch). Never blocks movement.
func play_action(a: StringName, duration: float) -> void:
	action = a
	action_timer = duration
	action_duration = duration


## Action progress 0..1 (0 = just started).
func action_progress() -> float:
	if action_duration <= 0.0:
		return 1.0
	return 1.0 - clampf(action_timer / action_duration, 0.0, 1.0)


func planar_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## Momentary loss of speed (pickup at pace, fumble). keep: fraction kept.
func apply_stumble(keep: float) -> void:
	planar_velocity *= clampf(keep, 0.0, 1.0)


func is_controllable() -> bool:
	return state == State.LOCOMOTION


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
