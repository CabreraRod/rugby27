class_name HumanController
extends Node
## Translates device input into a RugbyPlayer intent.
##
## Movement is camera-relative: "up" on the stick means "away from the
## camera on the ground plane". Runs before players each physics tick
## (negative priority) so intent and simulation are always in the same tick:
## zero frames of added input latency.

## >1 gives finer control near the stick centre (walk), full tilt unchanged.
@export var response_curve := 1.25

var player: RugbyPlayer
var camera: BroadcastCamera


func _ready() -> void:
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var mag := pow(clampf(raw.length(), 0.0, 1.0), response_curve)
	var world_dir := Vector2.ZERO
	if mag > 0.0:
		var axes := _ground_axes()
		world_dir = (axes[0] * raw.x + axes[1] * -raw.y).normalized()
	player.set_intent(world_dir, mag, Input.is_action_pressed("sprint"))


## [right, forward] on the ground plane as seen from the camera.
func _ground_axes() -> Array[Vector2]:
	if camera == null:
		return [Vector2(1, 0), Vector2(0, -1)]
	return camera.ground_axes()
