class_name EventRunner
extends RefCounted
## Interprets data/events/*.json command lists against a GameState.
## UI-facing commands are yielded as requests: call next() to get {"type": ...}; resolve with resume(value).
## Pure logic: no scene dependencies, so it is unit-testable headless.

var state: GameState
var _stack: Array = []  # [{"cmds": Array, "i": int}]
var _pending: Dictionary = {}
var finished: bool = true
var last_battle_won: bool = false

func _init(p_state: GameState) -> void:
	state = p_state

static func load_event(event_id: String) -> Array:
	var d := GameData._load_json("res://data/events/%s.json" % event_id)
	return d.get("commands", [])

func start(event_id: String) -> void:
	start_commands(load_event(event_id))

func start_commands(cmds: Array) -> void:
	_stack = [{"cmds": cmds, "i": 0}]
	finished = false
	_pending = {}

func _text(key: String) -> String:
	var t: String = str(GameData.localization.get("text", {}).get(key, key))
	return t.replace("{player}", state.player_name)

## Advance until a UI request is produced or the event ends. Returns the request ({"type":"done"} when finished).
func next() -> Dictionary:
	if not _pending.is_empty():
		return _pending
	while not _stack.is_empty():
		var frame: Dictionary = _stack[_stack.size() - 1]
		if int(frame["i"]) >= frame["cmds"].size():
			_stack.pop_back()
			continue
		var c: Dictionary = frame["cmds"][int(frame["i"])]
		frame["i"] = int(frame["i"]) + 1
		var req := _exec(c)
		if not req.is_empty():
			_pending = req
			return req
	finished = true
	return {"type": "done"}

## Provide the UI's answer to the pending request (choice index, battle result, etc.).
func resume(value = null) -> void:
	var req := _pending
	_pending = {}
	match str(req.get("type", "")):
		"choice":
			var idx := int(value)
			var results: Array = req.get("_results", [])
			if idx >= 0 and idx < results.size():
				_stack.append({"cmds": results[idx], "i": 0})
		"trainer_battle":
			last_battle_won = bool(value)
			var branch: Array = req.get("_win", []) if last_battle_won else req.get("_lose", [])
			if not branch.is_empty():
				_stack.append({"cmds": branch, "i": 0})
		"starter_choice":
			var idx := int(value)
			var options: Array = req["options"]
			if idx >= 0 and idx < options.size():
				var rng := RandomNumberGenerator.new()
				rng.seed = state.rng_seed + 1
				var s := PokemonSet.generate(str(options[idx]["species"]), int(options[idx].get("level", 5)), rng)
				state.add_monster(s)
				state.set_flag("starter", str(options[idx]["species"]))

func _exec(c: Dictionary) -> Dictionary:
	match str(c.get("cmd", "")):
		"message":
			return {"type": "message", "text": _text(str(c["text"]))}
		"choice":
			var opts: Array = []
			for o in c.get("options", []):
				opts.append(_text(str(o)))
			return {"type": "choice", "text": _text(str(c.get("text", ""))), "options": opts, "_results": c.get("results", [])}
		"if":
			var v = state.flag(str(c["flag"]), false)
			var ok: bool = (v == c.get("equals", true))
			var branch: Array = c.get("then", []) if ok else c.get("else", [])
			if not branch.is_empty():
				_stack.append({"cmds": branch, "i": 0})
		"set_flag":
			state.set_flag(str(c["flag"]), c.get("value", true))
		"give_item":
			state.add_item(str(c["item"]), int(c.get("count", 1)))
			return {"type": "message", "text": _text("got_item").replace("{item}", GameData.name_of("items", str(c["item"]))).replace("{n}", str(int(c.get("count", 1))))}
		"take_item":
			state.add_item(str(c["item"]), -int(c.get("count", 1)))
		"give_money":
			state.money += int(c["amount"])
			return {"type": "message", "text": _text("got_money").replace("{n}", str(int(c["amount"])))}
		"give_monster":
			var rng := RandomNumberGenerator.new()
			rng.seed = state.rng_seed + state.party.size() + 7
			var s := PokemonSet.generate(str(c["species"]), int(c.get("level", 5)), rng)
			var where := state.add_monster(s)
			return {"type": "message", "text": _text("got_monster").replace("{name}", GameData.name_of("species", s.species)).replace("{where}", _text("where_" + where))}
		"heal_party":
			state.heal_party()
			return {"type": "heal", "text": _text(str(c.get("text", "healed")))}
		"warp":
			return {"type": "warp", "map": str(c["map"]), "x": int(c["x"]), "y": int(c["y"]), "dir": str(c.get("dir", "down"))}
		"trainer_battle":
			var tid := str(c["trainer"])
			if c.has("once_flag") and bool(state.flag(str(c["once_flag"]), false)):
				return {}
			return {"type": "trainer_battle", "trainer": tid, "_win": c.get("win", []), "_lose": c.get("lose", [])}
		"shop":
			return {"type": "shop", "items": c.get("items", [])}
		"starter_choice":
			return {"type": "starter_choice", "text": _text(str(c.get("text", "starter_prompt"))), "options": c.get("options", [])}
		"end_game":
			state.set_flag("game_cleared", true)
			return {"type": "end_game", "text": _text(str(c.get("text", "ending")))}
		"badge":
			state.badges += 1
		"wait":
			return {"type": "wait", "seconds": float(c.get("seconds", 0.5))}
	return {}
