class_name TeamBuilder
extends Control
## Six-slot team editor: species / ability / item / nature / moves / EVs. Emits battle_requested(team).

signal battle_requested(team: Array)
signal back_requested

var team: Array = []  # Array[PokemonSet]
var current: int = 0
var _species_ids: Array = []
var _item_ids: Array = []
var _nature_ids: Array = []
var _slot_buttons: Array = []
var _species_opt: OptionButton
var _ability_opt: OptionButton
var _item_opt: OptionButton
var _nature_opt: OptionButton
var _move_opts: Array = []
var _ev_spins: Dictionary = {}
var _stats_label: Label
var _error_label: Label
var _set_opt: OptionButton
var _updating := false

func _ready() -> void:
	UITheme.fill_parent(self)
	GameData.ensure_loaded()
	_species_ids = GameData.species.keys()
	_species_ids.sort()
	_item_ids = GameData.items.keys()
	_item_ids.sort()
	_nature_ids = GameData.natures.keys()
	_nature_ids.sort()
	if team.is_empty():
		team = TeamStore.get_team("player")
		if team.is_empty():
			team = TeamStore.default_team()
	_build()
	_select_slot(0)

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	# left: slots
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(230, 0)
	root.add_child(left)
	left.add_child(UITheme.make_label("チーム（6体）", 18))
	for i in range(6):
		var b := UITheme.make_button("---", 15, Vector2(220, 40))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func(): _select_slot(idx))
		left.add_child(b)
		_slot_buttons.append(b)
	left.add_child(Control.new())
	var start := UITheme.make_button("この6体で たいせん！", 17, Vector2(220, 44))
	start.pressed.connect(_on_start)
	left.add_child(start)
	var back := UITheme.make_button("タイトルへ", 15, Vector2(220, 36))
	back.pressed.connect(func(): back_requested.emit())
	left.add_child(back)
	_error_label = UITheme.make_label("", 13, Color(1, 0.5, 0.5))
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.custom_minimum_size = Vector2(220, 0)
	left.add_child(_error_label)
	# right: editor
	var panel := UITheme.make_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var ed := VBoxContainer.new()
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.add_theme_constant_override("separation", 6)
	scroll.add_child(ed)
	var row := HBoxContainer.new()
	ed.add_child(row)
	row.add_child(UITheme.make_label("しゅぞく", 15))
	_species_opt = OptionButton.new()
	for id in _species_ids:
		_species_opt.add_item(GameData.name_of("species", id))
	_species_opt.item_selected.connect(_on_species_changed)
	row.add_child(_species_opt)
	row.add_child(UITheme.make_label("  おすすめ型", 15))
	_set_opt = OptionButton.new()
	_set_opt.item_selected.connect(_on_set_selected)
	row.add_child(_set_opt)
	var row2 := HBoxContainer.new()
	ed.add_child(row2)
	row2.add_child(UITheme.make_label("とくせい", 15))
	_ability_opt = OptionButton.new()
	_ability_opt.item_selected.connect(func(_i): _apply_from_ui())
	row2.add_child(_ability_opt)
	row2.add_child(UITheme.make_label("  もちもの", 15))
	_item_opt = OptionButton.new()
	_item_opt.add_item("なし")
	for id in _item_ids:
		_item_opt.add_item(GameData.name_of("items", id))
	_item_opt.item_selected.connect(func(_i): _apply_from_ui())
	row2.add_child(_item_opt)
	row2.add_child(UITheme.make_label("  せいかく", 15))
	_nature_opt = OptionButton.new()
	for id in _nature_ids:
		_nature_opt.add_item(GameData.name_of("natures", id))
	_nature_opt.item_selected.connect(func(_i): _apply_from_ui())
	row2.add_child(_nature_opt)
	ed.add_child(UITheme.make_label("わざ", 15))
	var mg := GridContainer.new()
	mg.columns = 2
	ed.add_child(mg)
	for i in range(4):
		var o := OptionButton.new()
		o.custom_minimum_size = Vector2(260, 32)
		o.item_selected.connect(func(_i): _apply_from_ui())
		mg.add_child(o)
		_move_opts.append(o)
	ed.add_child(UITheme.make_label("どりょくち（合計510まで、各252まで）", 15))
	var eg := GridContainer.new()
	eg.columns = 6
	ed.add_child(eg)
	for st in ["hp", "atk", "def", "spa", "spd", "spe"]:
		var vb := VBoxContainer.new()
		vb.add_child(UITheme.make_label(GameData.name_of("stats", st), 13))
		var sp := SpinBox.new()
		sp.min_value = 0
		sp.max_value = 252
		sp.step = 4
		sp.value_changed.connect(func(_v): _apply_from_ui())
		vb.add_child(sp)
		eg.add_child(vb)
		_ev_spins[st] = sp
	_stats_label = UITheme.make_label("", 14, Color(0.8, 0.9, 1.0))
	ed.add_child(_stats_label)

