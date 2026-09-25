class_name RPGMenu
extends Control
## Pause menu: パーティ / バッグ / ずかん / セーブ / せってい / とじる. Also hosts the shop screen.

signal closed
signal message(text: String)
signal save_requested

var state: GameState
var _root: PanelContainer
var _content: VBoxContainer
var _mode: String = "main"
var _selected_item: String = ""

func _ready() -> void:
	UITheme.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_root = UITheme.make_panel()
	_root.anchor_left = 0.1
	_root.anchor_right = 0.9
	_root.anchor_top = 0.06
	_root.anchor_bottom = 0.94
	add_child(_root)
	var scroll := ScrollContainer.new()
	_root.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)
	show_main()

func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()

func _btn(text: String, cb: Callable, size: int = 17) -> Button:
	var b := UITheme.make_button(text, size, Vector2(300, 40))
	b.pressed.connect(cb)
	_content.add_child(b)
	return b

func show_main() -> void:
	_mode = "main"
	_clear()
	_content.add_child(UITheme.make_label("メニュー    所持金 %d円   バッジ %d" % [state.money, state.badges], 20))
	_btn("パーティ", show_party)
	_btn("バッグ", show_bag)
	_btn("ずかん", show_dex)
	_btn("セーブ", func(): save_requested.emit(); message.emit("セーブしました。"))
	_btn("せってい", show_settings)
	_btn("とじる", func(): closed.emit())

func _party_line(ps: PokemonSet) -> String:
	var sp := GameData.get_species(ps.species)
	var max_hp := StatCalc.calc_hp(int(sp["base_stats"]["hp"]), int(ps.ivs["hp"]), int(ps.evs["hp"]), ps.level)
	var cur := max_hp if ps.current_hp < 0 else ps.current_hp
	return "%s Lv%d  HP %d/%d %s" % [GameData.name_of("species", ps.species), ps.level, cur, max_hp, GameData.name_of("status", ps.status) if ps.status != "" else ""]

func show_party(item_to_use: String = "") -> void:
	_mode = "party"
	_selected_item = item_to_use
	_clear()
	_content.add_child(UITheme.make_label("パーティ" + ("  — %s を つかう あいてを えらぶ" % GameData.name_of("items", item_to_use) if item_to_use != "" else ""), 20))
	for i in range(state.party.size()):
		var idx := i
		_btn(_party_line(state.party[i]), func(): _on_party_pick(idx))
	_btn("もどる", show_main)

func _on_party_pick(i: int) -> void:
	if _selected_item != "":
		var msg := BattleFlow.use_item_on_party(state, _selected_item, i)
		message.emit(msg if msg != "" else "つかっても こうかが ない！")
		if state.has_item(_selected_item):
			show_party(_selected_item)
		else:
			show_bag()
		return
	# detail + reorder
	_clear()
	var ps: PokemonSet = state.party[i]
	var sp := GameData.get_species(ps.species)
	var stats := StatCalc.compute_stats(sp["base_stats"], ps.ivs, ps.evs, ps.level, ps.nature)
	_content.add_child(UITheme.make_label(_party_line(ps), 20))
	_content.add_child(UITheme.make_label("タイプ: %s   とくせい: %s   もちもの: %s   せいかく: %s" % [" / ".join(sp["types"].map(func(t): return GameData.name_of("types", t))), GameData.name_of("abilities", ps.ability), GameData.name_of("items", ps.item) if ps.item != "" else "なし", GameData.name_of("natures", ps.nature)], 15))
	_content.add_child(UITheme.make_label("こうげき %d  ぼうぎょ %d  とくこう %d  とくぼう %d  すばやさ %d" % [stats["atk"], stats["def"], stats["spa"], stats["spd"], stats["spe"]], 15))
	_content.add_child(UITheme.make_label("わざ: " + ", ".join(ps.moves.map(func(m): return GameData.name_of("moves", m))), 15))
	_content.add_child(UITheme.make_label(str(GameData.localization.get("dex", {}).get(ps.species, "")), 14, Color(0.8, 0.85, 0.9)))
	if i > 0:
		_btn("先頭に する", func(): var p = state.party.pop_at(i); state.party.insert(0, p); show_party())
	_btn("もどる", show_party)

func show_bag() -> void:
	_mode = "bag"
	_clear()
	_content.add_child(UITheme.make_label("バッグ", 20))
	var ids: Array = state.bag.keys()
	ids.sort()
	if ids.is_empty():
		_content.add_child(UITheme.make_label("なにも もっていない。", 16))
	for id in ids:
		var idef := GameData.get_item(id)
		var iid: String = id
		_btn("%s ×%d  [%s]" % [GameData.name_of("items", id), state.bag[id], _pocket_name(str(idef.get("pocket", "held")))], func(): _on_bag_pick(iid))
	_btn("もどる", show_main)

