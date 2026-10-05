class_name PassingTuning
extends TuningData
## Passing + catching parameters (data/tuning/passing.json).
## Defaults mirror the JSON (guarded by tests/test_data.gd).

const DEFAULT_PATH := "res://data/tuning/passing.json"

# Pass speed (m/s, horizontal-ish) by passing attribute.
var quick_speed_min := 12.5
var quick_speed_max := 15.5
var long_speed_min := 15.5
var long_speed_max := 19.5
var min_flight := 0.25
var max_flight := 1.8
## Height the pass aims for at the receiver (chest).
var catch_height := 1.15

# Button: tap = quick pass to nearest; hold past skip_hold_time = long/skip pass.
var skip_hold_time := 0.16
## Pass auto-releases at this hold time.
var max_hold_time := 0.45

# Receiver selection.
var max_range := 26.0
## Receiver must be at least this far to the chosen side.
var min_lateral := 1.5
## Receivers up to this far AHEAD are still options (a forward pass is a
## mistake the player is allowed to make; the marker turns red).
var max_ahead := 4.0

# Accuracy: aim error SD (m) by passing attribute; never pushes the ball forward.
var err_max := 1.3
var err_min := 0.15
var err_long_mult := 1.5
## Extra error at full sprint (fraction).
var err_speed_mult := 0.5

## Forward pass if the ball moves toward the opponents' line faster than
## this relative to the passer (m/s).
var forward_tolerance := 0.6
## No receiver on that side: pass into space this far out / back.
var space_pass_lateral := 8.0
var space_pass_back := 2.0
## Passer can't catch/pick up their own pass for this long.
var passer_cooldown := 0.4
## A pass is considered finished this long after its planned flight time.
var pass_timeout_margin := 1.0

# Catching (see CatchModel).
var catch_reach := 1.0
var catch_reach_intended := 1.25
## Within this distance the ball is "in the hands": judge the catch now.
var catch_sure_dist := 0.45
var catch_min_height := 0.35
var catch_max_height := 2.4
var catch_base_min := 0.82
var catch_base_max := 0.99
## Relative ball speed a normal pass arrives at (lateral pass speed + run) is ~15-21 m/s.
var catch_speed_free := 18.0
var catch_speed_full := 28.0
var catch_speed_pen := 0.2
var catch_behind_pen := 0.2
var catch_height_pen := 0.15
var catch_comfort_low := 0.8
var catch_comfort_high := 1.7

# Interceptions (a defender in the passing lane).
var intercept_reach := 0.8
## Interception chance = normal catch chance × this.
var intercept_mult := 0.15
## A missed interception knocks the ball down this often (else it flies on).
var intercept_knockdown := 0.08
## No interceptions in the first part of the flight (ball leaving the hands).
var intercept_min_time := 0.15

# Dropped catch.
var knock_back_chance := 0.3
var knock_speed := 2.0
var knock_up := 1.8
var catch_retry_cooldown := 0.5


static func load_default() -> PassingTuning:
	var t := PassingTuning.new()
	t.apply_dict(JsonLoader.load_dict(DEFAULT_PATH))
	return t
