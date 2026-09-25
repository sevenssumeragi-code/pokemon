class_name BattleRunner
extends RefCounted
## Drives a Battle to completion with two AIs. Used by tests and the simulator.

static func run(battle: Battle, ai0: BattleAI, ai1: BattleAI, max_steps: int = 5000) -> Battle:
	var ais := [ai0, ai1]
	battle.start()
	var steps := 0
	while not battle.ended and steps < max_steps:
		steps += 1
		var progressed := false
		for i in range(2):
			var side = battle.sides[i]
			var req: Dictionary = side.request
			if req.is_empty() or req.get("type", "wait") == "wait" or not side.choice.is_empty():
				continue
			var choice: Array = ais[i].choose(battle, i, req)
			var err := battle.choose(i, choice)
			if err != "":
				push_warning("AI %d illegal choice (%s); using fallback" % [i, err])
				err = battle.choose(i, ais[i].fallback(req))
				if err != "":
					push_error("fallback also illegal: " + err)
					battle.ended = true
					battle.winner = -1
					return battle
			progressed = true
			if battle.ended:
				break
		if not progressed and not battle.ended:
			# no side can act: deadlock guard
			push_error("BattleRunner: no pending request but battle not ended (turn %d)" % battle.turn)
			battle.ended = true
			battle.winner = -1
	return battle

static func make_set(species: String, moves: Array, item: String = "", nature: String = "hardy", evs: Dictionary = {}, ability: String = "", level: int = 50) -> PokemonSet:
	var d := {"species": species, "moves": moves, "item": item, "nature": nature, "evs": evs, "level": level}
	if ability != "":
		d["ability"] = ability
	return PokemonSet.from_dict(d)
