class_name TestSuite
extends RefCounted
## Minimal assertion base for headless tests (no external framework needed).

var tree: SceneTree
var errors: Array[String] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func check_between(value: float, lo: float, hi: float, what: String) -> void:
	if value < lo or value > hi:
		errors.append("%s = %.3f, expected in [%.3f, %.3f]" % [what, value, lo, hi])
