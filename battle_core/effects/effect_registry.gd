class_name EffectRegistry
extends RefCounted
## Central lookup: (kind, id) -> Dictionary of event handlers (Callables).
## kinds: ability, item, status, volatile, side, slot, weather, terrain, field, move_effect

static var _instance: EffectRegistry = null

var tables: Dictionary = {}
var status_meta: Dictionary = {}
var volatile_meta: Dictionary = {}
var side_meta: Dictionary = {}
var _conditions: Conditions
var _abilities: Abilities
var _items: Items
var _move_effects: MoveEffects
var _item_cache: Dictionary = {}

static func get_instance() -> EffectRegistry:
	if _instance == null:
		_instance = EffectRegistry.new()
	return _instance

static func reset() -> void:
	_instance = null

func _init() -> void:
	_conditions = Conditions.new()
	_abilities = Abilities.new()
	_items = Items.new()
	_move_effects = MoveEffects.new()
	var c := _conditions.build()
	tables["status"] = c["status"]
	tables["volatile"] = c["volatile"]
	tables["side"] = c["side"]
	tables["slot"] = c["slot"]
	tables["weather"] = c["weather"]
	tables["terrain"] = c["terrain"]
	tables["field"] = c["field"]
	status_meta = c["status_meta"]
	volatile_meta = c["volatile_meta"]
	side_meta = c["side_meta"]
	tables["ability"] = _abilities.build()
	tables["item"] = _items.build()
	tables["move_effect"] = _move_effects.build()

func get_handlers(kind: String, id: String) -> Dictionary:
	if id == "":
		return {}
	var t: Dictionary = tables.get(kind, {})
	if kind == "item":
		if _item_cache.has(id):
			return _item_cache[id]
		var h: Dictionary = t.get(id, {})
		if h.is_empty():
			# generic handler declared in item data
			var idef := GameData.get_item(id)
			var gh: String = str(idef.get("handler", ""))
			if gh != "":
				h = t.get("generic:" + gh, {})
		_item_cache[id] = h
		return h
	if kind == "weather":
		return t.get(id, t.get("generic", {}))
	if kind == "terrain":
		return t.get(id, t.get("generic", {}))
	return t.get(id, {})

## For validation: does an implementation exist for this effect id?
func has_effect(kind: String, id: String) -> bool:
	if kind == "ability":
		return tables["ability"].has(id)
	if kind == "item":
		if tables["item"].has(id):
			return true
		var idef := GameData.get_item(id)
		var gh: String = str(idef.get("handler", ""))
		return gh == "" or tables["item"].has("generic:" + gh)
	if kind == "move_effect":
		return tables["move_effect"].has(id)
	return tables.get(kind, {}).has(id)