func _pocket_name(p: String) -> String:
	match p:
		"medicine": return "くすり"
		"ball": return "ボール"
		"evolution": return "しんか"
		"key": return "たいせつなもの"
	return "もちもの"

func _on_bag_pick(id: String) -> void:
	var pocket := str(GameData.get_item(id).get("pocket", "held"))
	if pocket == "medicine" or pocket == "evolution":
		show_party(id)
	elif pocket == "held":
		_clear()
		_content.add_child(UITheme.make_label("%s を だれに もたせる？" % GameData.name_of("items", id), 18))
		for i in range(state.party.size()):
			var idx := i
			_btn(_party_line(state.party[i]), func(): _give_held(id, idx))
		_btn("もどる", show_bag)
	else:
		message.emit("ここでは つかえない。")

func _give_held(id: String, idx: int) -> void:
	var ps: PokemonSet = state.party[idx]
	if ps.item != "":
		state.add_item(ps.item, 1)
	ps.item = id
	state.add_item(id, -1)
	message.emit("%sに %sを もたせた。" % [GameData.name_of("species", ps.species), GameData.name_of("items", id)])
	show_bag()

func show_dex() -> void:
	_mode = "dex"
	_clear()
	var ids: Array = GameData.species.keys()
	ids.sort_custom(func(a, b): return int(GameData.species[a].get("num", 0)) < int(GameData.species[b].get("num", 0)))
	var seen := state.dex_seen.size()
	var caught := state.dex_caught.size()
	_content.add_child(UITheme.make_label("ずかん  みつけた %d  つかまえた %d" % [seen, caught], 20))
	for id in ids:
		var num := int(GameData.species[id].get("num", 0))
		if state.dex_caught.has(id):
			var sp: Dictionary = GameData.species[id]
			_content.add_child(UITheme.make_label("No.%02d %s  [%s]  %s" % [num, GameData.name_of("species", id), " / ".join(sp["types"].map(func(t): return GameData.name_of("types", t))), str(GameData.localization.get("dex", {}).get(id, ""))], 14))
		elif state.dex_seen.has(id):
			_content.add_child(UITheme.make_label("No.%02d %s" % [num, GameData.name_of("species", id)], 14, Color(0.8, 0.8, 0.8)))
		else:
			_content.add_child(UITheme.make_label("No.%02d ？？？" % num, 14, Color(0.5, 0.5, 0.5)))
	_btn("もどる", show_main)

func show_settings() -> void:
	_mode = "settings"
	_clear()
	_content.add_child(UITheme.make_label("せってい", 20))
	var spd := int(state.settings.get("text_speed", 1))
	_btn("メッセージ速度: %s" % ["おそい", "ふつう", "はやい"][clampi(spd, 0, 2)], func(): state.settings["text_speed"] = (spd + 1) % 3; show_settings())
	_btn("もどる", show_main)

# ---------------- shop ----------------
func show_shop(items: Array) -> void:
	_mode = "shop"
	_clear()
	_content.add_child(UITheme.make_label("ショップ   所持金 %d円" % state.money, 20))
	for id in items:
		var price := int(GameData.get_item(id).get("price", 0))
		var iid: String = id
		_btn("%s  %d円  (もっている: %d)" % [GameData.name_of("items", id), price, int(state.bag.get(id, 0))], func(): _buy(iid, price, items))
	_btn("うる", func(): _sell_menu(items))
	_btn("やめる", func(): closed.emit())

func _buy(id: String, price: int, items: Array) -> void:
	if state.money < price:
		message.emit("おかねが たりない！")
		return
	state.money -= price
	state.add_item(id, 1)
	message.emit("%sを かった。" % GameData.name_of("items", id))
	show_shop(items)

func _sell_menu(items: Array) -> void:
	_clear()
	_content.add_child(UITheme.make_label("うる  所持金 %d円" % state.money, 20))
	var ids: Array = state.bag.keys()
	ids.sort()
	for id in ids:
		var idef := GameData.get_item(id)
		if str(idef.get("pocket", "held")) == "key":
			continue
		var price := int(int(idef.get("price", 0)) / 2)
		var iid: String = id
		_btn("%s ×%d  %d円" % [GameData.name_of("items", id), state.bag[id], price], func(): state.money += price; state.add_item(iid, -1); message.emit("%sを うった。" % GameData.name_of("items", iid)); _sell_menu(items))
	_btn("もどる", func(): show_shop(items))
