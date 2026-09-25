extends SceneTree
## Print one battle log between two species using recommended sets.
## godot --headless --path . -s tools/simulator/replay.gd -- a=renny sa=rest_talk b=gel sb=specs seed=3 [team=1]

func _init() -> void:
	var args := {}
	for x in OS.get_cmdline_user_args():
		var kv := x.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	GameData.ensure_loaded()
	var sets := GameData._load_json("res://data/sets/sets.json")
	var a: String = args.get("a", "renny")
	var b: String = args.get("b", "gel")
	var sa := _find(sets[a], args.get("sa", ""))
	var sb := _find(sets[b], args.get("sb", ""))
	var teams := [[_mk(a, sa)], [_mk(b, sb)]]
	if args.has("a2"):
		teams[0].append(_mk(args["a2"], _find(sets[args["a2"]], args.get("sa2", ""))))
	if args.has("b2"):
		teams[1].append(_mk(args["b2"], _find(sets[args["b2"]], args.get("sb2", ""))))
	var bt := Battle.new({"seed": int(args.get("seed", "1")), "teams": teams, "log": true, "max_turns": 200})
	BattleRunner.run(bt, HeuristicAI.new(1), HeuristicAI.new(2))
	print(bt.log_text())
	print("winner=", bt.winner, " turns=", bt.turn)
	EffectRegistry.reset()
	quit(0)

func _find(list: Array, name: String) -> Dictionary:
	for s in list:
		if s["name"] == name:
			return s
	return list[0]

func _mk(sp: String, sd: Dictionary) -> PokemonSet:
	return PokemonSet.from_dict({"species": sp, "moves": sd["moves"], "item": sd["item"], "nature": sd["nature"], "evs": sd["evs"], "ability": sd["ability"]})
