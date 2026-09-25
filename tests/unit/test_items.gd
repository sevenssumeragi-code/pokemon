extends TestCase

func before_each() -> void:
	GameData.ensure_loaded()

func test_choice_lock_and_switch_reset() -> void:
	var b := BT.make([BT.s("renny", ["waterfall", "crunch"], "choice_band"), BT.s("muni", ["protect"])], [BT.s("marutan", ["roost", "protect"], "", "hardy", {"hp": 252, "def": 252})])
	BT.turn(b, "move:waterfall", "move:roost")
	var req: Dictionary = b.sides[0].request
	var crunch_disabled := false
	for m in req["active"][0]["moves"]:
		if m["id"] == "crunch":
			crunch_disabled = m["disabled"]
	assert_true(crunch_disabled, "locked into waterfall")
	assert_ne(BT.turn(b, "move:crunch", "move:roost"), "", "choosing locked-out move is rejected")
	BT.turn(b, "switch:1", "move:roost")
	BT.turn(b, "switch:0", "move:roost")
	req = b.sides[0].request
	for m in req["active"][0]["moves"]:
		assert_false(m["disabled"], "lock cleared after switch")

func test_choice_band_multiplier() -> void:
	var b := BT.make([BT.s("renny", ["waterfall"], "choice_band")], [BT.s("marutan", ["roost"])])
	var a := BT.p1(b)
	assert_eq(a.get_stat("atk"), Battle.modify(a.stored_stats["atk"], 1.5))
	var c := BT.make([BT.s("renny", ["waterfall"], "choice_scarf")], [BT.s("marutan", ["roost"])])
	assert_eq(BT.p1(c).get_stat("spe"), Battle.modify(BT.p1(c).stored_stats["spe"], 1.5))

func test_leftovers_and_black_sludge() -> void:
	var b := BT.make([BT.s("renny", ["protect"], "leftovers")], [BT.s("gel_r_poison", ["protect"], "black_sludge")])
	BT.p1(b).hp = 100
	BT.p2(b).hp = 100
	BT.turn(b, "move:protect", "move:protect")
	assert_eq(BT.p1(b).hp, 100 + int(floor(BT.p1(b).max_hp / 16.0)))
	assert_eq(BT.p2(b).hp, 100 + int(floor(BT.p2(b).max_hp / 16.0)))
	var c := BT.make([BT.s("renny", ["protect"], "black_sludge")], [BT.s("gel_r_poison", ["protect"])])
	BT.p1(c).hp = 100
	BT.turn(c, "move:protect", "move:protect")
	assert_eq(BT.p1(c).hp, 100 - int(floor(BT.p1(c).max_hp / 8.0)))

func test_sitrus_and_lum() -> void:
	var b := BT.make([BT.s("renny", ["protect"], "sitrus_berry")], [BT.s("muni", ["will_o_wisp"])])
	var r := BT.p1(b)
	r.hp = int(floor(r.max_hp / 2.0))
	b.run_event("Update", r)
	assert_eq(r.item, "")
	assert_eq(r.hp, int(floor(r.max_hp / 2.0)) + int(floor(r.max_hp / 4.0)))
	var c := BT.make([BT.s("renny", ["protect"], "lum_berry")], [BT.s("muni", ["will_o_wisp"])])
	BT.turn(c, "move:protect", "move:will_o_wisp")
	# protect blocks; burn manually
	c.set_status(BT.p1(c), "brn", BT.p2(c), null)
	assert_eq(BT.p1(c).status, "")
	assert_eq(BT.p1(c).item, "")

func test_assault_vest_blocks_status_moves() -> void:
	var b := BT.make([BT.s("renny", ["waterfall", "rest"], "assault_vest")], [BT.s("muni", ["protect"])])
	var req: Dictionary = b.sides[0].request
	for m in req["active"][0]["moves"]:
		if m["id"] == "rest":
			assert_true(m["disabled"])
	assert_eq(BT.p1(b).get_stat("spd"), Battle.modify(BT.p1(b).stored_stats["spd"], 1.5))

func test_rocky_helmet_contact_damage() -> void:
	var b := BT.make([BT.s("renny", ["waterfall", "surf"])], [BT.s("marutan", ["roost"], "rocky_helmet", "hardy", {"hp": 252, "def": 252})])
	BT.turn(b, "move:waterfall", "move:roost")
	assert_eq(BT.p1(b).hp, BT.p1(b).max_hp - int(floor(BT.p1(b).max_hp / 6.0)))
	var c := BT.make([BT.s("renny", ["waterfall", "surf"])], [BT.s("marutan", ["roost"], "rocky_helmet", "hardy", {"hp": 252, "def": 252})])
	BT.turn(c, "move:surf", "move:roost")
	assert_eq(BT.p1(c).hp, BT.p1(c).max_hp)

func test_eviolite_only_for_nfe() -> void:
	var b := BT.make([BT.s("neo", ["protect"], "eviolite")], [BT.s("trans", ["protect"], "eviolite")])
	assert_eq(BT.p1(b).get_stat("def"), Battle.modify(BT.p1(b).stored_stats["def"], 1.5))
	assert_eq(BT.p2(b).get_stat("def"), BT.p2(b).stored_stats["def"])

