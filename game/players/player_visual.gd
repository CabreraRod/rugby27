class_name PlayerVisual
extends Node3D
## Procedural placeholder body + procedural animation.
##
## Pure presentation: reads RugbyPlayer state, never writes it. Built from
## primitive meshes so the project has zero third-party assets. Will be
## replaced by a skinned character + AnimationTree later; the contract
## (read-only view of RugbyPlayer) stays the same.
##
## Model forward is -Z (Godot convention).

const HIP_HEIGHT := 0.95
const LEG_LENGTH := 0.92
const ARM_LENGTH := 0.68
const SHOULDER_HEIGHT := 1.5

var player: RugbyPlayer

var _rig: Node3D        # yaw
var _lean: Node3D       # pitch/roll, pivots at the feet
var _body: Node3D       # bob
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _ring: MeshInstance3D
var _ring_pointer: MeshInstance3D

var _phase := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _ground_blend := 0.0
var _carry_blend := 0.0
var _dive_blend := 0.0
var _ruck_blend := 0.0
var _number: Label3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_build()
	if player:
		_yaw = _facing_to_yaw(player.facing)


func _build() -> void:
	var c := player.team_colors if player else {}
	var jersey := _mat(c.get("jersey", Color("#1f4fa3")))
	var shorts := _mat(c.get("shorts", Color.WHITE))
	var socks := _mat(c.get("socks", Color("#1f4fa3")))
	var skin := _mat(Color("#c99a78"))
	var boots := _mat(Color("#1a1a1a"))

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_lean = Node3D.new()
	_lean.name = "Lean"
	_rig.add_child(_lean)
	_body = Node3D.new()
	_body.name = "Body"
	_lean.add_child(_body)

	# Torso (jersey) — slightly broad, rugby build.
	var torso := _capsule(0.27, 0.78, jersey)
	torso.position = Vector3(0, 1.28, 0)
	torso.scale = Vector3(1.25, 1.0, 0.85)
	_body.add_child(torso)
	# Shorts.
	var hips := _box(Vector3(0.52, 0.26, 0.32), shorts)
	hips.position = Vector3(0, HIP_HEIGHT, 0)
	_body.add_child(hips)
	# Head + neck.
	var neck := _capsule(0.09, 0.2, skin)
	neck.position = Vector3(0, 1.7, 0)
	_body.add_child(neck)
	var head := _sphere(0.13, skin)
	head.position = Vector3(0, 1.84, -0.01)
	_body.add_child(head)

	_leg_l = _limb(Vector3(-0.14, HIP_HEIGHT - 0.06, 0), LEG_LENGTH, 0.085, skin, socks, boots)
	_leg_r = _limb(Vector3(0.14, HIP_HEIGHT - 0.06, 0), LEG_LENGTH, 0.085, skin, socks, boots)
	_arm_l = _limb(Vector3(-0.36, SHOULDER_HEIGHT, 0), ARM_LENGTH, 0.06, jersey, skin, skin)
	_arm_r = _limb(Vector3(0.36, SHOULDER_HEIGHT, 0), ARM_LENGTH, 0.06, jersey, skin, skin)

	# Control indicator: ring + pointer showing facing (readability first).
	var ind_mat := StandardMaterial3D.new()
	ind_mat.albedo_color = c.get("indicator", Color("#ffd23f"))
	ind_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ind_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ind_mat.albedo_color.a = 0.9
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.56
	torus.outer_radius = 0.64
	torus.rings = 32
	_ring.mesh = torus
	_ring.material_override = ind_mat
	_ring.position.y = 0.03
	_ring.scale = Vector3(1, 0.15, 1)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rig.add_child(_ring)
	_ring_pointer = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.28, 0.3, 0.02)
	_ring_pointer.mesh = prism
	_ring_pointer.material_override = ind_mat
	_ring_pointer.rotation_degrees = Vector3(-90, 0, 0)
	_ring_pointer.position = Vector3(0, 0.03, -0.82)
	_ring_pointer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rig.add_child(_ring_pointer)

	# Shirt number over the head (readability with several players).
	_number = Label3D.new()
	_number.text = str(player.profile.number) if player else ""
	_number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_number.fixed_size = true
	_number.pixel_size = 0.0009
	_number.font_size = 26
	_number.outline_size = 8
	_number.outline_modulate = Color(0, 0, 0, 0.8)
	_number.position = Vector3(0, 2.2, 0)
	_number.no_depth_test = true
	add_child(_number)


