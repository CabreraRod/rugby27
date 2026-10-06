class_name TeamStyle
extends RefCounted
## A team's tactical identity (0..100 each, from data/teams/*.json "style").
## Spec §13: these must actually change behaviour. Mapping:
##   tempo      — how quickly the AI carrier decides (think interval) and
##                how deep the support line stands (high tempo = flatter).
##   width      — lateral spacing of the support line.
##   aggression — defensive line speed (rush vs. sit and drift).
##   passing    — appetite to pass rather than carry.

var tempo := 50.0
var width := 50.0
var aggression := 50.0
var passing := 50.0


static func from_dict(d: Dictionary) -> TeamStyle:
	var s := TeamStyle.new()
	s.tempo = clampf(float(d.get("tempo", 50)), 0.0, 100.0)
	s.width = clampf(float(d.get("width", 50)), 0.0, 100.0)
	s.aggression = clampf(float(d.get("aggression", 50)), 0.0, 100.0)
	s.passing = clampf(float(d.get("passing", 50)), 0.0, 100.0)
	return s


func n(key: String) -> float:
	return float(get(key)) / 100.0


## Multiplier on support spacing (0.8 .. 1.2).
func width_factor() -> float:
	return lerpf(0.8, 1.2, n("width"))


## Multiplier on support depth (deep 1.25 .. flat 0.75).
func depth_factor() -> float:
	return lerpf(1.25, 0.75, n("tempo"))


## Defence derived from aggression: [gap_near, mark_retreat, engage_dist].
func defence_shape() -> Array:
	var a := n("aggression")
	return [lerpf(3.6, 2.4, a), lerpf(0.7, 0.25, a), lerpf(2.5, 3.6, a)]
