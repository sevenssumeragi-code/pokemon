class_name Battle
extends RefCounted
## Pure-logic battle engine (Gen 9 mechanics). No rendering dependencies.
## Effects (abilities/items/conditions/move effects) are dictionaries of Callables
## registered in EffectRegistry and dispatched through run_event / single_event.

const SWITCH_ORDER := 103
const MOVE_ORDER := 200
const RESIDUAL_ORDER := 300
const CRIT_TABLE := [0, 24, 8, 2, 1]

var rng: BattleRNG
var format: String = "singles"
var slots_per_side: int = 1
var sides: Array = []
var turn: int = 0
var ended: bool = false
var started: bool = false
var winner: int = -1  # side index; -1 = none/tie
var log: Array = []
var log_enabled: bool = true
var debug: bool = false

var weather: String = ""
var weather_state: Dictionary = {}
var terrain: String = ""
var terrain_state: Dictionary = {}
var pseudo_weather: Dictionary = {}

var registry: EffectRegistry
var queue: Array = []
var current_action: Dictionary = {}
var request_state: String = ""  # "", "move", "switch"
var faint_queue: Array = []
var mid_turn: bool = false
var last_move: Dictionary = {}  # last move used in battle
var last_successful_move_this_turn: String = ""
var active_move: Dictionary = {}
var active_pokemon = null
var active_target = null
var event_stack: Array = []  # each: {id, modifier}
var event_depth: int = 0
var effect_state_stack: Array = []
var stats: Dictionary = {"ability_activations": {}, "item_activations": {}, "moves_used": {}, "crits": 0, "misses": 0, "damage_by_species": {}, "kos_by_species": {}, "first_move": {}, "turns_present": {}}
var max_turns: int = 1000
var debug_fixed_roll: int = -1  # 85..100 forces the damage random factor (tests)
var debug_no_crit: bool = false
var estimating: bool = false  # true while AI runs side-effect-free damage estimates

# ============================================================
# Setup
# ============================================================
func _init(config: Dictionary = {}) -> void:
	GameData.ensure_loaded()
	registry = EffectRegistry.get_instance()
	rng = BattleRNG.new(int(config.get("seed", 0)))
	format = str(config.get("format", "singles"))
	slots_per_side = 2 if format == "doubles" else 1
	log_enabled = bool(config.get("log", true))
	debug = bool(config.get("debug", false))
	max_turns = int(config.get("max_turns", 1000))
	debug_fixed_roll = int(config.get("fixed_roll", -1))
	debug_no_crit = bool(config.get("no_crit", false))
	var teams: Array = config.get("teams", [])
	var names: Array = config.get("names", ["P1", "P2"])
	for i in range(teams.size()):
		var sets: Array = []
		for t in teams[i]:
			sets.append(t if t is PokemonSet else PokemonSet.from_dict(t))
		sides.append(BattleSide.new(self, i, str(names[i]) if i < names.size() else "P%d" % (i + 1), sets, slots_per_side))
	if sides.size() == 2:
		sides[0].foe = sides[1]
		sides[1].foe = sides[0]

func start() -> void:
	if started:
		return
	started = true
	add_log(["start"])
	turn = 0
	# lead switch-ins
	for side in sides:
		for slot in range(slots_per_side):
			if slot < side.team.size():
				_switch_in_raw(side.team[slot], slot)
	_run_switch_in_events()
	faint_messages()
	if ended:
		return
	next_turn()

# ============================================================
# Logging
# ============================================================
func add_log(entry: Array) -> void:
	if estimating:
		return
	if log_enabled:
		log.append(entry)
	if debug:
		print("  ", entry)

func pid(p) -> String:
	if p == null:
		return "-"
	return p.slot_id() + ":" + p.display_name

func stat_inc(cat: String, key: String) -> void:
	if estimating:
		return
	var d: Dictionary = stats[cat]
	d[key] = int(d.get(key, 0)) + 1

# ============================================================
# Event system
# ============================================================
## True only when a Variant is literally `false` (events relay strings/dicts too).
static func is_false(v) -> bool:
	return typeof(v) == TYPE_BOOL and v == false

static func is_true(v) -> bool:
	return typeof(v) == TYPE_BOOL and v == true

## Combine a multiplier into the current event's 4096-based modifier chain.
func chain_modify(num, den = 1) -> void:
	if event_stack.is_empty():
		return
	var next_mod := int(floor(float(num) * 4096.0 / float(den)))
	var top: Dictionary = event_stack[event_stack.size() - 1]
	top["modifier"] = (int(top["modifier"]) * next_mod + 2048) >> 12

## Apply a 4096-based modifier with Gen 5+ rounding (round half down).
static func modify(value: int, num, den = 1) -> int:
	var mod := int(floor(float(num) * 4096.0 / float(den)))
	return (value * mod + 2047) >> 12

func _effect_dict(kind: String, id: String, state: Dictionary, holder) -> Dictionary:
	return {"kind": kind, "id": id, "state": state, "holder": holder}

## Gather all active effect sources affecting `p` (a BattlePokemon).
func _pokemon_effects(p) -> Array:
	var out: Array = []
	if p.ability != "" and not ability_suppressed(p):
		out.append(_effect_dict("ability", p.ability, p.ability_state, p))
	if p.item != "":
		out.append(_effect_dict("item", p.item, p.item_state, p))
	if p.status != "":
		out.append(_effect_dict("status", p.status, p.status_state, p))
	for v in p.volatiles:
		out.append(_effect_dict("volatile", v, p.volatiles[v], p))
	for sc in p.side.side_conditions:
		out.append(_effect_dict("side", sc, p.side.side_conditions[sc], p))
	var slot_conds: Dictionary = p.side.slot_conditions.get(p.position, {})
	for sc in slot_conds:
		out.append(_effect_dict("slot", sc, slot_conds[sc], p))
	if weather != "":
		out.append(_effect_dict("weather", weather, weather_state, p))
	if terrain != "":
		out.append(_effect_dict("terrain", terrain, terrain_state, p))
	for pw in pseudo_weather:
		out.append(_effect_dict("field", pw, pseudo_weather[pw], p))
	return out

func _side_effects(side) -> Array:
	var out: Array = []
	for sc in side.side_conditions:
		out.append(_effect_dict("side", sc, side.side_conditions[sc], null))
	if weather != "":
		out.append(_effect_dict("weather", weather, weather_state, null))
	if terrain != "":
		out.append(_effect_dict("terrain", terrain, terrain_state, null))
	for pw in pseudo_weather:
		out.append(_effect_dict("field", pw, pseudo_weather[pw], null))
	return out

func _field_effects() -> Array:
	var out: Array = []
	if weather != "":
		out.append(_effect_dict("weather", weather, weather_state, null))
	if terrain != "":
		out.append(_effect_dict("terrain", terrain, terrain_state, null))
	for pw in pseudo_weather:
		out.append(_effect_dict("field", pw, pseudo_weather[pw], null))
	return out

func _collect(handlers: Array, effects: Array, key: String) -> void:
	for e in effects:
		var h: Dictionary = registry.get_handlers(e["kind"], e["id"])
		if h.has(key):
			var entry := {
				"callable": h[key], "effect": e, "key": key,
				"order": h.get(key + "Order", 1000000),
				"priority": h.get(key + "Priority", 0),
				"speed": e["holder"].speed if e["holder"] != null else 0,
			}
			handlers.append(entry)

func _gather_handlers(event_id: String, target, source) -> Array:
	var handlers: Array = []
	var actives := all_active()
	if target is BattlePokemon:
		_collect(handlers, _pokemon_effects(target), "on" + event_id)
		for p in actives:
			if p == target:
				continue
			if p.side == target.side:
				_collect(handlers, _pokemon_effects(p), "onAlly" + event_id)
			else:
				_collect(handlers, _pokemon_effects(p), "onFoe" + event_id)
	elif target is BattleSide:
		_collect(handlers, _side_effects(target), "on" + event_id)
		for p in actives:
			if p.side == target:
				_collect(handlers, _pokemon_effects(p), "onAlly" + event_id)
			else:
				_collect(handlers, _pokemon_effects(p), "onFoe" + event_id)
	else:
		_collect(handlers, _field_effects(), "on" + event_id)
	if source is BattlePokemon:
		_collect(handlers, _pokemon_effects(source), "onSource" + event_id)
	for p in actives:
		_collect(handlers, _pokemon_effects(p), "onAny" + event_id)
	return handlers

func _sort_handlers(handlers: Array) -> void:
	if handlers.size() < 2:
		return
	# random tie-break via shuffle first, then stable sort
	rng.shuffle(handlers)
	handlers.sort_custom(func(a, b):
		if a["order"] != b["order"]:
			return a["order"] < b["order"]
		if a["priority"] != b["priority"]:
			return a["priority"] > b["priority"]
		return a["speed"] > b["speed"])

## Run an event. Returns the (possibly modified) relay value; `false` means the event was stopped.
func run_event(event_id: String, target = null, source = null, effect = null, relay = null):
	if relay == null:
		relay = true
	var handlers := _gather_handlers(event_id, target, source)
	if handlers.is_empty():
		return relay
	_sort_handlers(handlers)
	event_stack.append({"id": event_id, "modifier": 4096})
	event_depth += 1
	for h in handlers:
		var e: Dictionary = h["effect"]
		var holder = e["holder"]
		if holder != null and holder.fainted and event_id != "Faint" and event_id != "AfterFaint":
			continue
		# skip stale effects (e.g. item consumed mid-event)
		if not _effect_still_active(e):
			continue
		var ev := {"target": target, "source": source, "effect": effect, "move": effect if (effect is Dictionary and effect.get("effect_type", "") == "move") else null, "value": relay, "state": e["state"], "effect_id": e["id"], "kind": e["kind"], "holder": holder}
		var ret = h["callable"].call(self, holder, ev)
		if ret != null:
			relay = ret
			if typeof(ret) == TYPE_BOOL and ret == false:
				break
	var top: Dictionary = event_stack.pop_back()
	event_depth -= 1
	if int(top["modifier"]) != 4096 and (typeof(relay) == TYPE_INT or typeof(relay) == TYPE_FLOAT):
		relay = (int(relay) * int(top["modifier"]) + 2047) >> 12
	return relay

