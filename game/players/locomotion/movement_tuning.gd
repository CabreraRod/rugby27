class_name MovementTuning
extends RefCounted
## Global movement-feel parameters, loaded from data/tuning/movement.json.
##
## Defaults below mirror the JSON so the game still runs (and tests stay
## deterministic) if the file is missing. Per-player differences come from
## PlayerAttributes; this file is the shared "physics of a rugby player".

const DEFAULT_PATH := "res://data/tuning/movement.json"

# Top speed (m/s) mapped from the speed attribute 0..100.
var sprint_speed_min := 6.4
var sprint_speed_max := 10.2
## Jog speed as a fraction of the player's sprint speed.
var jog_ratio := 0.66

# Acceleration (m/s^2 at standstill) mapped from the acceleration attribute.
var accel_min := 7.0
var accel_max := 10.5
## Acceleration fades as (speed/top)^power: higher power keeps accel strong for longer (quicker top speed).
var accel_curve_power := 1.6
## Minimum acceleration so targets are always reached.
var accel_floor := 0.2
## Deceleration when above the target speed while still holding a direction (e.g. releasing sprint).
var overspeed_decel := 6.0
## Deceleration with no input (feet braking).
var coast_decel := 13.0

# Turning.
var turn_rate_slow_deg := 900.0
var turn_rate_fast_deg := 230.0
## Speed kept while the velocity is 90 degrees off the desired direction.
var turn_speed_retention := 0.78

# Plant-and-cut: sharp direction reversals at speed must brake first.
var plant_angle_deg := 115.0
var plant_min_speed := 3.2
var plant_decel := 26.0

# Body facing (separate from velocity; used later for passing/tackling).
var facing_rate_slow_deg := 1000.0
var facing_rate_fast_deg := 420.0

# Role modifiers.
var carrier_speed_mult := 0.97
var carrier_turn_mult := 0.9
var defender_turn_mult := 1.08

# Stamina.
var stamina_max := 100.0
## Drain per second while sprinting: high stamina attribute -> min drain.
var sprint_drain_min := 7.0
var sprint_drain_max := 13.0
var regen_moving := 9.0
var regen_idle := 18.0
var regen_delay := 0.7
## Below this stamina value top speed and acceleration start to fade.
var fatigue_threshold := 35.0
var fatigue_min_mult := 0.84
## Sprint locks at/below this value and unlocks once recovered to sprint_unlock.
var sprint_lockout := 2.0
var sprint_unlock := 18.0

# Grounded (dive / tackled later).
var ground_time := 0.35
var get_up_time := 0.65
var ground_slide_decel := 9.0

var gravity := 24.0


static func load_default() -> MovementTuning:
	return load_from(DEFAULT_PATH)


static func load_from(path: String) -> MovementTuning:
	var t := MovementTuning.new()
	t.apply_dict(JsonLoader.load_dict(path))
	return t


## Applies known keys; warns about unknown keys so typos are caught early.
func apply_dict(d: Dictionary) -> void:
	var known := {}
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			known[p.name] = true
	for key in d.keys():
		if String(key).begins_with("_"):
			continue
		if known.has(key):
			set(key, float(d[key]))
		else:
			push_warning("MovementTuning: unknown key '%s'" % key)
