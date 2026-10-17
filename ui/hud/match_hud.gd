class_name MatchHud
extends CanvasLayer
## Minimal in-match HUD: controlled player, stamina, speed, possession, notices.
## Controls hint fades out after a few seconds.

const HINT_TIME := 9.0

var player: RugbyPlayer
var ball: RugbyBall
var team_control: TeamControl
var rucks: RuckSystem
var kicks: KickSystem


## Kick charge meter: fill, and for the drop goal the sweet spot in green.
class KickMeter extends Control:
	var charge := 0.0
	var sweet := -1.0
	var window := 0.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1, 1, 1, 0.14))
		if sweet >= 0.0:
			var z := Rect2(Vector2(size.x * (sweet - window), 0), Vector2(size.x * window * 2.0, size.y))
			draw_rect(z, Color(0.3, 0.85, 0.45, 0.55))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(charge, 0.0, 1.0), size.y)), Color(0.25, 0.55, 1.0, 0.9))
		if sweet >= 0.0:
			var x := size.x * clampf(charge, 0.0, 1.0)
			draw_line(Vector2(x, -3), Vector2(x, size.y + 3), Color.WHITE, 2.0)


var _kick_box: VBoxContainer
var _kick_label: Label
var _kick_meter: KickMeter

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
	_hint.text = "Move: WASD / L-stick   Sprint: Shift / RT   Pass: Q / E · LB / RB (hold = long)   Fend: LT+A · Ctrl+Space   Sidestep: Z / X key · R-stick flick\nKick (hold, aim with the stick, release): long ✕ A Space · high □ X V · grubber △ Y F (box kick for the 9 at a ruck) · drop ○ B G\nDefending: run into the carrier to tackle · Dive: Space / A · Switch: Q / E · LB / RB\nRuck: X (PS) · A (Xbox) · Space: commit a player · □ (PS) · X (Xbox) · V: hold the ball in (defence, risks a penalty)      Camera C · Debug F1 · Sandbox F2 · Reset R"
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

	_kick_box = VBoxContainer.new()
	_kick_box.anchor_left = 0.5
	_kick_box.anchor_right = 0.5
	_kick_box.anchor_top = 1.0
	_kick_box.anchor_bottom = 1.0
	_kick_box.offset_left = -170
	_kick_box.offset_right = 170
	_kick_box.offset_top = -96
	_kick_box.offset_bottom = -40
	_kick_box.visible = false
	add_child(_kick_box)
	_kick_label = Label.new()
	_kick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kick_label.add_theme_font_size_override("font_size", 18)
	_kick_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_kick_box.add_child(_kick_label)
	_kick_meter = KickMeter.new()
	_kick_meter.custom_minimum_size = Vector2(340, 14)
	_kick_box.add_child(_kick_meter)

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


func _update_kick_meter() -> void:
	var show := kicks != null and kicks.charging and kicks.charge_kicker == player
	_kick_box.visible = show
	if not show:
		return
	var pv: Array = kicks.preview()
	_kick_meter.charge = kicks.charge()
	if kicks.charge_type == KickModel.Type.DROP:
		_kick_meter.sweet = kicks.tuning.drop_sweet
		_kick_meter.window = KickModel.drop_window(player.profile.attributes.norm("kicking"), pv[1], kicks.tuning)
		_kick_label.text = "DROP GOAL  ·  %d m  ·  release in the green" % int(pv[1])
	else:
		_kick_meter.sweet = -1.0
		_kick_label.text = "%s  ·  %d m" % [KickModel.type_name(kicks.charge_type), int(pv[1])]
	_kick_meter.queue_redraw()


## "RUCK  2 v 1  ·  ✕ commit  ·  □ hold" — our bodies first.
func _ruck_text() -> String:
	if rucks == null or not rucks.is_active():
		return "RUCK"
	var us := team_control.team
	var them := team_control.opponents
	var s := "RUCK  %d v %d  ·  X/Space commit" % [rucks.count(us), rucks.count(them)]
	if rucks.defence == us:
		s += "  ·  □/V hold" + ("  HOLDING %.1fs" % rucks.held_time if rucks.holding else "")
	elif rucks.holding:
		s += "  ·  ball held in"
	return s


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
			TeamControl.Phase.RUCK:
				_phase_label.text = _ruck_text()
				_phase_label.add_theme_color_override("font_color", Color("#9ad1ff"))
			_:
				_phase_label.text = "LOOSE BALL"
				_phase_label.add_theme_color_override("font_color", Color("#ffd23f"))
	_update_kick_meter()
	# Alpha (not visibility) so the panel layout never jumps.
	_ball_tag.modulate.a = 1.0 if ball != null and ball.carrier == player else 0.0
	if _notice_timer > 0.0:
		_notice_timer -= delta
		_notice.modulate.a = clampf(_notice_timer / 0.3, 0.0, 1.0)
		_notice.visible = _notice_timer > 0.0

	if _hint_timer > 0.0:
		_hint_timer -= delta
		_hint.modulate.a = clampf(_hint_timer / 1.5, 0.0, 1.0)