func _effect_still_active(e: Dictionary) -> bool:
	var holder = e["holder"]
	match e["kind"]:
		"ability":
			return holder != null and holder.ability == e["id"]
		"item":
			return holder != null and holder.item == e["id"]
		"status":
			return holder != null and holder.status == e["id"]
		"volatile":
			return holder != null and holder.volatiles.has(e["id"])
		"side":
			var side = holder.side if holder != null else null
			if side == null:
				return true
			return side.side_conditions.has(e["id"])
		"weather":
			return weather == e["id"]
		"terrain":
			return terrain == e["id"]
		"field":
			return pseudo_weather.has(e["id"])
	return true

## Run a single named handler of a specific effect. Returns relay (null if handler absent / no change).
func single_event(event_id: String, kind: String, id: String, state: Dictionary, target, source = null, effect = null, relay = null):
	var h: Dictionary = registry.get_handlers(kind, id)
	var key := "on" + event_id
	if not h.has(key):
		return relay
	var holder = target if target is BattlePokemon else null
	var ev := {"target": target, "source": source, "effect": effect, "move": effect if (effect is Dictionary and effect.get("effect_type", "") == "move") else null, "value": relay, "state": state, "effect_id": id, "kind": kind, "holder": holder}
	event_stack.append({"id": event_id, "modifier": 4096})
	var ret = h[key].call(self, holder, ev)
	var top: Dictionary = event_stack.pop_back()
	if ret == null:
		ret = relay
	if int(top["modifier"]) != 4096 and (typeof(ret) == TYPE_INT or typeof(ret) == TYPE_FLOAT):
		ret = (int(ret) * int(top["modifier"]) + 2047) >> 12
	return ret

## Run the move's own effect handler (from move["effect"]).
func move_event(event_id: String, move: Dictionary, target, source, relay = null):
	var eff: String = str(move.get("effect", ""))
	if eff == "":
		return relay
	return single_event(event_id, "move_effect", eff, move, target, source, move, relay)

## Run an event for every active pokemon in speed order.
func each_event(event_id: String, effect = null) -> void:
	var actives := all_active()
	actives.sort_custom(func(a, b): return a.speed > b.speed)
	for p in actives:
		if not p.fainted:
			run_event(event_id, p, null, effect)

func ability_suppressed(_p) -> bool:
	return false

## Data-driven item flag lookup (e.g. "hazard_immune", "prevents_trapping").
func item_flag(p, flag: String) -> bool:
	if p == null or p.item == "":
		return false
	return bool(GameData.get_item(p.item).get("flags", {}).get(flag, false))

func ability_flag(p, flag: String) -> bool:
	if p == null or p.ability == "" or ability_suppressed(p):
		return false
	return bool(GameData.get_ability(p.ability).get("flags", {}).get(flag, false))

## Contact check honoring Protective Pads / Long Reach style flags.
func is_contact(move: Dictionary, source) -> bool:
	if not move.get("flags", []).has("contact"):
		return false
	if item_flag(source, "no_contact") or ability_flag(source, "no_contact"):
		return false
	return true

# ============================================================
# Accessors
# ============================================================
func all_active() -> Array:
	var out: Array = []
	for s in sides:
		for p in s.active:
			if p != null and not p.fainted:
				out.append(p)
	return out

func has_pseudo_weather(id: String) -> bool:
	return pseudo_weather.has(id)

func is_weather(ids) -> bool:
	if weather == "":
		return false
	if ids is Array:
		return ids.has(weather)
	return weather == ids

func is_terrain(id: String) -> bool:
	return terrain == id

func update_speeds() -> void:
	for p in all_active():
		p.speed = p.get_action_speed()

func get_move_data(id: String) -> Dictionary:
	return GameData.get_move(id)

# ============================================================
# Requests & choices
# ============================================================
func make_requests(kind: String) -> void:
	request_state = kind
	for side in sides:
		side.choice = {}
		side.request = _build_request(side, kind)

func _build_request(side, kind: String) -> Dictionary:
	if kind == "switch":
		var slots: Array = []
		for i in range(side.active.size()):
			var p = side.active[i]
			if p == null or p.fainted or p.switch_flag:
				if side.has_alive_bench():
					slots.append(i)
		if slots.is_empty():
			return {"type": "wait"}
		return {"type": "switch", "slots": slots, "bench": _bench_info(side)}
	# move request
	var active_reqs: Array = []
	var any := false
	for i in range(side.active.size()):
		var p = side.active[i]
		if p == null or p.fainted:
			continue
		any = true
		active_reqs.append(_move_request_for(p))
	if not any:
		return {"type": "wait"}
	return {"type": "move", "active": active_reqs, "bench": _bench_info(side)}

func _bench_info(side) -> Array:
	var out: Array = []
	for p in side.team:
		out.append({"index": p.team_index, "species": p.species_id, "hp": p.hp, "max_hp": p.max_hp, "status": p.status, "active": p.active, "fainted": p.fainted})
	return out

func _move_request_for(p) -> Dictionary:
	var moves: Array = []
	var locked_move := ""
	# locked into a multi-turn move?
	var lm = run_event("LockMove", p)
	if typeof(lm) == TYPE_STRING and lm != "":
		locked_move = lm
	if locked_move != "":
		moves.append({"id": locked_move, "pp": 0, "max_pp": 0, "disabled": false, "target": GameData.get_move(locked_move).get("target", "normal")})
		return {"slot": p.position, "moves": moves, "trapped": true, "locked": true, "pokemon": p.species_id}
	var can_move := 0
	for m in p.moves:
		var disabled := false
		if m["pp"] <= 0:
			disabled = true
		elif Battle.is_false(run_event("DisableMove", p, null, GameData.get_move(m["id"]))):
			disabled = true
		var md := GameData.get_move(m["id"])
		moves.append({"id": m["id"], "pp": m["pp"], "max_pp": m["max_pp"], "disabled": disabled, "target": md.get("target", "normal")})
		if not disabled:
			can_move += 1
	if can_move == 0:
		moves = [{"id": "struggle", "pp": 0, "max_pp": 0, "disabled": false, "target": "randomNormal"}]
	var trapped := is_trapped(p)
	return {"slot": p.position, "moves": moves, "trapped": trapped, "locked": false, "pokemon": p.species_id}

func is_trapped(p) -> bool:
	if p.has_type("ghost") or item_flag(p, "prevents_trapping"):
		return false
	if p.trapped or p.volatiles.has("trapped") or p.volatiles.has("partially_trapped") or p.volatiles.has("ingrain"):
		return true
	var r = run_event("TrapPokemon", p)
	return Battle.is_false(r)

## Submit a choice for a side. Choice is an Array (one entry per active slot / per pending switch slot)
## or a single Dictionary for singles. Entry: {"type":"move","move":id|"slot":i,"target":loc} or {"type":"switch","index":team_index}.
## Returns "" on success or an error string.
func choose(side_index: int, choice) -> String:
	var side = sides[side_index]
	var entries: Array = choice if choice is Array else [choice]
	var req: Dictionary = side.request
	if req.get("type", "wait") == "wait":
		return "no request pending"
	var err := _validate_choice(side, req, entries)
	if err != "":
		return err
	side.choice = {"entries": entries}
	if _all_chosen():
		commit_decisions()
	return ""

func _all_chosen() -> bool:
	for s in sides:
		if s.request.get("type", "wait") != "wait" and s.choice.is_empty():
			return false
	return true

func _validate_choice(side, req: Dictionary, entries: Array) -> String:
	if req["type"] == "switch":
		var slots: Array = req["slots"]
		if entries.size() != slots.size():
			return "need %d switch choices" % slots.size()
		var used := {}
		for e in entries:
			if e.get("type", "") != "switch":
				return "must switch"
			var idx := int(e.get("index", -1))
			if idx < 0 or idx >= side.team.size():
				return "bad index"
			var p = side.team[idx]
			if p.fainted or p.active or used.has(idx):
				return "cannot switch to %d" % idx
			used[idx] = true
		return ""
	# move request
	var actives: Array = req["active"]
	if entries.size() != actives.size():
		return "need %d choices" % actives.size()
	var used := {}
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var ar: Dictionary = actives[i]
		if e.get("type", "") == "switch":
			if ar["trapped"]:
				return "trapped"
			var idx := int(e.get("index", -1))
			if idx < 0 or idx >= side.team.size():
				return "bad index"
			var p = side.team[idx]
			if p.fainted or p.active or used.has(idx):
				return "cannot switch to %d" % idx
			used[idx] = true
		elif e.get("type", "") == "move":
			var mid := ""
			if e.has("move"):
				mid = str(e["move"])
			elif e.has("slot"):
				var s := int(e["slot"])
				if s < 0 or s >= ar["moves"].size():
					return "bad move slot"
				mid = ar["moves"][s]["id"]
			var found := false
			for m in ar["moves"]:
				if m["id"] == mid:
					found = true
					if m["disabled"]:
						return "move disabled: " + mid
			if not found:
				return "unknown move choice: " + mid
			e["move"] = mid
		else:
			return "bad choice type"
	return ""

func commit_decisions() -> void:
	var kind := request_state
	request_state = ""
	if kind == "switch":
		# perform switches, fastest first
		var acts: Array = []
		for side in sides:
			if side.choice.is_empty():
				continue
			var slots: Array = side.request["slots"]
			var entries: Array = side.choice["entries"]
			for i in range(slots.size()):
				var slot: int = slots[i]
				var cur = side.active[slot]
				acts.append({"side": side, "slot": slot, "pokemon": side.team[int(entries[i]["index"])], "speed": cur.speed if cur != null else 0, "out": cur})
		rng.shuffle(acts)
		acts.sort_custom(func(a, b): return a["speed"] > b["speed"])
		for a in acts:
			var outp = a["out"]
			if outp != null and not outp.fainted:
				# mid-turn switch (U-turn / Eject Button)
				switch_in(a["pokemon"], a["slot"], true)
			else:
				switch_in(a["pokemon"], a["slot"], false)
		for s in sides:
			s.request = {}
			s.choice = {}
		_run_switch_in_events()
		faint_messages()
		if ended:
			return
		if mid_turn:
			run_queue()
		else:
			# end-of-turn faint replacements done: check more faints (hazards) then next turn
			if _needs_switch_requests():
				make_requests("switch")
				return
			next_turn()
		return
	# move decisions -> build queue
	queue.clear()
	for side in sides:
		if side.choice.is_empty():
			continue
		var actives: Array = side.request["active"]
		var entries: Array = side.choice["entries"]
		for i in range(entries.size()):
			var e: Dictionary = entries[i]
			var p = side.active[int(actives[i]["slot"])]
			if e["type"] == "switch":
				queue.append({"choice": "switch", "pokemon": p, "target": side.team[int(e["index"])], "order": SWITCH_ORDER, "priority": 0, "frac": 0, "speed": 0})
			else:
				var move_id: String = e["move"]
				var md: Dictionary = GameData.get_move(move_id).duplicate(true)
				md["effect_type"] = "move"
				queue.append({"choice": "move", "pokemon": p, "move": move_id, "move_data": md, "target_loc": int(e.get("target", 0)), "order": MOVE_ORDER, "priority": 0, "frac": 0, "speed": 0})
	for s in sides:
		s.request = {}
		s.choice = {}
	queue.append({"choice": "residual", "order": RESIDUAL_ORDER, "priority": 0, "frac": 0, "speed": 0})
	mid_turn = true
	_resolve_priorities()
	# before-turn hooks (Quick Claw etc.)
	for a in queue:
		if a["choice"] == "move":
			var p = a["pokemon"]
			var frac = run_event("FractionalPriority", p, null, a["move_data"], 0)
			a["frac"] = frac if typeof(frac) != TYPE_BOOL else 0
	_sort_queue()
	run_queue()

