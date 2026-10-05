class_name DefenceTuning
extends TuningData
## Placeholder defence + AI-carrier parameters (data/tuning/defence.json).

const DEFAULT_PATH := "res://data/tuning/defence.json"

## Distance a defender holds in front of the attacker they mark: near the
## ball (line pressure) ... far from it (out wide, still drifting).
var gap_near := 3.0
var gap_far := 6.0
## Lateral distance from the ball at which the gap reaches gap_far.
var gap_falloff := 15.0
## Defenders sit this far on their mark's inside shoulder (toward the ball),
## pushing attackers toward touch — a drift defence.
var inside_offset := 0.7
var gain := 1.9
var settle_dist := 0.35
## The carrier's defender aims where the carrier will be this far ahead (s).
var pursue_lead := 0.3
## ... and stays this far in front of them (no tackling until M07).
var shadow_gap := 0.5
## If the human defender is this close to the carrier, the AI doesn't also
## send a pursuer.
var human_marks_carrier_dist := 4.0
## Fraction of an attacker's forward pace the defenders give ground at
## (line speed): marks hold/come up, the carrier's defender gives a little.
var mark_retreat := 0.5
var pursuer_retreat := 0.3
## Spare defenders sweep this far behind the ball.
var sweeper_depth := 18.0

# Placeholder AI ball carrier (opponents in possession).
## A defender this close in front (and within press_lateral) forces a pass.
var press_dist := 2.6
var press_lateral := 1.6
## Minimum time holding the ball before the AI passes again.
var ai_pass_cooldown := 0.7
## Carrier veers away from defenders within this distance.
var avoid_dist := 4.0
var avoid_weight := 0.45


static func load_default() -> DefenceTuning:
	var t := DefenceTuning.new()
	t.apply_dict(JsonLoader.load_dict(DEFAULT_PATH))
	return t
