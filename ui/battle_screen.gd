class_name BattleScreen
extends Control
## Human-vs-CPU battle screen. Drives a Battle, replays its log with pacing, shows commands.
## Layout: enemy info (top-left) + enemy sprite (top-right) / player sprite (bottom-left) + player info (bottom-right)
##         / message box + command panel (bottom).

signal battle_finished(winner: int)
signal back_to_title

var player_team: Array = []
var cpu_team: Array = []
var seed_value: int = 0
var auto_play: bool = false  # headless/self-test: player side is also AI-controlled, no delays
var message_delay: float = 0.8
var battle_override: Battle = null  # RPG layer supplies a prebuilt battle (wild/trainer)
var bot_can_catch: bool = false      # auto-play throws balls at weakened wild monsters

var battle: Battle
var cpu_ai: HeuristicAI
var auto_ai: HeuristicAI
var _log_index: int = 0
var _state: String = "idle"  # idle / playing / command / switch / ended
var _timer: float = 0.0
var _waiting_bar: bool = false
var _pending_entries: Array = []

# UI nodes
var _enemy_name: Label
var _enemy_status: Label
var _enemy_boosts: Label
var _enemy_bar: HPBar
var _enemy_sprite: TextureRect
var _player_name: Label
var _player_status: Label
var _player_boosts: Label
var _player_bar: HPBar
var _player_sprite: TextureRect
var _field_label: Label
var _message: RichTextLabel
var _cmd_panel: Control
var _move_panel: Control
var _switch_panel: Control
var _result_panel: Control
var _result_label: Label
var _move_buttons: Array = []
var _switch_buttons: Array = []
var _team_icons: HBoxContainer
var _enemy_team_icons: HBoxContainer
var _bag_note: Label
var _bag_panel: VBoxContainer
var _bag_item_pending: String = ""
var _rpg_finish_pending: bool = false

func _ready() -> void:
	UITheme.fill_parent(self)
	GameData.ensure_loaded()
	_build_ui()
	if not player_team.is_empty():
		start_battle()

func start_battle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	if battle_override != null:
		battle = battle_override
	else:
		if cpu_team.is_empty():
			cpu_team = TeamStore.random_team(6, rng)
		battle = Battle.new({"seed": rng.randi(), "teams": [player_team, cpu_team], "names": ["あなた", "CPU"], "log": true})
	cpu_ai = HeuristicAI.new(rng.randi())
	cpu_ai.known_moves_only = true
	auto_ai = HeuristicAI.new(rng.randi())
	_log_index = 0
	battle.start()
	_sync_all(true)
	_begin_playback()

