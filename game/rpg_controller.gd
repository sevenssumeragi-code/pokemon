class_name RPGController
extends Control
## Overworld: grid movement, warps, encounters, NPC/sign events, menu, wild & trainer battles.
## Bot-friendly API: try_move(dir), interact(), dialog_confirm(), dialog_choose(i), is_busy().

signal request_title
signal game_ended

const TILE := 32
var state: GameState
var map: MapData
var renderer: MapRenderer
var dialog: DialogBox
var menu: RPGMenu = null
var battle_screen: BattleScreen = null
var runner: EventRunner
var rng := RandomNumberGenerator.new()
var mode: String = "explore"  # explore / dialog / menu / battle / shop / ending
var auto_play: bool = false
var move_duration: float = 0.16
var _moving: bool = false
var _move_t: float = 0.0
var _move_from: Vector2
var _move_to: Vector2
var _move_target: Vector2i
var _result_queue: Array = []
var _after_dialog: Callable = Callable()
var _current_trainer: String = ""
var _learn_pending: Dictionary = {}
var steps_taken: int = 0
var _hold_dir: String = ""

func _ready() -> void:
	UITheme.fill_parent(self)
	clip_contents = true
	renderer = MapRenderer.new()
	add_child(renderer)
	dialog = DialogBox.new()
	add_child(dialog)
	dialog.confirmed.connect(_on_dialog_confirmed)
	dialog.chosen.connect(_on_dialog_chosen)
	if state != null:
		_start()

func setup(s: GameState) -> void:
	state = s
	if is_inside_tree():
		_start()

func _start() -> void:
	rng.seed = state.rng_seed if state.rng_seed != 0 else int(Time.get_unix_time_from_system())
	runner = EventRunner.new(state)
	renderer.state = state
	load_map(state.map_id, state.pos.x, state.pos.y, state.dir)

func load_map(id: String, x: int, y: int, dir: String) -> void:
	map = MapData.load_map(id)
	state.map_id = id
	state.pos = Vector2i(x, y)
	state.dir = dir
	renderer.set_map(map)
	renderer.player_pos = Vector2(x * TILE, y * TILE)
	renderer.player_dir = dir
	_moving = false
	_check_auto_events()

func _check_auto_events() -> void:
	for e in map.auto_events():
		if e.has("once_flag") and bool(state.flag(str(e["once_flag"]), false)):
			continue
		run_event(str(e["event"]))
		return

# ------------------------------------------------------------------
# movement
# ------------------------------------------------------------------
static func dir_vec(d: String) -> Vector2i:
	match d:
		"up": return Vector2i(0, -1)
		"down": return Vector2i(0, 1)
		"left": return Vector2i(-1, 0)
		"right": return Vector2i(1, 0)
	return Vector2i.ZERO

func is_busy() -> bool:
	return mode != "explore" or _moving

func try_move(d: String) -> bool:
	if is_busy():
		return false
	state.dir = d
	renderer.player_dir = d
	var t := state.pos + dir_vec(d)
	if not map.is_walkable(t.x, t.y, state):
		return false
	_moving = true
	_move_t = 0.0
	_move_from = Vector2(state.pos.x * TILE, state.pos.y * TILE)
	_move_to = Vector2(t.x * TILE, t.y * TILE)
	_move_target = t
	if auto_play or move_duration <= 0.0:
		_finish_move()
	return true

func _finish_move() -> void:
	_moving = false
	state.pos = _move_target
	renderer.player_pos = _move_to
	steps_taken += 1
	state.play_seconds += move_duration
	var w = map.warp_at(state.pos.x, state.pos.y)
	if w != null:
		load_map(str(w["map"]), int(w["tx"]), int(w["ty"]), str(w.get("dir", state.dir)))
		return
	var ev = map.event_at(state.pos.x, state.pos.y, "step")
	if ev != null:
		run_event(str(ev["event"]))
		return
	if map.is_encounter_tile(state.pos.x, state.pos.y) and not state.alive_party().is_empty():
		var enc := map.roll_encounter(rng)
		if not enc.is_empty():
			start_wild_battle(str(enc["species"]), int(enc["level"]))

