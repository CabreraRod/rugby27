extends SceneTree
## Headless test runner.
##   godot --headless --path . --import          (once, registers class_names)
##   godot --headless --path . --script res://tests/run_tests.gd
## Exit code 0 = all passed. See tools/run_tests.sh.

const SUITES := [
	"res://tests/test_locomotion.gd",
	"res://tests/test_stamina.gd",
	"res://tests/test_data.gd",
	"res://tests/test_match_scene.gd",
	"res://tests/test_ball_models.gd",
	"res://tests/test_ball_scene.gd",
	"res://tests/test_passing_models.gd",
	"res://tests/test_passing_scene.gd",
	"res://tests/test_defence.gd",
	"res://tests/test_tackling.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var passed := 0
	var failed := 0
	for path: String in SUITES:
		var suite: TestSuite = load(path).new()
		suite.tree = self
		print("\n== %s" % path.get_file())
		for m in suite.get_method_list():
			var method_name: String = m.name
			if not method_name.begins_with("test_"):
				continue
			suite.errors.clear()
			suite.before_each()
			await suite.call(method_name)
			suite.after_each()
			if suite.errors.is_empty():
				passed += 1
				print("  PASS  %s" % method_name)
			else:
				failed += 1
				print("  FAIL  %s" % method_name)
				for e in suite.errors:
					print("        - %s" % e)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
