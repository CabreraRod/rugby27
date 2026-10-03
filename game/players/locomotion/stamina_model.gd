class_name StaminaModel
extends RefCounted
## Sprint stamina with regen delay, fatigue curve and lockout hysteresis.
##
## Fatigue is a soft penalty (top speed / acceleration fade below a
## threshold) rather than a hard "can't run" switch, so the player always
## keeps control. Sprint itself locks only when empty and unlocks after a
## short recovery, which avoids sprint flicker at 0.

var value := 100.0
var max_value := 100.0
var sprint_locked := false
var _regen_wait := 0.0


func _init(p_max: float = 100.0) -> void:
	max_value = p_max
	value = p_max


func step(sprinting: bool, moving: bool, drain_rate: float, t: MovementTuning, dt: float) -> void:
	if sprinting:
		value = maxf(0.0, value - drain_rate * dt)
		_regen_wait = t.regen_delay
		if value <= t.sprint_lockout:
			sprint_locked = true
	elif _regen_wait > 0.0:
		_regen_wait -= dt
	else:
		var regen := t.regen_moving if moving else t.regen_idle
		value = minf(max_value, value + regen * dt)
	if sprint_locked and value >= t.sprint_unlock:
		sprint_locked = false


func can_sprint() -> bool:
	return not sprint_locked and value > 0.0


func fatigue_multiplier(t: MovementTuning) -> float:
	if value >= t.fatigue_threshold:
		return 1.0
	return lerpf(t.fatigue_min_mult, 1.0, value / t.fatigue_threshold)


func ratio() -> float:
	return value / max_value


func refill() -> void:
	value = max_value
	sprint_locked = false
	_regen_wait = 0.0
