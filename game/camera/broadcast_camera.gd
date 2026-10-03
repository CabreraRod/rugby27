class_name BroadcastCamera
extends Camera3D
## Broadcast-style rugby camera.
##
## Milestone 01: follows a single focus target with velocity look-ahead,
## critically-damped smoothing and speed-based zoom. It frames the space the
## player is running INTO rather than locking onto the player.
##
## Later milestones swap the single target for a "focus solver" (ball,
## attacking line, defensive line) — the framing/smoothing code stays.

enum Mode {
	SIDE,    ## Classic TV angle from the stand, side-on to play.
	END_ON,  ## Behind the attacking direction (+X).
}

@export var side_offset := Vector3(0.0, 10.0, 18.5)
@export var end_offset := Vector3(-16.0, 8.5, 0.0)
## Seconds of velocity to look ahead.
@export var lead_time := 0.55
@export var max_lead := 5.0
## Focus smoothing (seconds to settle).
@export var smooth_time := 0.22
## Extra distance at full sprint (fraction of offset).
@export var speed_zoom := 0.14
## Focus is clamped to this rectangle (pitch + in-goals + margin).
@export var focus_limit := Vector2(64.0, 33.0)

var target: RugbyPlayer
var mode: Mode = Mode.SIDE

var _focus := Vector3.ZERO
var _focus_vel := Vector3.ZERO
var _offset := Vector3.ZERO
var _zoom := 0.0


func _ready() -> void:
	fov = 48.0
	near = 0.2
	far = 700.0
	_offset = side_offset
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func snap() -> void:
	if target == null:
		return
	_focus = target.global_position
	_focus_vel = Vector3.ZERO
	_offset = _mode_offset()
	_apply()


func toggle_mode() -> void:
	mode = Mode.END_ON if mode == Mode.SIDE else Mode.SIDE


func _process(delta: float) -> void:
	if target == null or delta <= 0.0:
		return
	var tpos := target.get_global_transform_interpolated().origin
	var v := Vector3(target.planar_velocity.x, 0.0, target.planar_velocity.y)
	var lead := (v * lead_time).limit_length(max_lead)
	var desired := tpos + lead
	desired.x = clampf(desired.x, -focus_limit.x, focus_limit.x)
	desired.z = clampf(desired.z, -focus_limit.y, focus_limit.y)
	desired.y = 0.0

	_focus = _smooth_damp(_focus, desired, delta)
	var speed_t := clampf(v.length() / 9.5, 0.0, 1.0)
	_zoom = lerpf(_zoom, speed_t, 1.0 - exp(-1.5 * delta))
	_offset = _offset.lerp(_mode_offset(), 1.0 - exp(-3.0 * delta))
	_apply()


func _apply() -> void:
	global_position = _focus + _offset * (1.0 + speed_zoom * _zoom)
	look_at(_focus + Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _mode_offset() -> Vector3:
	return side_offset if mode == Mode.SIDE else end_offset


## [right, forward] unit vectors on the ground plane (x = world X, y = world Z).
func ground_axes() -> Array[Vector2]:
	var b := global_basis
	var right := Vector2(b.x.x, b.x.z)
	var fwd := Vector2(-b.z.x, -b.z.z)
	if right.length_squared() < 1e-6 or fwd.length_squared() < 1e-6:
		return [Vector2(1, 0), Vector2(0, -1)]
	return [right.normalized(), fwd.normalized()]


## Critically damped spring (Game Programming Gems 4, "Critically Damped Ease-In/Out").
func _smooth_damp(current: Vector3, goal: Vector3, dt: float) -> Vector3:
	var omega := 2.0 / maxf(smooth_time, 0.0001)
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - goal
	var temp := (_focus_vel + change * omega) * dt
	_focus_vel = (_focus_vel - temp * omega) * e
	return goal + (change + temp) * e
