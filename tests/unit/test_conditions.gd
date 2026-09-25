extends TestCase
## Status, weather, terrain, screens, hazards.

func before_each() -> void:
	GameData.ensure_loaded()

func test_status_no_stacking_and_type_immunities() -> void:
	var b := BT.make([BT.s("jinpachi", ["protect"])], [BT.s("namazuo", ["protect"])])
	var j := BT.p1(b)
	var n := BT.p2(b)
	assert_false(b.set_status(j, "brn", n, null), "fire immune to burn")
	assert_false(b.set_status(n, "par", j, null), "electric immune to paralysis")
	assert_false(b.set_status(n, "psn", j, null), "steel immune to poison")
	assert_false(b.set_status(n, "tox", j, null), "steel immune to toxic")
	assert_true(b.set_status(j, "par", n, null))
	assert_false(b.set_status(j, "slp", n, null), "already statused")
	assert_eq(j.status, "par")
	var c := BT.make([BT.s("gel", ["protect"])], [BT.s("gel_r_poison", ["protect"])])
	assert_false(c.set_status(BT.p1(c), "frz", null, null), "ice immune to freeze")
	assert_false(c.set_status(BT.p2(c), "psn", null, null), "poison immune to poison")

func test_toxic_escalates_and_resets_on_switch() -> void:
	var b := BT.make([BT.s("renny", ["protect"], "", "hardy", {"hp": 252}), BT.s("muni", ["protect"])], [BT.s("gel_r_poison", ["toxic", "protect"])])
	var r := BT.p1(b)
	b.set_status(r, "tox", BT.p2(b), null)
	var unit := int(floor(r.max_hp / 16.0))
	var hp := r.hp
	BT.turn(b, "move:protect", "move:protect")
	assert_eq(r.hp, hp - unit)
	hp = r.hp
	BT.turn(b, "move:protect", "move:protect")
	assert_eq(r.hp, hp - unit * 2)
	BT.turn(b, "switch:1", "move:protect")
	BT.turn(b, "switch:0", "move:protect")
	assert_eq(r.status, "tox")
	assert_eq(int(r.status_state["stage"]), 1, "counter reset (one tick happened this turn)")

func test_burn_and_poison_residual() -> void:
	var b := BT.make([BT.s("renny", ["protect"])], [BT.s("marutan", ["protect"])])
	var r := BT.p1(b)
	var m := BT.p2(b)
	b.set_status(r, "brn", null, null)
	b.set_status(m, "psn", null, null)
	BT.turn(b, "move:protect", "move:protect")
	assert_eq(r.hp, r.max_hp - int(floor(r.max_hp / 16.0)))
	assert_eq(m.hp, m.max_hp - int(floor(m.max_hp / 8.0)))

func test_paralysis_speed_and_sleep_duration_range() -> void:
	var b := BT.make([BT.s("renny", ["protect"])], [BT.s("marutan", ["protect"])])
	var r := BT.p1(b)
	var spe := r.get_stat("spe")
	b.set_status(r, "par", null, null)
	assert_eq(r.get_stat("spe"), Battle.modify(spe, 0.5))
	var seen := {}
	for i in range(60):
		var c := BT.make([BT.s("renny", ["waterfall"])], [BT.s("marutan", ["protect", "roost"], "", "hardy", {"hp": 252, "def": 252})], {"seed": 1000 + i})
		c.set_status(BT.p1(c), "slp", null, null)
		var turns := 0
		while BT.p1(c).status == "slp" and turns < 10:
			BT.turn(c, "move:waterfall", "move:roost")
			turns += 1
		seen[turns] = true
	# loop counts the wake turn too: 1-3 sleeping turns -> 2..4 iterations
	assert_true(seen.has(2) and seen.has(3) and seen.has(4), "sleep lasts 1-3 turns, seen %s" % str(seen.keys()))
	assert_false(seen.has(5))
	assert_false(seen.has(1))

func test_freeze_thaw_by_fire_move() -> void:
	var b := BT.make([BT.s("jinpachi", ["flamethrower"])], [BT.s("renny", ["protect", "roost"], "", "hardy", {"hp": 252})])
	var r := BT.p2(b)
	b.set_status(r, "frz", null, null)
	BT.turn(b, "move:flamethrower", "move:roost")
	assert_eq(r.status, "")

func test_weather_duration_override_and_extender() -> void:
	var b := BT.make([BT.s("renny", ["rain_dance", "protect"], "damp_rock")], [BT.s("jinpachi", ["sunny_day", "protect"])])
	BT.turn(b, "move:rain_dance", "move:protect")
	assert_eq(b.weather, "rain")
	assert_eq(int(b.weather_state["duration"]), 7)
	BT.turn(b, "move:protect", "move:sunny_day")
	assert_eq(b.weather, "sun")
	assert_eq(int(b.weather_state["duration"]), 4)
	for i in range(3):
		BT.turn(b, "move:protect", "move:protect")
		b.remove_volatile(BT.p1(b), "stall")
		b.remove_volatile(BT.p2(b), "stall")
	assert_eq(b.weather, "sun")
	BT.turn(b, "move:protect", "move:protect")
	assert_eq(b.weather, "", "sun ends after 5 turns")

