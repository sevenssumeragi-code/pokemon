class_name PokemonSet
extends RefCounted
## A team-builder definition of one monster (species + build). Serializable.

var species: String = ""
var nickname: String = ""
var level: int = 50
var nature: String = "hardy"
var ability: String = ""
var item: String = ""
var moves: Array = []
var ivs: Dictionary = {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31}
var evs: Dictionary = {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}
var gender: String = "N"
var shiny: bool = false
var exp: int = 0
var current_hp: int = -1  # -1 = full (RPG layer persistence)
var status: String = ""
var friendship: int = 70

static func from_dict(d: Dictionary) -> PokemonSet:
	var s := PokemonSet.new()
	s.species = str(d.get("species", ""))
	s.nickname = str(d.get("nickname", ""))
	s.level = int(d.get("level", 50))
	s.nature = str(d.get("nature", "hardy"))
	s.ability = str(d.get("ability", ""))
	s.item = str(d.get("item", ""))
	s.moves = Array(d.get("moves", []))
	var ivs = d.get("ivs", {})
	for k in s.ivs:
		if ivs.has(k):
			s.ivs[k] = int(ivs[k])
	var evs = d.get("evs", {})
	for k in s.evs:
		if evs.has(k):
			s.evs[k] = int(evs[k])
	s.gender = str(d.get("gender", "N"))
	s.shiny = bool(d.get("shiny", false))
	s.exp = int(d.get("exp", 0))
	s.current_hp = int(d.get("current_hp", -1))
	s.status = str(d.get("status", ""))
	s.friendship = int(d.get("friendship", 70))
	if s.ability == "":
		var sp = GameData.get_species(s.species)
		if not sp.is_empty():
			s.ability = str(sp.get("abilities", {}).get("0", ""))
	return s

func to_dict() -> Dictionary:
	return {
		"species": species, "nickname": nickname, "level": level, "nature": nature,
		"ability": ability, "item": item, "moves": moves.duplicate(),
		"ivs": ivs.duplicate(), "evs": evs.duplicate(), "gender": gender, "shiny": shiny,
		"exp": exp, "current_hp": current_hp, "status": status, "friendship": friendship,
	}

func duplicate_set() -> PokemonSet:
	return PokemonSet.from_dict(to_dict())

func total_evs() -> int:
	var t := 0
	for k in evs:
		t += int(evs[k])
	return t

## Validate against game data; returns list of problems (empty = ok).
func validate() -> Array[String]:
	var errs: Array[String] = []
	var sp = GameData.get_species(species)
	if sp.is_empty():
		errs.append("unknown species " + species)
		return errs
	if total_evs() > 510:
		errs.append("EV total > 510")
	for k in evs:
		if evs[k] > 252 or evs[k] < 0:
			errs.append("EV out of range: " + k)
	for k in ivs:
		if ivs[k] > 31 or ivs[k] < 0:
			errs.append("IV out of range: " + k)
	if moves.is_empty() or moves.size() > 4:
		errs.append("move count must be 1..4")
	var learnable := PokemonSet.learnable_moves(species)
	for m in moves:
		if GameData.get_move(m).is_empty():
			errs.append("unknown move " + str(m))
		elif not learnable.has(m):
			errs.append("%s cannot learn %s" % [species, m])
	var abil_ok := false
	for slot in sp.get("abilities", {}):
		if sp["abilities"][slot] == ability:
			abil_ok = true
	if not abil_ok:
		errs.append("%s cannot have ability %s" % [species, ability])
	if item != "" and GameData.get_item(item).is_empty():
		errs.append("unknown item " + item)
	if not GameData.natures.has(nature):
		errs.append("unknown nature " + nature)
	return errs

static func learnable_moves(species_id: String) -> Array:
	var sp = GameData.get_species(species_id)
	var out := []
	var ls = sp.get("learnset", {})
	for e in ls.get("level", []):
		if not out.has(e["move"]):
			out.append(e["move"])
	for m in ls.get("tm", []):
		if not out.has(m):
			out.append(m)
	for m in ls.get("egg", []):
		if not out.has(m):
			out.append(m)
	# pre-evolution moves are inherited
	var pre = sp.get("evolves_from")
	if pre != null and str(pre) != "":
		for m in learnable_moves(str(pre)):
			if not out.has(m):
				out.append(m)
	return out
