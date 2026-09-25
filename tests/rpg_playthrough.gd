extends SceneTree
## Headless story playthrough bot: new game -> starter -> grind -> trainers -> cave -> boss -> ending.
## godot --headless --path . -s tests/rpg_playthrough.gd
## Prints PLAYTHROUGH_OK on success.

var main: MainUI
var ctrl: RPGController
var gstate: GameState
var frames := 0
var plan: Array = []
var step_i := 0
var path: Array = []  # pending tile moves for the current goto
var log_lines: Array = []
var boss_attempts := 0
var last_map := ""

func _initialize() -> void:
	GameData.ensure_loaded()
	GameState.slot_prefix = "test_save"
	main = MainUI.new()
	root.add_child(main)
	main.start_new_game()
	ctrl = main._current
	gstate = ctrl.state
	ctrl.auto_play = true
	ctrl.move_duration = 0.0
	ctrl.state.rng_seed = 4242
	ctrl.rng.seed = 4242
	plan = [
		{"type": "goto", "map": "town", "x": 4, "y": 4},          # 0 leave home
		{"type": "goto", "map": "lab", "x": 4, "y": 4},           # 1
		{"type": "interact", "dir": "up"},                        # 2 prof -> starter
		{"type": "expect_flag", "flag": "got_starter"},           # 3
		{"type": "grind", "map": "field", "level": 12},           # 4
		{"type": "heal"},                                         # 5
		{"type": "goto", "map": "field", "x": 8, "y": 5},         # 6
		{"type": "interact", "dir": "down"},                      # 7 trainer a
		{"type": "expect_flag", "flag": "trainer_a_beaten", "retry_from": 4},  # 8
		{"type": "grind", "map": "field", "level": 15},           # 9
		{"type": "heal"},                                         # 10
		{"type": "goto", "map": "field", "x": 14, "y": 17},       # 11
		{"type": "interact", "dir": "right"},                     # 12 trainer b
		{"type": "expect_flag", "flag": "trainer_b_beaten", "retry_from": 9},  # 13
		{"type": "goto", "map": "field", "x": 15, "y": 21},       # 14
		{"type": "interact", "dir": "right"},                     # 15 hiker (mind stone)
		{"type": "grind", "map": "cave", "level": 22},            # 16
		{"type": "heal"},                                         # 17
		{"type": "goto", "map": "cave", "x": 10, "y": 16},        # 18
		{"type": "interact", "dir": "right"},                     # 19 boss
		{"type": "expect_flag", "flag": "boss_beaten", "retry_from": 16},  # 20
	]

func _log(t: String) -> void:
	log_lines.append(t)
	printerr("[bot f%d] %s" % [frames, t])

func _fail(t: String) -> bool:
	printerr("PLAYTHROUGH_FAIL: " + t)
	print("PLAYTHROUGH_FAIL: " + t)
	_cleanup()
	quit(1)
	return true

func _cleanup() -> void:
	for i in [1]:
		var p := ProjectSettings.globalize_path(GameState.save_path(i))
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	EffectRegistry.reset()

func _process(_d: float) -> bool:
	frames += 1
	if frames > 400000:
		return _fail("frame limit")
	if not (main._current is RPGController):
		if gstate.flag("game_cleared", false):
			print("PLAYTHROUGH_OK frames=%d party=%s money=%d dex_caught=%d" % [frames, _party_desc(), gstate.money, gstate.dex_caught.size()])
			_cleanup()
			quit(0)
			return true
		return _fail("left the RPG without clearing")
	if ctrl.state.map_id != last_map:
		last_map = ctrl.state.map_id
		_log("map -> " + last_map)
	match ctrl.mode:
		"battle":
			return false
		"dialog", "learn":
			if ctrl.dialog.visible and ctrl.dialog.awaiting_choice:
				ctrl.dialog_choose(0)
			elif ctrl.dialog.visible:
				ctrl.dialog_confirm()
			return false
		"shop", "menu":
			ctrl.menu.closed.emit()
			return false
		"ending":
			return false
	if ctrl.is_busy():
		return false
	if step_i >= plan.size():
		return _fail("plan exhausted without ending")
	var st: Dictionary = plan[step_i]
	match str(st["type"]):
		"goto":
			if _goto(str(st["map"]), int(st["x"]), int(st["y"])):
				step_i += 1
		"interact":
			ctrl.state.dir = str(st["dir"])
			ctrl.renderer.player_dir = ctrl.state.dir
			if not ctrl.interact():
				return _fail("interact failed at step %d (%s facing %s)" % [step_i, str(ctrl.state.pos), st["dir"]])
			step_i += 1
		"expect_flag":
			if bool(ctrl.state.flag(str(st["flag"]), false)):
				step_i += 1
			else:
				if st.has("retry_from"):
					boss_attempts += 1
					if boss_attempts > 10:
						return _fail("too many failed attempts (%s)" % st["flag"])
					_log("attempt for %s failed; grinding more (party: %s)" % [st["flag"], _party_desc()])
					plan[int(st["retry_from"])]["level"] = int(plan[int(st["retry_from"])]["level"]) + 3
					step_i = int(st["retry_from"])
				else:
					return _fail("flag %s not set after step" % st["flag"])
		"heal":
			if _heal_needed() or true:
				if _goto("town", 11, 6):
					ctrl.state.dir = "up"
					ctrl.renderer.player_dir = "up"
					ctrl.interact()
					step_i += 1
			else:
				step_i += 1
		"grind":
			if _grind(str(st["map"]), int(st["level"])):
				step_i += 1
	return false

