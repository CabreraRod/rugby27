class_name KickTuning
extends TuningData
## Kicking parameters (data/tuning/kick.json). See KickModel and KickSystem.

const DEFAULT_PATH := "res://data/tuning/kick.json"

## Seconds of holding for a full charge (long, high, low kicks).
var charge_time := 1.1
## Holding a full charge this much longer kicks automatically.
var overhold := 0.5
## Aim: at most this far from straight ahead (degrees).
var aim_max_deg := 75.0
## The kicker can't gather his own kick for this long.
var kicker_cooldown := 0.7
## Where the boot meets the ball: height and distance ahead of the kicker.
var contact_height := 0.55
var contact_ahead := 0.35
## ✕ Long kick: launch angle, distance at zero charge, full-charge distance for a poor .. great kicker.
var long_angle := 34.0
var long_min := 15.0
var long_max_lo := 42.0
var long_max_hi := 62.0
## □ High kick (up and under).
var high_angle := 68.0
var high_min := 8.0
var high_max_lo := 28.0
var high_max_hi := 40.0
## △ at the base of a ruck: the 9's box kick (quicker charge).
var box_angle := 70.0
var box_charge_time := 0.7
var box_min := 8.0
var box_max_lo := 22.0
var box_max_hi := 30.0
## The 9 counts as "at the base" for this long after the ball comes out, within this radius.
var box_window := 2.0
var box_radius := 3.0
## △ Low kick (grubber): horizontal speed at zero / full charge (poor .. great kicker), pushed into the ground.
var low_speed_min := 5.0
var low_speed_lo := 9.5
var low_speed_hi := 12.0
var low_down := 2.2
## Accuracy (poor .. great kicker): direction error SD (deg), distance error SD (fraction).
var dir_err_lo := 7.0
var dir_err_hi := 1.5
var dist_err_lo := 0.12
var dist_err_hi := 0.04
## ○ Drop goal: full charge time, sweet spot, window half-width (poor .. great kicker) at ref distance.
var drop_charge_time := 1.2
var drop_sweet := 0.5
var drop_window_lo := 0.06
var drop_window_hi := 0.13
var drop_ref_dist := 25.0
## Launch angle; the perfect drop crosses the posts this high (m).
var drop_angle := 38.0
var drop_clear := 4.5
## Speed lost per unit of under-charge / gained per unit of over-charge.
var drop_short := 0.9
var drop_long := 0.35
var drop_noise_deg := 0.6
## Strongest drop a poor .. great kicker can strike (m/s): out of range falls short.
var drop_max_speed_lo := 18.0
var drop_max_speed_hi := 23.5
var drop_contact_height := 0.3
## Catching a kick: height the receiver waits for it; base chance by handling; penalties.
var catch_height := 1.5
var catch_base_lo := 0.8
var catch_base_hi := 0.97
var catch_contest_radius := 1.8
var catch_contest_pen := 0.3
var catch_run_pen := 0.15
var catch_run_speed := 6.0
## Kick chase: onside chasers per kick; the receiver settles this close; the rest line up this far behind the ball.
var chasers := 2.0
var receiver_settle := 0.4
var chase_line_back := 6.0
## AI kicking.
var ai_think := 0.3
var ai_own22_dist := 22.0
var ai_clear_pressure := 7.0
var ai_clear_p := 0.75
var ai_box_p := 0.25
var ai_box_own_half := 1.0
var ai_grubber_p := 0.06
var ai_grubber_line := 6.0
var ai_grubber_space := 12.0
var ai_high_p := 0.03
var ai_touch_margin := 4.0


static func load_default() -> KickTuning:
	var t := KickTuning.new()
	t.apply_dict(JsonLoader.load_dict(DEFAULT_PATH))
	return t
