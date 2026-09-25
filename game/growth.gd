class_name Growth
extends RefCounted
## Experience curves, exp gain (Gen 5+ scaled formula), level-ups, evolution checks.

static func exp_for_level(rate: String, level: int) -> int:
	var n := float(level)
	match rate:
		"fast": return int(floor(4.0 * n * n * n / 5.0))
		"medium_fast": return int(n * n * n)
		"medium_slow": return int(floor(6.0 / 5.0 * n * n * n - 15.0 * n * n + 100.0 * n - 140.0))
		"slow": return int(floor(5.0 * n * n * n / 4.0))
	return int(n * n * n)

static func level_for_exp(rate: String, exp: int) -> int:
	var lv := 1
	while lv < 100 and exp_for_level(rate, lv + 1) <= exp:
		lv += 1
	return lv

## Gen 5+ scaled experience: a = base exp of fainted, b = fainted level, L = receiver level.
static func exp_gain(base_exp: int, fainted_level: int, receiver_level: int, trainer: bool, participants: int = 1) -> int:
	var a := float(base_exp) * float(fainted_level) / 5.0 / float(maxi(1, participants))
	var scale := pow((2.0 * fainted_level + 10.0) / (fainted_level + receiver_level + 10.0), 2.5)
	var e: float = floor(a * scale) + 1.0
	if trainer:
		e = floor(e * 1.5)
	return int(e)

## Apply exp to a set; returns list of levels gained (each level as int).
static func add_exp(pset: PokemonSet, amount: int) -> Array:
	var sp := GameData.get_species(pset.species)
	var rate := str(sp.get("growth_rate", "medium_fast"))
	if pset.exp < exp_for_level(rate, pset.level):
		pset.exp = exp_for_level(rate, pset.level)
	var gained: Array = []
	pset.exp += amount
	while pset.level < 100 and pset.exp >= exp_for_level(rate, pset.level + 1):
		pset.level += 1
		gained.append(pset.level)
	return gained

## Moves learned at exactly `level`.
static func moves_at_level(species: String, level: int) -> Array:
	var out: Array = []
	for e in GameData.get_species(species).get("learnset", {}).get("level", []):
		if int(e["level"]) == level:
			out.append(e["move"])
	return out

## Evolution target for a level-up (or "" if none).
static func evolution_by_level(species: String, level: int) -> String:
	for ev in _evolutions(species):
		if ev.get("method") == "level" and level >= int(ev.get("level", 999)):
			return str(ev["into"])
	return ""

static func evolution_by_item(species: String, item: String) -> String:
	for ev in _evolutions(species):
		if ev.get("method") == "item" and str(ev.get("item", "")) == item:
			return str(ev["into"])
	return ""

static func _evolutions(species: String) -> Array:
	var ev = GameData.get_species(species).get("evolution")
	if ev == null:
		return []
	if ev is Array:
		return ev
	return [ev]

## Evolve a set in place (keeps moves, item, nature, ivs/evs; ability slot preserved).
static func evolve(pset: PokemonSet, into: String) -> void:
	var old := GameData.get_species(pset.species)
	var slot := "0"
	for k in old.get("abilities", {}):
		if old["abilities"][k] == pset.ability:
			slot = k
	pset.species = into
	var nsp := GameData.get_species(into)
	pset.ability = str(nsp["abilities"].get(slot, nsp["abilities"]["0"]))
	# keep HP fraction
	pset.current_hp = -1
