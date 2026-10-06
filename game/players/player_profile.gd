class_name PlayerProfile
extends RefCounted
## Static identity + ratings of a player, loaded from data files.

var display_name := "Player"
var number := 0
var position := "Unknown"
## Body mass (kg). Matters in contact (tackles now, rucks/scrums later).
var weight_kg := 95.0
var attributes: PlayerAttributes

## Used when a data file gives no weight.
const DEFAULT_WEIGHT_BY_POSITION := {
	"LooseheadProp": 118.0, "Hooker": 108.0, "TightheadProp": 120.0,
	"Lock": 116.0, "Flanker": 106.0, "Number8": 110.0,
	"ScrumHalf": 78.0, "FlyHalf": 86.0, "InsideCentre": 100.0,
	"OutsideCentre": 95.0, "Wing": 90.0, "FullBack": 92.0,
}


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.display_name = String(d.get("name", "Player"))
	p.number = int(d.get("number", 0))
	p.position = String(d.get("position", "Unknown"))
	p.weight_kg = float(d.get("weight_kg", DEFAULT_WEIGHT_BY_POSITION.get(p.position, 95.0)))
	p.attributes = PlayerAttributes.from_dict(d.get("attributes", {}))
	return p


static func load_squad(path: String) -> Array[PlayerProfile]:
	var out: Array[PlayerProfile] = []
	var data := JsonLoader.load_dict(path)
	for entry in data.get("players", []):
		out.append(from_dict(entry))
	return out


func short_label() -> String:
	return "#%d %s" % [number, display_name]