func _refresh_slots() -> void:
	for i in range(6):
		var s: PokemonSet = team[i]
		_slot_buttons[i].text = "%d. %s" % [i + 1, GameData.name_of("species", s.species)]
		_slot_buttons[i].disabled = (i == current)

func _select_slot(i: int) -> void:
	current = i
	_refresh_slots()
	_load_to_ui()

func _load_to_ui() -> void:
	_updating = true
	var s: PokemonSet = team[current]
	_species_opt.select(_species_ids.find(s.species))
	_fill_species_dependent(s.species)
	var sp := GameData.get_species(s.species)
	var abl: Array = sp["abilities"].values()
	_ability_opt.select(maxi(0, abl.find(s.ability)))
	_item_opt.select(_item_ids.find(s.item) + 1)
	_nature_opt.select(maxi(0, _nature_ids.find(s.nature)))
	var learn := PokemonSet.learnable_moves(s.species)
	learn.sort()
	for i in range(4):
		var mid: String = s.moves[i] if i < s.moves.size() else ""
		_move_opts[i].select(learn.find(mid) + 1)
	for st in _ev_spins:
		_ev_spins[st].value = s.evs.get(st, 0)
	_updating = false
	_update_stats()

func _fill_species_dependent(species: String) -> void:
	var sp := GameData.get_species(species)
	_ability_opt.clear()
	for k in sp["abilities"]:
		_ability_opt.add_item(GameData.name_of("abilities", sp["abilities"][k]) + ("（夢）" if k == "H" else ""))
	var learn := PokemonSet.learnable_moves(species)
	learn.sort()
	for o in _move_opts:
		o.clear()
		o.add_item("---")
		for m in learn:
			var md := GameData.get_move(m)
			o.add_item("%s [%s]" % [GameData.name_of("moves", m), GameData.name_of("types", md["type"])])
	_set_opt.clear()
	_set_opt.add_item("（型を選ぶ）")
	for sd in TeamStore.recommended_sets().get(species, []):
		_set_opt.add_item(sd["name"])

func _on_species_changed(i: int) -> void:
	if _updating:
		return
	var species: String = _species_ids[i]
	var sets: Array = TeamStore.recommended_sets().get(species, [])
	if not sets.is_empty():
		team[current] = TeamStore.set_from_recommended(species, sets[0])
	else:
		team[current] = PokemonSet.from_dict({"species": species, "moves": PokemonSet.learnable_moves(species).slice(0, 4)})
	_refresh_slots()
	_load_to_ui()

func _on_set_selected(i: int) -> void:
	if _updating or i <= 0:
		return
	var s: PokemonSet = team[current]
	var sets: Array = TeamStore.recommended_sets().get(s.species, [])
	team[current] = TeamStore.set_from_recommended(s.species, sets[i - 1])
	_refresh_slots()
	_load_to_ui()

func _apply_from_ui() -> void:
	if _updating:
		return
	var s: PokemonSet = team[current]
	var sp := GameData.get_species(s.species)
	var abl: Array = sp["abilities"].values()
	s.ability = abl[clampi(_ability_opt.selected, 0, abl.size() - 1)]
	s.item = "" if _item_opt.selected <= 0 else _item_ids[_item_opt.selected - 1]
	s.nature = _nature_ids[maxi(0, _nature_opt.selected)]
	var learn := PokemonSet.learnable_moves(s.species)
	learn.sort()
	var moves: Array = []
	for o in _move_opts:
		if o.selected > 0:
			var m: String = learn[o.selected - 1]
			if not moves.has(m):
				moves.append(m)
	s.moves = moves
	for st in _ev_spins:
		s.evs[st] = int(_ev_spins[st].value)
	_update_stats()

func _update_stats() -> void:
	var s: PokemonSet = team[current]
	var sp := GameData.get_species(s.species)
	var stats := StatCalc.compute_stats(sp["base_stats"], s.ivs, s.evs, s.level, s.nature)
	var parts: PackedStringArray = []
	for st in ["hp", "atk", "def", "spa", "spd", "spe"]:
		parts.append("%s %d" % [GameData.name_of("stats", st), stats[st]])
	var errs := s.validate()
	_stats_label.text = "Lv%d 実数値: %s   努力値合計 %d" % [s.level, "  ".join(parts), s.total_evs()]
	_error_label.text = "\n".join(errs) if not errs.is_empty() else ""

func _on_start() -> void:
	var problems: Array[String] = []
	for i in range(6):
		for e in team[i].validate():
			problems.append("%d: %s" % [i + 1, e])
	if not problems.is_empty():
		_error_label.text = "\n".join(problems)
		return
	TeamStore.save_team("player", team)
	battle_requested.emit(team)
