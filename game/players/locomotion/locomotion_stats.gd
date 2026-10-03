class_name LocomotionStats
extends RefCounted
## Per-player movement numbers for the current tick, derived from global
## tuning + attributes + situational multipliers (role, fatigue).

var sprint_top := 9.0   ## m/s
var jog_top := 6.0      ## m/s
var accel := 9.0        ## m/s^2 at standstill
var turn_mult := 1.0
var sprint_drain := 10.0  ## stamina/s


static func derive(t: MovementTuning, attrs: PlayerAttributes, speed_mult: float, turn_mult: float, fatigue_mult: float) -> LocomotionStats:
	var s := LocomotionStats.new()
	s.sprint_top = lerpf(t.sprint_speed_min, t.sprint_speed_max, attrs.norm("speed")) * speed_mult * fatigue_mult
	s.jog_top = s.sprint_top * t.jog_ratio
	# Fatigue hurts acceleration a little less than top speed.
	s.accel = lerpf(t.accel_min, t.accel_max, attrs.norm("acceleration")) * lerpf(1.0, fatigue_mult, 0.6)
	s.turn_mult = turn_mult
	s.sprint_drain = lerpf(t.sprint_drain_max, t.sprint_drain_min, attrs.norm("stamina"))
	return s
