class_name BattlePokemon
extends RefCounted
## Runtime state of one monster inside a battle.

const STAT_EVENT := {"atk": "ModifyAtk", "def": "ModifyDef", "spa": "ModifySpA", "spd": "ModifySpD", "spe": "ModifySpe"}

var battle  # Battle (untyped to avoid cyclic typing)
var side  # BattleSide
var set: PokemonSet
var species: Dictionary
var species_id: String = ""
var display_name: String = ""
var level: int = 50
var gender: String = "N"
var weight_kg: float = 10.0

var base_types: Array = []
var types: Array = []
var added_type: String = ""

var stored_stats: Dictionary = {}  # computed from set: hp/atk/def/spa/spd/spe
var max_hp: int = 1
var hp: int = 1
var boosts: Dictionary = {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0, "accuracy": 0, "evasion": 0}

var status: String = ""
var status_state: Dictionary = {}
var volatiles: Dictionary = {}  # id -> state Dictionary

var base_ability: String = ""
var ability: String = ""
var ability_state: Dictionary = {}
var item: String = ""
var item_state: Dictionary = {}
var last_item: String = ""
var used_item_this_turn: bool = false
var ate_berry: bool = false

var moves: Array = []  # [{id, pp, max_pp}]
var position: int = 0
var team_index: int = 0
var active: bool = false
var fainted: bool = false
var is_started: bool = false

var last_move: String = ""
var last_move_used_turn: int = -1
var move_this_turn: String = ""  # "" = not yet moved; else move id or "skipped"
var last_damage: int = 0
var hurt_this_turn: int = 0
var newly_switched: bool = false
var active_turns: int = 0
var active_move_actions: int = 0
var stats_lowered_this_turn: bool = false
var stats_raised_this_turn: bool = false
var switch_flag = false  # false, true, or "copyvolatile"
var force_switch_flag: bool = false
var trapped: bool = false
var attacked_by: Array = []  # [{source, damage, move, category}]
var last_attacked_by: Dictionary = {}
var times_attacked: int = 0
var being_called_back: bool = false
var illusion = null
var faint_queued: bool = false
var can_mega = false
var revealed_moves: Dictionary = {}  # move ids this pokemon has used (for fair AI)
var participants: Dictionary = {}  # foe side only: player team indices that fought this pokemon (exp share)
var speed: int = 0


func _init(pset: PokemonSet, p_side, p_battle, p_team_index: int) -> void:
	set = pset
	side = p_side
	battle = p_battle
	team_index = p_team_index
	species_id = pset.species
	species = GameData.get_species(species_id)
	display_name = pset.nickname if pset.nickname != "" else species_id
	level = pset.level
	gender = pset.gender
	weight_kg = float(species.get("weight_kg", 10.0))
	base_types = Array(species.get("types", ["normal"])).duplicate()
	types = base_types.duplicate()
	stored_stats = StatCalc.compute_stats(species.get("base_stats", {}), pset.ivs, pset.evs, level, pset.nature)
	max_hp = stored_stats["hp"]
	hp = max_hp if pset.current_hp < 0 else clampi(pset.current_hp, 0, max_hp)
	if pset.status != "":
		status = pset.status
	base_ability = pset.ability
	ability = base_ability
	item = pset.item
	for m in pset.moves:
		var md := GameData.get_move(m)
		var pp := int(md.get("pp", 5))
		var maxpp := int(floor(pp * 8.0 / 5.0)) if not md.get("no_pp_boosts", false) else pp
		moves.append({"id": m, "pp": maxpp, "max_pp": maxpp})
	if hp <= 0:
		fainted = true

func describe() -> String:
	return "%s(%s)" % [display_name, "p%d%s" % [side.index + 1, String.chr(97 + position)] if active else "bench"]

func slot_id() -> String:
	return "p%d%s" % [side.index + 1, String.chr(97 + position)]

