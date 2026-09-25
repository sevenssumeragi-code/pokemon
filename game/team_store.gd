class_name TeamStore
extends RefCounted
## Saves/loads player teams (user://teams.json) and builds CPU teams from recommended sets.

const PATH := "user://teams.json"

static func load_teams() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	return json.data if typeof(json.data) == TYPE_DICTIONARY else {}

static func save_team(name: String, team: Array) -> void:
	var teams := load_teams()
	var arr: Array = []
	for s in team:
		arr.append(s.to_dict() if s is PokemonSet else s)
	teams[name] = arr
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(teams, "  "))
	f.close()

static func get_team(name: String) -> Array:
	var teams := load_teams()
	var out: Array = []
	for d in teams.get(name, []):
		out.append(PokemonSet.from_dict(d))
	return out

static func recommended_sets() -> Dictionary:
	return GameData._load_json("res://data/sets/sets.json")

static func set_from_recommended(species: String, sdef: Dictionary, level: int = 50) -> PokemonSet:
	return PokemonSet.from_dict({"species": species, "moves": sdef["moves"], "item": sdef["item"], "nature": sdef["nature"], "evs": sdef["evs"], "ability": sdef["ability"], "level": level})

## Random CPU team of `n` distinct species using recommended sets.
static func random_team(n: int, rng: RandomNumberGenerator, exclude: Array = []) -> Array:
	var sets := recommended_sets()
	var ids: Array = sets.keys()
	ids.sort()
	var pool: Array = []
	for i in ids:
		if not exclude.has(i):
			pool.append(i)
	var out: Array = []
	for k in range(n):
		if pool.is_empty():
			break
		var idx := rng.randi_range(0, pool.size() - 1)
		var sp: String = pool[idx]
		pool.remove_at(idx)
		var sdef: Dictionary = sets[sp][rng.randi_range(0, sets[sp].size() - 1)]
		out.append(set_from_recommended(sp, sdef))
	return out

## Default player team (first recommended set of six varied species).
static func default_team() -> Array:
	var sets := recommended_sets()
	var out: Array = []
	for sp in ["renny", "jinpachi", "hyu", "muni", "gel", "trans"]:
		out.append(set_from_recommended(sp, sets[sp][0]))
	return out
