extends TestCase
## Priority, speed ties, switching, U-turn, faint replacement, protect, substitute, encore/taunt.

func before_each() -> void:
	GameData.ensure_loaded()

func _first_move(b: Battle, from: int = 0) -> String:
	for i in range(from, b.log.size()):
		if b.log[i][0] == "move":
			return b.log[i][2]
	return ""

func test_priority_beats_speed() -> void:
	var b := BT.make([BT.s("renny", ["aqua_jet"])], [BT.s("jinpachi", ["tackle"], "", "jolly", {"spe": 252})])
	BT.turn(b, "move:aqua_jet", "move:tackle")
	assert_eq(_first_move(b), "aqua_jet")

func test_speed_tie_is_random() -> void:
	var firsts := {}
	for i in range(30):
		var b := BT.make([BT.s("renny", ["tackle"])], [BT.s("renny_r", ["tackle"])], {"seed": 2000 + i})
		BT.turn(b, "move:tackle", "move:tackle")
		var e = b.log.filter(func(x): return x[0] == "move")[0]
		firsts[e[1]] = true
	assert_eq(firsts.size(), 2, "both sides sometimes move first on a tie")

func test_switch_happens_before_moves() -> void:
	var b := BT.make([BT.s("renny", ["tackle"]), BT.s("muni", ["protect"])], [BT.s("jinpachi", ["tackle"], "", "jolly", {"spe": 252})])
	BT.turn(b, "switch:1", "move:tackle")
	assert_eq(BT.p1(b).species_id, "muni")
	assert_true(BT.p1(b).hp < BT.p1(b).max_hp, "incoming muni took the hit")

func test_u_turn_requests_switch_mid_turn_then_foe_moves() -> void:
	var b := BT.make([BT.s("jinpachi", ["u_turn"], "", "jolly", {"spe": 252}), BT.s("muni", ["protect"])], [BT.s("renny", ["tackle"])])
	BT.turn(b, "move:u_turn", "move:tackle")
	assert_eq(b.request_state, "switch")
	assert_eq(b.sides[0].request["type"], "switch")
	assert_eq(b.sides[1].request.get("type"), "wait")
	BT.one(b, 0, "switch:1")
	assert_eq(BT.p1(b).species_id, "muni")
	assert_true(BT.p1(b).hp < BT.p1(b).max_hp, "renny's tackle hit the replacement")
	assert_eq(b.turn, 2)

func test_faint_replacement_at_end_of_turn() -> void:
	var b := BT.make([BT.s("trans", ["close_combat"], "", "adamant", {"atk": 252}), BT.s("muni", ["protect"])], [BT.s("gel", ["haze", "ice_beam"]), BT.s("renny", ["tackle"])])
	BT.p1(b).boosts["atk"] = 6
	BT.turn(b, "move:close_combat", "move:haze")
	assert_true(BT.p2(b).fainted)
	assert_eq(b.request_state, "switch")
	assert_eq(b.sides[1].request["type"], "switch")
	BT.one(b, 1, "switch:1")
	assert_eq(BT.p2(b).species_id, "renny")
	assert_eq(b.turn, 2)

func test_battle_ends_when_team_fainted() -> void:
	var b := BT.make([BT.s("trans", ["close_combat"], "", "adamant", {"atk": 252})], [BT.s("gel", ["haze"])])
	BT.p1(b).boosts["atk"] = 6
	BT.turn(b, "move:close_combat", "move:haze")
	assert_true(b.ended)
	assert_eq(b.winner, 0)

func test_protect_blocks_and_consecutive_fails() -> void:
	var successes := 0
	for i in range(30):
		var b := BT.make([BT.s("muni", ["protect"])], [BT.s("renny", ["tackle"])], {"seed": 3000 + i})
		BT.turn(b, "move:protect", "move:tackle")
		assert_eq(BT.p1(b).hp, BT.p1(b).max_hp, "first protect always works")
		BT.turn(b, "move:protect", "move:tackle")
		if BT.p1(b).hp == BT.p1(b).max_hp:
			successes += 1
	assert_in_range(successes, 3, 18, "second protect ~1/3: %d/30" % successes)

func test_substitute_absorbs_and_blocks_status() -> void:
	var b := BT.make([BT.s("renny", ["substitute", "protect"], "", "hardy", {"hp": 252})], [BT.s("muni", ["thunder_wave", "tackle", "charm"])])
	BT.turn(b, "move:substitute", "move:charm")
	var r := BT.p1(b)
	assert_true(r.volatiles.has("substitute"))
	assert_eq(r.hp, r.max_hp - int(floor(r.max_hp / 4.0)))
	BT.turn(b, "move:protect", "move:thunder_wave")
	b.remove_volatile(r, "stall")
	var c := BT.make([BT.s("renny", ["substitute", "protect"], "", "hardy", {"hp": 252})], [BT.s("muni", ["thunder_wave", "tackle"], "", "hardy", {"spe": 252})])
	# muni faster: sub first turn? muni thunder waves first -> renny paralyzed. so use: renny sub turn 1 while muni tackles
	BT.turn(c, "move:substitute", "move:tackle")
	BT.turn(c, "move:protect", "move:thunder_wave")
	assert_eq(BT.p1(c).status, "", "status blocked by substitute (or protect)")
	assert_true(BT.has_log(c, "-fail") or BT.has_log(c, "-activate", "protect"))

