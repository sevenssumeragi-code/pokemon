class_name BattleSide
extends RefCounted
## One player's side: team, active slots, side conditions.

var battle
var index: int = 0
var name: String = ""
var team: Array = []  # Array[BattlePokemon]
var active: Array = []  # slots; null when empty
var foe  # BattleSide
var side_conditions: Dictionary = {}  # id -> state
var slot_conditions: Dictionary = {}  # slot -> {id -> state}
var slots: int = 1
var faint_switch_pending: Array = []  # slot indices needing replacement
var last_selected_move: String = ""
var choice: Dictionary = {}  # pending decision(s) for this turn
var request: Dictionary = {}
var total_fainted: int = 0

func _init(p_battle, p_index: int, p_name: String, sets: Array, p_slots: int) -> void:
	battle = p_battle
	index = p_index
	name = p_name
	slots = p_slots
	for i in range(sets.size()):
		var p := BattlePokemon.new(sets[i], self, battle, i)
		team.append(p)
	for i in range(slots):
		active.append(null)

func alive_count() -> int:
	var n := 0
	for p in team:
		if not p.fainted:
			n += 1
	return n

func has_alive_bench() -> bool:
	for p in team:
		if not p.fainted and not p.active:
			return true
	return false

func bench() -> Array:
	var out := []
	for p in team:
		if not p.active and not p.fainted:
			out.append(p)
	return out

func active_pokemon() -> Array:
	var out := []
	for p in active:
		if p != null and not p.fainted:
			out.append(p)
	return out

func add_side_condition(id: String, source, effect = null) -> bool:
	return battle.add_side_condition(self, id, source, effect)

func remove_side_condition(id: String) -> bool:
	return battle.remove_side_condition(self, id)

func has_side_condition(id: String) -> bool:
	return side_conditions.has(id)

func get_side_condition(id: String) -> Dictionary:
	return side_conditions.get(id, {})

func snapshot() -> Dictionary:
	var t := []
	for p in team:
		t.append(p.snapshot())
	return {"name": name, "team": t, "side_conditions": side_conditions.duplicate(true)}
