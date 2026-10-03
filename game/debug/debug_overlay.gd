class_name DebugOverlay
extends CanvasLayer
## Toggleable developer overlay (F1).
##
## Text panel with the controlled player's simulation state, plus world-space
## vectors: velocity (green), input intent (yellow), facing (cyan), plant
## flash (red). Will grow to cover AI targets, lines, ruck state, etc.

var player: RugbyPlayer

var _label: Label
var _lines: MeshInstance3D
var _mesh: ImmediateMesh


func _ready() -> void:
	layer = 20
	visible = false
	var panel := PanelContainer.new()
	panel.offset_left = 16
	panel.offset_top = 16
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.65)
	bg.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(_label)

	_mesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_lines.material_override = mat
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lines.visible = false


func attach_world(world_root: Node3D) -> void:
	world_root.add_child(_lines)
	_lines.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func toggle() -> void:
	visible = not visible
	_lines.visible = visible


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	var m := player.locomotion_debug()
	var st := player.stats
	var a := player.profile.attributes
	_label.text = "\n".join([
		"RUGBY 27 · DEBUG  (F1)",
		"fps %d" % Engine.get_frames_per_second(),
		"",
		"player    %s (%s)" % [player.profile.short_label(), player.profile.position],
		"state     %s" % player.state_name(),
		"role      %s" % player.role_name(),
		"pos       (%.1f, %.1f)" % [player.global_position.x, player.global_position.z],
		"speed     %.2f m/s  target %.2f" % [player.current_speed(), m.last_target_speed],
		"sprint    %s   top %.2f  jog %.2f" % [str(player.is_sprinting), st.sprint_top, st.jog_top],
		"accel     %.1f m/s²  (measured %.1f)" % [st.accel, player.planar_accel.length()],
		"turn Δ    %.0f°   plant %s" % [rad_to_deg(m.last_turn_angle), str(m.last_planted)],
		"stamina   %.1f  fatigue x%.2f  locked %s" % [player.stamina.value, player.stamina.fatigue_multiplier(player.tuning), str(player.stamina.sprint_locked)],
		"",
		"attrs     spd %d  acc %d  sta %d  str %d" % [a.rating("speed"), a.rating("acceleration"), a.rating("stamina"), a.rating("strength")],
		"in field  %s" % str(FieldDimensions.in_field_of_play(Vector2(player.global_position.x, player.global_position.z))),
	])
	_draw_vectors(m)


func _draw_vectors(m: LocomotionModel) -> void:
	_mesh.clear_surfaces()
	var origin := player.get_global_transform_interpolated().origin + Vector3(0, 0.08, 0)
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var v := player.planar_velocity
	_line(origin, origin + Vector3(v.x, 0, v.y) * 0.5, Color.LIME_GREEN)
	var i := player.intent_dir()
	_line(origin + Vector3(0, 0.05, 0), origin + Vector3(0, 0.05, 0) + Vector3(i.x, 0, i.y) * 3.0, Color.YELLOW)
	var f := player.facing
	_line(origin + Vector3(0, 1.6, 0), origin + Vector3(0, 1.6, 0) + Vector3(f.x, 0, f.y) * 1.2, Color.CYAN)
	if m.last_planted:
		_line(origin, origin + Vector3(0, 2.4, 0), Color.RED)
	_mesh.surface_end()


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(b)