func _resolve_priorities() -> void:
	update_speeds()
	for a in queue:
		if a["choice"] == "move":
			var p = a["pokemon"]
			var md: Dictionary = a["move_data"]
			var pr = run_event("ModifyPriority", p, null, md, int(md.get("priority", 0)))
			a["priority"] = int(pr) if typeof(pr) != TYPE_BOOL else 0
			a["speed"] = p.speed
		elif a["choice"] == "switch":
			a["speed"] = a["pokemon"].speed

func _sort_queue() -> void:
	rng.shuffle(queue)
	queue.sort_custom(func(a, b):
		if a["order"] != b["order"]:
			return a["order"] < b["order"]
		if a["priority"] != b["priority"]:
			return a["priority"] > b["priority"]
		if a["frac"] != b["frac"]:
			return a["frac"] > b["frac"]
		if a["speed"] != b["speed"]:
			return _speed_before(a["speed"], b["speed"])
		return false)

func _speed_before(a: int, b: int) -> bool:
	if has_pseudo_weather("trick_room"):
		return a < b
	return a > b

func _needs_switch_requests() -> bool:
	for side in sides:
		for p in side.active:
			if p != null and (p.fainted or p.switch_flag) and side.has_alive_bench():
				return true
	return false

# ============================================================
# Turn loop
# ============================================================
func next_turn() -> void:
	turn += 1
	mid_turn = false
	if turn > max_turns:
		ended = true
		winner = -1
		add_log(["tie", "turn limit"])
		return
	add_log(["turn", turn])
	_first_mover_recorded = false
	for p in all_active():
		var tp: Dictionary = stats["turns_present"]
		tp[p.species_id] = int(tp.get(p.species_id, 0)) + 1
		p.move_this_turn = ""
		p.hurt_this_turn = 0
		p.used_item_this_turn = false
		p.stats_lowered_this_turn = false
		p.stats_raised_this_turn = false
		p.newly_switched = false
		p.attacked_by.clear()
		p.active_turns += 1
	update_speeds()
	make_requests("move")

func run_queue() -> void:
	while not queue.is_empty():
		var action: Dictionary = queue.pop_front()
		current_action = action
		_run_action(action)
		if ended:
			return
		# dynamic speed: re-sort remaining move actions (Gen 8+)
		update_speeds()
		for a in queue:
			if a["choice"] == "move" and a["pokemon"] != null:
				a["speed"] = a["pokemon"].speed
		_sort_queue()
		each_event("Update")
		faint_messages()
		if ended:
			return
		# forced random switches (Roar, Dragon Tail, Red Card)
		for side in sides:
			for p in side.active:
				if p != null and not p.fainted and p.force_switch_flag:
					p.force_switch_flag = false
					if side.has_alive_bench():
						drag_in(side, p.position)
		faint_messages()
		if ended:
			return
		# mid-turn switch requests (U-turn, Eject Button, Baton Pass)
		var need := false
		for side in sides:
			for p in side.active:
				if p != null and not p.fainted and p.switch_flag:
					if side.has_alive_bench():
						need = true
					else:
						p.switch_flag = false
		if need:
			make_requests("switch")
			return
	# queue empty: turn is over
	mid_turn = false
	_check_fainted()
	if _needs_switch_requests():
		make_requests("switch")
		return
	next_turn()

func _check_fainted() -> void:
	for side in sides:
		for i in range(side.active.size()):
			var p = side.active[i]
			if p != null and p.fainted:
				if side.has_alive_bench():
					p.switch_flag = true
				else:
					side.active[i] = null

func _run_action(action: Dictionary) -> void:
	match action["choice"]:
		"switch":
			var p = action["pokemon"]
			if p != null and not p.fainted and p.active:
				switch_in(action["target"], p.position, true)
				_run_switch_in_events()
		"move":
			var p = action["pokemon"]
			if p == null or p.fainted or not p.active:
				return
			if not _first_mover_recorded:
				_first_mover_recorded = true
				var fm: Dictionary = stats["first_move"]
				fm[p.species_id] = int(fm.get(p.species_id, 0)) + 1
			run_move(p, action["move"], action["target_loc"], {"move_data": action.get("move_data", {})})
		"residual":
			add_log(["residual"])
			residual()
			each_event("Update")

# ============================================================
# Switching
# ============================================================
func _switch_in_raw(p, slot: int) -> void:
	var side = p.side
	var old = side.active[slot]
	if old != null and old != p:
		old.active = false
		old.position = -1
	side.active[slot] = p
	p.active = true
	p.position = slot
	p.newly_switched = true
	p.is_started = false
	p.active_turns = 0
	p.active_move_actions = 0
	p.switch_flag = false
	p.force_switch_flag = false
	p.clear_boosts()
	p.clear_volatiles()
	p.ability_state = {}
	p.item_state = {}
	p.types = p.base_types.duplicate()
	p.added_type = ""
	p.last_move = ""
	p.move_this_turn = ""
	p.speed = p.get_action_speed()
	side.slot_conditions.erase(-1)
	add_log(["switch", pid(p), p.species_id, p.hp, p.max_hp])
	_pending_switch_ins.append(p)

var _pending_switch_ins: Array = []

## Switch `p` into `slot` of its side. `is_mid_turn` true when replacing a live pokemon.
func switch_in(p, slot: int, is_mid_turn: bool) -> bool:
	var side = p.side
	if p.fainted or p.active:
		return false
	var old = side.active[slot]
	var copy_boosts: Dictionary = {}
	var copy_volatiles: Dictionary = {}
	if old != null and not old.fainted:
		old.being_called_back = true
		run_event("SwitchOut", old)
		if str(old.switch_flag) == "copyvolatile":
			copy_boosts = old.boosts.duplicate()
			for v in ["substitute", "leech_seed", "confusion", "aqua_ring", "ingrain", "focus_energy", "curse", "perish_song", "magnet_rise", "trapped", "partially_trapped", "embargo", "heal_block", "laser_focus", "lock_on", "power_trick", "telekinesis"]:
				if old.volatiles.has(v):
					copy_volatiles[v] = old.volatiles[v].duplicate()
		single_event("End", "ability", old.ability, old.ability_state, old)
		old.clear_volatiles()
		old.clear_boosts()
		old.status_state.erase("time_shift")
		old.trapped = false
		old.being_called_back = false
		old.types = old.base_types.duplicate()
		old.added_type = ""
		if old.status == "tox":
			old.status_state["stage"] = 0
	_switch_in_raw(p, slot)
	if not copy_boosts.is_empty():
		p.boosts = copy_boosts
		for v in copy_volatiles:
			p.volatiles[v] = copy_volatiles[v]
		add_log(["-activate", pid(p), "baton_pass"])
	if is_mid_turn:
		# remove queued actions of the switched-out pokemon
		var new_queue: Array = []
		for a in queue:
			if a.get("pokemon") == old and old != null:
				continue
			new_queue.append(a)
		queue = new_queue
	return true

## Run entry hazards + ability/item starts for pokemon that just switched in, in speed order.
func _run_switch_in_events() -> void:
	if _pending_switch_ins.is_empty():
		return
	var list := _pending_switch_ins.duplicate()
	_pending_switch_ins.clear()
	update_speeds()
	rng.shuffle(list)
	list.sort_custom(func(a, b): return a.speed > b.speed)
	# entry hazards first (all), then abilities/items
	for p in list:
		if p.fainted or not p.active:
			continue
		run_event("EntryHazard", p)
		faint_messages()
	for p in list:
		if p.fainted or not p.active:
			continue
		p.is_started = true
		single_event("Start", "ability", p.ability, p.ability_state, p)
		single_event("Start", "item", p.item, p.item_state, p)
		run_event("SwitchIn", p)
	each_event("Update")
	faint_messages()

## Force a pokemon out (Roar/Dragon Tail/Red Card): random bench replacement immediately.
func drag_in(side, slot: int) -> bool:
	var bench: Array = side.bench()
	if bench.is_empty():
		return false
	var p = rng.sample(bench)
	switch_in(p, slot, true)
	add_log(["drag", pid(p)])
	_run_switch_in_events()
	return true

# ============================================================
# Move execution
# ============================================================
func get_target(p, move: Dictionary, target_loc: int):
	var tt: String = str(move.get("target", "normal"))
	if tt == "scripted":
		var la: Dictionary = p.last_attacked_by
		if not la.is_empty() and la.get("turn") == turn:
			var src = la.get("source")
			if src != null and src.active and not src.fainted and src.side != p.side:
				return src
		return null
	if tt in ["self", "allySide", "allyTeam", "adjacentAllyOrSelf"] and target_loc == 0:
		return p
	if tt in ["all", "foeSide", "allySide", "allyTeam"]:
		return p
	if target_loc > 0:
		var foe_slot := target_loc - 1
		if foe_slot < p.side.foe.active.size():
			var t = p.side.foe.active[foe_slot]
			if t != null and not t.fainted:
				return t
	elif target_loc < 0:
		var ally_slot := -target_loc - 1
		if ally_slot < p.side.active.size():
			var t = p.side.active[ally_slot]
			if t != null and not t.fainted:
				return t
	if tt in ["adjacentAlly"]:
		var allies: Array = p.allies()
		return rng.sample(allies) if not allies.is_empty() else null
	return get_random_target(p, move)

