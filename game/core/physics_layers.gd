class_name PhysicsLayers
extends RefCounted
## Collision layer bits used across the game.
##
## The ball does NOT physically collide with players: picking up, knocking
## and (later) catching are resolved by gameplay rules, which keeps outcomes
## readable and tunable. The ball does collide with the world (ground, posts).

const WORLD := 1
const PLAYERS := 2
const BALL := 4