func _process(delta: float) -> void:
	if state == null:
		return
	if _moving:
		_move_t += delta
		var f := clampf(_move_t / move_duration, 0.0, 1.0)
		renderer.player_pos = _move_from.lerp(_move_to, f)
		if f >= 1.0:
			_finish_move()
		return
	if mode == "explore" and not auto_play:
		var d := ""
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): d = "up"
		elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): d = "down"
		elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): d = "left"
		elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): d = "right"
		if d != "":
			try_move(d)

func _unhandled_input(event: InputEvent) -> void:
	if auto_play or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if mode == "explore" and not _moving:
		if event.keycode in [KEY_Z, KEY_ENTER, KEY_SPACE]:
			interact()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_X, KEY_ESCAPE]:
			open_menu()
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------
# interaction / events
# ------------------------------------------------------------------
func interact() -> bool:
	if is_busy():
		return false
	var t := state.pos + dir_vec(state.dir)
	var npc = map.npc_at(t.x, t.y, state)
	if npc != null:
		run_event(str(npc["event"]))
		return true
	var ev = map.event_at(t.x, t.y, "interact")
	if ev != null:
		run_event(str(ev["event"]))
		return true
	return false

func run_event(id: String) -> void:
	runner.start(id)
	mode = "dialog"
	_pump()

func _pump() -> void:
	var req := runner.next()
	match str(req.get("type", "")):
		"done":
			dialog.hide_box()
			mode = "explore"
			if _after_dialog.is_valid():
				var cb := _after_dialog
				_after_dialog = Callable()
				cb.call()
		"message", "heal":
			_show_message(str(req["text"]), func(): runner.resume(); _pump())
		"wait":
			runner.resume()
			_pump()
		"choice":
			dialog.show_choice(str(req["text"]), req["options"])
		"starter_choice":
			var opts: Array = []
			for o in req["options"]:
				opts.append(str(GameData.localization.get("text", {}).get(str(o.get("text", "")), GameData.name_of("species", str(o["species"])))))
			dialog.show_choice(str(req["text"]), opts)
		"warp":
			dialog.hide_box()
			load_map(str(req["map"]), int(req["x"]), int(req["y"]), str(req["dir"]))
			runner.resume()
			if mode == "dialog":
				_pump()
		"trainer_battle":
			dialog.hide_box()
			start_trainer_battle(str(req["trainer"]))
		"shop":
			dialog.hide_box()
			mode = "shop"
			_ensure_menu()
			menu.visible = true
			menu.show_shop(req["items"])
		"end_game":
			_show_message(str(req["text"]), func(): runner.resume(); mode = "ending"; dialog.hide_box(); state.save(1); game_ended.emit())

func _show_message(text: String, then: Callable) -> void:
	mode = "dialog"
	dialog.show_message(text)
	_after_message = then
	if auto_play:
		call_deferred("_on_dialog_confirmed")

var _after_message: Callable = Callable()

func _on_dialog_confirmed() -> void:
	if not dialog.visible or dialog.awaiting_choice:
		return
	var cb := _after_message
	_after_message = Callable()
	if cb.is_valid():
		cb.call()

func _on_dialog_chosen(i: int) -> void:
	if mode == "dialog" and not runner.finished:
		runner.resume(i)
		_pump()
	elif mode == "learn":
		_apply_learn_choice(i)

## Bot helpers
func dialog_confirm() -> void:
	_on_dialog_confirmed()

func dialog_choose(i: int) -> void:
	_on_dialog_chosen(i)

# ------------------------------------------------------------------
# menu
# ------------------------------------------------------------------
func _ensure_menu() -> void:
	if menu == null:
		menu = RPGMenu.new()
		menu.state = state
		add_child(menu)
		menu.closed.connect(_on_menu_closed)
		menu.message.connect(func(t): _show_message(t, func(): mode = "menu" if menu.visible else "explore"))
		menu.save_requested.connect(func(): state.save(1))
	menu.state = state