# ------------------------------------------------------------------
# UI construction
# ------------------------------------------------------------------
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.32, 0.55, 0.38)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ground := ColorRect.new()
	ground.color = Color(0.25, 0.45, 0.3)
	ground.anchor_top = 0.62
	ground.anchor_bottom = 1.0
	ground.anchor_right = 1.0
	add_child(ground)

	# enemy sprite
	_enemy_sprite = TextureRect.new()
	_enemy_sprite.custom_minimum_size = Vector2(192, 192)
	_enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enemy_sprite.anchor_left = 0.62
	_enemy_sprite.anchor_right = 0.62
	_enemy_sprite.anchor_top = 0.06
	_enemy_sprite.anchor_bottom = 0.06
	_enemy_sprite.offset_right = 192
	_enemy_sprite.offset_bottom = 192
	add_child(_enemy_sprite)
	# player sprite
	_player_sprite = TextureRect.new()
	_player_sprite.custom_minimum_size = Vector2(224, 224)
	_player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_sprite.anchor_left = 0.12
	_player_sprite.anchor_right = 0.12
	_player_sprite.anchor_top = 0.30
	_player_sprite.anchor_bottom = 0.30
	_player_sprite.offset_right = 224
	_player_sprite.offset_bottom = 224
	add_child(_player_sprite)

	# enemy info panel
	var ep := UITheme.make_panel()
	ep.anchor_left = 0.03
	ep.anchor_top = 0.05
	ep.offset_right = 300
	add_child(ep)
	var ev := VBoxContainer.new()
	ep.add_child(ev)
	_enemy_name = UITheme.make_label("", 17)
	ev.add_child(_enemy_name)
	_enemy_bar = HPBar.new()
	_enemy_bar.show_numbers = false
	_enemy_bar.custom_minimum_size = Vector2(240, 14)
	_enemy_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ev.add_child(_enemy_bar)
	_enemy_status = UITheme.make_label("", 13, Color(1, 0.85, 0.5))
	ev.add_child(_enemy_status)
	_enemy_boosts = UITheme.make_label("", 12, Color(0.8, 0.9, 1))
	ev.add_child(_enemy_boosts)
	_enemy_team_icons = HBoxContainer.new()
	ev.add_child(_enemy_team_icons)

	# player info panel
	var pp := UITheme.make_panel()
	pp.anchor_left = 0.60
	pp.anchor_top = 0.36
	pp.offset_right = 360
	add_child(pp)
	var pv := VBoxContainer.new()
	pp.add_child(pv)
	_player_name = UITheme.make_label("", 17)
	pv.add_child(_player_name)
	_player_bar = HPBar.new()
	_player_bar.custom_minimum_size = Vector2(200, 14)
	_player_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pv.add_child(_player_bar)
	_player_status = UITheme.make_label("", 13, Color(1, 0.85, 0.5))
	pv.add_child(_player_status)
	_player_boosts = UITheme.make_label("", 12, Color(0.8, 0.9, 1))
	pv.add_child(_player_boosts)
	_team_icons = HBoxContainer.new()
	pv.add_child(_team_icons)

	# field info
	var fp := UITheme.make_panel(Color(0.05, 0.05, 0.1, 0.7))
	fp.anchor_left = 0.35
	fp.anchor_right = 0.65
	fp.anchor_top = 0.0
	fp.offset_top = 4
	add_child(fp)
	_field_label = UITheme.make_label("", 13, Color(0.9, 0.9, 0.6))
	_field_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fp.add_child(_field_label)

	# bottom: message + commands
	var bottom := HBoxContainer.new()
	bottom.anchor_top = 0.72
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_left = 8
	bottom.offset_right = -8
	bottom.offset_bottom = -8
	bottom.add_theme_constant_override("separation", 8)
	add_child(bottom)
	var mp := UITheme.make_panel()
	mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(mp)
	_message = RichTextLabel.new()
	_message.scroll_following = true
	_message.add_theme_font_size_override("normal_font_size", 17)
	_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mp.add_child(_message)
	var cp := UITheme.make_panel()
	cp.custom_minimum_size = Vector2(380, 0)
	bottom.add_child(cp)
	var stack := Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cp.add_child(stack)
	# command panel
	_cmd_panel = GridContainer.new()
	_cmd_panel.columns = 2
	_cmd_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_cmd_panel)
	var b_fight := UITheme.make_button("たたかう", 20, Vector2(170, 56))
	b_fight.pressed.connect(_show_moves)
	_cmd_panel.add_child(b_fight)
	var b_mon := UITheme.make_button("モンスター", 20, Vector2(170, 56))
	b_mon.pressed.connect(func(): _show_switch(false))
	_cmd_panel.add_child(b_mon)
	var b_bag := UITheme.make_button("アイテム", 20, Vector2(170, 56))
	b_bag.pressed.connect(_show_bag)
	_cmd_panel.add_child(b_bag)
	var b_run := UITheme.make_button("にげる", 20, Vector2(170, 56))
	b_run.pressed.connect(_forfeit)
	_cmd_panel.add_child(b_run)
	_bag_note = UITheme.make_label("", 12, Color(1, 0.7, 0.7))
	_cmd_panel.add_child(_bag_note)
	# move panel
	_move_panel = VBoxContainer.new()
	_move_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_move_panel)
	var mg := GridContainer.new()
	mg.columns = 2
	_move_panel.add_child(mg)
	for i in range(4):
		var b := UITheme.make_button("-", 15, Vector2(170, 52))
		var idx := i
		b.pressed.connect(func(): _choose_move(idx))
		mg.add_child(b)
		_move_buttons.append(b)
	var mback := UITheme.make_button("もどる", 14, Vector2(100, 30))
	mback.pressed.connect(_show_commands)
	_move_panel.add_child(mback)
	# switch panel
	_switch_panel = VBoxContainer.new()
	_switch_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_switch_panel)
	var sg := GridContainer.new()
	sg.columns = 2
	_switch_panel.add_child(sg)
	for i in range(6):
		var b := UITheme.make_button("-", 13, Vector2(170, 40))
		var idx := i
		b.pressed.connect(func(): _choose_switch(idx))
		sg.add_child(b)
		_switch_buttons.append(b)
	var sback := UITheme.make_button("もどる", 14, Vector2(100, 30))
	sback.pressed.connect(_show_commands)
	_switch_panel.add_child(sback)
	# bag panel
	_bag_panel = VBoxContainer.new()
	_bag_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_bag_panel)
	# result panel
	_result_panel = VBoxContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_result_panel)
	_result_label = UITheme.make_label("", 22)
	_result_panel.add_child(_result_label)
	var rb := UITheme.make_button("タイトルへ もどる", 16, Vector2(200, 44))
	rb.pressed.connect(func(): back_to_title.emit())
	_result_panel.add_child(rb)
	_hide_panels()

