class_name PlayerAttributes
extends RefCounted
## Player ratings on a 1..99 scale. Gameplay systems read normalized values
## (0..1) so tuning curves stay independent of the rating scale.

const KEYS: Array[String] = [
	"speed", "acceleration", "strength", "passing", "kicking",
	"tackling", "handling", "decision_making", "stamina",
]
const DEFAULT_RATING := 50

var _values := {}


static func from_dict(d: Dictionary) -> PlayerAttributes:
	var a := PlayerAttributes.new()
	for k in KEYS:
		a._values[k] = clampi(int(d.get(k, DEFAULT_RATING)), 1, 99)
	for k in d.keys():
		if not KEYS.has(k):
			push_warning("PlayerAttributes: unknown attribute '%s'" % k)
	return a


func rating(key: String) -> int:
	return _values.get(key, DEFAULT_RATING)


## 0..1 normalized rating.
func norm(key: String) -> float:
	return rating(key) / 100.0


func to_dict() -> Dictionary:
	return _values.duplicate()