func _party_desc() -> String:
	var parts: PackedStringArray = []
	for p in gstate.party:
		parts.append("%s Lv%d" % [p.species, p.level])
	return ", ".join(parts)

func _max_level() -> int:
	var m := 0
	for p in ctrl.state.party:
		m = maxi(m, p.level)
	return m

func _heal_needed() -> bool:
	for p in ctrl.state.party:
		if p.current_hp == 0:
			return true
		if p.current_hp > 0:
			var sp := GameData.get_species(p.species)
			var mx := StatCalc.calc_hp(int(sp["base_stats"]["hp"]), int(p.ivs["hp"]), int(p.evs["hp"]), p.level)
			if p.current_hp * 2 < mx:
				return true
	return false

var _grind_toggle := false
func _grind(map_id: String, level: int) -> bool:
	if _max_level() >= level:
		return true
	if _heal_needed() and ctrl.state.map_id != "town":
		if _goto("town", 11, 6):
			ctrl.state.dir = "up"
			ctrl.renderer.player_dir = "up"
			ctrl.interact()
		return false
	if ctrl.state.map_id == "town" and _heal_needed():
		if _goto("town", 11, 6):
			ctrl.state.dir = "up"
			ctrl.renderer.player_dir = "up"
			ctrl.interact()
		return false
	# walk between two encounter tiles
	var a := Vector2i(2, 2) if map_id == "field" else Vector2i(5, 1)
	var b := Vector2i(4, 3) if map_id == "field" else Vector2i(7, 3)
	var target := b if _grind_toggle else a
	if _goto(map_id, target.x, target.y):
		_grind_toggle = not _grind_toggle
	return false

# ---------------- navigation ----------------
const ROUTES := {
	"home>town": [["home", 4, 6]], "town>home": [["town", 4, 3]],
	"town>lab": [["town", 13, 3]], "lab>town": [["lab", 5, 7]],
	"town>shop": [["town", 9, 10]], "shop>town": [["shop", 4, 6]],
	"town>field": [["town", 7, 15]], "field>town": [["field", 8, 0]],
	"field>cave": [["field", 18, 21]], "cave>field": [["cave", 1, 1]],
}

func _next_hop(from_map: String, to_map: String) -> Array:
	if from_map == to_map:
		return []
	var key := from_map + ">" + to_map
	if ROUTES.has(key):
		return ROUTES[key][0]
	# two-hop via town / field
	for mid in ["town", "field"]:
		if ROUTES.has(from_map + ">" + mid) and (mid == to_map or ROUTES.has(mid + ">" + to_map) or _next_hop(mid, to_map).size() > 0):
			return ROUTES[from_map + ">" + mid][0]
	return []

## Move one step toward (map,x,y). Returns true when standing there.
func _goto(map_id: String, x: int, y: int) -> bool:
	if ctrl.state.map_id != map_id:
		var hop := _next_hop(ctrl.state.map_id, map_id)
		if hop.is_empty():
			_fail("no route %s -> %s" % [ctrl.state.map_id, map_id])
			return false
		_step_toward(int(hop[1]), int(hop[2]))
		return false
	if ctrl.state.pos == Vector2i(x, y):
		return true
	_step_toward(x, y)
	return false

func _step_toward(x: int, y: int) -> void:
	var p := _bfs(ctrl.state.pos, Vector2i(x, y))
	if p.size() < 2:
		_fail("no path from %s to (%d,%d) on %s" % [str(ctrl.state.pos), x, y, ctrl.state.map_id])
		return
	var nxt: Vector2i = p[1]
	var d := nxt - ctrl.state.pos
	var dir := "down"
	if d == Vector2i(0, -1): dir = "up"
	elif d == Vector2i(-1, 0): dir = "left"
	elif d == Vector2i(1, 0): dir = "right"
	ctrl.try_move(dir)

func _bfs(from: Vector2i, to: Vector2i) -> Array:
	var m := ctrl.map
	var prev := {}
	var q: Array = [from]
	prev[from] = null
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur == to:
			break
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = cur + d
			if prev.has(n):
				continue
			if n != to and not m.is_walkable(n.x, n.y, ctrl.state):
				continue
			if n == to and not (m.is_walkable(n.x, n.y, ctrl.state)):
				continue
			prev[n] = cur
			q.append(n)
	if not prev.has(to):
		return []
	var out: Array = []
	var c = to
	while c != null:
		out.push_front(c)
		c = prev[c]
	return out