# ---------- types ----------
func has_type(t: String) -> bool:
	return types.has(t)

func get_types() -> Array:
	var out := types.duplicate()
	if added_type != "" and not out.has(added_type):
		out.append(added_type)
	return out

func set_types(new_types: Array) -> void:
	types = new_types.duplicate()
	added_type = ""

func is_grounded() -> bool:
	if battle.has_pseudo_weather("gravity"):
		return true
	if volatiles.has("ingrain") or volatiles.has("smack_down") or volatiles.has("roost"):
		return true
	if has_type("flying") and not volatiles.has("roost"):
		return false
	if ability == "levitate" and not battle.ability_suppressed(self):
		return false
	if battle.item_flag(self, "airborne"):
		return false
	if volatiles.has("magnet_rise") or volatiles.has("telekinesis"):
		return false
	return true

# ---------- stats ----------
## Return current effective stat value (boosted + modified by events).
func get_stat(stat: String, unboosted: bool = false, unmodified: bool = false) -> int:
	if stat == "hp":
		return max_hp
	var v: int = stored_stats[stat]
	if not unboosted:
		var b: int = boosts[stat]
		v = StatCalc.apply_boost(v, b)
	if not unmodified:
		v = battle.run_event(STAT_EVENT[stat], self, null, null, v)
		v = maxi(1, int(v))
	return v

## Speed used for turn ordering (includes paralysis, items, trick room handled by battle).
func get_action_speed() -> int:
	return get_stat("spe")

func get_boosted_stat_ignoring(stat: String, ignore_positive: bool, ignore_negative: bool) -> int:
	var v: int = stored_stats[stat]
	var b: int = boosts[stat]
	if ignore_positive and b > 0:
		b = 0
	if ignore_negative and b < 0:
		b = 0
	return StatCalc.apply_boost(v, b)

func positive_boosts() -> int:
	var n := 0
	for k in boosts:
		if boosts[k] > 0:
			n += boosts[k]
	return n

# ---------- hp ----------
func hp_fraction() -> float:
	return float(hp) / float(max_hp)

func is_full_hp() -> bool:
	return hp >= max_hp

# ---------- moves ----------
func get_move_slot(move_id: String) -> Dictionary:
	for m in moves:
		if m["id"] == move_id:
			return m
	return {}

func has_move(move_id: String) -> bool:
	return not get_move_slot(move_id).is_empty()

func deduct_pp(move_id: String, amount: int = 1) -> int:
	var slot := get_move_slot(move_id)
	if slot.is_empty():
		return 0
	var before: int = slot["pp"]
	slot["pp"] = maxi(0, before - amount)
	return before - slot["pp"]

# ---------- volatiles ----------
func has_volatile(id: String) -> bool:
	return volatiles.has(id)

func get_volatile(id: String) -> Dictionary:
	return volatiles.get(id, {})

func clear_volatiles() -> void:
	volatiles.clear()

func clear_boosts() -> void:
	for k in boosts:
		boosts[k] = 0

# ---------- misc ----------
func is_ally(other) -> bool:
	return other != null and other.side == side

func is_foe(other) -> bool:
	return other != null and other.side != side

func allies() -> Array:
	var out := []
	for p in side.active:
		if p != null and p != self and not p.fainted:
			out.append(p)
	return out

func foes() -> Array:
	var out := []
	for p in side.foe.active:
		if p != null and not p.fainted:
			out.append(p)
	return out

func adjacent_foes() -> Array:
	# In singles/doubles all foes are adjacent.
	return foes()

## Snapshot for serialization / tests.
func snapshot() -> Dictionary:
	return {
		"species": species_id, "hp": hp, "max_hp": max_hp, "status": status,
		"boosts": boosts.duplicate(), "item": item, "ability": ability,
		"volatiles": volatiles.keys(), "types": types.duplicate(),
		"moves": moves.duplicate(true), "active": active, "fainted": fainted,
	}
