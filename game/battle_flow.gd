class_name BattleFlow
extends RefCounted
## Builds RPG battles from GameState and applies results (exp, level-ups, evolution, capture, HP sync).

static func party_sets(state: GameState) -> Array:
	var out: Array = []
	for p in state.party:
		out.append(p)
	return out

static func make_wild_battle(state: GameState, species: String, level: int, rng: RandomNumberGenerator) -> Battle:
	var wild := PokemonSet.generate(species, level, rng)
	state.mark_seen(species)
	var b := Battle.new({"seed": rng.randi(), "teams": [party_sets(state), [wild]], "names": [state.player_name, "やせいの"], "wild": true, "bag": state.bag, "log": true})
	return b

static func load_trainer(trainer_id: String) -> Dictionary:
	return GameData._load_json("res://data/trainers/%s.json" % trainer_id)

static func make_trainer_battle(state: GameState, trainer_id: String, rng: RandomNumberGenerator) -> Battle:
	var t := load_trainer(trainer_id)
	var team: Array = []
	for m in t.get("team", []):
		var s := PokemonSet.generate(str(m["species"]), int(m["level"]), rng, str(m.get("item", "")))
		if m.has("moves"):
			s.moves = m["moves"]
		team.append(s)
		state.mark_seen(s.species)
	var b := Battle.new({"seed": rng.randi(), "teams": [party_sets(state), team], "names": [state.player_name, GameData.msg(str(t.get("name_key", trainer_id)))], "allow_items": true, "bag": state.bag, "log": true})
	return b

## Sync party HP/status back from the battle and compute exp/level/evolution/capture outcomes.
## Returns an Array of result dictionaries in display order:
##  {"type":"message","text":...} / {"type":"learn","index":i,"move":id} / {"type":"evolve","index":i,"into":id} / {"type":"caught","set":PokemonSet}
static func apply_results(state: GameState, battle: Battle, trainer_id: String = "") -> Array:
	var out: Array = []
	var side0 = battle.sides[0]
	for i in range(mini(state.party.size(), side0.team.size())):
		var bp = side0.team[i]
		var ps: PokemonSet = state.party[i]
		ps.current_hp = 0 if bp.fainted else bp.hp
		ps.status = bp.status if not bp.fainted else ""
	# exp for fainted foes
	var won: bool = battle.winner == 0 or battle.captured != null
	if battle.winner == 0 or battle.captured != null or battle.escaped:
		for foe in battle.sides[1].team:
			if not foe.fainted:
				continue
			var base_exp := int(GameData.get_species(foe.species_id).get("base_exp", 100))
			var parts: Array = foe.participants.keys()
			var alive_parts: Array = []
			for idx in parts:
				if int(idx) < state.party.size() and state.party[int(idx)].current_hp != 0:
					alive_parts.append(int(idx))
			for idx in alive_parts:
				var ps: PokemonSet = state.party[idx]
				var gain := Growth.exp_gain(base_exp, foe.level, ps.level, trainer_id != "", alive_parts.size())
				var before := ps.level
				var levels := Growth.add_exp(ps, gain)
				out.append({"type": "message", "text": "%sは %d の けいけんちを もらった！" % [GameData.name_of("species", ps.species), gain]})
				for lv in levels:
					out.append({"type": "message", "text": "%sは レベル %d に あがった！" % [GameData.name_of("species", ps.species), lv]})
					for mv in Growth.moves_at_level(ps.species, lv):
						if ps.moves.has(mv):
							continue
						if ps.moves.size() < 4:
							ps.moves.append(mv)
							out.append({"type": "message", "text": "%sは %s を おぼえた！" % [GameData.name_of("species", ps.species), GameData.name_of("moves", mv)]})
						else:
							out.append({"type": "learn", "index": idx, "move": mv})
				if not levels.is_empty():
					var into := Growth.evolution_by_level(ps.species, ps.level)
					if into != "":
						out.append({"type": "evolve", "index": idx, "into": into})
	if battle.captured != null:
		var cs: PokemonSet = battle.captured.set
		cs.current_hp = battle.captured.hp
		cs.status = battle.captured.status
		var where := state.add_monster(cs)
		out.append({"type": "message", "text": "やった！ %sを つかまえた！" % GameData.name_of("species", cs.species)})
		out.append({"type": "message", "text": "%sは %sに おくられた。" % [GameData.name_of("species", cs.species), "手持ちに くわわった" if where == "party" else "ボックス"]})
	if trainer_id != "" and won:
		var money := int(load_trainer(trainer_id).get("money", 0))
		if money > 0:
			state.money += money
			out.append({"type": "message", "text": "しょうきんとして %d円 手に入れた！" % money})
	return out

## Player lost every monster: lose half money, heal, return to town.
static func white_out(state: GameState) -> Array:
	var lost := int(state.money / 2)
	state.money -= lost
	state.heal_party()
	state.map_id = "town"
	state.pos = Vector2i(4, 4)
	state.dir = "down"
	return [{"type": "message", "text": GameData.msg("lost_battle") if GameData.localization.get("text", {}).has("lost_battle") else "目の前が 真っ暗に なった…"},
			{"type": "message", "text": "%sは %d円 おとしてしまった…" % [state.player_name, lost]}]

static func apply_learn(state: GameState, index: int, move: String, replace_slot: int) -> void:
	var ps: PokemonSet = state.party[index]
	if replace_slot >= 0 and replace_slot < ps.moves.size():
		ps.moves[replace_slot] = move

static func apply_evolve(state: GameState, index: int, into: String) -> void:
	Growth.evolve(state.party[index], into)
	state.mark_caught(into)

## Use a medicine item on a party member outside battle. Returns message or "" if unusable.
static func use_item_on_party(state: GameState, item_id: String, index: int) -> String:
	if not state.has_item(item_id) or index < 0 or index >= state.party.size():
		return ""
	var eff: Dictionary = GameData.get_item(item_id).get("effect", {})
	var ps: PokemonSet = state.party[index]
	var sp := GameData.get_species(ps.species)
	var max_hp := StatCalc.calc_hp(int(sp["base_stats"]["hp"]), int(ps.ivs["hp"]), int(ps.evs["hp"]), ps.level)
	var cur := max_hp if ps.current_hp < 0 else ps.current_hp
	var name := GameData.name_of("species", ps.species)
	if eff.has("heal_hp"):
		if cur <= 0 or cur >= max_hp:
			return ""
		var nh := mini(max_hp, cur + int(eff["heal_hp"]))
		ps.current_hp = -1 if nh >= max_hp else nh
		state.add_item(item_id, -1)
		return "%sの たいりょくが %d かいふくした！" % [name, nh - cur]
	if eff.has("cure_status"):
		if ps.status == "" or cur <= 0 or not (str(eff["cure_status"]) == "all" or str(eff["cure_status"]) == ps.status):
			return ""
		ps.status = ""
		state.add_item(item_id, -1)
		return "%sの じょうたいいじょうが なおった！" % name
	if eff.has("revive"):
		if cur > 0:
			return ""
		ps.current_hp = maxi(1, int(max_hp * float(eff["revive"])))
		state.add_item(item_id, -1)
		return "%sは げんきを とりもどした！" % name
	if eff.has("evolve"):
		var into := Growth.evolution_by_item(ps.species, item_id)
		if into == "":
			return ""
		state.add_item(item_id, -1)
		Growth.evolve(ps, into)
		state.mark_caught(into)
		return "おめでとう！ %sは %sに しんかした！" % [name, GameData.name_of("species", into)]
	return ""
