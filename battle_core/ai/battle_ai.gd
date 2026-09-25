class_name BattleAI
extends RefCounted
## Base class for decision makers. Subclasses override choose().

var rng: BattleRNG

func _init(seed: int = 0) -> void:
	rng = BattleRNG.new(seed)

## Return a choice (Array of entries) for the given request.
func choose(_battle, _side_index: int, request: Dictionary) -> Array:
	return fallback(request)

## Legal-but-dumb choice used as a safety net.
func fallback(request: Dictionary) -> Array:
	var out: Array = []
	if request.get("type") == "switch":
		var used := {}
		for slot in request["slots"]:
			for b in request["bench"]:
				if not b["active"] and not b["fainted"] and not used.has(b["index"]):
					used[b["index"]] = true
					out.append({"type": "switch", "index": b["index"]})
					break
		return out
	for a in request.get("active", []):
		for m in a["moves"]:
			if not m["disabled"]:
				out.append({"type": "move", "move": m["id"]})
				break
	return out
