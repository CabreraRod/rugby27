extends Node
## Registers all input actions at startup.
##
## Bindings live here (code, reviewable in diffs) instead of a serialized blob
## in project.godot. Actions that already exist (e.g. remapped by the user in
## the editor) are left untouched.

const STICK_DEADZONE := 0.12
const TRIGGER_DEADZONE := 0.35


func _enter_tree() -> void:
	# Movement — keyboard + left stick.
	_add("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]], STICK_DEADZONE)
	_add("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]], STICK_DEADZONE)
	_add("move_up", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]], STICK_DEADZONE)
	_add("move_down", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]], STICK_DEADZONE)

	# Sprint — Shift, right trigger or right bumper.
	_add("sprint", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], TRIGGER_DEADZONE)

	# Camera.
	_add("camera_toggle", [KEY_C], [JOY_BUTTON_BACK], [], 0.5)

	# Developer tools (removed from release builds later).
	_add("dev_debug_overlay", [KEY_F1], [], [], 0.5)
	_add("dev_reset_player", [KEY_R], [JOY_BUTTON_START], [], 0.5)
	_add("dev_go_to_ground", [KEY_G], [JOY_BUTTON_B], [], 0.5)
	_add("dev_cycle_role", [KEY_B], [], [], 0.5)
	_add("dev_next_profile", [KEY_N], [JOY_BUTTON_Y], [], 0.5)
	_add("dev_reload_tuning", [KEY_F5], [], [], 0.5)
	_add("dev_drop_ball", [KEY_F], [JOY_BUTTON_X], [], 0.5)
	_add("dev_toss_ball", [KEY_T], [JOY_BUTTON_LEFT_SHOULDER], [], 0.5)


func _add(action: StringName, keys: Array, buttons: Array, axes: Array, deadzone: float) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, deadzone)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = a[0]
		jm.axis_value = a[1]
		InputMap.action_add_event(action, jm)
