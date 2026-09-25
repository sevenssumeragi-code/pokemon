extends TestCase
## Growth/exp, save-load equality, wild battle: run, items, capture.

func before_each() -> void:
	GameData.ensure_loaded()

func test_exp_curves_and_gain() -> void:
	assert_eq(Growth.exp_for_level("medium_fast", 10), 1000)
	assert_eq(Growth.exp_for_level("medium_slow", 100), 1059860)
	assert_eq(Growth.exp_for_level("fast", 100), 800000)
	assert_eq(Growth.exp_for_level("slow", 100), 1250000)
	assert_eq(Growth.level_for_exp("medium_fast", 999), 9)
	assert_eq(Growth.level_for_exp("medium_fast", 1000), 10)
	# Gen 5 formula sanity: base 64 lv5 vs receiver lv5 wild, 1 participant -> floor(64*5/5 * ((20)/(20))^2.5)+1 = 65
	assert_eq(Growth.exp_gain(64, 5, 5, false), 65)
	assert_eq(Growth.exp_gain(64, 5, 5, true), 97)

func test_level_up_learn_and_evolve() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var s := PokemonSet.generate("neo", 33, rng)
	var gained := Growth.add_exp(s, Growth.exp_for_level("medium_fast", 34) - Growth.exp_for_level("medium_fast", 33))
	assert_eq(gained, [34])
	assert_eq(Growth.evolution_by_level("neo", 34), "trans")
	assert_eq(Growth.evolution_by_level("neo", 33), "")
	assert_eq(Growth.evolution_by_item("neo", "mind_stone"), "trans_r")
	Growth.evolve(s, "trans")
	assert_eq(s.species, "trans")
	assert_true(s.validate().is_empty(), str(s.validate()))

func test_generate_is_legal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for sp in GameData.species:
		for lv in [5, 20, 50]:
			var s := PokemonSet.generate(sp, lv, rng)
			assert_true(s.validate().is_empty(), "%s lv%d: %s" % [sp, lv, str(s.validate())])

func test_save_load_roundtrip_identical() -> void:
	var g := GameState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	g.party = [PokemonSet.generate("renny", 12, rng), PokemonSet.generate("muni", 9, rng)]
	g.party[0].current_hp = 17
	g.party[1].status = "psn"
	g.box = [PokemonSet.generate("gel", 7, rng)]
	g.bag = {"potion": 3, "monster_ball": 5}
	g.money = 1234
	g.flags = {"met_prof": true, "boss_defeated": false, "counter": 3}
	g.map_id = "field"
	g.pos = Vector2i(7, 12)
	g.dir = "left"
	g.mark_seen("hyu")
	g.mark_caught("renny")
	g.play_seconds = 321.5
	assert_true(g.save(9))
	var l := GameState.load_slot(9)
	assert_not_null(l)
	assert_true(g.equals(l), "save/load must be identical")
	assert_eq(l.party[0].current_hp, 17)
	assert_eq(l.party[1].status, "psn")
	assert_eq(l.pos, Vector2i(7, 12))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path(9)))

func _wild(seed: int, bag: Dictionary) -> Battle:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mine := PokemonSet.generate("renny", 20, rng)
	var wild := PokemonSet.generate("muni", 5, rng)
	var b := Battle.new({"seed": seed, "teams": [[mine], [wild]], "wild": true, "bag": bag, "log": true, "fixed_roll": 100, "no_crit": true})
	b.start()
	return b

func test_run_from_wild() -> void:
	var b := _wild(1, {})
	var err := b.choose(0, [{"type": "run"}])
	assert_eq(err, "")
	# wild side auto-chooses via AI in real play; here submit a move
	b.choose(1, [{"type": "move", "move": b.sides[1].request["active"][0]["moves"][0]["id"]}])
	assert_true(b.escaped, "faster renny always escapes")
	assert_true(b.ended)

func test_capture_and_ball_consumed() -> void:
	var caught := 0
	for i in range(20):
		var bag := {"monster_ball": 1}
		var b := _wild(100 + i, bag)
		# weaken the wild first
		b.sides[1].active[0].hp = 1
		var err := b.choose(0, [{"type": "item", "item": "monster_ball"}])
		assert_eq(err, "")
		b.choose(1, [{"type": "move", "move": b.sides[1].request["active"][0]["moves"][0]["id"]}])
		assert_false(bag.has("monster_ball"), "ball consumed")
		if b.captured != null:
			caught += 1
			assert_true(b.ended and b.winner == 0)
	assert_true(caught >= 14, "muni (rate 190) at 1 HP should be caught most of the time: %d/20" % caught)

func test_medicine_in_battle_and_ball_refused_vs_trainer() -> void:
	var bag := {"potion": 2, "monster_ball": 1}
	var b := _wild(7, bag)
	var me: BattlePokemon = b.sides[0].active[0]
	me.hp = 10
	assert_eq(b.choose(0, [{"type": "item", "item": "potion", "target": 0}]), "")
	b.choose(1, [{"type": "move", "move": b.sides[1].request["active"][0]["moves"][0]["id"]}])
	assert_eq(int(bag.get("potion", 0)), 1)
	assert_true(me.hp >= 30 - 5 or me.hp == me.max_hp, "healed 20 (minus wild damage)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var t := Battle.new({"seed": 2, "teams": [[PokemonSet.generate("renny", 20, rng)], [PokemonSet.generate("muni", 5, rng)]], "allow_items": true, "bag": bag})
	t.start()
	assert_ne(t.choose(0, [{"type": "item", "item": "monster_ball"}]), "", "no balls vs trainers")
	assert_ne(t.choose(0, [{"type": "run"}]), "", "no running from trainers")

func test_participants_tracked_for_exp() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var b := Battle.new({"seed": 4, "teams": [[PokemonSet.generate("renny", 20, rng), PokemonSet.generate("gel", 20, rng)], [PokemonSet.generate("muni", 5, rng)]], "wild": true})
	b.start()
	b.choose(0, [{"type": "switch", "index": 1}])
	b.choose(1, [{"type": "move", "move": b.sides[1].request["active"][0]["moves"][0]["id"]}])
	var foe = b.sides[1].team[0]
	assert_true(foe.participants.has(0) and foe.participants.has(1))
