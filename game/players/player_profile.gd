class_name PlayerProfile
extends RefCounted
## Static identity + ratings of a player, loaded from data files.

var display_name := "Player"
var number := 0
var position := "Unknown"
var attributes: PlayerAttributes


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.display_name = String(d.get("name", "Player"))
	p.number = int(d.get("number", 0))
	p.position = String(d.get("position", "Unknown"))
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