func open_menu() -> void:
	if is_busy():
		return
	_ensure_menu()
	mode = "menu"
	menu.visible = true
	menu.show_main()

func _on_menu_closed() -> void:
	menu.visible = false
	if mode == "shop":
		mode = "dialog"
		runner.resume()
		_pump()
	else:
		mode = "explore"

# ------------------------------------------------------------------
# battles
# ------------------------------------------------------------------
func start_wild_battle(species: String, level: int) -> void:
	var b := BattleFlow.make_wild_battle(state, species, level, rng)
	_current_trainer = ""
	_launch_battle(b)

func start_trainer_battle(trainer_id: String) -> void:
	var b := BattleFlow.make_trainer_battle(state, trainer_id, rng)
	_current_trainer = trainer_id
	_launch_battle(b)

func _launch_battle(b: Battle) -> void:
	mode = "battle"
	battle_screen = BattleScreen.new()
	battle_screen.battle_override = b
	battle_screen.auto_play = auto_play
	battle_screen.bot_can_catch = auto_play
	battle_screen.player_team = BattleFlow.party_sets(state)
	battle_screen.battle_finished.connect(_on_battle_finished)
	add_child(battle_screen)

func _on_battle_finished(_winner: int) -> void:
	var b := battle_screen.battle
	var results := BattleFlow.apply_results(state, b, _current_trainer)
	var lost := (b.winner == 1 and not b.escaped and b.captured == null)
	var won := b.winner == 0
	battle_screen.queue_free()
	battle_screen = null
	mode = "dialog"
	if lost:
		results.append_array(BattleFlow.white_out(state))
	_result_queue = results
	_after_dialog = func():
		if lost:
			load_map(state.map_id, state.pos.x, state.pos.y, state.dir)
			if not runner.finished:
				runner.resume(false)
				mode = "dialog"
				_pump()
		elif _current_trainer != "" and not runner.finished:
			mode = "dialog"
			runner.resume(won)
			_pump()
		_current_trainer = ""
	_next_result()

func _next_result() -> void:
	if _result_queue.is_empty():
		dialog.hide_box()
		mode = "explore"
		if _after_dialog.is_valid():
			var cb := _after_dialog
			_after_dialog = Callable()
			cb.call()
		return
	var r: Dictionary = _result_queue.pop_front()
	match str(r["type"]):
		"message":
			_show_message(str(r["text"]), _next_result)
		"evolve":
			var ps: PokemonSet = state.party[int(r["index"])]
			var old := GameData.name_of("species", ps.species)
			BattleFlow.apply_evolve(state, int(r["index"]), str(r["into"]))
			_show_message("おや…？ %sの ようすが…！\nおめでとう！ %sは %sに しんかした！" % [old, old, GameData.name_of("species", ps.species)], _next_result)
		"learn":
			_learn_pending = r
			var ps: PokemonSet = state.party[int(r["index"])]
			if auto_play:
				BattleFlow.apply_learn(state, int(r["index"]), str(r["move"]), 0)
				_next_result()
				return
			mode = "learn"
			var opts: Array = []
			for m in ps.moves:
				opts.append(GameData.name_of("moves", m) + " を わすれる")
			opts.append("おぼえない")
			dialog.show_choice("%sは %s を おぼえたい…。 どの わざを わすれる？" % [GameData.name_of("species", ps.species), GameData.name_of("moves", str(r["move"]))], opts)

func _apply_learn_choice(i: int) -> void:
	var r := _learn_pending
	_learn_pending = {}
	var ps: PokemonSet = state.party[int(r["index"])]
	if i < ps.moves.size():
		var forgot := GameData.name_of("moves", ps.moves[i])
		BattleFlow.apply_learn(state, int(r["index"]), str(r["move"]), i)
		_show_message("%sは %s を わすれて %s を おぼえた！" % [GameData.name_of("species", ps.species), forgot, GameData.name_of("moves", str(r["move"]))], _next_result)
	else:
		_show_message("%sは %s を おぼえなかった。" % [GameData.name_of("species", ps.species), GameData.name_of("moves", str(r["move"]))], _next_result)