func _hide_panels() -> void:
	_bag_panel.visible = false
	_cmd_panel.visible = false
	_move_panel.visible = false
	_switch_panel.visible = false
	_result_panel.visible = false

# ------------------------------------------------------------------
# Sync helpers
# ------------------------------------------------------------------
func _active(side: int) -> BattlePokemon:
	var s = battle.sides[side]
	for p in s.active:
		if p != null:
			return p
	return null

func _sync_all(instant: bool) -> void:
	_sync_side(0, instant)
	_sync_side(1, instant)
	_sync_field()
	_sync_team_icons()

func _sync_side(side: int, instant: bool) -> void:
	var p := _active(side)
	var name_l := _player_name if side == 0 else _enemy_name
	var bar := _player_bar if side == 0 else _enemy_bar
	var sprite := _player_sprite if side == 0 else _enemy_sprite
	var status_l := _player_status if side == 0 else _enemy_status
	var boosts_l := _player_boosts if side == 0 else _enemy_boosts
	if p == null:
		name_l.text = ""
		sprite.texture = null
		return
	name_l.text = "%s  Lv%d" % [GameData.name_of("species", p.species_id), p.level]
	bar.set_hp(p.max_hp, p.hp, instant)
	sprite.texture = SpriteLoader.get_texture(p.species_id, side == 0)
	sprite.modulate = Color(1, 1, 1, 0.0 if p.fainted else 1.0)
	_sync_status(p, status_l, boosts_l)

func _sync_status(p: BattlePokemon, status_l: Label, boosts_l: Label) -> void:
	var st := ""
	if p.status != "":
		st = GameData.name_of("status", p.status)
	var vols: PackedStringArray = []
	for v in ["confusion", "leech_seed", "substitute", "attract", "taunt", "encore", "yawn", "perish_song", "curse"]:
		if p.volatiles.has(v):
			vols.append(GameData.name_of("status", v) if GameData.localization.get("status", {}).has(v) else GameData.name_of("moves", v))
	status_l.text = st + ("  " + " ".join(vols) if not vols.is_empty() else "")
	var bs: PackedStringArray = []
	for k in ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"]:
		var b: int = p.boosts[k]
		if b != 0:
			bs.append("%s%+d" % [GameData.name_of("stats", k), b])
	boosts_l.text = " ".join(bs)