func get_random_target(p, move: Dictionary):
	var tt: String = str(move.get("target", "normal"))
	if tt in ["self", "allySide", "allyTeam", "all", "foeSide", "adjacentAllyOrSelf"]:
		return p
	var foes: Array = p.foes()
	if foes.is_empty():
		return null
	return rng.sample(foes)

func get_move_targets(p, target, move: Dictionary) -> Array:
	var tt: String = str(move.get("target", "normal"))
	match tt:
		"allAdjacentFoes":
			return p.foes()
		"allAdjacent":
			var out: Array = p.foes()
			out.append_array(p.allies())
			return out
		"self", "allySide", "allyTeam", "all", "foeSide":
			return [p]
		_:
			if target == null or target.fainted:
				target = get_random_target(p, move)
			return [target] if target != null else []

## Called by the action queue for a chosen move.
func run_move(p, move_id: String, target_loc: int = 0, options: Dictionary = {}) -> void:
	var move_data: Dictionary = options.get("move_data", {})
	if move_data.is_empty():
		move_data = GameData.get_move(move_id).duplicate(true)
	if move_data.is_empty():
		push_error("unknown move " + move_id)
		return
	var external: bool = options.get("external", false)
	p.active_move_actions += 1
	# locked move (Outrage / charge turn / Encore) overrides choice
	var locked := false
	var lm = run_event("LockMove", p)
	if not external and typeof(lm) == TYPE_STRING and lm != "" and lm != "recharge":
		if lm != move_id:
			move_id = lm
			move_data = GameData.get_move(move_id).duplicate(true)
		locked = p.volatiles.has("locked_move") or p.volatiles.has("two_turn_move")
	var target = get_target(p, move_data, target_loc)
	if not external:
		var will_try = run_event("BeforeMove", p, target, move_data)
		if Battle.is_false(will_try):
			run_event("MoveAborted", p, target, move_data)
			p.move_this_turn = "aborted"
			if p.volatiles.has("two_turn_move"):
				remove_volatile(p, "two_turn_move")
			if p.volatiles.has("locked_move"):
				remove_volatile(p, "locked_move")
			return
		if move_id != "struggle" and not locked:
			p.deduct_pp(move_id, 1)
	p.last_move = move_id
	p.last_move_used_turn = turn
	p.move_this_turn = move_id
	stat_inc("moves_used", move_id)
	if move_data.get("locked_move", false) and not p.volatiles.has("locked_move"):
		add_volatile(p, "locked_move", p, move_data)
	var ok := use_move(move_data, p, target, options)
	if ok:
		last_successful_move_this_turn = move_id
		p.volatiles.erase("_last_move_failed")
	else:
		p.volatiles["_last_move_failed"] = {"id": "_last_move_failed"}
		if p.volatiles.has("locked_move"):
			remove_volatile(p, "locked_move")
	if move_data.get("effect", "") != "fury_cutter":
		p.volatiles.erase("fury_cutter")
	if ok and move_data.get("flags", []).has("recharge") and int(active_move_total_damage) > 0:
		add_volatile(p, "must_recharge", p, move_data)
	run_event("AfterMove", p, target, move_data)
	faint_messages()

var active_move_total_damage: int = 0
var _first_mover_recorded: bool = false

## Side-effect-free expected damage (average roll, no crit) for AI use. Does not consume RNG.
func estimate_damage(attacker, defender, move_id: String, roll: int = 92) -> int:
	var md := GameData.get_move(move_id)
	if md.is_empty() or md["category"] == "status" or defender == null:
		return 0
	var mv: Dictionary = md.duplicate(true)
	mv["effect_type"] = "move"
	if mv.get("ignore_immunity", null) == null:
		mv["ignore_immunity"] = false
	var prev_est := estimating
	var prev_roll := debug_fixed_roll
	var prev_crit := debug_no_crit
	var prev_move := active_move
	estimating = true
	debug_fixed_roll = roll
	debug_no_crit = true
	run_event("ModifyType", attacker, defender, mv)
	move_event("ModifyMove", mv, attacker, defender)
	var dmg = 0
	if run_immunity(defender, mv["type"], mv) and not (mv.get("prankster_boosted", false) and defender.has_type("dark")):
		var d = get_damage(attacker, defender, mv)
		if typeof(d) == TYPE_INT:
			dmg = d
	estimating = prev_est
	debug_fixed_roll = prev_roll
	debug_no_crit = prev_crit
	active_move = prev_move
	return int(dmg)

## Execute a move (already past BeforeMove). Returns success.
func use_move(base_move: Dictionary, p, target, options: Dictionary = {}) -> bool:
	var move: Dictionary = base_move.duplicate(true)
	move["effect_type"] = "move"
	move["hit"] = 0
	move["total_damage"] = 0
	move["spread_hit"] = false
	move["source_effect"] = options.get("source_effect", "")
	if move.get("ignore_immunity", null) == null:
		move["ignore_immunity"] = (move["category"] == "status")
	var prev_move := active_move
	var prev_pokemon = active_pokemon
	var prev_target = active_target
	active_move = move
	active_pokemon = p
	active_target = target
	add_log(["move", pid(p), move["id"], pid(target) if target != null and target != p else ""])
	# type / move modifications
	run_event("ModifyType", p, target, move)
	move_event("ModifyMove", move, p, target)
	run_event("ModifyMove", p, target, move)
	if target != null and target.fainted:
		target = get_random_target(p, move)
	var needs_target: bool = not (move["target"] in ["self", "allySide", "allyTeam", "all", "foeSide"])
	if needs_target and target == null:
		add_log(["-notarget", pid(p)])
		active_move = prev_move
		active_pokemon = prev_pokemon
		active_target = prev_target
		return false
	# TryMove: move-level then pokemon-level
	if Battle.is_false(move_event("TryMove", move, target, p)) or Battle.is_false(run_event("TryMove", p, target, move)):
		active_move = prev_move
		active_pokemon = prev_pokemon
		active_target = prev_target
		return false
	# Prepare (charging etc.)
	if Battle.is_false(move_event("Try", move, target, p)):
		add_log(["-fail", pid(p)])
		active_move = prev_move
		active_pokemon = prev_pokemon
		active_target = prev_target
		return false
	var targets := get_move_targets(p, target, move)
	if targets.size() > 1:
		move["spread_hit"] = true
	if move.get("self_destruct", "") == "always":
		faint(p, p, move)
	var success := false
	if move["target"] in ["all", "foeSide", "allySide", "allyTeam"]:
		success = _try_field_move(move, p)
	elif move["target"] == "self" or (targets.size() == 1 and targets[0] == p):
		success = _try_self_move(move, p)
	else:
		success = _try_spread_move(targets, p, move)
	last_move = move
	active_move_total_damage = int(move["total_damage"])
	if success:
		if move.get("self_switch", false) and p.hp > 0 and not p.fainted and p.side.has_alive_bench():
			p.switch_flag = move["self_switch"]
		if int(move["total_damage"]) > 0:
			run_event("AfterMoveSecondarySelf", p, target, move)
		if move.get("self_destruct", "") == "if_hit":
			faint(p, p, move)
	else:
		move_event("MoveFail", move, target, p)
	if move.get("effect", "") == "fury_cutter" and success:
		var fc: Dictionary = p.volatiles.get("fury_cutter", {"id": "fury_cutter", "count": 0})
		fc["count"] = mini(4, int(fc.get("count", 0)) + 1)
		p.volatiles["fury_cutter"] = fc
	active_move = prev_move
	active_pokemon = prev_pokemon
	active_target = prev_target
	return success

func _try_field_move(move: Dictionary, p) -> bool:
	if Battle.is_false(move_event("TryHit", move, p, p)):
		add_log(["-fail", pid(p)])
		return false
	var did := false
	var side = p.side if move["target"] in ["allySide", "allyTeam"] else p.side.foe
	if move.has("side_condition"):
		if add_side_condition(side, move["side_condition"], p, move):
			did = true
	if move.has("weather"):
		if set_weather(move["weather"], p, move):
			did = true
	if move.has("terrain"):
		if set_terrain(move["terrain"], p, move):
			did = true
	if move.has("pseudo_weather"):
		if add_pseudo_weather(move["pseudo_weather"], p, move):
			did = true
	var hr = move_event("Hit", move, p, p)
	if Battle.is_false(hr) and not did:
		add_log(["-fail", pid(p)])
		return false
	if hr != null and not Battle.is_false(hr):
		did = true
	if move.has("self_boosts") or move.has("self"):
		_apply_self_effects(move, p)
	if not did and hr == null and not move.has("self"):
		add_log(["-fail", pid(p)])
		return false
	return true

func _try_self_move(move: Dictionary, p) -> bool:
	if Battle.is_false(move_event("TryHit", move, p, p)):
		add_log(["-fail", pid(p)])
		return false
	if Battle.is_false(run_event("TryHit", p, p, move)):
		add_log(["-fail", pid(p)])
		return false
	var r := move_hit(p, p, move, false, false)
	if not r:
		add_log(["-fail", pid(p)])
	return r

func _try_spread_move(targets: Array, p, move: Dictionary) -> bool:
	var hit_targets: Array = []
	for t in targets:
		if t == null or t.fainted:
			continue
		if _hit_steps(t, p, move):
			hit_targets.append(t)
	if hit_targets.is_empty():
		if move["category"] == "status" or move["hit"] == 0:
			pass
		return false
	return true