func test_sandstorm_damage_and_immunities() -> void:
	var b := BT.make([BT.s("jinpachi_r", ["sandstorm", "protect"])], [BT.s("renny", ["protect"], "", "hardy", {"hp": 252})])
	BT.turn(b, "move:sandstorm", "move:protect")
	assert_eq(BT.p1(b).hp, BT.p1(b).max_hp, "rock immune")
	assert_eq(BT.p2(b).hp, BT.p2(b).max_hp - int(floor(BT.p2(b).max_hp / 16.0)))
	assert_eq(BT.p1(b).get_stat("spd"), Battle.modify(BT.p1(b).stored_stats["spd"], 1.5), "rock SpD 1.5x in sand")

func test_snow_blizzard_always_hits() -> void:
	var b := BT.make([BT.s("gel", ["blizzard"])], [BT.s("muni_r_normal", ["minimize"])])
	var m := BT.p2(b)
	m.boosts["evasion"] = 6
	var mv: Dictionary = GameData.get_move("blizzard").duplicate(true)
	mv["effect_type"] = "move"
	var hits := 0
	for i in range(50):
		if b._accuracy_check(m, BT.p1(b), mv):
			hits += 1
	assert_eq(hits, 50)

func test_terrain_boost_and_duration_and_extender() -> void:
	var b := BT.make([BT.s("namazuo", ["electric_terrain", "wild_charge", "protect"], "terrain_extender")], [BT.s("renny", ["protect"], "", "hardy", {"hp": 252})])
	BT.turn(b, "move:electric_terrain", "move:protect")
	assert_eq(b.terrain, "electric")
	assert_eq(int(b.terrain_state["duration"]), 7)
	var mv: Dictionary = GameData.get_move("wild_charge").duplicate(true)
	mv["effect_type"] = "move"
	var bp = b.run_event("BasePower", BT.p1(b), BT.p2(b), mv, 90)
	assert_eq(int(bp), Battle.modify(90, 5325, 4096))

func test_electric_terrain_blocks_sleep_for_grounded() -> void:
	var b := BT.make([BT.s("muni_r_bug", ["sleep_powder", "electric_terrain"])], [BT.s("renny", ["protect", "roost"])])
	b.set_terrain("electric", null, null)
	assert_false(b.set_status(BT.p2(b), "slp", BT.p1(b), null))
	var c := BT.make([BT.s("muni_r_bug", ["sleep_powder"])], [BT.s("marutan", ["protect"])])
	c.set_terrain("electric", null, null)
	assert_true(c.set_status(BT.p2(c), "slp", BT.p1(c), null), "flying not grounded")

func test_misty_terrain_blocks_status_and_halves_dragon() -> void:
	var b := BT.make([BT.s("muni_r_dragon", ["dragon_pulse"])], [BT.s("renny", ["protect"])])
	var mv: Dictionary = GameData.get_move("dragon_pulse").duplicate(true)
	mv["effect_type"] = "move"
	var bp0 := int(b.run_event("BasePower", BT.p1(b), BT.p2(b), mv, 85))
	b.set_terrain("misty", null, null)
	var bp1 := int(b.run_event("BasePower", BT.p1(b), BT.p2(b), mv, 85))
	assert_eq(bp1, Battle.modify(bp0, 0.5))
	assert_false(b.set_status(BT.p2(b), "brn", BT.p1(b), null))

func test_grassy_terrain_heals_and_weakens_earthquake() -> void:
	var b := BT.make([BT.s("trans", ["earthquake", "protect"])], [BT.s("renny", ["protect"], "", "hardy", {"hp": 252})])
	b.set_terrain("grassy", null, null)
	BT.p2(b).hp = 100
	var mv: Dictionary = GameData.get_move("earthquake").duplicate(true)
	mv["effect_type"] = "move"
	assert_eq(int(b.run_event("BasePower", BT.p1(b), BT.p2(b), mv, 100)), 50)
	BT.turn(b, "move:protect", "move:protect")
	assert_eq(BT.p2(b).hp, 100 + int(floor(BT.p2(b).max_hp / 16.0)))

func test_psychic_terrain_blocks_priority_on_grounded() -> void:
	var b := BT.make([BT.s("renny", ["aqua_jet"])], [BT.s("trans_r", ["psychic_terrain", "protect"], "", "hardy", {"hp": 252})])
	BT.turn(b, "move:aqua_jet", "move:psychic_terrain")
	var hp := BT.p2(b).hp
	BT.turn(b, "move:aqua_jet", "move:protect")
	assert_eq(BT.p2(b).hp, hp, "aqua jet blocked by psychic terrain")