func _sync_field() -> void:
	var parts: PackedStringArray = []
	if battle.weather != "":
		parts.append(GameData.name_of("weather", battle.weather) + "(%d)" % int(battle.weather_state.get("duration", 0)))
	if battle.terrain != "":
		parts.append(GameData.name_of("terrain", battle.terrain) + "(%d)" % int(battle.terrain_state.get("duration", 0)))
	for pw in battle.pseudo_weather:
		parts.append(GameData.name_of("field", pw) + "(%d)" % int(battle.pseudo_weather[pw].get("duration", 0)))
	for i in range(2):
		var sc: Dictionary = battle.sides[i].side_conditions
		if not sc.is_empty():
			var names: PackedStringArray = []
			for k in sc:
				names.append(GameData.name_of("side_conditions", k))
			parts.append(("みかた: " if i == 0 else "あいて: ") + " ".join(names))
	_field_label.text = "ターン %d   %s" % [battle.turn, "  ".join(parts)]

func _sync_team_icons() -> void:
	for i in range(2):
		var box := _team_icons if i == 0 else _enemy_team_icons
		for c in box.get_children():
			c.queue_free()
		for p in battle.sides[i].team:
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(14, 14)
			dot.color = Color(0.4, 0.4, 0.4) if p.fainted else (Color(0.9, 0.8, 0.2) if p.status != "" else Color(0.3, 0.9, 0.4))
			box.add_child(dot)

# ------------------------------------------------------------------
# Log playback
# ------------------------------------------------------------------
func _begin_playback() -> void:
	_state = "playing"
	_hide_panels()
	_timer = 0.0

func _process(delta: float) -> void:
	if battle == null:
		return
	if _rpg_finish_pending:
		_timer -= delta
		if _timer <= 0.0 or auto_play:
			_rpg_finish_pending = false
			battle_finished.emit(battle.winner)
		return
	if _state == "playing":
		if _waiting_bar:
			if _player_bar.is_animating() or _enemy_bar.is_animating():
				return
			_waiting_bar = false
		_timer -= delta
		if _timer > 0.0 and not auto_play:
			return
		_advance_log()

func _input(event: InputEvent) -> void:
	if _state == "playing" and (event is InputEventMouseButton and event.pressed or event is InputEventKey and event.pressed):
		_timer = 0.0

func _advance_log() -> void:
	while _log_index < battle.log.size():
		var e: Array = battle.log[_log_index]
		_log_index += 1
		var handled_visual := _apply_visual(e)
		var text := LogFormatter.format(e)
		if text != "":
			_message.append_text(text + "\n")
			_timer = message_delay if not auto_play else 0.0
			if handled_visual:
				_waiting_bar = true
			return
		if handled_visual:
			_waiting_bar = true
			_timer = 0.2
			return
	# log exhausted
	_sync_all(false)
	_after_playback()

## Update sprites/bars for an entry. Returns true if an HP animation was started.
func _apply_visual(e: Array) -> bool:
	match str(e[0]):
		"-hp", "-damage", "-heal", "-sethp":
			var side := 0 if str(e[1]).begins_with("p1") else 1
			var bar := _player_bar if side == 0 else _enemy_bar
			bar.set_hp(int(e[3]), int(e[2]))
			return true
		"switch", "drag":
			var side := 0 if str(e[1]).begins_with("p1") else 1
			_sync_side(side, true)
			_sync_team_icons()
		"faint":
			var side := 0 if str(e[1]).begins_with("p1") else 1
			var sprite := _player_sprite if side == 0 else _enemy_sprite
			sprite.modulate = Color(1, 1, 1, 0.15)
			_sync_team_icons()
		"turn", "-weather", "-fieldstart", "-fieldend", "-sidestart", "-sideend":
			_sync_field()
		"-status", "-curestatus", "-boost", "-unboost", "-start", "-end", "-clearallboost", "-clearboost":
			var side := 0 if str(e[1]).begins_with("p1") else 1
			var p := _active(side)
			if p != null:
				_sync_status(p, _player_status if side == 0 else _enemy_status, _player_boosts if side == 0 else _enemy_boosts)
			_sync_team_icons()
	return false

