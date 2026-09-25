extends TestCase
## Double battles: two active slots, spread damage, ally-affecting abilities, targeting, replacements.

func before_each() -> void:
	GameData.ensure_loaded()

func _make(t1: Array, t2: Array, cfg: Dictionary = {}) -> Battle:
	var c := {"seed": 1, "teams": [t1, t2], "format": "doubles", "log": true, "fixed_roll": 100, "no_crit": true}
	for k in cfg:
		c[k] = cfg[k]
	var b := Battle.new(c)
	b.start()
	return b

func test_two_actives_each_side_and_requests() -> void:
	var b := _make([BT.s("renny", ["tackle"]), BT.s("gel", ["tackle"]), BT.s("muni", ["tackle"])], [BT.s("hyu", ["tackle"]), BT.s("trans", ["tackle"])])
	assert_eq(b.sides[0].active_pokemon().size(), 2)
	assert_eq(b.sides[1].active_pokemon().size(), 2)
	assert_eq(b.sides[0].request["active"].size(), 2)

func test_spread_move_hits_both_foes_at_075() -> void:
	var b := _make([BT.s("gel", ["blizzard", "ice_beam"]), BT.s("muni", ["protect"])], [BT.s("marutan", ["peck"], "", "hardy", {"hp": 252}), BT.s("hyu_r", ["protect"], "", "hardy", {"hp": 252})])
	var g := BT.p1(b)
	var m = b.sides[1].active[0]
	var h = b.sides[1].active[1]
	var mv: Dictionary = GameData.get_move("blizzard").duplicate(true)
	mv["effect_type"] = "move"
	var single := int(b.get_damage(g, m, mv))
	mv["spread_hit"] = true
	var spread := int(b.get_damage(g, m, mv))
	assert_true(spread < single, "spread reduced")
	var err := b.choose(0, [{"type": "move", "move": "blizzard"}, {"type": "move", "move": "protect"}])
	assert_eq(err, "")
	b.choose(1, [{"type": "move", "move": "peck", "target": 1}, {"type": "move", "move": "protect"}])
	assert_true(m.hp < m.max_hp, "marutan hit")
	# hyu_r protected: check log has protect activation
	assert_true(BT.has_log(b, "-activate", "protect"))

func test_flame_domain_boosts_ally_fire_move() -> void:
	var b := _make([BT.s("jinpachi", ["protect"]), BT.s("gel_r_dark", ["flamethrower"])], [BT.s("hyu_r", ["protect"]), BT.s("muni", ["protect"])])
	var ally = b.sides[0].active[1]
	var foe = b.sides[1].active[0]
	var mv: Dictionary = GameData.get_move("flamethrower").duplicate(true)
	mv["effect_type"] = "move"
	var with_ally := int(b.get_damage(ally, foe, mv))
	b.sides[0].active[0].ability = "levitate"
	var without := int(b.get_damage(ally, foe, mv))
	assert_true(absf(float(with_ally) / float(without) - 1.5) < 0.05, "%d vs %d" % [with_ally, without])

func test_dark_domain_boosts_ally_ghost_move() -> void:
	var b := _make([BT.s("hyu", ["protect"]), BT.s("gel", ["shadow_ball"])], [BT.s("trans_r", ["protect"]), BT.s("muni", ["protect"])])
	var ally = b.sides[0].active[1]
	var foe = b.sides[1].active[0]
	var mv: Dictionary = GameData.get_move("shadow_ball").duplicate(true)
	mv["effect_type"] = "move"
	var with_ally := int(b.get_damage(ally, foe, mv))
	b.sides[0].active[0].ability = "levitate"
	var without := int(b.get_damage(ally, foe, mv))
	assert_true(absf(float(with_ally) / float(without) - 1.5) < 0.05)

func test_intimidate_hits_both_foes() -> void:
	var b := _make([BT.s("gel_r_poison", ["protect"]), BT.s("muni", ["protect"])], [BT.s("renny", ["protect"]), BT.s("trans", ["protect"])])
	assert_eq(b.sides[1].active[0].boosts["atk"], -1)
	assert_eq(b.sides[1].active[1].boosts["atk"], -1)

func test_targeted_move_and_retarget_on_faint() -> void:
	var b := _make([BT.s("trans", ["close_combat"], "", "adamant", {"atk": 252}), BT.s("jinpachi", ["flamethrower"], "", "timid", {"spe": 252})],
		[BT.s("neo", ["protect", "tackle"]), BT.s("gel", ["haze"], "", "hardy", {"hp": 252}), BT.s("muni", ["tackle"])])
	b.sides[0].active[1].boosts["spa"] = 6
	# both attack slot 1 (neo): jinpachi (faster) KOs neo, trans must retarget to gel
	var err := b.choose(0, [{"type": "move", "move": "close_combat", "target": 1}, {"type": "move", "move": "flamethrower", "target": 1}])
	assert_eq(err, "")
	b.choose(1, [{"type": "move", "move": "tackle", "target": 1}, {"type": "move", "move": "haze"}])
	var neo = b.sides[1].team[0]
	var gel = b.sides[1].team[1]
	assert_true(neo.fainted, "neo KO'd by boosted flamethrower")
	assert_true(gel.hp < gel.max_hp, "close combat retargeted to gel")
	# replacement request only for side 1 slot 0
	assert_eq(b.request_state, "switch")
	assert_eq(b.sides[1].request["slots"], [0])
	assert_eq(b.choose(1, [{"type": "switch", "index": 2}]), "")
	assert_eq(b.sides[1].active[0].species_id, "muni")

func test_ally_targeting_helping_hand() -> void:
	var b := _make([BT.s("muni", ["helping_hand"]), BT.s("gel", ["ice_beam"])], [BT.s("renny", ["protect"], "", "hardy", {"hp": 252}), BT.s("trans", ["protect"], "", "hardy", {"hp": 252})])
	var gel = b.sides[0].active[1]
	var foe = b.sides[1].active[1]
	var mv: Dictionary = GameData.get_move("ice_beam").duplicate(true)
	mv["effect_type"] = "move"
	var base := int(b.get_damage(gel, foe, mv))
	b.add_volatile(gel, "helping_hand", b.sides[0].active[0], null)
	var boosted := int(b.get_damage(gel, foe, mv))
	assert_true(absf(float(boosted) / float(base) - 1.5) < 0.05, "%d vs %d" % [boosted, base])
	var err := b.choose(0, [{"type": "move", "move": "helping_hand", "target": -2}, {"type": "move", "move": "ice_beam", "target": 2}])
	assert_eq(err, "")

func test_heuristic_ai_plays_doubles_to_completion() -> void:
	var sets := GameData._load_json("res://data/sets/sets.json")
	var ids: Array = sets.keys()
	ids.sort()
	var rng := BattleRNG.new(77)
	var done := 0
	for k in range(6):
		rng.shuffle(ids)
		var teams := [[], []]
		for side in range(2):
			for i in range(4):
				var sp: String = ids[side * 4 + i]
				var sd: Dictionary = rng.sample(sets[sp])
				teams[side].append(PokemonSet.from_dict({"species": sp, "moves": sd["moves"], "item": sd["item"], "nature": sd["nature"], "evs": sd["evs"], "ability": sd["ability"]}))
		var b := Battle.new({"seed": k + 1, "teams": teams, "format": "doubles", "log": false, "max_turns": 300})
		BattleRunner.run(b, HeuristicAI.new(k), HeuristicAI.new(k + 50))
		if b.ended and b.winner >= 0:
			done += 1
	assert_eq(done, 6, "all doubles battles finish with a winner")
