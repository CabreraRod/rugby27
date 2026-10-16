class_name TackleTuning
extends TuningData
## Tackling + carrier-move parameters (data/tuning/tackle.json). See TackleModel.

const DEFAULT_PATH := "res://data/tuning/tackle.json"

## Centre-to-centre distance at which a defender makes contact.
var contact_radius := 0.85
## A tackler can't attempt again for this long.
var tackler_cooldown := 0.5
## After breaking a tackle, that tackler can't retry for this long.
var retackle_immunity := 0.6
## Mass (kg) that counts as 1.0; contact mass = (kg/ref)^mass_exp.
var mass_ref := 100.0
var mass_exp := 0.7
## Speed-independent part of tackle power / resistance (technique, bracing).
var brace := 4.0
## How much speed (m/s) adds on top of brace.
var speed_weight := 0.6
## Tackling attribute 0..100 -> power multiplier.
var skill_min := 0.75
var skill_max := 1.25
## Carrier strength attribute 0..100 -> resistance multiplier.
var strength_min := 0.8
var strength_max := 1.2
## Angle multipliers on tackle power.
var headon_mult := 1.0
var side_mult := 1.05
var behind_mult := 0.85
## P(break) = logistic(steep * (center - ln(power/resistance))), clamped.
var break_steep := 3.2
var break_center := -0.85
var break_min := 0.03
var break_max := 0.85
## P(dominant | held) grows with ln(ratio) beyond dominant_start.
var dominant_start := -0.25
var dominant_slope := 0.8
var dominant_max := 0.6
## Ground times (s).
var tackled_ground := 1.3
var tackler_ground := 0.8
var dominant_tackler_ground := 0.45
var broken_tackler_ground := 0.75
## Carrier keeps this fraction of speed when breaking a tackle.
var broken_keep := 0.65
## Carrier velocity kept (signed) as they go down: + falls forward, - driven back.
var normal_slide := 0.35
var dominant_slide := -0.3
## Chance the carrier loses the ball forward in the tackle.
var spill_dominant := 0.08
var spill_normal := 0.02
## Fallback only (no RuckSystem, e.g. isolated tests): after a tackle only the tackled team may pick the ball up for this long. M08 rucks replace it in matches.
var placement_protect := 2.5
## Dive tackle: extra reach in front, active window, lunge speed, power bonus, ground time on a miss.
var dive_reach := 2.0
var dive_window := 0.35
var dive_speed := 7.5
var dive_power_mult := 1.15
var dive_miss_ground := 1.1
## Fend (hand-off): active window, cooldown, resistance multiplier vs. front/side tackles.
var fend_window := 0.35
var fend_cooldown := 1.2
var fend_mult := 1.35
## Sidestep: lateral burst (m/s), window in which tacklers are wrong-footed, cooldown, power multiplier, stamina cost.
var sidestep_speed := 3.5
var sidestep_window := 0.25
var sidestep_cooldown := 0.9
var sidestep_power_mult := 0.7
var sidestep_stamina := 6.0
## Placeholder AI carrier fends when a defender is this close in front.
var ai_fend_dist := 1.6


static func load_default() -> TackleTuning:
	var t := TackleTuning.new()
	t.apply_dict(JsonLoader.load_dict(DEFAULT_PATH))
	return t