func _after_playback() -> void:
	if battle.ended:
		_state = "ended"
		_hide_panels()
		_result_panel.visible = true
		if battle.captured != null:
			_result_label.text = "つかまえた！"
		elif battle.escaped:
			_result_label.text = "うまく にげきれた！"
		elif battle.winner == 0:
			_result_label.text = "あなたの かち！"
		elif battle.winner == 1:
			_result_label.text = "あなたの まけ…"
		else:
			_result_label.text = "ひきわけ"
		if battle_override != null:
			_result_panel.visible = false
			_timer = 0.6
			_rpg_finish_pending = true
			return
		battle_finished.emit(battle.winner)
		return
	# CPU decides whenever it has a request
	_cpu_decide()
	if battle.ended or _log_index < battle.log.size():
		_begin_playback()
		return
	var req: Dictionary = battle.sides[0].request
	if req.get("type", "wait") == "wait":
		# nothing for the player to do (e.g. only CPU switching) — CPU already decided; continue
		if _log_index < battle.log.size():
			_begin_playback()
		return
	if auto_play:
		var ch := auto_ai.choose(battle, 0, req)
		if bot_can_catch and battle.is_wild and req["type"] == "move" and battle.sides[0].team.size() < 6:
			var foe = battle.sides[1].active[0]
			var ball := ""
			for id in ["ultra_ball", "great_ball", "monster_ball"]:
				if int(battle.bag.get(id, 0)) > 0:
					ball = id
					break
			if ball != "" and foe != null and foe.hp * 2 <= foe.max_hp:
				ch = [{"type": "item", "item": ball, "target": -1}]
		battle.choose(0, ch)
		_cpu_decide()
		_begin_playback()
		return
	if req["type"] == "switch":
		_show_switch(true)
	else:
		_show_commands()

func _cpu_decide() -> void:
	var req: Dictionary = battle.sides[1].request
	if req.get("type", "wait") != "wait" and battle.sides[1].choice.is_empty():
		var ch := cpu_ai.choose(battle, 1, req)
		var err := battle.choose(1, ch)
		if err != "":
			battle.choose(1, cpu_ai.fallback(req))

# ------------------------------------------------------------------
# Player commands
# ------------------------------------------------------------------
func _show_commands() -> void:
	_state = "command"
	_hide_panels()
	_bag_note.text = ""
	_cmd_panel.visible = true

func _show_moves() -> void:
	var req: Dictionary = battle.sides[0].request
	if req.get("type") != "move":
		return
	_hide_panels()
	_move_panel.visible = true
	var moves: Array = req["active"][0]["moves"]
	for i in range(4):
		var b: Button = _move_buttons[i]
		if i < moves.size():
			var m: Dictionary = moves[i]
			var md := GameData.get_move(m["id"])
			b.text = "%s\n%s  PP %d/%d" % [GameData.name_of("moves", m["id"]), GameData.name_of("types", md.get("type", "normal")), m["pp"], m["max_pp"]]
			b.disabled = m["disabled"]
			b.visible = true
		else:
			b.visible = false

func _show_switch(forced: bool) -> void:
	_state = "switch"
	_hide_panels()
	_switch_panel.visible = true
	_switch_panel.get_child(1).visible = not forced
	var req: Dictionary = battle.sides[0].request
	var trapped: bool = req.get("type") == "move" and req["active"][0]["trapped"]
	for i in range(6):
		var b: Button = _switch_buttons[i]
		if i < battle.sides[0].team.size():
			var p = battle.sides[0].team[i]
			b.visible = true
			b.text = "%s  %d/%d %s" % [GameData.name_of("species", p.species_id), p.hp, p.max_hp, GameData.name_of("status", p.status) if p.status != "" else ""]
			b.disabled = p.fainted or p.active or trapped
		else:
			b.visible = false
	if trapped:
		_bag_note.text = "にげられない！ こうたいできない！"

