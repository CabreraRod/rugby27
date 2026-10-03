class_name FieldBuilder
extends RefCounted
## Builds the pitch, goalposts and collision ground procedurally.

const PITCH_SHADER := preload("res://game/field/pitch.gdshader")
const GROUND_SIZE := Vector2(220.0, 170.0)


static func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Field"
	parent.add_child(root)
	_build_ground(root)
	_build_posts(root, 1.0)
	_build_posts(root, -1.0)
	return root


static func _build_ground(root: Node3D) -> void:
	# Collision: one large flat box. Players never leave Y = 0 in M01.
	var body := StaticBody3D.new()
	body.name = "Ground"
	root.add_child(body)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE.x, 1.0, GROUND_SIZE.y)
	col.shape = box
	col.position.y = -0.5
	body.add_child(col)

	# Visual: a single quad; all detail comes from the shader.
	var mi := MeshInstance3D.new()
	mi.name = "PitchSurface"
	var plane := PlaneMesh.new()
	plane.size = GROUND_SIZE
	mi.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = PITCH_SHADER
	mat.set_shader_parameter("half_length", FieldDimensions.HALF_LENGTH)
	mat.set_shader_parameter("in_goal", FieldDimensions.IN_GOAL)
	mat.set_shader_parameter("half_width", FieldDimensions.HALF_WIDTH)
	mat.set_shader_parameter("line_22_x", FieldDimensions.line_22_x())
	mat.set_shader_parameter("line_10_x", FieldDimensions.LINE_10_FROM_HALFWAY)
	mat.set_shader_parameter("line_5_try", FieldDimensions.LINE_5_FROM_TRY)
	mat.set_shader_parameter("line_5_touch", FieldDimensions.LINE_5_FROM_TOUCH)
	mat.set_shader_parameter("line_15_touch", FieldDimensions.LINE_15_FROM_TOUCH)
	mat.set_shader_parameter("line_width", FieldDimensions.LINE_WIDTH)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)


## H-shaped goalposts on the try line at x = side * HALF_LENGTH.
static func _build_posts(root: Node3D, side: float) -> void:
	var posts := Node3D.new()
	posts.name = "Posts_%s" % ("East" if side > 0.0 else "West")
	posts.position = Vector3(side * FieldDimensions.HALF_LENGTH, 0.0, 0.0)
	root.add_child(posts)

	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.96)
	white.roughness = 0.4
	var pad := StandardMaterial3D.new()
	pad.albedo_color = Color("#c8102e")
	pad.roughness = 0.8

	var half_gap := FieldDimensions.POST_GAP * 0.5 + FieldDimensions.POST_RADIUS
	for z: float in [-half_gap, half_gap]:
		var upright := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = FieldDimensions.POST_RADIUS
		cyl.bottom_radius = FieldDimensions.POST_RADIUS
		cyl.height = FieldDimensions.POST_HEIGHT
		cyl.radial_segments = 12
		upright.mesh = cyl
		upright.material_override = white
		upright.position = Vector3(0.0, FieldDimensions.POST_HEIGHT * 0.5, z)
		posts.add_child(upright)

		var protector := MeshInstance3D.new()
		var pcyl := CylinderMesh.new()
		pcyl.top_radius = 0.32
		pcyl.bottom_radius = 0.32
		pcyl.height = 2.0
		pcyl.radial_segments = 16
		protector.mesh = pcyl
		protector.material_override = pad
		protector.position = Vector3(0.0, 1.0, z)
		posts.add_child(protector)

		# Posts are solid: players must run around them.
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.32
		shape.height = 2.0
		col.shape = shape
		col.position = Vector3(0.0, 1.0, z)
		body.add_child(col)
		posts.add_child(body)

	var bar := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = FieldDimensions.POST_RADIUS * 0.85
	bcyl.bottom_radius = FieldDimensions.POST_RADIUS * 0.85
	bcyl.height = half_gap * 2.0
	bcyl.radial_segments = 12
	bar.mesh = bcyl
	bar.material_override = white
	bar.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	bar.position = Vector3(0.0, FieldDimensions.CROSSBAR_HEIGHT, 0.0)
	posts.add_child(bar)
