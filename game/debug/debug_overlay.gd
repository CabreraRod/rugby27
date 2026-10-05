class_name DebugOverlay
extends CanvasLayer
## Toggleable developer overlay (F1).
##
## Text panel with the controlled player's and the ball's state, plus
## world-space drawing: velocity (green), input intent (yellow), facing
## (cyan), plant flash (red), pickup reach (white), predicted ball flight
## until the next ground contact (orange), support slots (blue) and the
## pass in flight: aim point and the release line across the pitch (green =
## legal, red = forward), defensive assignments (red = pursuer on the
## carrier, pink = marking, purple = sweeper; faint line to the mark) and
## loose-ball chasers (yellow). Will grow to cover AI targets, defensive/offside
## lines, ruck state, etc.

var player: RugbyPlayer
var ball: RugbyBall
var possession: PossessionController
var passing: PassingSystem
var team_control: TeamControl
var opp_control: TeamControl

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
		"zone      %s" % FieldDimensions.Zone.keys()[FieldDimensions.zone_of(Vector2(player.global_position.x, player.global_position.z))],
		"",
	] + _ball_lines())
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
	if ball:
		_circle(Vector3(origin.x, 0.05, origin.z), ball.tuning.pickup_reach, Color(1, 1, 1, 0.6))
		if ball.is_loose():
			_draw_prediction()
	_draw_passing()
	_mesh.surface_end()


func _draw_passing() -> void:
	if team_control:
		for runner in team_control.slots.keys():
			var slot: Vector2 = team_control.slots[runner]
			var rp: Vector3 = runner.get_global_transform_interpolated().origin
			var sp := Vector3(slot.x, 0.06, slot.y)
			_circle(sp, 0.4, Color("#4ea8ff"))
			_line(Vector3(rp.x, 0.06, rp.z), sp, Color(0.3, 0.65, 1.0, 0.5))
	for c in [team_control, opp_control]:
		if c == null:
			continue
		for asg in c.assignments:
			var dp: Vector3 = asg.defender.get_global_transform_interpolated().origin
			var tp := Vector3(asg.target.x, 0.06, asg.target.y)
			var col := Color("#ff5a5f") if asg.role == &"pursue" else (Color("#c77dff") if asg.role == &"sweep" else Color("#ff9f9f"))
			_circle(tp, 0.35, col)
			_line(Vector3(dp.x, 0.06, dp.z), tp, col)
			if asg.mark:
				var mp: Vector3 = asg.mark.get_global_transform_interpolated().origin
				_line(Vector3(dp.x, 1.0, dp.z), Vector3(mp.x, 1.0, mp.z), Color(1, 0.4, 0.4, 0.35))
		if c.chaser:
			var cp: Vector3 = c.chaser.get_global_transform_interpolated().origin
			_line(Vector3(cp.x, 0.1, cp.z), Vector3(ball.global_position.x, 0.1, ball.global_position.z), Color("#ffd23f"))
	if passing and passing.in_flight:
		var a := passing.flight_aim
		_circle(Vector3(a.x, 0.07, a.z), 0.55, Color("#ffd23f"))
		_line(Vector3(a.x, 0.07, a.z), a, Color("#ffd23f"))
		var x := passing.flight_release_pos.x
		var col := Color("#ff5a5f") if passing.flight_forward else Color("#7cff6b")
		_line(Vector3(x, 0.08, -FieldDimensions.HALF_WIDTH), Vector3(x, 0.08, FieldDimensions.HALF_WIDTH), col)


func _ball_lines() -> Array:
	if ball == null:
		return []
	var v := ball.ball_velocity()
	var who := ball.carrier.profile.short_label() if ball.carrier else "-"
	var last := ball.last_touched_by.profile.short_label() if ball.last_touched_by else "-"
	var lines := [
		"ball      %s   carrier %s" % [RugbyBall.State.keys()[ball.state], who],
		"ball pos  (%.1f, %.2f, %.1f)  speed %.1f m/s" % [ball.global_position.x, ball.global_position.y, ball.global_position.z, v.length()],
		"ball      on_ground %s  bounces %d  last defl %.0f°" % [str(ball.on_ground), ball.bounce_count, rad_to_deg(ball.last_bounce_deflection)],
		"last touch %s" % last,
	]
	if possession and ball.is_loose():
		lines.append("pickup    chance now %.0f%%" % (possession.pickup_chance(player) * 100.0))
	if team_control:
		lines.append("phase     %s" % TeamControl.Phase.keys()[team_control.phase])
	if passing:
		lines.append("")
		if passing.charging:
			lines.append("pass      charging %s %.2fs %s" % ["LEFT" if passing.charge_side == PassTargeting.LEFT else "RIGHT", passing.charge_time, "LONG" if passing.is_long_charge() else "quick"])
		if passing.in_flight:
			var r := passing.flight_receiver.profile.short_label() if passing.flight_receiver else "space"
			lines.append("pass      → %s  T %.2fs  fwd %.2f m/s %s" % [r, passing.flight_time, passing.flight_forward_speed, "FORWARD" if passing.flight_forward else "ok"])
		elif not passing.charging:
			lines.append("pass      -")
	return lines


## Ballistic prediction (gravity + air damping) until the ball reaches the ground.
func _draw_prediction() -> void:
	var p := ball.get_global_transform_interpolated().origin
	var v := ball.ball_velocity()
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var dt := 1.0 / 30.0
	var col := Color("#ff9f1c")
	for i in 120:
		var nv := v + Vector3(0, -g * dt, 0)
		nv *= maxf(0.0, 1.0 - ball.tuning.air_damp * dt)
		var np := p + nv * dt
		if np.y <= ball.tuning.radius:
			np.y = ball.tuning.radius
			_line(p, np, col)
			_circle(Vector3(np.x, 0.06, np.z), 0.35, col)
			return
		_line(p, np, col)
		p = np
		v = nv


func _circle(c: Vector3, r: float, col: Color) -> void:
	var seg := 24
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		_line(c + Vector3(cos(a0), 0, sin(a0)) * r, c + Vector3(cos(a1), 0, sin(a1)) * r, col)


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(b)