## Limb pivoting at `origin`, hanging down: upper segment, lower segment, end.
func _limb(origin: Vector3, length: float, radius: float, upper_mat: Material, lower_mat: Material, end_mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = origin
	_body.add_child(pivot)
	var upper := _capsule(radius * 1.15, length * 0.55, upper_mat)
	upper.position.y = -length * 0.25
	pivot.add_child(upper)
	var lower := _capsule(radius, length * 0.55, lower_mat)
	lower.position.y = -length * 0.68
	pivot.add_child(lower)
	var end := _box(Vector3(radius * 2.2, radius * 1.4, radius * 3.2), end_mat)
	end.position = Vector3(0, -length + radius * 0.7, -radius * 0.8)
	pivot.add_child(end)
	return pivot


func _process(delta: float) -> void:
	if player == null:
		return
	var spd := player.current_speed()
	var top := maxf(player.stats.sprint_top, 0.1)
	var speed_t := clampf(spd / top, 0.0, 1.0)

	# Yaw follows facing (already rate-limited in the simulation).
	var target_yaw := _facing_to_yaw(player.facing)
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-25.0 * delta))
	_rig.rotation.y = _yaw

	# Lean from acceleration expressed in the body frame.
	var fwd := player.facing
	var side := Vector2(-fwd.y, fwd.x)
	var a := player.planar_accel
	var a_fwd := a.dot(fwd)
	var a_side := a.dot(side)
	var target_pitch := clampf(-(a_fwd * 0.022 + speed_t * 0.16), -0.42, 0.18)
	# Lean into the turn: centripetal accel to the right -> top tilts right (-Z roll).
	var target_roll := clampf(-a_side * 0.028, -0.35, 0.35)
	var k := 1.0 - exp(-10.0 * delta)
	_pitch = lerpf(_pitch, target_pitch, k)
	_roll = lerpf(_roll, target_roll, k)

	# Grounded pose blend.
	var grounded := 1.0 if player.state == RugbyPlayer.State.GROUNDED else 0.0
	var ground_rate := 9.0 if grounded > 0.5 else 3.2
	_ground_blend = lerpf(_ground_blend, grounded, 1.0 - exp(-ground_rate * delta))
	# Dive: throw the body forward (blends into the grounded pose).
	var dive := 1.0 if player.state == RugbyPlayer.State.DIVING else 0.0
	_dive_blend = lerpf(_dive_blend, dive, 1.0 - exp(-16.0 * delta))
	var pitch := lerpf(_pitch, -1.1, _dive_blend)
	# Bound in a ruck: bent at the hips, driving forward (M08 placeholder pose).
	var rucking := 1.0 if player.state == RugbyPlayer.State.RUCKING else 0.0
	_ruck_blend = lerpf(_ruck_blend, rucking, 1.0 - exp(-12.0 * delta))
	pitch = lerpf(pitch, -0.95, _ruck_blend)
	_lean.rotation = Vector3(lerpf(pitch, -1.45, _ground_blend), 0.0, _roll * (1.0 - _ground_blend))

	# Stride cycle: frequency rises with speed, stride lengthens.
	var stride_len := 1.1 + speed_t * 1.3
	_phase = fmod(_phase + (spd / stride_len) * PI * delta, TAU)
	var amp := clampf(spd / 2.5, 0.0, 1.0) * lerpf(0.45, 0.85, speed_t) * (1.0 - _ground_blend)
	var s := sin(_phase)
	_leg_l.rotation.x = s * amp
	_leg_r.rotation.x = -s * amp
	_arm_l.rotation.x = -s * amp * 0.9
	_arm_r.rotation.x = s * amp * 0.9
	_arm_l.rotation.z = -0.12
	_arm_r.rotation.z = 0.12
	# Ball carrier: right arm tucked around the ball (ball sits on the right).
	var carry := 1.0 if player.role == RugbyPlayer.Role.BALL_CARRIER else 0.0
	_carry_blend = lerpf(_carry_blend, carry, 1.0 - exp(-14.0 * delta))
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.75, _carry_blend)
	_arm_r.rotation.z = lerpf(0.12, -0.25, _carry_blend)
	_body.position.y = absf(cos(_phase)) * 0.06 * amp - 0.03 * amp
	if _ruck_blend > 0.05:
		# Arms bound over the next man.
		_arm_l.rotation = _arm_l.rotation.lerp(Vector3(1.35, 0.0, 0.3), _ruck_blend)
		_arm_r.rotation = _arm_r.rotation.lerp(Vector3(1.35, 0.0, -0.3), _ruck_blend)
	_apply_action_pose()

	# Indicator only on the controlled player; hidden when grounded.
	_ring.visible = _ground_blend < 0.5 and player.is_controlled
	_ring_pointer.visible = _ring.visible
	_number.text = str(player.profile.number)
	_number.modulate = Color("#ffd23f") if player.is_controlled else Color.WHITE
	# Follow the body down when the player is on the ground (the lean pivots
	# the body toward local -Z, so the head ends up about 1 m that way).
	_number.position = Vector3(0, 2.2, 0).lerp(Vector3(0, 0.6, -1.0), _ground_blend)


## Short procedural overlays for passes and catches (cosmetic, never blocks).
func _apply_action_pose() -> void:
	var t := player.action_progress()
	match player.action:
		&"pass_left", &"pass_right":
			# Both hands forward, sweeping across the body toward the target.
			var dir := -1.0 if player.action == &"pass_left" else 1.0
			var sweep := lerpf(-0.6, 0.9, t) * dir
			var lift := sin(t * PI) * 0.4 + 1.0
			_arm_l.rotation = Vector3(lift, 0.0, sweep - 0.2)
			_arm_r.rotation = Vector3(lift, 0.0, sweep + 0.2)
		&"catch":
			var reach := 1.3 * (1.0 - t * 0.5)
			_arm_l.rotation = Vector3(reach, 0.0, 0.25)
			_arm_r.rotation = Vector3(reach, 0.0, -0.25)
		&"dive", &"tackle":
			# Arms wrapping forward.
			_arm_l.rotation = Vector3(1.5, 0.0, 0.35)
			_arm_r.rotation = Vector3(1.5, 0.0, -0.35)
		&"fend":
			# Free (left) arm locked straight out at the tackler.
			var punch := sin(clampf(t * 1.6, 0.0, 1.0) * PI * 0.5)
			_arm_l.rotation = Vector3(lerpf(0.2, 1.55, punch), 0.0, 0.05)
		&"tackled":
			_arm_l.rotation = Vector3(2.2, 0.0, -0.4)


static func _facing_to_yaw(f: Vector2) -> float:
	# Rotate model forward (-Z) onto world direction (f.x, 0, f.y).
	return atan2(-f.x, -f.y)


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	return m


static func _capsule(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(height, radius * 2.0)
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = mat
	return mi


static func _sphere(radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	return mi


static func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	return mi