## Accuracy / immunity / protect gate for one target. Returns true if the move connected.
func _hit_steps(target, p, move: Dictionary) -> bool:
	# 0. semi-invulnerable targets (Fly / Dig / Phantom Force)
	var ttm: Dictionary = target.volatiles.get("two_turn_move", {})
	if not ttm.is_empty() and str(ttm.get("invulnerable", "")) != "" and target != p:
		var hits_inv: Array = move.get("hits_invulnerable", [])
		if not hits_inv.has(str(ttm["invulnerable"])):
			add_log(["-miss", pid(p), pid(target)])
			stats["misses"] += 1
			return false
	# 1. move-level TryHit
	if Battle.is_false(move_event("TryHit", move, target, p)):
		add_log(["-fail", pid(p)])
		return false
	# 2. TryHit event on target (Protect, absorbing abilities, Prankster vs Dark, etc.)
	var th = run_event("TryHit", target, p, move)
	if Battle.is_false(th):
		return false
	# 3. type immunity
	if not _check_immunity(target, p, move):
		return false
	# 4. accuracy
	if not _accuracy_check(target, p, move):
		add_log(["-miss", pid(p), pid(target)])
		stats["misses"] += 1
		move_event("Miss", move, target, p)
		return false
	# 5. hit loop (multi-hit)
	var hits := 1
	if move.has("multihit"):
		var mh = move["multihit"]
		if mh is Array:
			var min_h := int(mh[0])
			var max_h := int(mh[1])
			var forced = run_event("ModifyMultiHit", p, target, move, 0)
			if typeof(forced) == TYPE_INT and forced > 0:
				hits = forced
			elif min_h == 2 and max_h == 5:
				var roll := rng.next(20)
				if roll < 7: hits = 2
				elif roll < 14: hits = 3
				elif roll < 17: hits = 4
				else: hits = 5
			else:
				hits = rng.range_int(min_h, max_h)
		else:
			hits = int(mh)
	var actual_hits := 0
	for i in range(hits):
		if target.fainted or (i > 0 and (p.fainted or p.hp <= 0)):
			break
		if i > 0 and move.has("multi_accuracy") and not _accuracy_check(target, p, move):
			break
		move["hit"] = i + 1
		if not move_hit(target, p, move, false, false):
			break
		actual_hits += 1
		each_event("Update")
	if hits > 1 and actual_hits > 0:
		add_log(["-hitcount", pid(target), actual_hits])
	return actual_hits > 0

func _check_immunity(target, p, move: Dictionary) -> bool:
	if target == p:
		return true
	# Prankster-boosted status vs Dark
	if move.get("prankster_boosted", false) and target.has_type("dark") and move["category"] == "status" and target != p:
		add_log(["-immune", pid(target)])
		return false
	# Powder moves vs Grass
	if move["flags"].has("powder") and (target.has_type("grass") or item_flag(target, "powder_immune") or ability_flag(target, "overcoat")):
		add_log(["-immune", pid(target)])
		return false
	if Battle.is_true(move.get("ignore_immunity", false)):
		return true
	if not run_immunity(target, move["type"], move):
		add_log(["-immune", pid(target)])
		return false
	return true

## Type immunity check for `p` against attacking type.
func run_immunity(p, type: String, move = null) -> bool:
	if type == "ground" and not p.is_grounded():
		if move == null or not move.get("ignore_grounding", false):
			return false
	var neg = run_event("NegateImmunity", p, null, move, type)
	if Battle.is_false(neg):
		return true
	for t in p.get_types():
		if GameData.type_mod(type, t) == 0.0:
			return false
	return true

func _accuracy_check(target, p, move: Dictionary) -> bool:
	var acc = move["accuracy"]
	# weather overrides from data
	if weather != "":
		var ahi = move.get("always_hit_in", [])
		if ahi.has(weather):
			acc = true
		var ain = move.get("accuracy_in", {})
		if ain.has(weather):
			acc = int(ain[weather])
	if move.get("ohko", false):
		if target.level > p.level:
			add_log(["-immune", pid(target), "[ohko]"])
			return false
		acc = 30 + (p.level - target.level)
	if typeof(acc) == TYPE_BOOL and acc == true:
		return true
	var accuracy := int(acc)
	if not move.get("ohko", false):
		var boost := 0
		if not move.get("ignore_accuracy", false):
			boost += p.boosts["accuracy"]
		if not move.get("ignore_evasion", false) and not (target.volatiles.has("minimize") and move["flags"].has("crushes_minimized")):
			boost -= target.boosts["evasion"]
		boost = clampi(boost, -6, 6)
		if boost > 0:
			accuracy = int(floor(accuracy * (3 + boost) / 3.0))
		elif boost < 0:
			accuracy = int(floor(accuracy * 3.0 / (3 - boost)))
		if target.volatiles.has("minimize") and move["flags"].has("crushes_minimized"):
			return true
		var mod_acc = run_event("ModifyAccuracy", target, p, move, accuracy)
		if typeof(mod_acc) == TYPE_BOOL:
			return mod_acc
		accuracy = int(mod_acc)
	var r = run_event("Accuracy", target, p, move, accuracy)
	if typeof(r) == TYPE_BOOL:
		return r
	accuracy = int(r)
	return rng.next(100) < accuracy

## One hit of a move on one target. Returns true if the hit "did something".
func move_hit(target, p, move: Dictionary, is_secondary: bool, is_self: bool, move_data: Dictionary = {}) -> bool:
	if move_data.is_empty():
		move_data = move
	if target == null:
		return false
	var did_something := false
	var damage = 0
	var hit_sub := false
	if not is_self and not is_secondary and target != p:
		# Substitute intercept
		if target.volatiles.has("substitute") and not move["flags"].has("bypasssub") and not move["flags"].has("sound"):
			hit_sub = true
	if not is_secondary and not is_self:
		if Battle.is_false(move_event("PrepareHit", move, target, p)):
			return false
	# damage
	if not is_secondary and not is_self and move["category"] != "status":
		damage = get_damage(p, target, move)
		if damage == null or (typeof(damage) == TYPE_BOOL and damage == false):
			return false
		if hit_sub:
			damage = _hit_substitute(target, p, move, int(damage))
			if Battle.is_false(damage):
				return false
		else:
			damage = damage_pokemon(target, int(damage), p, move)
			if damage == 0 and move["category"] != "status":
				# 0 damage from a damaging move = failed (e.g. Damage event blocked)
				pass
		move["total_damage"] = int(move["total_damage"]) + int(damage)
		if int(damage) > 0:
			did_something = true
			p.last_damage = int(damage)
			target.last_attacked_by = {"source": p, "damage": int(damage), "move": move["id"], "category": move["category"], "turn": turn}
			target.attacked_by.append(target.last_attacked_by)
			target.times_attacked += 1
			add_log(["-hp", pid(target), target.hp, target.max_hp])
	if hit_sub and move["category"] != "status":
		# secondary effects on target are blocked; self effects/drain still apply
		if move.has("drain") and int(damage) > 0:
			var amt := maxi(1, int(floor(int(damage) * float(move["drain"][0]) / float(move["drain"][1]))))
			heal_pokemon(p, amt, target, move)
		if move.has("recoil") and int(damage) > 0:
			_apply_recoil(p, int(damage), move)
		if move.has("self"):
			_apply_self_effects(move, p)
		_apply_secondaries(target, p, move, true)
		move_event("AfterSubDamage", move, target, p, damage)
		return true
	if hit_sub and move["category"] == "status" and target != p:
		add_log(["-fail", pid(p)])
		return false
	# primary effects
	if move_data.has("boosts") and not target.fainted:
		var r = boost(target, move_data["boosts"], p, move, is_secondary, is_self)
		if r: did_something = true
	if move_data.has("heal") and not target.fainted:
		var hf = move_data["heal"]
		var amt := maxi(1, int(round(target.max_hp * float(hf[0]) / float(hf[1]))))
		var healed := heal_pokemon(target, amt, p, move)
		if healed > 0:
			did_something = true
		elif not is_secondary and not is_self:
			add_log(["-fail", pid(p), "heal"])
	if move_data.has("status") and not target.fainted:
		var r := set_status(target, move_data["status"], p, move)
		if r: did_something = true
	if move_data.has("volatile_status") and not target.fainted:
		var r := add_volatile(target, move_data["volatile_status"], p, move)
		if r: did_something = true
	if move_data.has("side_condition"):
		var side = target.side
		if add_side_condition(side, move_data["side_condition"], p, move): did_something = true
	if move_data.has("weather"):
		if set_weather(move_data["weather"], p, move): did_something = true
	if move_data.has("terrain"):
		if set_terrain(move_data["terrain"], p, move): did_something = true
	if move_data.has("pseudo_weather"):
		if add_pseudo_weather(move_data["pseudo_weather"], p, move): did_something = true
	if move_data.has("force_switch") and not target.fainted and not is_secondary:
		if target.side.has_alive_bench() and not Battle.is_false(run_event("DragOut", target, p, move)):
			target.force_switch_flag = true
			did_something = true
	if not is_secondary and not is_self:
		# move's own Hit handler
		var hr = move_event("Hit", move, target, p)
		if Battle.is_false(hr):
			if not did_something:
				return false
		elif hr != null:
			did_something = true
		# Hit event on target
		if target != p:
			run_event("Hit", target, p, move)
	if is_secondary or is_self:
		return did_something
	# drain / recoil
	if move.has("drain") and int(damage) > 0:
		var amt := maxi(1, int(floor(int(damage) * float(move["drain"][0]) / float(move["drain"][1]))))
		heal_pokemon(p, amt, target, move)
	if move.has("recoil") and int(damage) > 0:
		_apply_recoil(p, int(damage), move)
	# self effects
	if move.has("self") and (not move.has("multihit") or move["hit"] == 1 or true):
		if not move.has("multihit") or not move.get("_self_applied", false):
			_apply_self_effects(move, p)
			if move.has("multihit"):
				move["_self_applied"] = true
	# secondaries
	_apply_secondaries(target, p, move, false)
	# contact / damaging-hit reactions
	if int(damage) > 0:
		run_event("DamagingHit", target, p, move, int(damage))
		move_event("AfterHit", move, target, p)
		run_event("AfterHit", target, p, move)
	elif move["category"] == "status" and did_something:
		move_event("AfterHit", move, target, p)
	if move["category"] == "status" and not did_something:
		add_log(["-fail", pid(p)])
		return false
	if move["category"] != "status" and int(damage) <= 0 and not did_something:
		return false
	return true

func _apply_self_effects(move: Dictionary, p) -> void:
	var s = move.get("self", null)
	if s == null or p.fainted:
		return
	if s.has("chance") and rng.next(100) >= int(s["chance"]):
		return
	move_hit(p, p, move, false, true, s)

