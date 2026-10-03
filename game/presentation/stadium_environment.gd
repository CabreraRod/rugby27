class_name StadiumEnvironment
extends RefCounted
## Sky, light and a deliberately simple stadium bowl (Milestone 01 scope:
## "basic environment"). No logos, no real-world branding.

static func build(parent: Node3D) -> void:
	_build_world_environment(parent)
	_build_sun(parent)
	_build_stands(parent)


static func _build_world_environment(parent: Node3D) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.52, 0.82)
	sky_mat.sky_horizon_color = Color(0.72, 0.80, 0.88)
	sky_mat.ground_horizon_color = Color(0.55, 0.6, 0.6)
	sky_mat.ground_bottom_color = Color(0.2, 0.22, 0.2)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.03
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.78, 0.85)
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.4

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	parent.add_child(we)


static func _build_sun(parent: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# Afternoon sun, slightly behind the broadcast camera so faces read well.
	sun.rotation_degrees = Vector3(-48.0, 28.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_blur = 1.2
	parent.add_child(sun)


static func _build_stands(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Stadium"
	parent.add_child(root)

	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.46, 0.47, 0.5)
	concrete.roughness = 0.95
	var seats := StandardMaterial3D.new()
	seats.albedo_color = Color(0.17, 0.25, 0.42)
	seats.roughness = 0.85
	var boards_a := StandardMaterial3D.new()
	boards_a.albedo_color = Color(0.1, 0.12, 0.16)
	var boards_b := StandardMaterial3D.new()
	boards_b.albedo_color = Color(0.85, 0.32, 0.12)

	var hw := FieldDimensions.HALF_WIDTH
	var dead := FieldDimensions.dead_ball_x()

	# Perimeter boards (plain alternating panels).
	for side: float in [-1.0, 1.0]:
		var i := 0
		var x := -dead - 4.0
		while x < dead + 4.0:
			_box(root, Vector3(5.8, 0.9, 0.15), Vector3(x + 3.0, 0.45, side * (hw + 5.0)), boards_a if i % 2 == 0 else boards_b)
			x += 6.0
			i += 1

	# Side stands: stepped tiers along both touchlines.
	for side: float in [-1.0, 1.0]:
		for tier: int in 8:
			var z := side * (hw + 9.0 + tier * 1.6)
			var h := 0.8 + tier * 1.1
			_box(root, Vector3(dead * 2.0 + 10.0, h, 1.6), Vector3(0.0, h * 0.5, z), seats if tier % 2 == 0 else concrete)
		# Roof line.
		_box(root, Vector3(dead * 2.0 + 10.0, 0.6, 16.0), Vector3(0.0, 21.0, side * (hw + 22.0)), concrete)

	# End stands (lower).
	for side: float in [-1.0, 1.0]:
		for tier: int in 5:
			var x := side * (dead + 10.0 + tier * 1.6)
			var h := 0.8 + tier * 1.0
			_box(root, Vector3(1.6, h, hw * 2.0 + 6.0), Vector3(x, h * 0.5, 0.0), seats if tier % 2 == 0 else concrete)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
