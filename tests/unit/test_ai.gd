extends TestCase

func before_each() -> void:
	GameData.ensure_loaded()

func test_heuristic_ai_finishes_battles_legally() -> void:
	var sets := GameData._load_json("res://data/sets/sets.json")
	var ids: Array = sets.keys()
	ids.sort()
	var rng := BattleRNG.new(99)
	var finished := 0
	var turns := 0
	for k in range(12):
		rng.shuffle(ids)
		var teams := [[], []]
		for side in range(2):
			for i in range(3):
				var sp: String = ids[side * 3 + i]
				var sd: Dictionary = rng.sample(sets[sp])
				teams[side].append(PokemonSet.from_dict({"species": sp, "moves": sd["moves"], "item": sd["item"], "nature": sd["nature"], "evs": sd["evs"], "ability": sd["ability"]}))
		var b := Battle.new({"seed": k + 1, "teams": teams, "log": false, "max_turns": 300})
		BattleRunner.run(b, HeuristicAI.new(k), HeuristicAI.new(k + 100))
		if b.ended and b.winner >= 0:
			finished += 1
		turns += b.turn
	assert_eq(finished, 12, "all battles reach a winner")
	assert_true(turns / 12.0 < 80, "avg turns %.1f" % (turns / 12.0))

func test_heuristic_prefers_super_effective_ko() -> void:
	var b := BT.make([BT.s("gel", ["ice_beam", "water_gun", "haze", "protect"], "", "timid", {"spa": 252, "spe": 252})], [BT.s("muni_r_dragon", ["tackle"])])
	var ai := HeuristicAI.new(1)
	ai.temperature = 0.0
	var ch := ai.choose(b, 0, b.sides[0].request)
	assert_eq(ch[0]["move"], "ice_beam")

func test_heuristic_heals_when_low() -> void:
	var b := BT.make([BT.s("marutan", ["roost", "air_slash", "toxic", "defog"], "leftovers", "bold", {"hp": 252, "def": 252})], [BT.s("muni", ["tackle"])])
	BT.p1(b).hp = int(BT.p1(b).max_hp * 0.3)
	var ai := HeuristicAI.new(1)
	ai.temperature = 0.0
	var ch := ai.choose(b, 0, b.sides[0].request)
	assert_eq(ch[0]["move"], "roost")

func test_known_moves_only_mode_runs() -> void:
	var b := BT.make([BT.s("renny", ["waterfall", "crunch", "rest", "sleep_talk"], "leftovers")], [BT.s("gel", ["blizzard", "freeze_dry", "aurora_veil", "protect"], "light_clay")])
	var ai := HeuristicAI.new(1)
	ai.known_moves_only = true
	var ch := ai.choose(b, 0, b.sides[0].request)
	assert_eq(ch.size(), 1)
	BT.turn(b, "move:waterfall", "move:blizzard")
	assert_true(BT.p2(b).revealed_moves.has("blizzard"))
	assert_false(BT.p2(b).revealed_moves.has("freeze_dry"))
