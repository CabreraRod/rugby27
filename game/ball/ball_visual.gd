class_name BallVisual
extends Node3D
## Oval ball mesh + cosmetic tumble + ground marker. Read-only view of RugbyBall.
##
## Physics uses a sphere with locked rotation; the oval shape and its
## end-over-end tumble are presentation only, so they can never make the
## simulation unfair.

const LENGTH_SCALE := 1.55   # long axis vs. short axis

var ball: RugbyBall

var _orient: Node3D          # rotation only (unit scale)
var _mesh: MeshInstance3D    # oval scale only
var _marker: MeshInstance3D
var _spin_axis := Vector3.RIGHT
var _spin_rate := 0.0


func _ready() -> void:
	_orient = Node3D.new()
	add_child(_orient)
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	var r := ball.tuning.radius * 0.88
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 20
	sm.rings = 10
	_mesh.mesh = sm
	_mesh.scale = Vector3(1.0, 1.0, LENGTH_SCALE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#f3efe4")
	mat.roughness = 0.55
	_mesh.material_override = mat
	_orient.add_child(_mesh)
	# Seam band so the tumble reads.
	var band := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r * 0.96
	torus.outer_radius = r * 1.04
	torus.rings = 24
	band.mesh = torus
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color("#c8102e")
	band.material_override = band_mat
	band.rotation_degrees = Vector3(90, 0, 0)
	band.scale = Vector3(1, 1, 0.35)
	_mesh.add_child(band)

	_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.28
	ring.rings = 24
	_marker.mesh = ring
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(1.0, 1.0, 1.0, 0.75)
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker.material_override = mmat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.scale = Vector3(1, 0.1, 1)
	_marker.top_level = true
	_marker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_marker)

	ball.bounced.connect(_on_bounced)
	ball.released.connect(_on_released)


func _on_bounced(speed: float, _deflection: float, _sat_up: bool) -> void:
	_spin_axis = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)).normalized()
	if _spin_axis.length_squared() < 0.01:
		_spin_axis = Vector3.RIGHT
	_spin_rate = clampf(speed * 2.2, 3.0, 22.0)


func _on_released(_by: RugbyPlayer, v: Vector3, _reason: StringName) -> void:
	var h := Vector3(v.x, 0, v.z)
	_spin_axis = Vector3.UP.cross(h).normalized() if h.length() > 0.2 else Vector3.RIGHT
	_spin_rate = clampf(v.length() * 2.0, 0.0, 15.0)


func _process(delta: float) -> void:
	var pos := ball.get_global_transform_interpolated().origin
	var b := _orient.basis.orthonormalized()
	match ball.state:
		RugbyBall.State.HELD:
			# Tucked: long axis along the carrier's facing, nose slightly up.
			var f := ball.carrier.facing
			var target := Basis.looking_at(Vector3(f.x, 0.35, f.y).normalized(), Vector3.UP)
			b = b.slerp(target, 1.0 - exp(-20.0 * delta))
			_spin_rate = 0.0
		RugbyBall.State.LOOSE:
			var v := ball.linear_velocity
			var h := Vector3(v.x, 0, v.z)
			if ball.on_ground and h.length() > 0.1:
				# Rolling: end-over-end around the axis perpendicular to travel.
				_spin_axis = Vector3.UP.cross(h).normalized()
				_spin_rate = h.length() / (ball.tuning.radius * 1.3)
			elif ball.on_ground:
				_spin_rate = lerpf(_spin_rate, 0.0, 1.0 - exp(-6.0 * delta))
				# Settle lying on its side.
				var flat := Basis(Vector3.UP, b.get_euler().y)
				b = b.slerp(flat, 1.0 - exp(-8.0 * delta))
			if _spin_rate > 0.01:
				b = b.rotated(_spin_axis, _spin_rate * delta)
		RugbyBall.State.DEAD:
			_spin_rate = 0.0
	_orient.basis = b.orthonormalized()

	# Ground marker: shows where a loose ball is; grows with height.
	_marker.visible = ball.state == RugbyBall.State.LOOSE
	_marker.global_position = Vector3(pos.x, 0.03, pos.z)
	var height_t := clampf(pos.y / 6.0, 0.0, 1.0)
	_marker.scale = Vector3(1.0 + height_t, 0.1, 1.0 + height_t)