func _apply_secondaries(target, p, move: Dictionary, sub_hit: bool) -> void:
	var secs: Array = []
	if move.has("secondary") and move["secondary"] != null:
		secs.append(move["secondary"])
	if move.has("secondaries"):
		secs.append_array(move["secondaries"])
	if secs.is_empty():
		return
	secs = run_event("ModifySecondaries", target, p, move, secs.duplicate(true))
	if typeof(secs) == TYPE_BOOL:
		return
	for sec in secs:
		var chance := int(sec.get("chance", 100))
		chance = run_event("ModifyChance", p, target, move, chance)
		if typeof(chance) == TYPE_BOOL:
			continue
		if rng.next(100) >= int(chance):
			continue
		if sec.has("self") and not p.fainted:
			move_hit(p, p, move, true, true, sec["self"])
		if sub_hit:
			continue
		if target.fainted:
			continue
		var sd := {}
		for k in ["boosts", "status", "volatile_status"]:
			if sec.has(k):
				sd[k] = sec[k]
		if not sd.is_empty():
			move_hit(target, p, move, true, false, sd)

func _apply_recoil(p, damage: int, move: Dictionary) -> void:
	if Battle.is_false(run_event("Recoil", p, null, move)):
		return
	var rc = move["recoil"]
	var amt := maxi(1, int(round(damage * float(rc[0]) / float(rc[1]))))
	damage_pokemon(p, amt, p, {"effect_type": "recoil", "id": "recoil"})

func _hit_substitute(target, p, move: Dictionary, damage: int):
	var sub: Dictionary = target.volatiles["substitute"]
	if damage <= 0:
		return 0
	if damage > int(sub["hp"]):
		damage = int(sub["hp"])
	sub["hp"] = int(sub["hp"]) - damage
	p.last_damage = damage
	if int(sub["hp"]) <= 0:
		add_log(["-end", pid(target), "substitute"])
		target.volatiles.erase("substitute")
	else:
		add_log(["-activate", pid(target), "substitute", "damage"])
	return damage

# ============================================================
# Damage calculation (Gen 5+ formula, Showdown rounding)
# ============================================================
## Returns int damage, 0 for no-damage moves, or false if the move fails.
func get_damage(p, target, move: Dictionary):
	if move.has("damage_callback"):
		var d = move_event("DamageCallback", move, target, p, null)
		if d == null:
			d = _generic_damage_callback(move["damage_callback"], p, target, move)
		return d
	if move["category"] == "status":
		return 0
	var base_power := int(move["power"])
	if move.has("base_power_callback"):
		var bp = move_event("BasePowerCallback", move, target, p, base_power)
		if bp == null:
			bp = _generic_base_power_callback(move["base_power_callback"], p, target, move)
		base_power = int(bp)
	if base_power <= 0:
		return 0
	base_power = maxi(1, base_power)
	# critical hit
	var crit := bool(move.get("will_crit", false))
	if debug_no_crit:
		crit = false
	elif not crit:
		var ratio := int(move.get("crit_ratio", 1))
		var r = run_event("ModifyCritRatio", p, target, move, ratio)
		ratio = clampi(int(r) if typeof(r) != TYPE_BOOL else ratio, 0, 4)
		if ratio > 0:
			crit = rng.next(CRIT_TABLE[ratio]) == 0
	if crit:
		var c = run_event("CriticalHit", target, null, move, true)
		crit = not (typeof(c) == TYPE_BOOL and c == false)
	move["crit"] = crit
	# base power modifications
	var bp2 = move_event("BasePower", move, target, p, base_power)
	if bp2 != null and typeof(bp2) != TYPE_BOOL:
		base_power = int(bp2)
	var bp3 = run_event("BasePower", p, target, move, base_power)
	if typeof(bp3) != TYPE_BOOL:
		base_power = int(bp3)
	var tinv: Dictionary = target.volatiles.get("two_turn_move", {})
	if not tinv.is_empty() and move.get("double_vs_invulnerable", []).has(str(tinv.get("invulnerable", ""))):
		base_power *= 2
	base_power = maxi(1, base_power)
	var level: int = p.level
	var attacker = p
	var defender = target
	if move.get("use_target_offense", false):
		attacker = target
	var is_physical: bool = move["category"] == "physical"
	var atk_stat: String = move.get("override_offensive_stat", "atk" if is_physical else "spa")
	var def_stat: String = move.get("override_defensive_stat", "def" if is_physical else "spd")
	var atk_boosts: int = attacker.boosts[atk_stat]
	var def_boosts: int = defender.boosts[def_stat]
	var ignore_off: bool = move.get("ignore_offensive", false) or (crit and atk_boosts < 0)
	var ignore_def: bool = move.get("ignore_defensive", false) or (crit and def_boosts > 0)
	if ignore_off:
		atk_boosts = 0
	if ignore_def:
		def_boosts = 0
	var attack: int = StatCalc.apply_boost(attacker.stored_stats[atk_stat], atk_boosts)
	var defense: int = StatCalc.apply_boost(defender.stored_stats[def_stat], def_boosts)
	var atk_event := "Modify" + ("Atk" if atk_stat == "atk" else ("SpA" if atk_stat == "spa" else ("Def" if atk_stat == "def" else "SpD")))
	var def_event := "Modify" + ("Def" if def_stat == "def" else ("SpD" if def_stat == "spd" else ("Atk" if def_stat == "atk" else "SpA")))
	var a2 = run_event(atk_event, attacker, defender, move, attack)
	if typeof(a2) != TYPE_BOOL:
		attack = maxi(1, int(a2))
	var d2 = run_event(def_event, defender, attacker, move, defense)
	if typeof(d2) != TYPE_BOOL:
		defense = maxi(1, int(d2))
	var base_damage: int = int(floor(int(floor(int(floor(2 * level / 5.0 + 2)) * base_power * attack / float(defense))) / 50.0))
	return _modify_damage(base_damage, p, target, move, crit)

func _modify_damage(base_damage: int, p, target, move: Dictionary, crit: bool) -> int:
	var type: String = move["type"]
	base_damage += 2
	if move.get("spread_hit", false):
		base_damage = modify(base_damage, 3, 4)
	# weather
	var wd = run_event("WeatherModifyDamage", p, target, move, base_damage)
	if typeof(wd) != TYPE_BOOL:
		base_damage = int(wd)
	if crit:
		base_damage = int(floor(base_damage * 1.5))
		stats["crits"] += 1
		add_log(["-crit", pid(target)])
	# random factor 85-100%
	var roll: int = (100 - rng.next(16)) if debug_fixed_roll < 0 else debug_fixed_roll
	base_damage = int(floor(base_damage * roll / 100.0))
	# STAB
	if type != "???" and (p.has_type(type) or move.get("force_stab", false)):
		var stab = run_event("ModifySTAB", p, target, move, 1.5)
		base_damage = modify(base_damage, stab)
	# type effectiveness
	var type_mod := run_effectiveness(target, move)
	move["type_mod"] = type_mod
	if type_mod > 0:
		for i in range(type_mod):
			base_damage *= 2
		add_log(["-supereffective", pid(target)])
	elif type_mod < 0:
		for i in range(-type_mod):
			base_damage = int(floor(base_damage / 2.0))
		add_log(["-resisted", pid(target)])
	# burn
	if p.status == "brn" and move["category"] == "physical" and not move.get("ignore_burn", false):
		if not Battle.is_false(run_event("BurnDamageReduction", p, target, move)):
			base_damage = modify(base_damage, 1, 2)
	# final modifiers (Life Orb, screens, Multiscale, resist berries, ...)
	var fd = run_event("ModifyDamage", p, target, move, base_damage)
	if typeof(fd) != TYPE_BOOL:
		base_damage = int(fd)
	if base_damage < 1:
		base_damage = 1
	return base_damage

## log2 type effectiveness total (-6..6) for move vs target's types.
func run_effectiveness(target, move: Dictionary) -> int:
	var total := 0
	for t in target.get_types():
		var m := GameData.type_mod(move["type"], t)
		var e := 0
		if m == 2.0: e = 1
		elif m == 0.5: e = -1
		var me = move_event("Effectiveness", move, target, null, {"type": t, "value": e})
		if typeof(me) == TYPE_DICTIONARY:
			e = int(me["value"])
		elif typeof(me) == TYPE_INT:
			e = me
		var re = run_event("Effectiveness", target, null, move, {"type": t, "value": e})
		if typeof(re) == TYPE_DICTIONARY:
			e = int(re["value"])
		total += e
	return clampi(total, -6, 6)

## Convenience: multiplier form for AI/UI (0, 0.25, 0.5, 1, 2, 4).
func effectiveness_multiplier(move_type: String, target) -> float:
	if not run_immunity(target, move_type, {"type": move_type, "ignore_grounding": false, "flags": []}):
		return 0.0
	var m := 1.0
	for t in target.get_types():
		m *= GameData.type_mod(move_type, t)
	return m

func _generic_damage_callback(kind, p, target, move: Dictionary):
	match str(kind):
		"level":
			return p.level
		"half_hp":
			return maxi(1, int(floor(target.hp / 2.0)))
		"endeavor":
			if target.hp <= p.hp:
				return false
			return target.hp - p.hp
		"final_gambit":
			return p.hp
		_:
			if str(kind).begins_with("fixed:"):
				return int(str(kind).substr(6))
	return 0

func _generic_base_power_callback(kind, p, target, move: Dictionary) -> int:
	var k := str(kind)
	match k:
		"weight":  # Low Kick / Grass Knot
			var w: float = target.weight_kg
			if w >= 200: return 120
			if w >= 100: return 100
			if w >= 50: return 80
			if w >= 25: return 60
			if w >= 10: return 40
			return 20
		"speed_ratio":  # Electro Ball
			var ratio := int(floor(p.get_stat("spe") / float(maxi(1, target.get_stat("spe")))))
			if ratio >= 4: return 150
			if ratio >= 3: return 120
			if ratio >= 2: return 80
			if ratio >= 1: return 60
			return 40
		"gyro_ball":
			var v := int(floor(25.0 * target.get_stat("spe") / float(maxi(1, p.get_stat("spe"))))) + 1
			return mini(150, maxi(1, v))
		"user_hp":  # Eruption / Water Spout
			return maxi(1, int(floor(150 * p.hp / float(p.max_hp))))
		"target_hp":  # Crush Grip / Wring Out
			return maxi(1, int(floor(120 * target.hp / float(target.max_hp))))
		"low_hp":  # Flail / Reversal
			var r := int(floor(48.0 * p.hp / float(p.max_hp)))
			if r <= 1: return 200
			if r <= 4: return 150
			if r <= 9: return 100
			if r <= 16: return 80
			if r <= 32: return 40
			return 20
		"stored_power":
			return 20 + 20 * p.positive_boosts()
		"punishment":
			return mini(200, 60 + 20 * target.positive_boosts())
		"heavy_slam":
			var r := int(floor(p.weight_kg / maxf(0.1, target.weight_kg)))
			if r >= 5: return 120
			if r >= 4: return 100
			if r >= 3: return 80
			if r >= 2: return 60
			return 40
		"acrobatics":
			return 110 if p.item == "" else 55
		"facade":
			return int(move["power"]) * (2 if p.status in ["brn", "par", "psn", "tox"] else 1)
		"hex":
			return int(move["power"]) * (2 if target.status != "" else 1)
		"brine":
			return int(move["power"]) * (2 if target.hp * 2 <= target.max_hp else 1)
		"venoshock":
			return int(move["power"]) * (2 if target.status in ["psn", "tox"] else 1)
		"knock_off":
			return int(move["power"]) * 3 / 2 if (target.item != "" and _can_lose_item(target)) else int(move["power"])
		"payback":
			return int(move["power"]) * (2 if target.move_this_turn != "" else 1)
		"avalanche":
			var la: Dictionary = p.last_attacked_by
			return int(move["power"]) * (2 if (not la.is_empty() and la.get("turn") == turn and la.get("source") == target) else 1)
		"retaliate":
			return int(move["power"])
	return int(move["power"])