func test_weakness_policy() -> void:
	var b := BT.make([BT.s("gel", ["ice_beam", "water_gun"])], [BT.s("muni_r_dragon", ["protect", "roost"], "weakness_policy", "hardy", {"hp": 252, "spd": 252})])
	BT.turn(b, "move:water_gun", "move:roost")
	assert_eq(BT.p2(b).item, "weakness_policy")
	BT.turn(b, "move:ice_beam", "move:roost")
	assert_eq(BT.p2(b).item, "")
	assert_eq(BT.p2(b).boosts["atk"], 2)
	assert_eq(BT.p2(b).boosts["spa"], 2)

func test_resist_berry_halves_super_effective() -> void:
	var b := BT.make([BT.s("gel", ["ice_beam"])], [BT.s("muni_r_dragon", ["protect"], "yache_berry", "hardy", {"hp": 252})])
	BT.p2(b).hp -= 1
	var d := BT.p2(b)
	var hp0 := d.hp
	BT.turn(b, "move:ice_beam", "move:protect")
	assert_eq(d.item, "yache_berry", "protected")
	BT.turn(b, "move:ice_beam", "move:protect")
	# protect fails on 2nd consecutive use with 1/3 chance to succeed; force by removing stall
	b.remove_volatile(d, "stall")
	b.remove_volatile(d, "protect")
	var c := BT.make([BT.s("gel", ["ice_beam"])], [BT.s("muni_r_dragon", ["roost"], "yache_berry", "hardy", {"hp": 252})])
	var cd := BT.p2(c)
	cd.hp -= 1
	var hp1 := cd.hp
	var mv: Dictionary = GameData.get_move("ice_beam").duplicate(true)
	mv["effect_type"] = "move"
	var full := int(c.get_damage(BT.p1(c), cd, mv))
	BT.turn(c, "move:ice_beam", "move:roost")
	assert_eq(cd.item, "")
	assert_true(BT.has_log(c, "-enditem", "yache_berry"))

func test_air_balloon_immunity_and_pop() -> void:
	var b := BT.make([BT.s("trans", ["earthquake", "sacred_sword"], "", "hardy", {})], [BT.s("namazuo", ["protect", "iron_defense"], "air_balloon", "hardy", {"hp": 252, "def": 252})])
	BT.turn(b, "move:earthquake", "move:iron_defense")
	assert_eq(BT.p2(b).hp, BT.p2(b).max_hp)
	assert_true(BT.has_log(b, "-immune"))
	BT.turn(b, "move:sacred_sword", "move:iron_defense")
	assert_eq(BT.p2(b).item, "")
	BT.turn(b, "move:earthquake", "move:iron_defense")
	assert_true(BT.p2(b).hp < BT.p2(b).max_hp)

func test_eject_button_and_red_card() -> void:
	var b := BT.make([BT.s("renny", ["waterfall"]), BT.s("muni", ["protect"])], [BT.s("marutan", ["roost"], "eject_button", "hardy", {"hp": 252, "def": 252}), BT.s("gel", ["protect"])])
	BT.turn(b, "move:waterfall", "move:roost")
	assert_eq(b.request_state, "switch")
	assert_eq(b.sides[1].request["type"], "switch")
	BT.one(b, 1, "switch:1")
	assert_eq(BT.p2(b).species_id, "gel")
	var c := BT.make([BT.s("renny", ["waterfall"]), BT.s("muni", ["protect"])], [BT.s("marutan", ["roost"], "red_card", "hardy", {"hp": 252, "def": 252})])
	BT.turn(c, "move:waterfall", "move:roost")
	assert_eq(BT.p1(c).species_id, "muni", "attacker dragged out")
	assert_eq(BT.p2(c).item, "")

func test_light_clay_extends_screens() -> void:
	var b := BT.make([BT.s("muni", ["reflect", "light_screen"], "light_clay")], [BT.s("renny", ["protect"])])
	BT.turn(b, "move:reflect", "move:protect")
	assert_eq(int(b.sides[0].side_conditions["reflect"]["duration"]), 7, "8 turns, one elapsed")

func test_type_boost_item() -> void:
	var b := BT.make([BT.s("jinpachi", ["close_combat"], "black_belt")], [BT.s("renny", ["protect"])])
	var mv: Dictionary = GameData.get_move("close_combat").duplicate(true)
	mv["effect_type"] = "move"
	var bp = b.run_event("BasePower", BT.p1(b), BT.p2(b), mv, 120)
	assert_eq(int(bp), 144)

func test_quick_claw_fractional_priority() -> void:
	var first := 0
	for i in range(60):
		var b := BT.make([BT.s("jinpachi_r", ["rock_slide"], "quick_claw")], [BT.s("jinpachi", ["tackle"])], {"seed": 500 + i})
		BT.turn(b, "move:rock_slide", "move:tackle")
		for e in b.log:
			if e[0] == "move":
				if e[2] == "rock_slide":
					first += 1
				break
	assert_in_range(first, 3, 24, "quick claw ~20%%: %d/60" % first)
