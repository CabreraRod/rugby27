class_name MatchHud
extends CanvasLayer
## Minimal in-match HUD: controlled player, stamina, speed, possession, notices.
## Controls hint fades out after a few seconds.

const HINT_TIME := 9.0

var player: RugbyPlayer
var ball: RugbyBall
var team_control: TeamControl

var _name_label: Label
var _speed_label: Label
var _stamina_bar: ProgressBar
var _stamina_fill: StyleBoxFlat
var _hint: Label
var _hint_timer := HINT_TIME
var _ball_tag: Label
var _notice: Label
var _notice_timer := 0.0
var _notice_duration := 1.0
var _phase_label: Label


func _ready() -> void:
	layer = 10
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24
	panel.offset_top = -118
	panel.offset_bottom = -24
	panel.offset_right = 344
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.07, 0.1, 0.78)
	bg.set_corner_radius_all(6)
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	bg.content_margin_top = 8
	bg.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var row := HBoxContainer.new()
	v.add_child(row)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_label)
	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override("font_size", 16)
	_speed_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	row.add_child(_speed_label)

	var tags := HBoxContainer.new()
	v.add_child(tags)
	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 14)
	_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tags.add_child(_phase_label)
	_ball_tag = Label.new()
	_ball_tag.text = "● BALL"
	_ball_tag.add_theme_font_size_override("font_size", 14)
	_ball_tag.add_theme_color_override("font_color", Color("#ffd23f"))
	tags.add_child(_ball_tag)

	_stamina_bar = ProgressBar.new()
	_stamina_bar.show_percentage = false
	_stamina_bar.custom_minimum_size = Vector2(0, 12)
	_stamina_bar.max_value = 1.0
	_stamina_bar.step = 0.001
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(3)
	_stamina_fill = StyleBoxFlat.new()
	_stamina_fill.bg_color = Color("#4cd47a")
	_stamina_fill.set_corner_radius_all(3)
	_stamina_bar.add_theme_stylebox_override("background", track)
	_stamina_bar.add_theme_stylebox_override("fill", _stamina_fill)
	v.add_child(_stamina_bar)

	_hint = Label.new()
	_hint.text = "Move: WASD / L-stick   Sprint: Shift / RT   Pass: Q / E · LB / RB (hold = long)   Fend: V / X   Sidestep: Z / X key · R-stick flick\nDefending: run into the carrier to tackle · Dive: Space / A · Switch: Q / E · LB / RB      Camera C · Debug F1 · Sandbox F2 · Reset R"
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.offset_left = -700
	_hint.offset_right = 700
	_hint.offset_top = 18
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_hint)

	_notice = Label.new()
	_notice.anchor_left = 0.5
	_notice.anchor_right = 0.5
	_notice.anchor_top = 0.28
	_notice.offset_left = -400
	_notice.offset_right = 400
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_font_size_override("font_size", 46)
	_notice.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_notice.add_theme_constant_override("shadow_offset_x", 2)
	_notice.add_theme_constant_override("shadow_offset_y", 2)
	_notice.visible = false
	add_child(_notice)


## Short centre-screen message (TOUCH, FUMBLED, ...). Never pauses play.
func notify(text: String, color: Color = Color.WHITE, duration: float = 1.2) -> void:
	_notice.text = text
	_notice.add_theme_color_override("font_color", color)
	_notice_duration = maxf(duration, 0.2)
	_notice_timer = _notice_duration
	_notice.visible = true


func _process(delta: float) -> void:
	if player == null:
		return
	var p := player.profile
	_name_label.text = "%s  ·  %s" % [p.short_label(), p.position]
	_speed_label.text = "%4.1f km/h" % (player.current_speed() * 3.6)
	var st := player.stamina
	_stamina_bar.value = st.ratio()
	var col := Color("#4cd47a")
	if st.sprint_locked:
		col = Color("#e5484d")
	elif st.value < player.tuning.fatigue_threshold:
		col = Color("#f5a524")
	_stamina_fill.bg_color = col

	if team_control:
		match team_control.phase:
			TeamControl.Phase.ATTACK:
				_phase_label.text = "ATTACK"
				_phase_label.add_theme_color_override("font_color", Color("#7cff6b"))
			TeamControl.Phase.DEFEND:
				_phase_label.text = "DEFENCE  ·  A dive  ·  LB/RB switch"
				_phase_label.add_theme_color_override("font_color", Color("#ff8a8f"))
			_:
				_phase_label.text = "LOOSE BALL"
				_phase_label.add_theme_color_override("font_color", Color("#ffd23f"))
	# Alpha (not visibility) so the panel layout never jumps.
	_ball_tag.modulate.a = 1.0 if ball != null and ball.carrier == player else 0.0
	if _notice_timer > 0.0:
		_notice_timer -= delta
		_notice.modulate.a = clampf(_notice_timer / 0.3, 0.0, 1.0)
		_notice.visible = _notice_timer > 0.0

	if _hint_timer > 0.0:
		_hint_timer -= delta
		_hint.modulate.a = clampf(_hint_timer / 1.5, 0.0, 1.0)
