class_name SupportTuning
extends TuningData
## Receiver-dummy support line parameters (data/tuning/support.json).

const DEFAULT_PATH := "res://data/tuning/support.json"

## Depth behind the ball of the first receiver on each side.
var depth_first := 2.5
## Extra depth per receiver further out (a staggered line).
var depth_step := 1.0
## Lateral gap between receivers.
var spacing := 7.0
## How hard runners correct toward their slot (1/s).
var gain := 1.6
## Slots never closer than this to the touchline.
var touch_margin := 2.0
## Within this distance of a still slot, stop.
var settle_dist := 0.35
## Receiving a pass: stick within this angle of your run keeps your pace.
var receiver_assist_angle := 45.0


static func load_default() -> SupportTuning:
	var t := SupportTuning.new()
	t.apply_dict(JsonLoader.load_dict(DEFAULT_PATH))
	return t
