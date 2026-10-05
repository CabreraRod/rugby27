class_name HumanController
extends Node
## Reads the human's movement input and converts it to a world intent.
##
## Movement is camera-relative: "up" on the stick means "away from the
## camera on the ground plane". TeamControl calls read_intent() every
## physics tick and decides which player receives it.

## >1 gives finer control near the stick centre (walk), full tilt unchanged.
@export var response_curve := 1.25

var camera: BroadcastCamera
## When set, returned instead of device input (tests, scripted captures).
var scripted: SupportRunner.Intent


func read_intent() -> SupportRunner.Intent:
	if scripted:
		return scripted
	var it := SupportRunner.Intent.new()
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	it.mag = pow(clampf(raw.length(), 0.0, 1.0), response_curve)
	if it.mag > 0.0:
		var axes := _ground_axes()
		it.dir = (axes[0] * raw.x + axes[1] * -raw.y).normalized()
	it.sprint = Input.is_action_pressed("sprint")
	return it


## [right, forward] on the ground plane as seen from the camera.
func _ground_axes() -> Array[Vector2]:
	if camera == null:
		return [Vector2(1, 0), Vector2(0, -1)]
	return camera.ground_axes()
