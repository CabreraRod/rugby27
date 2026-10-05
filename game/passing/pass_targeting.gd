class_name PassTargeting
extends RefCounted
## Pure receiver selection. Works on ground-plane positions so it is
## trivially unit-testable.
##
## Rule: receivers on the chosen side (at least min_lateral out), within
## range and not too far ahead, ordered by lateral distance. Tap -> nearest,
## hold -> next one out (skip pass).

const LEFT := 0
const RIGHT := 1


## Unit vector for a side, from the attacker's point of view.
static func side_vector(team_left: Vector2, side: int) -> Vector2:
	return team_left if side == LEFT else -team_left


## Indices into `mates`, nearest-out first.
static func candidates(passer: Vector2, attack: Vector2, side_vec: Vector2, mates: Array[Vector2], t: PassingTuning) -> Array[int]:
	var scored: Array = []
	for i in mates.size():
		var rel := mates[i] - passer
		var lat := rel.dot(side_vec)
		if lat < t.min_lateral:
			continue
		if rel.dot(attack) > t.max_ahead:
			continue
		if rel.length() > t.max_range:
			continue
		scored.append([lat, i])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array[int] = []
	for s in scored:
		out.append(s[1])
	return out


## Index of the chosen receiver or -1 (pass into space).
static func select(passer: Vector2, attack: Vector2, side_vec: Vector2, mates: Array[Vector2], skip: bool, t: PassingTuning) -> int:
	var c := candidates(passer, attack, side_vec, mates, t)
	if c.is_empty():
		return -1
	if skip and c.size() > 1:
		return c[1]
	return c[0]


## How far ahead (m, along attack) a receiver is: > 0 means a likely forward pass.
static func ahead_of(passer: Vector2, receiver: Vector2, attack: Vector2) -> float:
	return (receiver - passer).dot(attack)
