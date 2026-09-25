extends SceneTree
## Headless balance simulator.
## godot --headless --path . -s tools/simulator/simulate.gd -- mode=3v3 battles=1000 seed=1 ai=heuristic out=reports/raw/x.json
## modes: 1v1 (all species pairs x sets), 3v3 / 6v6 (random teams from recommended sets)

var args := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	GameData.ensure_loaded()
	var mode: String = args.get("mode", "3v3")
	var battles := int(args.get("battles", "200"))
	var seed := int(args.get("seed", "1"))
	var ai_kind: String = args.get("ai", "heuristic")
	var out: String = args.get("out", "reports/raw/sim_%s_%d.json" % [mode, seed])
	var t0 := Time.get_ticks_msec()
	var result: Dictionary
	if mode == "1v1":
		result = run_1v1(battles, seed, ai_kind)
	else:
		result = run_team(mode, battles, seed, ai_kind)
	result["elapsed_ms"] = Time.get_ticks_msec() - t0
	result["mode"] = mode
	result["seed"] = seed
	result["ai"] = ai_kind
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out.get_base_dir()))
	var f := FileAccess.open("res://" + out, FileAccess.WRITE)
	f.store_string(JSON.stringify(result))
	f.close()
	print("wrote %s (%d ms)" % [out, result["elapsed_ms"]])
	EffectRegistry.reset()
	quit(0)

func make_ai(kind: String, seed: int) -> BattleAI:
	if kind == "random":
		return RandomAI.new(seed)
	return HeuristicAI.new(seed)

func set_to_pokemon(species: String, sdef: Dictionary) -> PokemonSet:
	return PokemonSet.from_dict({"species": species, "moves": sdef["moves"], "item": sdef["item"], "nature": sdef["nature"], "evs": sdef["evs"], "ability": sdef["ability"], "level": 50})

func sets_data() -> Dictionary:
	return GameData._load_json("res://data/sets/sets.json")

# ------------------------------------------------------------
func run_1v1(battles_per_pair: int, seed: int, ai_kind: String) -> Dictionary:
	var sets := sets_data()
	var ids: Array = sets.keys()
	ids.sort()
	var matchups := {}
	var species := {}
	var rng := BattleRNG.new(seed)
	var n := 0
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			for sa in sets[a]:
				for sb in sets[b]:
					var key := "%s/%s vs %s/%s" % [a, sa["name"], b, sb["name"]]
					var wins_a := 0
					var wins_b := 0
					var ties := 0
					var turns := 0
					for k in range(battles_per_pair):
						var bt := Battle.new({"seed": rng.next(1 << 30), "teams": [[set_to_pokemon(a, sa)], [set_to_pokemon(b, sb)]], "log": false, "max_turns": 200})
						BattleRunner.run(bt, make_ai(ai_kind, rng.next(1 << 30)), make_ai(ai_kind, rng.next(1 << 30)))
						turns += bt.turn
						if bt.winner == 0: wins_a += 1
						elif bt.winner == 1: wins_b += 1
						else: ties += 1
						n += 1
					matchups[key] = {"a": a, "set_a": sa["name"], "b": b, "set_b": sb["name"], "wins_a": wins_a, "wins_b": wins_b, "ties": ties, "avg_turns": float(turns) / battles_per_pair}
					_acc(species, a, "games", battles_per_pair); _acc(species, a, "wins", wins_a)
					_acc(species, b, "games", battles_per_pair); _acc(species, b, "wins", wins_b)
	return {"battles": n, "matchups": matchups, "species": species}

func _acc(d: Dictionary, key: String, field: String, v) -> void:
	if not d.has(key):
		d[key] = {}
	d[key][field] = d[key].get(field, 0) + v

# ------------------------------------------------------------
func run_team(mode: String, battles: int, seed: int, ai_kind: String) -> Dictionary:
	var team_size := 6 if mode == "6v6" else 3
	var sets := sets_data()
	var ids: Array = sets.keys()
	ids.sort()
	var rng := BattleRNG.new(seed)
	var species := {}
	var set_stats := {}
	var abilities := {}
	var items := {}
	var turns_hist := {}
	var ties := 0
	var total_turns := 0
	var pair_stats := {}  # species vs species when both present (team win)
	var stalls := {}
	for k in range(battles):
		if k > 0 and k % 250 == 0:
			printerr("progress %d/%d" % [k, battles])
		var pool: Array = ids.duplicate()
		rng.shuffle(pool)
		var teams: Array = [[], []]
		var used_species: Array = [[], []]
		var set_names: Array = [[], []]
		for side in range(2):
			for i in range(team_size):
				var sp: String = pool[side * team_size + i]
				var sdef: Dictionary = rng.sample(sets[sp])
				teams[side].append(set_to_pokemon(sp, sdef))
				used_species[side].append(sp)
				set_names[side].append("%s/%s" % [sp, sdef["name"]])
		var bt := Battle.new({"seed": rng.next(1 << 30), "teams": teams, "log": false, "max_turns": 300})
		BattleRunner.run(bt, make_ai(ai_kind, rng.next(1 << 30)), make_ai(ai_kind, rng.next(1 << 30)))
		total_turns += bt.turn
		turns_hist[str(mini(bt.turn, 60))] = int(turns_hist.get(str(mini(bt.turn, 60)), 0)) + 1
		if bt.winner < 0:
			ties += 1
		if bt.turn >= 60:
			var key := ""
			var names: Array = set_names[0].duplicate()
			names.append_array(set_names[1])
			names.sort()
			key = " + ".join(PackedStringArray(names))
			stalls[key] = int(stalls.get(key, 0)) + 1
		for side in range(2):
			var won := 1 if bt.winner == side else 0
			for i in range(team_size):
				var sp: String = used_species[side][i]
				_acc(species, sp, "games", 1)
				_acc(species, sp, "wins", won)
				_acc(species, sp, "damage", int(bt.stats["damage_by_species"].get(sp, 0)))
				_acc(species, sp, "kos", int(bt.stats["kos_by_species"].get(sp, 0)))
				_acc(species, sp, "first_move", int(bt.stats["first_move"].get(sp, 0)))
				_acc(species, sp, "turns_present", int(bt.stats["turns_present"].get(sp, 0)))
				var fainted := 0
				for p in bt.sides[side].team:
					if p.species_id == sp and p.fainted:
						fainted = 1
				_acc(species, sp, "fainted", fainted)
				_acc(species, sp, "turns", bt.turn)
				if bt.turn >= 60:
					_acc(species, sp, "long_games", 1)
				_acc(set_stats, set_names[side][i], "games", 1)
				_acc(set_stats, set_names[side][i], "wins", won)
				for osp in used_species[1 - side]:
					var pk: String = sp + ">" + osp
					_acc(pair_stats, pk, "games", 1)
					_acc(pair_stats, pk, "wins", won)
		for ab in bt.stats["ability_activations"]:
			abilities[ab] = int(abilities.get(ab, 0)) + int(bt.stats["ability_activations"][ab])
		for it in bt.stats["item_activations"]:
			items[it] = int(items.get(it, 0)) + int(bt.stats["item_activations"][it])
	return {"battles": battles, "team_size": team_size, "species": species, "sets": set_stats, "abilities": abilities, "items": items, "turns_hist": turns_hist, "ties": ties, "avg_turns": float(total_turns) / maxf(1, battles), "pairs": pair_stats, "stalls": stalls}
