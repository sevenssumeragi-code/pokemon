extends SceneTree
## Headless test runner.
## Usage: godot --headless --path . -s tests/test_runner.gd [-- filter]
## Discovers tests/unit/test_*.gd, instantiates each, runs every `test_*` method.

const TEST_DIR := "res://tests/unit/"

func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var total_tests := 0
	var total_asserts := 0
	var failed_tests := 0
	var all_failures: Array[String] = []
	var files := _list_test_files()
	files.sort()
	var t0 := Time.get_ticks_msec()
	for path in files:
		if filter != "" and not path.contains(filter) :
			continue
		var script: GDScript = load(path)
		if script == null:
			all_failures.append("%s: failed to load" % path)
			failed_tests += 1
			continue
		var inst = script.new()
		if not (inst is TestCase):
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			if m.name.begins_with("test_"):
				methods.append(m.name)
		methods.sort()
		var file_fail := 0
		for m in methods:
			inst._current = "%s::%s" % [path.get_file(), m]
			var before: int = inst._failures.size()
			inst.before_each()
			inst.call(m)
			inst.after_each()
			total_tests += 1
			if inst._failures.size() > before:
				failed_tests += 1
				file_fail += 1
		total_asserts += inst._assert_count
		all_failures.append_array(inst._failures)
		print("%s  %s  (%d tests, %d failed)" % ["FAIL" if file_fail > 0 else " ok ", path.get_file(), methods.size(), file_fail])
	var dt := Time.get_ticks_msec() - t0
	print("")
	for f in all_failures:
		print("  FAILED " + f)
	print("=== %d tests, %d assertions, %d failed, %d ms ===" % [total_tests, total_asserts, failed_tests, dt])
	EffectRegistry.reset()
	GameData.loaded = false
	quit(1 if failed_tests > 0 else 0)

func _list_test_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(TEST_DIR + f)
		f = dir.get_next()
	dir.list_dir_end()
	return out
