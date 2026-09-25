class_name MapData
extends RefCounted
## Loads data/maps/*.json + data/maps/tileset.json and answers tile / warp / npc / event queries.
## Adding a map is data-only: drop a JSON in data/maps/.

static var _cache: Dictionary = {}
static var tileset: Dictionary = {}

var id: String = ""
var width: int = 0
var height: int = 0
var tiles: Array = []  # rows of tile ids
var warps: Array = []
var npcs: Array = []
var events: Array = []
var encounters: Dictionary = {}
var name_key: String = ""
var raw: Dictionary = {}

static func load_map(map_id: String) -> MapData:
	if _cache.has(map_id):
		return _cache[map_id]
	if tileset.is_empty():
		tileset = GameData._load_json("res://data/maps/tileset.json")
	var d := GameData._load_json("res://data/maps/%s.json" % map_id)
	if d.is_empty():
		push_error("MapData: missing map " + map_id)
		return null
	var m := MapData.new()
	m.raw = d
	m.id = map_id
	m.width = int(d["width"])
	m.height = int(d["height"])
	m.tiles = d["tiles"]
	m.warps = d.get("warps", [])
	m.npcs = d.get("npcs", [])
	m.events = d.get("events", [])
	m.encounters = d.get("encounters", {})
	m.name_key = str(d.get("name_key", map_id))
	_cache[map_id] = m
	return m

static func clear_cache() -> void:
	_cache.clear()
	tileset.clear()

static func all_map_ids() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://data/maps")
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".json") and f != "tileset.json":
			out.append(f.get_basename())
		f = dir.get_next()
	out.sort()
	return out

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func tile_id(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return -1
	return int(tiles[y][x])

func tile_def(x: int, y: int) -> Dictionary:
	return tileset.get(str(tile_id(x, y)), {})

func is_walkable(x: int, y: int, state: GameState = null) -> bool:
	if not in_bounds(x, y):
		return false
	if not bool(tile_def(x, y).get("walkable", false)):
		return false
	if npc_at(x, y, state) != null:
		return false
	return true

func is_encounter_tile(x: int, y: int) -> bool:
	return bool(tile_def(x, y).get("encounter", false))

func warp_at(x: int, y: int):
	for w in warps:
		if int(w["x"]) == x and int(w["y"]) == y:
			return w
	return null

## NPCs can be hidden by a flag ("hidden_flag") or shown only when a flag is set ("visible_flag").
func npc_at(x: int, y: int, state: GameState = null):
	for n in visible_npcs(state):
		if int(n["x"]) == x and int(n["y"]) == y:
			return n
	return null

func visible_npcs(state: GameState = null) -> Array:
	var out: Array = []
	for n in npcs:
		if state != null:
			if n.has("hidden_flag") and bool(state.flag(str(n["hidden_flag"]), false)):
				continue
			if n.has("visible_flag") and not bool(state.flag(str(n["visible_flag"]), false)):
				continue
		out.append(n)
	return out

func event_at(x: int, y: int, trigger: String):
	for e in events:
		if str(e.get("trigger", "interact")) == trigger and int(e.get("x", -1)) == x and int(e.get("y", -1)) == y:
			return e
	return null

func auto_events() -> Array:
	var out: Array = []
	for e in events:
		if str(e.get("trigger", "")) == "auto":
			out.append(e)
	return out

## Roll a wild encounter for a step on an encounter tile. Returns {"species","level"} or {}.
func roll_encounter(rng: RandomNumberGenerator) -> Dictionary:
	if encounters.is_empty():
		return {}
	var rate := int(encounters.get("rate", 10))
	if rng.randi_range(1, 100) > rate:
		return {}
	var table: Array = encounters.get("table", [])
	var total := 0
	for e in table:
		total += int(e.get("weight", 1))
	var r := rng.randi_range(1, maxi(1, total))
	for e in table:
		r -= int(e.get("weight", 1))
		if r <= 0:
			return {"species": e["species"], "level": rng.randi_range(int(e["min"]), int(e["max"]))}
	return {}
