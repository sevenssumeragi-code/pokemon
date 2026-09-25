class_name BT
extends RefCounted
## Test helpers for building and driving battles deterministically.

static func s(species: String, moves: Array, item: String = "", nature: String = "hardy", evs: Dictionary = {}, ability: String = "", level: int = 50) -> PokemonSet:
	return BattleRunner.make_set(species, moves, item, nature, evs, ability, level)

## Create and start a battle. Default: fixed max roll, no crits, seed 1.
static func make(team1: Array, team2: Array, cfg: Dictionary = {}) -> Battle:
	var c := {"seed": 1, "teams": [team1, team2], "log": true, "fixed_roll": 100, "no_crit": true}
	for k in cfg:
		c[k] = cfg[k]
	var b := Battle.new(c)
	b.start()
	return b

static func parse(choice: String) -> Dictionary:
	var parts := choice.split(":")
	if parts[0] == "switch":
		return {"type": "switch", "index": int(parts[1])}
	var d := {"type": "move", "move": parts[1]}
	if parts.size() > 2:
		d["target"] = int(parts[2])
	return d

## Submit one choice per side (singles). Returns error string ("" ok).
static func turn(b: Battle, c1: String, c2: String) -> String:
	var e1 := b.choose(0, [parse(c1)])
	if e1 != "":
		return "p1: " + e1
	var e2 := b.choose(1, [parse(c2)])
	if e2 != "":
		return "p2: " + e2
	return ""

## Submit a choice for one side only (when the other side has no request).
static func one(b: Battle, side: int, c: String) -> String:
	return b.choose(side, [parse(c)])

static func p1(b: Battle) -> BattlePokemon:
	return b.sides[0].active[0]

static func p2(b: Battle) -> BattlePokemon:
	return b.sides[1].active[0]

static func has_log(b: Battle, kind: String, contains: String = "") -> bool:
	for e in b.log:
		if e[0] == kind:
			if contains == "":
				return true
			for x in e:
				if str(x).contains(contains):
					return true
	return false

static func count_log(b: Battle, kind: String, contains: String = "") -> int:
	var n := 0
	for e in b.log:
		if e[0] == kind:
			if contains == "":
				n += 1
			else:
				for x in e:
					if str(x).contains(contains):
						n += 1
						break
	return n

## Damage dealt to `p` during the log since index `from`.
static func damage_taken(b: Battle, p: BattlePokemon, from: int = 0) -> int:
	var total := 0
	var last_hp := -1
	for i in range(from, b.log.size()):
		var e = b.log[i]
		if (e[0] == "-hp" or e[0] == "-damage") and str(e[1]).begins_with(p.slot_id() + ":"):
			pass
	return total
