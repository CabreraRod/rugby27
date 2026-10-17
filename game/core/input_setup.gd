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

	# Sprint — Shift or right trigger.
	_add("sprint", [KEY_SHIFT], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], TRIGGER_DEADZONE)

	# Passing — to the attacker's left / right. Tap = quick, hold = long/skip.
	_add("pass_left", [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER], [], 0.5)
	_add("pass_right", [KEY_E], [JOY_BUTTON_RIGHT_SHOULDER], [], 0.5)

	# Ball carrier moves. Fend (hand-off) = skill modifier (LT / L2 / Ctrl) + ✕,
	# as in Rugby 08 (skill moves on LT + a face button).
	_add("skill_mod", [KEY_CTRL], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]], TRIGGER_DEADZONE)
	_add("sidestep_left", [KEY_Z], [], [[JOY_AXIS_RIGHT_X, -1.0]], 0.7)
	_add("sidestep_right", [KEY_X], [], [[JOY_AXIS_RIGHT_X, 1.0]], 0.7)
	# Defence.
	_add("dive_tackle", [KEY_SPACE], [JOY_BUTTON_A], [], 0.5)
	# Kicking (Rugby 08): hold to charge, release to kick. PlayStation face
	# buttons → Xbox: ✕ = A, □ = X, △ = Y, ○ = B.
	#   ✕ long kick · □ high kick · △ grubber (box kick for the 9 at a ruck) · ○ drop goal
	_add("kick_long", [KEY_SPACE], [JOY_BUTTON_A], [], 0.5)
	_add("kick_high", [KEY_V], [JOY_BUTTON_X], [], 0.5)
	_add("kick_low", [KEY_F], [JOY_BUTTON_Y], [], 0.5)
	_add("kick_drop", [KEY_G], [JOY_BUTTON_B], [], 0.5)
	# Rucks (Rugby 08): X / ✕ commits one more player, □ holds the ball in
	# (defence). PlayStation ✕ = bottom face button (Xbox A), □ = left (Xbox X).
	_add("ruck_commit", [KEY_SPACE], [JOY_BUTTON_A], [], 0.5)
	_add("ruck_hold", [KEY_V], [JOY_BUTTON_X], [], 0.5)

	# Camera.
	_add("camera_toggle", [KEY_C], [JOY_BUTTON_BACK], [], 0.5)

	# Developer tools (removed from release builds later).
	_add("dev_debug_overlay", [KEY_F1], [], [], 0.5)
	_add("dev_reset_player", [KEY_R], [JOY_BUTTON_START], [], 0.5)
	_add("dev_go_to_ground", [KEY_F7], [], [], 0.5)
	_add("dev_cycle_role", [KEY_B], [], [], 0.5)
	_add("dev_next_profile", [KEY_N], [], [], 0.5)
	_add("dev_reload_tuning", [KEY_F5], [], [], 0.5)
	_add("dev_drop_ball", [KEY_F6], [], [], 0.5)
	_add("dev_toss_ball", [KEY_T], [JOY_BUTTON_DPAD_DOWN], [], 0.5)
	_add("dev_sandbox", [KEY_F2], [JOY_BUTTON_DPAD_UP], [], 0.5)


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
