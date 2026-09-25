class_name RandomAI
extends BattleAI
## Picks uniformly among legal moves; switches with a small probability.

var switch_chance: float = 0.1

func choose(_battle, _side_index: int, request: Dictionary) -> Array:
	var out: Array = []
	if request.get("type") == "switch":
		var bench: Array = []
		for b in request["bench"]:
			if not b["active"] and not b["fainted"]:
				bench.append(b["index"])
		rng.shuffle(bench)
		for i in range(request["slots"].size()):
			if i < bench.size():
				out.append({"type": "switch", "index": bench[i]})
		return out
	var used_bench := {}
	for a in request.get("active", []):
		var bench: Array = []
		for b in request["bench"]:
			if not b["active"] and not b["fainted"] and not used_bench.has(b["index"]):
				bench.append(b["index"])
		if not a["trapped"] and not bench.is_empty() and rng.random_float() < switch_chance:
			var idx = rng.sample(bench)
			used_bench[idx] = true
			out.append({"type": "switch", "index": idx})
			continue
		var legal: Array = []
		for m in a["moves"]:
			if not m["disabled"]:
				legal.append(m["id"])
		if legal.is_empty():
			legal = ["struggle"]
		out.append({"type": "move", "move": rng.sample(legal)})
	return out
