class_name Team
extends RefCounted
## A side on the pitch: its players and the direction it attacks.
##
## Left/right are always from the attacker's point of view (facing the
## opponent's try line), never screen-relative, so passing directions stay
## consistent with any camera.

var name := "Team"
## +1 attacks toward +X, -1 toward -X.
var attack_dir := 1.0
var players: Array[RugbyPlayer] = []


func attack() -> Vector2:
	return Vector2(attack_dir, 0.0)


## Unit vector to the attacker's left on the ground plane.
## Facing +X (Y up), right is +Z, so left is -Z.
func left() -> Vector2:
	return Vector2(0.0, -attack_dir)


func has(p: RugbyPlayer) -> bool:
	return players.has(p)


func teammates_of(p: RugbyPlayer) -> Array[RugbyPlayer]:
	var out: Array[RugbyPlayer] = []
	for m in players:
		if m != p:
			out.append(m)
	return out