func _can_lose_item(p) -> bool:
	return p.item != ""

# ============================================================
# Damage / heal / faint
# ============================================================
func damage_pokemon(target, amount: int, source = null, effect = null, ignore_events: bool = false) -> int:
	if target == null or target.fainted or target.hp <= 0:
		return 0
	if amount <= 0 and not (effect is Dictionary and effect.get("effect_type") == "move"):
		return 0
	amount = maxi(1, amount) if amount > 0 else 0
	if not ignore_events:
		var d = run_event("Damage", target, source, effect, amount)
		if typeof(d) == TYPE_BOOL:
			return 0
		amount = int(d)
	if amount <= 0:
		return 0
	var before: int = target.hp
	target.hp = maxi(0, target.hp - amount)
	var dealt: int = before - target.hp
	target.hurt_this_turn += dealt
	if effect is Dictionary and effect.get("effect_type") == "move":
		if source != null and source != target:
			var dd: Dictionary = stats["damage_by_species"]
			dd[source.species_id] = int(dd.get(source.species_id, 0)) + dealt
			if target.hp <= 0:
				var kd: Dictionary = stats["kos_by_species"]
				kd[source.species_id] = int(kd.get(source.species_id, 0)) + 1
	else:
		var eid := str(effect.get("id", "")) if effect is Dictionary else str(effect)
		add_log(["-damage", pid(target), target.hp, target.max_hp, eid])
	if target.hp <= 0:
		faint(target, source, effect)
	else:
		run_event("AfterDamage", target, source, effect, dealt)
	return dealt

func heal_pokemon(target, amount: int, source = null, effect = null) -> int:
	if target == null or target.fainted or target.hp <= 0:
		return 0
	if target.hp >= target.max_hp:
		return 0
	var h = run_event("TryHeal", target, source, effect, amount)
	if typeof(h) == TYPE_BOOL:
		return 0
	amount = int(h)
	var before: int = target.hp
	target.hp = mini(target.max_hp, target.hp + amount)
	var healed: int = target.hp - before
	var eid := str(effect.get("id", "")) if effect is Dictionary else str(effect)
	add_log(["-heal", pid(target), target.hp, target.max_hp, eid])
	return healed

func faint(p, source = null, effect = null) -> void:
	if p.faint_queued:
		return
	p.hp = 0
	p.faint_queued = true
	faint_queue.append({"pokemon": p, "source": source, "effect": effect})

func faint_messages() -> void:
	while not faint_queue.is_empty():
		var f: Dictionary = faint_queue.pop_front()
		var p = f["pokemon"]
		if p.fainted:
			continue
		add_log(["faint", pid(p)])
		run_event("BeforeFaint", p, f["source"], f["effect"])
		p.fainted = true
		p.faint_queued = false
		p.status = ""
		p.status_state = {}
		p.clear_volatiles()
		p.clear_boosts()
		p.side.total_fainted += 1
		single_event("End", "ability", p.ability, p.ability_state, p)
		run_event("Faint", p, f["source"], f["effect"])
		# remove queued actions of the fainted pokemon
		var nq: Array = []
		for a in queue:
			if a.get("pokemon") == p:
				continue
			nq.append(a)
		queue = nq
	_check_win()

func _check_win() -> void:
	if ended:
		return
	var alive: Array = []
	for i in range(sides.size()):
		alive.append(sides[i].alive_count() > 0)
	if alive[0] and alive[1]:
		return
	ended = true
	if alive[0]:
		winner = 0
	elif alive[1]:
		winner = 1
	else:
		winner = -1
	add_log(["win", winner])

# ============================================================
# Boosts
# ============================================================
func boost(target, boosts: Dictionary, source = null, effect = null, is_secondary: bool = false, is_self: bool = false) -> bool:
	if target == null or target.fainted or not target.active:
		return false
	var b: Dictionary = boosts.duplicate()
	var cb = run_event("ChangeBoost", target, source, effect, b)
	if typeof(cb) == TYPE_DICTIONARY:
		b = cb
	var tb = run_event("TryBoost", target, source, effect, b)
	if typeof(tb) == TYPE_BOOL:
		return false
	b = tb
	var success := false
	var eid := str(effect.get("id", "")) if effect is Dictionary else ""
	for stat in b:
		var amt := int(b[stat])
		if amt == 0:
			continue
		var cur: int = target.boosts[stat]
		var nv := clampi(cur + amt, -6, 6)
		var delta := nv - cur
		if delta == 0:
			add_log(["-boost-fail", pid(target), stat, "max" if amt > 0 else "min"])
			continue
		target.boosts[stat] = nv
		success = true
		if delta > 0:
			target.stats_raised_this_turn = true
			add_log(["-boost", pid(target), stat, delta, eid])
		else:
			target.stats_lowered_this_turn = true
			add_log(["-unboost", pid(target), stat, -delta, eid])
		run_event("AfterEachBoost", target, source, effect, delta)
	if success:
		run_event("AfterBoost", target, source, effect, b)
		run_event("Update", target)
	return success

# ============================================================
# Status
# ============================================================
func set_status(target, status_id: String, source = null, effect = null, ignore_immunities: bool = false, force: bool = false) -> bool:
	if target == null or target.fainted or not target.active:
		return false
	var is_move: bool = effect is Dictionary and effect.get("effect_type") == "move"
	if target.status != "" and not force:
		if is_move and not (effect.has("secondary") or effect.has("secondaries")):
			add_log(["-fail", pid(target), "already-status", target.status])
		return false
	if force and target.status != "":
		cure_status(target, source, effect, true)
	var sdef: Dictionary = registry.status_meta.get(status_id, {})
	if not ignore_immunities:
		var immune_types: Array = sdef.get("immune_types", [])
		var bypass := false
		if source != null and source != target and (status_id == "psn" or status_id == "tox"):
			if GameData.get_ability(source.ability).get("flags", {}).get("corrosion", false):
				bypass = true
		if not bypass:
			for t in target.get_types():
				if immune_types.has(t):
					if is_move:
						add_log(["-immune", pid(target), status_id])
					return false
	var ss = run_event("SetStatus", target, source, effect, status_id)
	if typeof(ss) == TYPE_BOOL and ss == false:
		return false
	target.status = status_id
	target.status_state = {"id": status_id, "source": source, "time": 0, "start_time": 0, "stage": 0}
	if effect is Dictionary and effect.get("sleep_turns", 0) > 0:
		target.status_state["fixed_turns"] = int(effect["sleep_turns"])
	single_event("Start", "status", status_id, target.status_state, target, source, effect)
	add_log(["-status", pid(target), status_id])
	run_event("AfterSetStatus", target, source, effect, status_id)
	run_event("Update", target)
	return true

func cure_status(target, source = null, effect = null, silent: bool = false) -> bool:
	if target == null or target.status == "":
		return false
	var old: String = target.status
	single_event("End", "status", old, target.status_state, target)
	target.status = ""
	target.status_state = {}
	if not silent:
		add_log(["-curestatus", pid(target), old])
	run_event("StatusCure", target, source, effect, old)
	return true

# ============================================================
# Volatiles
# ============================================================
func add_volatile(target, id: String, source = null, effect = null, extra: Dictionary = {}) -> bool:
	if target == null or target.fainted or not target.active:
		return false
	if target.volatiles.has(id):
		var rr = single_event("Restart", "volatile", id, target.volatiles[id], target, source, effect)
		return Battle.is_true(rr)
	var tv = run_event("TryAddVolatile", target, source, effect, id)
	if typeof(tv) == TYPE_BOOL and tv == false:
		return false
	var state := {"id": id, "source": source, "source_effect": str(effect.get("id", "")) if effect is Dictionary else "", "turn": turn}
	for k in extra:
		state[k] = extra[k]
	var meta: Dictionary = registry.volatile_meta.get(id, {})
	if meta.has("duration"):
		state["duration"] = int(meta["duration"])
	target.volatiles[id] = state
	var st = single_event("Start", "volatile", id, state, target, source, effect)
	if typeof(st) == TYPE_BOOL and st == false:
		target.volatiles.erase(id)
		return false
	return true

func remove_volatile(target, id: String) -> bool:
	if target == null or not target.volatiles.has(id):
		return false
	var state: Dictionary = target.volatiles[id]
	single_event("End", "volatile", id, state, target)
	target.volatiles.erase(id)
	return true

# ============================================================
# Side conditions / slot conditions
# ============================================================
func add_side_condition(side, id: String, source = null, effect = null) -> bool:
	if side.side_conditions.has(id):
		var rr = single_event("Restart", "side", id, side.side_conditions[id], side, source, effect)
		if Battle.is_true(rr):
			return true
		if effect is Dictionary and effect.get("effect_type") == "move":
			add_log(["-fail", pid(source)])
		return false
	var state := {"id": id, "source": source, "turn": turn}
	side.side_conditions[id] = state
	var st = single_event("Start", "side", id, state, side, source, effect)
	if typeof(st) == TYPE_BOOL and st == false:
		side.side_conditions.erase(id)
		if effect is Dictionary and effect.get("effect_type") == "move":
			add_log(["-fail", pid(source)])
		return false
	add_log(["-sidestart", "p%d" % (side.index + 1), id])
	return true

