class_name GameState
extends RefCounted
## Whole-game persistent state: party, box, bag, money, flags, position, dex, settings. JSON save/load.

static var current: GameState = null

var player_name: String = "プレイヤー"
var party: Array = []  # Array[PokemonSet]
var box: Array = []
var bag: Dictionary = {}  # item id -> count
var money: int = 3000
var flags: Dictionary = {}  # string -> bool/int/string
var map_id: String = "town"
var pos: Vector2i = Vector2i(5, 5)
var dir: String = "down"
var dex_seen: Dictionary = {}
var dex_caught: Dictionary = {}
var play_seconds: float = 0.0
var settings: Dictionary = {"text_speed": 1, "battle_animation": true, "volume": 8}
var rng_seed: int = 0
var badges: int = 0

func to_dict() -> Dictionary:
	var pd: Array = []
	for p in party:
		pd.append(p.to_dict())
	var bd: Array = []
	for p in box:
		bd.append(p.to_dict())
	return {
		"version": 1, "player_name": player_name, "party": pd, "box": bd, "bag": bag.duplicate(), "money": money,
		"flags": flags.duplicate(), "map_id": map_id, "pos": [pos.x, pos.y], "dir": dir,
		"dex_seen": dex_seen.duplicate(), "dex_caught": dex_caught.duplicate(), "play_seconds": play_seconds,
		"settings": settings.duplicate(), "rng_seed": rng_seed, "badges": badges,
	}

static func from_dict(d: Dictionary) -> GameState:
	var g := GameState.new()
	g.player_name = str(d.get("player_name", "プレイヤー"))
	for pd in d.get("party", []):
		g.party.append(PokemonSet.from_dict(pd))
	for pd in d.get("box", []):
		g.box.append(PokemonSet.from_dict(pd))
	for k in d.get("bag", {}):
		g.bag[k] = int(d["bag"][k])
	g.money = int(d.get("money", 0))
	g.flags = d.get("flags", {}).duplicate()
	g.map_id = str(d.get("map_id", "town"))
	var p = d.get("pos", [5, 5])
	g.pos = Vector2i(int(p[0]), int(p[1]))
	g.dir = str(d.get("dir", "down"))
	g.dex_seen = d.get("dex_seen", {}).duplicate()
	g.dex_caught = d.get("dex_caught", {}).duplicate()
	g.play_seconds = float(d.get("play_seconds", 0.0))
	g.settings = d.get("settings", {}).duplicate()
	g.rng_seed = int(d.get("rng_seed", 0))
	g.badges = int(d.get("badges", 0))
	return g

static var slot_prefix: String = "save"  # tests override to avoid touching real saves

static func save_path(slot: int) -> String:
	return "user://%s%d.json" % [slot_prefix, slot]

func save(slot: int = 1) -> bool:
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "  "))
	f.close()
	return true

static func load_slot(slot: int = 1) -> GameState:
	var path := save_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return null
	return from_dict(json.data)

static func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(save_path(slot))

# ---------- helpers ----------
func add_item(id: String, n: int = 1) -> void:
	bag[id] = int(bag.get(id, 0)) + n
	if bag[id] <= 0:
		bag.erase(id)

func has_item(id: String, n: int = 1) -> bool:
	return int(bag.get(id, 0)) >= n

func flag(key: String, default = false):
	return flags.get(key, default)

func set_flag(key: String, value = true) -> void:
	flags[key] = value

func alive_party() -> Array:
	var out: Array = []
	for p in party:
		if p.current_hp != 0:
			out.append(p)
	return out

func first_alive_index() -> int:
	for i in range(party.size()):
		if party[i].current_hp != 0:
			return i
	return -1

func heal_party() -> void:
	for p in party:
		p.current_hp = -1
		p.status = ""

func mark_seen(species: String) -> void:
	dex_seen[species] = true

func mark_caught(species: String) -> void:
	dex_seen[species] = true
	dex_caught[species] = true

## Add a monster to the party or the box.
func add_monster(pset: PokemonSet) -> String:
	mark_caught(pset.species)
	if party.size() < 6:
		party.append(pset)
		return "party"
	box.append(pset)
	return "box"

## Structural equality for save/load tests.
func equals(other: GameState) -> bool:
	return JSON.stringify(to_dict()) == JSON.stringify(other.to_dict())
