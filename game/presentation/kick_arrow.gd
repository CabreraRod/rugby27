class_name KickArrow
extends Node3D
## Rugby 08's blue kick arrow: while the human charges a kick, a flat arrow
## on the pitch grows from the kicker toward where the ball will land (the
## drop goal points at the posts). While a kick is in the air, a ring marks
## where it comes down. Pure presentation: reads KickSystem / TeamControl.

const COLOR := Color(0.25, 0.55, 1.0, 0.75)
const RING := Color(1.0, 0.82, 0.25, 0.85)

var kicks: KickSystem
var control: TeamControl

var _mesh := ImmediateMesh.new()


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	if kicks == null:
		return
	var mine := control != null and kicks.charging and kicks.charge_kicker == control.controlled
	if mine:
		var pv: Array = kicks.preview()
		var from := kicks.charge_kicker.planar_position()
		var to: Vector2 = pv[0]
		_arrow(from, to)
	if kicks.in_flight:
		_ring(kicks.catch_point, 0.9)


func _arrow(from: Vector2, to: Vector2) -> void:
	var d := to - from
	var length := d.length()
	if length < 0.5:
		return
	var f := d / length
	var side := Vector2(-f.y, f.x)
	var start := from + f * 0.8
	var head := maxf(length - 2.2, 0.8)
	var w := 0.35
	var y := 0.06
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := start + side * w
	var b := start - side * w
	var c := from + f * head + side * w
	var e := from + f * head - side * w
	for q in [a, b, c, b, e, c]:
		_v(q, y, COLOR)
	var tip := to
	for q in [from + f * head + side * 1.0, from + f * head - side * 1.0, tip]:
		_v(q, y, COLOR)
	_mesh.surface_end()


func _ring(c: Vector2, r: float) -> void:
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 28
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var o0 := c + Vector2(cos(a0), sin(a0)) * r
		var o1 := c + Vector2(cos(a1), sin(a1)) * r
		var i0 := c + Vector2(cos(a0), sin(a0)) * (r - 0.18)
		var i1 := c + Vector2(cos(a1), sin(a1)) * (r - 0.18)
		for q in [o0, i0, o1, i0, i1, o1]:
			_v(q, 0.06, RING)
	_mesh.surface_end()


func _v(p: Vector2, y: float, col: Color) -> void:
	_mesh.surface_set_color(col)
	_mesh.surface_add_vertex(Vector3(p.x, y, p.y))
