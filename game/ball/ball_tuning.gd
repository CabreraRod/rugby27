class_name BallTuning
extends TuningData
## Ball physics + possession parameters (data/tuning/ball.json).
## Defaults mirror the JSON (guarded by tests/test_data.gd).

const DEFAULT_PATH := "res://data/tuning/ball.json"

# Body.
var radius := 0.11
var mass := 0.44
var air_damp := 0.03

# Bounce (see BounceModel).
## Base vertical restitution on grass.
var restitution := 0.5
var restitution_var := 0.12
## Impacts slower than this (m/s downward) don't bounce; the ball rolls.
var bounce_min_vy := 1.2
## Max horizontal deflection of a bounce (hard impacts reach it, soft ones less).
var max_deflect_deg := 35.0
## Impact speed at which bounces become fully "wild".
var wild_impact_speed := 8.0
## Fraction of horizontal speed kept through a bounce (random in range).
var horiz_keep_min := 0.55
var horiz_keep_max := 0.95
## Sideways scatter for near-vertical drops (fraction of impact speed).
var drop_scatter := 0.18
## Chance (at full wildness) the ball "sits up": higher, slower bounce.
var sit_up_chance := 0.15
var sit_up_vy_mult := 1.5
var sit_up_keep_mult := 0.5
## Restitution against posts/walls.
var wall_restitution := 0.45

# Ground.
var roll_decel := 2.4
var rest_speed := 0.15

# Carry socket (player local: side = right, forward, height).
var carry_side := 0.26
var carry_forward := 0.12
var carry_height := 1.08

# Pickup (see PickupModel).
var pickup_reach := 0.85
var pickup_max_height := 1.3
var pickup_base_min := 0.8
var pickup_base_max := 0.995
var pickup_speed_pen_good_hands := 0.15
var pickup_speed_pen_bad_hands := 0.4
var pickup_ball_speed_free := 2.0
var pickup_ball_speed_full := 10.0
var pickup_ball_speed_pen := 0.35
var pickup_retry_cooldown := 0.5
## Speed kept when picking up above jog pace.
var pickup_stumble := 0.88

# Failed pickup.
var fumble_stumble := 0.8
var fumble_kick_base := 1.5
var fumble_kick_per_speed := 0.35
var fumble_kick_up := 1.2
var fumble_spread_deg := 30.0

# Dev restart after the ball goes dead (real restarts arrive with M11/M14).
var dead_ball_restart_delay := 1.6


static func load_default() -> BallTuning:
	var t := BallTuning.new()
	t.apply_dict(JsonLoader.load_dict(DEFAULT_PATH))
	return t