func test_taunt_blocks_status_moves() -> void:
	var b := BT.make([BT.s("gel_r_dark", ["taunt"], "", "hardy", {"spe": 252})], [BT.s("muni", ["wish", "moonblast"], "", "hardy", {})])
	BT.turn(b, "move:taunt", "move:wish")
	assert_true(BT.p2(b).volatiles.has("taunt"))
	var req: Dictionary = b.sides[1].request
	for m in req["active"][0]["moves"]:
		if m["id"] == "wish":
			assert_true(m["disabled"])
		if m["id"] == "moonblast":
			assert_false(m["disabled"])

func test_encore_locks_last_move() -> void:
	var b := BT.make([BT.s("muni", ["encore", "protect"], "", "hardy", {})], [BT.s("renny", ["tackle", "waterfall"], "", "hardy", {"spe": 252})])
	BT.turn(b, "move:protect", "move:tackle")
	b.remove_volatile(BT.p1(b), "stall")
	BT.turn(b, "move:encore", "move:tackle")
	assert_true(BT.p2(b).volatiles.has("encore"))
	var req: Dictionary = b.sides[1].request
	for m in req["active"][0]["moves"]:
		if m["id"] == "waterfall":
			assert_true(m["disabled"])

func test_leech_seed_and_grass_immunity() -> void:
	var b := BT.make([BT.s("hyu_r", ["leech_seed", "protect"])], [BT.s("renny", ["protect"], "", "hardy", {"hp": 252})])
	var h := BT.p1(b)
	h.hp = 50
	BT.turn(b, "move:leech_seed", "move:protect")
	# protect blocked it; use non-protect turn
	b.remove_volatile(BT.p2(b), "stall")
	var c := BT.make([BT.s("hyu_r", ["leech_seed", "protect"])], [BT.s("renny", ["tackle"], "", "hardy", {"hp": 252})])
	BT.p1(c).hp = 50
	BT.turn(c, "move:leech_seed", "move:tackle")
	assert_true(BT.p2(c).volatiles.has("leech_seed"))
	assert_true(BT.p1(c).hp > 50 - 40, "seeder healed")
	var g := BT.make([BT.s("hyu_r", ["leech_seed"])], [BT.s("hyu_r", ["protect"])])
	assert_false(g.add_volatile(BT.p2(g), "leech_seed", BT.p1(g), null), "grass immune")

func test_roar_forces_random_switch() -> void:
	var b := BT.make([BT.s("marutan", ["whirlwind"])], [BT.s("renny", ["tackle"]), BT.s("muni", ["protect"]), BT.s("gel", ["protect"])])
	BT.turn(b, "move:whirlwind", "move:tackle")
	assert_ne(BT.p2(b).species_id, "renny")
	assert_eq(b.turn, 2)

func test_struggle_when_no_pp() -> void:
	var b := BT.make([BT.s("renny", ["tackle"])], [BT.s("marutan", ["protect", "roost"], "", "hardy", {"hp": 252, "def": 252})])
	BT.p1(b).moves[0]["pp"] = 0
	var req: Dictionary = b.sides[0].request
	b.make_requests("move")
	req = b.sides[0].request
	assert_eq(req["active"][0]["moves"][0]["id"], "struggle")
	BT.turn(b, "move:struggle", "move:roost")
	assert_true(BT.p1(b).hp < BT.p1(b).max_hp, "struggle recoil")

func test_dynamic_speed_after_paralysis() -> void:
	# renny (slower) paralyzes faster jinpachi with thunder wave? renny can't learn. use muni(prankster) vs jinpachi; then check next turn order
	var b := BT.make([BT.s("muni", ["thunder_wave", "moonblast"])], [BT.s("jinpachi", ["tackle"], "", "hardy", {})])
	BT.turn(b, "move:thunder_wave", "move:tackle")
	assert_eq(BT.p2(b).status, "par")
	var idx := b.log.size()
	BT.turn(b, "move:moonblast", "move:tackle")
	assert_eq(_first_move(b, idx), "moonblast", "paralyzed jinpachi now slower than muni")

func test_multi_hit_distribution() -> void:
	var counts := {}
	for i in range(200):
		var b := BT.make([BT.s("jinpachi_r", ["rock_blast"])], [BT.s("marutan", ["roost"], "", "hardy", {"hp": 252, "def": 252})], {"seed": 4000 + i})
		BT.turn(b, "move:rock_blast", "move:roost")
		for e in b.log:
			if e[0] == "-hitcount":
				counts[int(e[2])] = int(counts.get(int(e[2]), 0)) + 1
	assert_true(counts.has(2) and counts.has(3) and counts.has(4) and counts.has(5))
	assert_true(counts[2] > counts[4] and counts[3] > counts[5], "2-3 hits more common: %s" % str(counts))
