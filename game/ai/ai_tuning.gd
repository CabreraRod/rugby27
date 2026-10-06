class_name AITuning
extends TuningData
## M07 basic AI parameters (data/tuning/ai.json).

const DEFAULT_PATH := "res://data/tuning/ai.json"

## Carrier decision interval: slow (low tempo/decisions) .. fast.
var think_slow := 0.4
var think_fast := 0.15
## Score noise (×(1 - decision_making)) so weaker deciders misjudge.
var decision_noise := 0.25
## Running-line candidates: rays from -a..+a around the attack direction.
var ray_angles_deg := 45.0
var ray_steps := 7.0
var ray_range := 20.0
## Score bonus per unit of straightness (go forward unless space is elsewhere).
var straight_bias := 0.6
## Keep the current line unless another beats it by this much (no jitter).
var line_hysteresis := 0.8
## Rays ending within this of touch are penalised.
var touch_avoid := 5.0
## Start considering a pass when the nearest defender ahead is this close.
var pass_consider_dist := 7.0
## Pass if any decent option exists when contact is this close.
var pass_must_dist := 2.8
## A pass must beat carrying by this score.
var pass_margin := 1.0
## A defender this close to the passing lane makes it risky.
var lane_risk_dist := 1.6
var lane_risk_penalty := 4.0
## Penalty per metre a receiver is ahead (forward-pass risk).
var ahead_penalty := 3.0
## Space around a receiver counts up to this.
var receiver_space_cap := 12.0
## Carry score bonus × P(break) from TackleModel.
var carry_break_bonus := 6.0
## A receiver deeper than this behind the carrier costs ground (penalised).
var deep_receiver := 7.0
## Sidestep when a defender is this close head-on ...
var sidestep_trigger := 2.6
## ... and there is at least this much space to one side.
var sidestep_space := 3.0
## Support runners flatten when the defence is this close to the ball.
var flat_trigger := 10.0
## Depth of a flat line (m).
var flat_depth := 1.4
## How far (0..1) runners slide toward the nearest defensive gap.
var gap_seek := 0.55
## Gaps considered within this lateral distance of a runner's slot.
var gap_window := 4.5
## Inside support runner: this far behind and inside the carrier.
var inside_support_back := 2.0
var inside_support_side := 2.2
## Inside cover defender: this far behind and inside the tackler's target.
var cover_back := 1.5
var cover_side := 1.8
## A defender this far behind the carrier (along attack) is beaten: he chases.
var beaten_margin := 1.0
## Beaten defenders chase only within this distance.
var beaten_range := 18.0
## AI dives when the carrier is between dive_min and contact+dive reach ...
var dive_min := 1.3
## ... and getting away (lateral or outpacing by this m/s).
var dive_escape_speed := 2.0
## Minimum time between AI dives per player.
var dive_cooldown := 2.0


static func load_default() -> AITuning:
	var t := AITuning.new()
	t.apply_dict(JsonLoader.load_dict(DEFAULT_PATH))
	return t