func _choose_move(i: int) -> void:
	var req: Dictionary = battle.sides[0].request
	if req.get("type") != "move":
		return
	var moves: Array = req["active"][0]["moves"]
	if i >= moves.size():
		return
	var err := battle.choose(0, [{"type": "move", "move": moves[i]["id"]}])
	if err != "":
		_message.append_text("[color=salmon]%s[/color]\n" % err)
		return
	_cpu_decide()
	_begin_playback()

func _choose_switch(i: int) -> void:
	if _bag_item_pending != "":
		_choose_item(_bag_item_pending, i)
		return
	var err := battle.choose(0, [{"type": "switch", "index": i}])
	if err != "":
		_message.append_text("[color=salmon]%s[/color]\n" % err)
		return
	_cpu_decide()
	_begin_playback()

func _show_bag() -> void:
	var req: Dictionary = battle.sides[0].request
	if req.get("type") != "move" or not battle.allow_items:
		_bag_note.text = "たいせんでは アイテムは つかえない！"
		return
	_hide_panels()
	_bag_panel.visible = true
	for c in _bag_panel.get_children():
		c.queue_free()
	var ids: Array = battle.bag.keys()
	ids.sort()
	var any := false
	var grid := GridContainer.new()
	grid.columns = 2
	_bag_panel.add_child(grid)
	for id in ids:
		var pocket := str(GameData.get_item(id).get("pocket", "held"))
		if pocket != "medicine" and pocket != "ball":
			continue
		if pocket == "ball" and not battle.is_wild:
			continue
		any = true
		var iid: String = id
		var b := UITheme.make_button("%s ×%d" % [GameData.name_of("items", id), int(battle.bag[id])], 14, Vector2(170, 36))
		b.pressed.connect(func(): _pick_bag_item(iid))
		grid.add_child(b)
	if not any:
		_bag_panel.add_child(UITheme.make_label("つかえる アイテムが ない", 14))
	var back := UITheme.make_button("もどる", 14, Vector2(100, 30))
	back.pressed.connect(_show_commands)
	_bag_panel.add_child(back)

func _pick_bag_item(id: String) -> void:
	var pocket := str(GameData.get_item(id).get("pocket", "held"))
	if pocket == "ball":
		_choose_item(id, -1)
		return
	_bag_item_pending = id
	_hide_panels()
	_switch_panel.visible = true
	_switch_panel.get_child(1).visible = true
	for i in range(6):
		var b: Button = _switch_buttons[i]
		if i < battle.sides[0].team.size():
			var p = battle.sides[0].team[i]
			b.visible = true
			b.text = "%s  %d/%d %s" % [GameData.name_of("species", p.species_id), p.hp, p.max_hp, GameData.name_of("status", p.status) if p.status != "" else ""]
			b.disabled = false
		else:
			b.visible = false

func _choose_item(id: String, target: int) -> void:
	_bag_item_pending = ""
	var err := battle.choose(0, [{"type": "item", "item": id, "target": target}])
	if err != "":
		_message.append_text("[color=salmon]%s[/color]\n" % err)
		_show_commands()
		return
	_cpu_decide()
	_begin_playback()

func _forfeit() -> void:
	if battle.is_wild:
		var req: Dictionary = battle.sides[0].request
		if req.get("type") == "move":
			battle.choose(0, [{"type": "run"}])
			_cpu_decide()
			_begin_playback()
		return
	_state = "ended"
	_hide_panels()
	_result_panel.visible = true
	_result_label.text = "にげだした…"
	battle_finished.emit(1)
