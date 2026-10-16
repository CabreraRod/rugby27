class_name RuckTuning
extends TuningData
## Ruck parameters (data/tuning/ruck.json). See RuckModel and RuckSystem.

const DEFAULT_PATH := "res://data/tuning/ruck.json"

## Seconds from the ruck forming to the contest being decided. Bodies bound
## after this don't count (arrival timing matters).
var contest_time := 1.4
## Players a side can commit (X taps), not counting the tackled player.
var max_commit := 4.0
## The nearest attacking support within this range joins automatically.
var auto_support_range := 9.0
## The nearest defender on his feet within this range contests automatically.
var auto_jackal_range := 3.5
## Reaction time added to a committed player's estimated arrival (s).
var reaction := 0.15
## A committed player binds once this close to the ball.
var bind_reach := 1.5
## Getting up and out of a ruck when it ends (s).
var unbind_recover := 0.5
## The 9 takes the ball out once this close to it.
var pickup_reach := 1.4
## Where the 9 waits: behind the ball and to one side (m).
var nine_back := 1.1
var nine_side := 0.5
## Defenders not in the ruck stand at least this far on their side of the ball.
var offside_gap := 2.0
## Safety: a ruck never lasts longer than this (ball goes to the 9).
var timeout := 6.0
## Body units: (kg / mass_ref)^mass_exp × strength multiplier.
var mass_ref := 90.0
var mass_exp := 0.7
var strength_min := 0.85
var strength_max := 1.15
## P(turnover) = clamp(logistic(contest_bias + contest_slope * x), p_min, p_max).
var contest_bias := -2.45
var contest_slope := 1.5
## Added to x when a defender is over the ball before any attacker.
var jackal_bonus := 0.7
var p_min := 0.01
var p_max := 0.9
## Holding the ball in (□): penalty hazard per second = hold_rate + hold_rate_slope × seconds held.
var hold_rate := 0.12
var hold_rate_slope := 0.34
## Holding this long is always penalised.
var hold_max := 3.5
## AI: decision interval in a ruck.
var ai_think := 0.25
## AI defence: P(bid) = bid_base + aggression × bid_aggression (+ isolated / near own line).
var bid_base := 0.04
var bid_aggression := 0.1
var bid_isolated := 0.55
var bid_near_line := 0.15
var near_line_dist := 12.0
## AI defence bid size (commits): bid_min..bid_max, or isolated_bid against an isolated carrier.
var bid_min := 3.0
var bid_max := 4.0
var isolated_bid := 2.0
## AI attack keeps at least (defence bodies + att_margin) in, but misses the read att_miss of the time.
var att_margin := 1.0
var att_miss := 0.12
## AI defence: P(hold) = hold_base + aggression × hold_aggression (+ near own line); hold for ai_hold_min..max s.
var hold_base := 0.06
var hold_aggression := 0.1
var hold_near_line := 0.25
var ai_hold_min := 0.5
var ai_hold_max := 1.6


static func load_default() -> RuckTuning:
	var t := RuckTuning.new()
	t.apply_dict(JsonLoader.load_dict(DEFAULT_PATH))
	return t
