class_name PassMarkers
extends Node3D
## Floating labels over the receiver each pass button would hit right now.
##
##   white  = quick pass target
##   yellow = target of the pass being charged (moves out on a long hold)
##   red    = that pass would likely be forward (receiver ahead of the ball)
## Pure presentation: reads PassingSystem / TeamControl, never writes.

var passing: PassingSystem
var control: TeamControl

var _labels: Array[Label3D] = []
const TEXT := ["◀ Q · LB", "RB · E ▶"]


func _ready() -> void:
	for i in 2:
		var l := Label3D.new()
		l.text = TEXT[i]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0011
		l.font_size = 24
		l.outline_size = 10
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.top_level = true
		l.visible = false
		add_child(l)
		_labels.append(l)


func _process(_delta: float) -> void:
	var carrier := control.controlled if control else null
	var show := carrier != null and passing.ball.carrier == carrier and carrier.team != null
	for side in 2:
		var l := _labels[side]
		if not show:
			l.visible = false
			continue
		var charging_this := passing.charging and passing.charge_side == side
		var target := passing.preview(carrier, side, charging_this and passing.is_long_charge())
		if target == null:
			l.visible = false
			continue
		l.visible = true
		var pos := target.get_global_transform_interpolated().origin
		l.global_position = pos + Vector3(0, 2.95, 0)
		var ahead := PassTargeting.ahead_of(carrier.planar_position(), target.planar_position(), carrier.team.attack())
		var col := Color.WHITE
		if ahead > 0.3:
			col = Color("#ff5a5f")
		elif charging_this:
			col = Color("#ffd23f")
		l.modulate = col
		l.font_size = 30 if charging_this else 24
