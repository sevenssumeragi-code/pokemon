class_name GameData
extends RefCounted
## Loads all JSON game data from res://data and exposes lookup helpers.
## Every directory is scanned; each *.json file must be a Dictionary of id -> definition.

static var loaded: bool = false
static var species: Dictionary = {}
static var moves: Dictionary = {}
static var abilities: Dictionary = {}
static var items: Dictionary = {}
static var natures: Dictionary = {}
static var weather: Dictionary = {}
static var terrain: Dictionary = {}
static var type_list: Array = []
static var type_chart: Dictionary = {}
static var localization: Dictionary = {}
static var data_root: String = "res://data/"

static func ensure_loaded() -> void:
	if not loaded:
		load_all()

static func load_all(root: String = "res://data/") -> void:
	data_root = root
	species = _load_dir(root + "species")
	moves = _load_dir(root + "moves")
	abilities = _load_dir(root + "abilities")
	items = _load_dir(root + "items")
	weather = _load_dir(root + "weather")
	terrain = _load_dir(root + "terrain")
	var tc = _load_json(root + "types/typechart.json")
	type_list = tc.get("types", [])
	type_chart = tc.get("chart", {})
	natures = _load_json(root + "types/natures.json")
	localization = _load_json(root + "localization/ja.json")
	# fill defaults
	for id in moves:
		_normalize_move(moves[id], id)
	for id in species:
		species[id]["id"] = id
	for id in abilities:
		abilities[id]["id"] = id
	for id in items:
		items[id]["id"] = id
	loaded = true

static func _normalize_move(m: Dictionary, id: String) -> void:
	m["id"] = id
	if not m.has("priority"): m["priority"] = 0
	if not m.has("flags"): m["flags"] = []
	if not m.has("target"): m["target"] = "normal"
	if not m.has("category"): m["category"] = "status"
	if not m.has("power"): m["power"] = 0
	if not m.has("accuracy"): m["accuracy"] = true
	if not m.has("pp"): m["pp"] = 10
	if not m.has("crit_ratio"): m["crit_ratio"] = 1

static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("GameData: missing " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(txt)
	if err != OK:
		push_error("GameData: JSON error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("GameData: %s is not a dictionary" % path)
		return {}
	return json.data

static func _load_dir(dir_path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("GameData: missing dir " + dir_path)
		return out
	var files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for name in files:
		var d := _load_json(dir_path + "/" + name)
		for k in d:
			if out.has(k):
				push_warning("GameData: duplicate id %s in %s" % [k, name])
			out[k] = d[k]
	return out

## Type effectiveness of attacking type vs one defending type (0, 0.5, 1, 2).
static func type_mod(atk_type: String, def_type: String) -> float:
	var row = type_chart.get(atk_type)
	if row == null:
		return 1.0
	return float(row.get(def_type, 1.0))

## Combined effectiveness vs a list of types.
static func effectiveness(atk_type: String, def_types: Array) -> float:
	var m := 1.0
	for t in def_types:
		m *= type_mod(atk_type, t)
	return m

static func get_move(id: String) -> Dictionary:
	return moves.get(id, {})

static func get_species(id: String) -> Dictionary:
	return species.get(id, {})

static func get_ability(id: String) -> Dictionary:
	return abilities.get(id, {})

static func get_item(id: String) -> Dictionary:
	return items.get(id, {})

## Display name lookup (category: species/moves/abilities/items/types/natures/status/messages)
static func name_of(category: String, id: String) -> String:
	var cat = localization.get(category, {})
	return str(cat.get(id, id))

static func msg(key: String, args: Dictionary = {}) -> String:
	var s: String = str(localization.get("messages", {}).get(key, key))
	for k in args:
		s = s.replace("{%s}" % k, str(args[k]))
	return s
