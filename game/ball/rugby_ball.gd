class_name RugbyBall
extends RigidBody3D
## The ball: an independent physics object (Jolt RigidBody3D).
##
## States:
##   LOOSE — simulated by physics (in the air, bouncing, rolling, resting).
##   HELD  — frozen kinematic, follows the carrier's carry socket.
##   DEAD  — out of play; frozen where it went out until a restart.
## (Passes/kicks with an intended target arrive in M04/M09 as an IN_FLIGHT
## flavour of LOOSE.)
##
## The ball owns its own physics and out-of-bounds detection. It does NOT
## decide who gets it: PossessionController does.

signal carrier_changed(old_carrier: RugbyPlayer, new_carrier: RugbyPlayer)
signal released(by: RugbyPlayer, velocity: Vector3, reason: StringName)
signal bounced(speed: float, deflection: float, sat_up: bool)
signal went_dead(zone: FieldDimensions.Zone, point: Vector3)

enum State { LOOSE, HELD, DEAD }

var tuning: BallTuning
var state: State = State.LOOSE
var carrier: RugbyPlayer
var last_touched_by: RugbyPlayer
## Seeded randomness for bounces (deterministic tests / future replays).
var rng := RandomNumberGenerator.new()

var on_ground := false
var last_bounce_deflection := 0.0
var bounce_count := 0

var _prev_vel := Vector3.ZERO
var _pending_velocity: Variant = null
var _shape: SphereShape3D
var _material := PhysicsMaterial.new()


func setup(p_tuning: BallTuning, seed_value: int = 27) -> void:
	tuning = p_tuning
	rng.seed = seed_value
	_apply_tuning()


func _ready() -> void:
	if tuning == null:
		setup(BallTuning.new())
	process_physics_priority = 10   # after players moved this tick
	collision_layer = PhysicsLayers.BALL
	collision_mask = PhysicsLayers.WORLD
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	lock_rotation = true            # visual tumble is cosmetic (BallVisual)
	gravity_scale = 1.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	# We resolve bounce and rolling friction ourselves.
	_material.friction = 0.0
	_material.bounce = 0.0
	physics_material_override = _material
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var col := CollisionShape3D.new()
	col.name = "Collision"
	_shape = SphereShape3D.new()
	col.shape = _shape
	add_child(col)
	_apply_tuning()


func set_tuning(t: BallTuning) -> void:
	tuning = t
	_apply_tuning()


func _apply_tuning() -> void:
	mass = tuning.mass
	linear_damp = tuning.air_damp
	if _shape:
		_shape.radius = tuning.radius


# --- Possession API (called by PossessionController) -----------------------

func attach(p: RugbyPlayer) -> void:
	var old := carrier
	carrier = p
	last_touched_by = p
	state = State.HELD
	freeze = true
	linear_velocity = Vector3.ZERO
	on_ground = false
	_prev_vel = Vector3.ZERO
	_follow_carrier()
	carrier_changed.emit(old, p)


## Releases the ball into physics with an initial velocity.
func release(v: Vector3, reason: StringName) -> void:
	var by := carrier
	_detach()
	_go_loose(v)
	released.emit(by, v, reason)


## Releases the ball and places it at a ground point (e.g. tackled player).
func place(at: Vector3, reason: StringName) -> void:
	var by := carrier
	_detach()
	global_position = Vector3(at.x, tuning.radius, at.z)
	reset_physics_interpolation()
	_go_loose(Vector3.ZERO)
	released.emit(by, Vector3.ZERO, reason)


## Knocks a loose ball (fumbled pickup, dropped catch).
func knock(v: Vector3, by: RugbyPlayer, reason: StringName = &"fumble") -> void:
	last_touched_by = by
	_go_loose(v)
	released.emit(by, v, reason)


## Puts a loose ball at a position with a velocity (dev tools, restarts).
func spawn_loose(pos: Vector3, v: Vector3) -> void:
	_detach()
	global_position = pos
	reset_physics_interpolation()
	_go_loose(v)


func is_loose() -> bool:
	return state == State.LOOSE


func ball_velocity() -> Vector3:
	return _pending_velocity if _pending_velocity != null else linear_velocity


func carry_socket_position(p: RugbyPlayer) -> Vector3:
	var fwd := p.facing
	var right := Vector2(-fwd.y, fwd.x)
	var off := right * tuning.carry_side + fwd * tuning.carry_forward
	return p.global_position + Vector3(off.x, tuning.carry_height, off.y)


# --- Simulation --------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	match state:
		State.HELD:
			_follow_carrier()
			_check_out_held()
		State.LOOSE:
			_check_out_loose()
			if global_position.y < -5.0:  # safety net
				spawn_loose(Vector3(0, 1, 0), Vector3.ZERO)


func _integrate_forces(s: PhysicsDirectBodyState3D) -> void:
	if state != State.LOOSE:
		return
	if _pending_velocity != null:
		s.linear_velocity = _pending_velocity
		_prev_vel = _pending_velocity
		_pending_velocity = null
		on_ground = false
		return

	var v := s.linear_velocity
	var ground := false
	var dt := s.step
	for i in s.get_contact_count():
		var n := s.get_contact_local_normal(i)
		if n.y > 0.6:
			ground = true
		elif _prev_vel.dot(n) < -1.0:
			# Posts / walls: reflect the incoming normal component.
			var vn := _prev_vel.dot(n)
			v = _prev_vel - n * vn * (1.0 + tuning.wall_restitution)

	if ground and _prev_vel.y < -tuning.bounce_min_vy:
		var r := BounceModel.resolve(_prev_vel, rng, tuning)
		v = r.velocity
		last_bounce_deflection = r.deflection
		bounce_count += 1
		bounced.emit(-_prev_vel.y, r.deflection, r.sat_up)
	elif ground:
		var h := BounceModel.roll(Vector2(v.x, v.z), tuning, dt)
		v = Vector3(h.x, minf(maxf(v.y, 0.0), 0.5), h.y)

	on_ground = ground
	s.linear_velocity = v
	_prev_vel = v


func _follow_carrier() -> void:
	if carrier == null:
		return
	global_position = carry_socket_position(carrier)


func _check_out_held() -> void:
	var p := Vector2(carrier.global_position.x, carrier.global_position.z)
	var zone := FieldDimensions.zone_of(p)
	if FieldDimensions.is_out(zone):
		_go_dead(zone, Vector3(p.x, 0.0, p.y))


func _check_out_loose() -> void:
	# A ball in the air over touch is still in play until it lands (or hits
	# something) beyond the line.
	if not on_ground and global_position.y > tuning.radius + 0.06:
		return
	var p := Vector2(global_position.x, global_position.z)
	var zone := FieldDimensions.zone_of(p, tuning.radius)
	if FieldDimensions.is_out(zone):
		_go_dead(zone, Vector3(p.x, 0.0, p.y))


func _go_dead(zone: FieldDimensions.Zone, point: Vector3) -> void:
	_detach()
	state = State.DEAD
	freeze = true
	_pending_velocity = null
	global_position = Vector3(global_position.x, tuning.radius, global_position.z)
	went_dead.emit(zone, point)


func _go_loose(v: Vector3) -> void:
	state = State.LOOSE
	freeze = false
	sleeping = false
	on_ground = false
	_pending_velocity = v
	linear_velocity = v


func _detach() -> void:
	if carrier == null:
		return
	var old := carrier
	carrier = null
	carrier_changed.emit(old, null)