func remove_side_condition(side, id: String) -> bool:
	if not side.side_conditions.has(id):
		return false
	single_event("End", "side", id, side.side_conditions[id], side)
	side.side_conditions.erase(id)
	add_log(["-sideend", "p%d" % (side.index + 1), id])
	return true

func add_slot_condition(side, slot: int, id: String, source = null, effect = null, extra: Dictionary = {}) -> bool:
	if not side.slot_conditions.has(slot):
		side.slot_conditions[slot] = {}
	var d: Dictionary = side.slot_conditions[slot]
	if d.has(id):
		return false
	var state := {"id": id, "source": source, "turn": turn, "slot": slot}
	for k in extra:
		state[k] = extra[k]
	d[id] = state
	single_event("Start", "slot", id, state, side.active[slot], source, effect)
	return true

func remove_slot_condition(side, slot: int, id: String) -> bool:
	var d: Dictionary = side.slot_conditions.get(slot, {})
	if not d.has(id):
		return false
	d.erase(id)
	return true

# ============================================================
# Weather / terrain / field
# ============================================================
func set_weather(id: String, source = null, effect = null) -> bool:
	if weather == id:
		if effect is Dictionary and effect.get("effect_type") == "move":
			add_log(["-fail", pid(source)])
		return false
	var tw = run_event("TrySetWeather", source, source, effect, id)
	if typeof(tw) == TYPE_BOOL and tw == false:
		return false
	var wdef: Dictionary = GameData.weather.get(id, {})
	if wdef.is_empty():
		push_error("unknown weather " + id)
		return false
	if weather != "":
		single_event("End", "weather", weather, weather_state, null)
	weather = id
	weather_state = {"id": id, "source": source, "turn": turn}
	var dur := int(wdef.get("duration", 5))
	if source != null and source.item != "" and str(GameData.get_item(source.item).get("extends_weather", "")) == id:
		dur = int(wdef.get("extended_duration", 8))
	if effect is Dictionary and effect.get("effect_type") == "ability" and wdef.get("infinite_from_ability", false):
		dur = 0
	weather_state["duration"] = dur
	single_event("Start", "weather", id, weather_state, null, source, effect)
	add_log(["-weather", id, "[from] " + (str(effect.get("id", "")) if effect is Dictionary else "")])
	run_event("WeatherChange", null, source, effect, id)
	each_event("WeatherChange")
	return true

func clear_weather() -> void:
	if weather == "":
		return
	var old := weather
	single_event("End", "weather", weather, weather_state, null)
	weather = ""
	weather_state = {}
	add_log(["-weather", "none", old])
	each_event("WeatherChange")

func set_terrain(id: String, source = null, effect = null) -> bool:
	if terrain == id:
		if effect is Dictionary and effect.get("effect_type") == "move":
			add_log(["-fail", pid(source)])
		return false
	var tdef: Dictionary = GameData.terrain.get(id, {})
	if tdef.is_empty():
		push_error("unknown terrain " + id)
		return false
	if terrain != "":
		single_event("End", "terrain", terrain, terrain_state, null)
	terrain = id
	terrain_state = {"id": id, "source": source, "turn": turn}
	var dur := int(tdef.get("duration", 5))
	if source != null and source.item != "" and GameData.get_item(source.item).get("extends_terrain", false):
		dur = int(tdef.get("extended_duration", 8))
	terrain_state["duration"] = dur
	single_event("Start", "terrain", id, terrain_state, null, source, effect)
	add_log(["-fieldstart", id])
	each_event("TerrainChange")
	return true

func clear_terrain() -> void:
	if terrain == "":
		return
	var old := terrain
	single_event("End", "terrain", terrain, terrain_state, null)
	terrain = ""
	terrain_state = {}
	add_log(["-fieldend", old])
	each_event("TerrainChange")

func add_pseudo_weather(id: String, source = null, effect = null) -> bool:
	if pseudo_weather.has(id):
		var rr = single_event("Restart", "field", id, pseudo_weather[id], null, source, effect)
		if Battle.is_true(rr):
			return true
		return false
	var state := {"id": id, "source": source, "turn": turn}
	pseudo_weather[id] = state
	var st = single_event("Start", "field", id, state, null, source, effect)
	if typeof(st) == TYPE_BOOL and st == false:
		pseudo_weather.erase(id)
		return false
	add_log(["-fieldstart", id])
	return true

func remove_pseudo_weather(id: String) -> bool:
	if not pseudo_weather.has(id):
		return false
	single_event("End", "field", id, pseudo_weather[id], null)
	pseudo_weather.erase(id)
	add_log(["-fieldend", id])
	return true

# ============================================================
# Items
# ============================================================
## Consume (eat/use) the holder's item. Returns true if consumed.
func use_item(p, source = null, effect = null) -> bool:
	if p.item == "" or p.fainted:
		return false
	var item_id: String = p.item
	var idef := GameData.get_item(item_id)
	if idef.get("is_berry", false):
		add_log(["-enditem", pid(p), item_id, "[eat]"])
		p.ate_berry = true
	else:
		add_log(["-enditem", pid(p), item_id])
	stat_inc("item_activations", item_id)
	single_event("Use", "item", item_id, p.item_state, p, source, effect)
	p.last_item = item_id
	p.item = ""
	p.item_state = {}
	p.used_item_this_turn = true
	run_event("AfterUseItem", p, source, effect, item_id)
	return true

## Remove item without using (Knock Off, Trick). Returns the item id or "".
func take_item(p, source = null) -> String:
	if p.item == "":
		return ""
	var item_id: String = p.item
	var ti = run_event("TakeItem", p, source, null, item_id)
	if typeof(ti) == TYPE_BOOL and ti == false:
		return ""
	single_event("End", "item", item_id, p.item_state, p)
	p.last_item = item_id
	p.item = ""
	p.item_state = {}
	run_event("AfterTakeItem", p, source, null, item_id)
	return item_id

func set_item(p, item_id: String, source = null) -> bool:
	if p.fainted:
		return false
	p.item = item_id
	p.item_state = {}
	if item_id != "":
		single_event("Start", "item", item_id, p.item_state, p, source)
	return true

func can_eat_berry(p) -> bool:
	return GameData.get_item(p.item).get("is_berry", false) and not Battle.is_false(run_event("TryEatItem", p))

# ============================================================
# Residual (end of turn)
# ============================================================
func residual() -> void:
	var handlers: Array = []
	_collect_residual(handlers, _field_effects())
	for side in sides:
		var effs: Array = []
		for sc in side.side_conditions:
			var e := _effect_dict("side", sc, side.side_conditions[sc], null)
			e["side"] = side
			effs.append(e)
		for slot in side.slot_conditions:
			for sc in side.slot_conditions[slot]:
				var e := _effect_dict("slot", sc, side.slot_conditions[slot][sc], side.active[slot] if slot < side.active.size() else null)
				e["side"] = side
				e["slot"] = slot
				effs.append(e)
		_collect_residual(handlers, effs)
	update_speeds()
	for p in all_active():
		var effs: Array = []
		if p.ability != "":
			effs.append(_effect_dict("ability", p.ability, p.ability_state, p))
		if p.item != "":
			effs.append(_effect_dict("item", p.item, p.item_state, p))
		if p.status != "":
			effs.append(_effect_dict("status", p.status, p.status_state, p))
		for v in p.volatiles:
			effs.append(_effect_dict("volatile", v, p.volatiles[v], p))
		_collect_residual(handlers, effs)
	_sort_handlers(handlers)
	for h in handlers:
		if ended:
			return
		var e: Dictionary = h["effect"]
		var holder = e["holder"]
		if holder != null and (holder.fainted or not holder.active) and e["kind"] != "slot":
			continue
		if not _effect_still_active(e):
			continue
		var st: Dictionary = e["state"]
		if st.has("duration") and int(st["duration"]) > 0:
			st["duration"] = int(st["duration"]) - 1
			if int(st["duration"]) <= 0:
				_end_effect(e)
				faint_messages()
				continue
		if h["callable"] == null:
			continue
		var ev := {"target": holder, "source": null, "effect": null, "move": null, "value": null, "state": st, "effect_id": e["id"], "kind": e["kind"], "holder": holder, "side": e.get("side", null)}
		event_stack.append({"id": "Residual", "modifier": 4096})
		h["callable"].call(self, holder, ev)
		event_stack.pop_back()
		faint_messages()

func _collect_residual(handlers: Array, effects: Array) -> void:
	for e in effects:
		var h: Dictionary = registry.get_handlers(e["kind"], e["id"])
		var has_dur: bool = e["state"].has("duration") and int(e["state"]["duration"]) > 0
		if h.has("onResidual") or has_dur:
			handlers.append({
				"callable": h.get("onResidual", null), "effect": e, "key": "onResidual",
				"order": h.get("onResidualOrder", 1000000) if h.has("onResidual") else 1000000,
				"priority": -int(h.get("onResidualSubOrder", 0)),
				"speed": e["holder"].speed if e["holder"] != null else 0,
			})

func _end_effect(e: Dictionary) -> void:
	var holder = e["holder"]
	match e["kind"]:
		"volatile":
			remove_volatile(holder, e["id"])
		"side":
			remove_side_condition(e["side"], e["id"])
		"slot":
			var side = e["side"]
			var slot: int = int(e["slot"])
			var d: Dictionary = side.slot_conditions.get(slot, {})
			if d.has(e["id"]):
				var state: Dictionary = d[e["id"]]
				d.erase(e["id"])
				single_event("End", "slot", e["id"], state, side.active[slot] if slot < side.active.size() else null)
		"weather":
			clear_weather()
		"terrain":
			clear_terrain()
		"field":
			remove_pseudo_weather(e["id"])

# ============================================================
# Serialization (for save/load and tests)
# ============================================================
func snapshot() -> Dictionary:
	var s := []
	for side in sides:
		s.append(side.snapshot())
	return {"turn": turn, "weather": weather, "weather_state": {"duration": weather_state.get("duration", 0)}, "terrain": terrain, "terrain_state": {"duration": terrain_state.get("duration", 0)}, "pseudo_weather": pseudo_weather.keys(), "sides": s, "ended": ended, "winner": winner}

## Simple text rendering of the log (internal IDs).
func log_text() -> String:
	var lines: PackedStringArray = []
	for e in log:
		var parts: PackedStringArray = []
		for x in e:
			parts.append(str(x))
		lines.append("|".join(parts))
	return "\n".join(lines)