func test_screens_halve_damage_and_expire() -> void:
	var b := BT.make([BT.s("muni", ["reflect", "protect"])], [BT.s("renny", ["waterfall", "surf"], "", "hardy", {"atk": 252})])
	var m := BT.p1(b)
	var r := BT.p2(b)
	var mv: Dictionary = GameData.get_move("waterfall").duplicate(true)
	mv["effect_type"] = "move"
	var d0 := int(b.get_damage(r, m, mv))
	b.add_side_condition(b.sides[0], "reflect", m, null)
	var d1 := int(b.get_damage(r, m, mv))
	assert_eq(d1, Battle.modify(d0, 0.5))
	var mv2: Dictionary = GameData.get_move("surf").duplicate(true)
	mv2["effect_type"] = "move"
	var s0 := int(b.get_damage(r, m, mv2))
	b.add_side_condition(b.sides[0], "light_screen", m, null)
	assert_eq(int(b.get_damage(r, m, mv2)), Battle.modify(s0, 0.5))
	assert_eq(int(b.sides[0].side_conditions["reflect"]["duration"]), 5)

func test_aurora_veil_requires_snow() -> void:
	var b := BT.make([BT.s("gel", ["aurora_veil"])], [BT.s("renny", ["protect", "roost"])])
	BT.turn(b, "move:aurora_veil", "move:roost")
	assert_true(b.sides[0].has_side_condition("aurora_veil"))
	var c := BT.make([BT.s("muni", ["protect"])], [BT.s("renny", ["protect", "roost"])])
	# muni cannot learn aurora veil; test via direct add with no weather
	var gel := BT.make([BT.s("gel", ["aurora_veil"], "", "hardy", {}, "levitate")], [BT.s("renny", ["roost"])])
	BT.turn(gel, "move:aurora_veil", "move:roost")
	assert_false(gel.sides[0].has_side_condition("aurora_veil"), "fails without snow")

func test_hazards_on_switch_in() -> void:
	var b := BT.make([BT.s("trans", ["stealth_rock", "spikes", "protect"]), BT.s("muni", ["protect"])],
		[BT.s("gel_r_poison", ["toxic_spikes", "protect"]), BT.s("jinpachi", ["protect"]), BT.s("marutan", ["protect"]), BT.s("gel", ["protect"])])
	BT.turn(b, "move:stealth_rock", "move:toxic_spikes")
	BT.turn(b, "move:spikes", "move:protect")
	BT.turn(b, "move:protect", "switch:1")
	var j := BT.p2(b)
	# jinpachi (fire): rocks 2x -> 1/4, spikes 1 layer 1/8
	assert_eq(j.hp, j.max_hp - int(floor(j.max_hp / 4.0)) - int(floor(j.max_hp / 8.0)))
	BT.turn(b, "move:protect", "switch:2")
	var m := BT.p2(b)
	assert_eq(m.hp, m.max_hp - int(floor(m.max_hp / 4.0)), "flying: rocks only")
	BT.turn(b, "move:protect", "switch:3")
	var g := BT.p2(b)
	assert_eq(g.hp, g.max_hp - int(floor(g.max_hp / 4.0)) - int(floor(g.max_hp / 8.0)))
	# toxic spikes on p1 side: muni is grounded fairy -> poisoned
	BT.turn(b, "switch:1", "move:protect")
	assert_eq(BT.p1(b).status, "psn")
	# poison type absorbs toxic spikes
	var c := BT.make([BT.s("gel_r_poison", ["toxic_spikes", "protect"]), BT.s("muni", ["protect"])], [BT.s("gel_r_poison", ["protect"]), BT.s("gel_r_dark", ["protect"])])
	BT.turn(c, "move:toxic_spikes", "move:protect")
	BT.turn(c, "move:toxic_spikes", "switch:1")
	BT.turn(c, "move:protect", "switch:0")
	assert_false(c.sides[1].has_side_condition("toxic_spikes"), "absorbed by grounded poison type")

func test_trick_room_reverses_order() -> void:
	var b := BT.make([BT.s("jinpachi_r", ["trick_room", "rock_slide"], "", "hardy", {})], [BT.s("jinpachi", ["tackle"], "", "jolly", {"spe": 252})])
	BT.turn(b, "move:trick_room", "move:tackle")
	assert_true(b.has_pseudo_weather("trick_room"))
	var idx := b.log.size()
	BT.turn(b, "move:rock_slide", "move:tackle")
	var first := ""
	for i in range(idx, b.log.size()):
		if b.log[i][0] == "move":
			first = b.log[i][2]
			break
	assert_eq(first, "rock_slide", "slower moves first in trick room")
