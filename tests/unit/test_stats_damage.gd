extends TestCase

func before_each() -> void:
	GameData.ensure_loaded()

func test_stat_formula_known_values() -> void:
	# Garchomp Lv100 base 108/130/95/80/85/102, 31 IV, 252 HP/252 Atk/4 Spe Adamant -> 357/394/226/176/206/241 (Atk boosted, SpA lowered)
	assert_eq(StatCalc.calc_hp(108, 31, 0, 100), 357)
	assert_eq(StatCalc.calc_hp(108, 31, 252, 100), 420)
	assert_eq(StatCalc.calc_stat(130, 31, 252, 100, 1.1), 394)
	assert_eq(StatCalc.calc_stat(95, 31, 0, 100, 1.0), 226)
	assert_eq(StatCalc.calc_stat(80, 31, 0, 100, 0.9), 176)
	assert_eq(StatCalc.calc_stat(102, 31, 4, 100, 1.0), 241)
	# Level 50 checks: base 100 HP, 31 IV, 252 EV -> 207 ; base 100 stat, 31 IV, 0 EV, neutral -> 120
	assert_eq(StatCalc.calc_hp(100, 31, 252, 50), 207)
	assert_eq(StatCalc.calc_stat(100, 31, 0, 50, 1.0), 120)
	assert_eq(StatCalc.calc_stat(100, 31, 252, 50, 1.1), 167)

func test_boost_multipliers() -> void:
	assert_eq(StatCalc.apply_boost(100, 0), 100)
	assert_eq(StatCalc.apply_boost(100, 1), 150)
	assert_eq(StatCalc.apply_boost(100, 2), 200)
	assert_eq(StatCalc.apply_boost(100, 6), 400)
	assert_eq(StatCalc.apply_boost(100, -1), 66)
	assert_eq(StatCalc.apply_boost(100, -6), 25)
	assert_eq(StatCalc.acc_fraction(2), Vector2i(5, 3))
	assert_eq(StatCalc.acc_fraction(-3), Vector2i(3, 6))

func test_modify_rounding() -> void:
	# Showdown-style: round half down at /4096
	assert_eq(Battle.modify(100, 1.5), 150)
	assert_eq(Battle.modify(33, 1.5), 49)   # 49.5 rounds down
	assert_eq(Battle.modify(101, 1.5), 151)  # 151.5 -> 151
	assert_eq(Battle.modify(100, 5324, 4096), 130)  # Life Orb 5324/4096 -> 130.48 -> 130

func test_bulbapedia_example_ice_fang() -> void:
	# Lv75 attacker, Atk 123, Ice Fang (65) vs Def 163 Dragon/Ground target: 168..196 non-crit (Bulbapedia example)
	var b := BT.make([BT.s("gel", ["ice_fang"])], [BT.s("muni_r_dragon", ["tackle"])], {"fixed_roll": 100})
	var a := BT.p1(b)
	var d := BT.p2(b)
	a.level = 75
	a.stored_stats["atk"] = 123
	d.stored_stats["def"] = 163
	d.types = ["dragon", "ground"]
	d.hp -= 1  # disable Multiscale
	var mv: Dictionary = GameData.get_move("ice_fang").duplicate(true)
	mv["effect_type"] = "move"
	var dmg = b.get_damage(a, d, mv)
	assert_eq(dmg, 196)
	b.debug_fixed_roll = 85
	mv = GameData.get_move("ice_fang").duplicate(true)
	mv["effect_type"] = "move"
	assert_eq(b.get_damage(a, d, mv), 168)

func _ref_damage(level: int, power: int, atk: int, df: int, roll: int, stab: bool, type_mult: float, extra_mod: float = 1.0, burn: bool = false) -> int:
	var base := int(floor(int(floor(int(floor(2 * level / 5.0 + 2)) * power * atk / float(df))) / 50.0)) + 2
	base = int(floor(base * roll / 100.0))
	if stab:
		base = Battle.modify(base, 1.5)
	var m := type_mult
	while m > 1.0:
		base *= 2
		m /= 2.0
	while m < 1.0 and m > 0:
		base = int(floor(base / 2.0))
		m *= 2.0
	if burn:
		base = Battle.modify(base, 0.5)
	if extra_mod != 1.0:
		base = Battle.modify(base, extra_mod)
	return maxi(1, base)

func test_engine_matches_reference_formula_various() -> void:
	# Jinpachi (fire, Atk) Flare Blitz vs Gel (ice): STAB, 2x
	var b := BT.make([BT.s("jinpachi", ["flare_blitz", "close_combat", "u_turn"], "", "adamant", {"atk": 252})], [BT.s("gel", ["tackle"], "", "hardy", {"hp": 252})])
	var a := BT.p1(b)
	var d := BT.p2(b)
	for roll in [85, 92, 100]:
		b.debug_fixed_roll = roll
		var mv: Dictionary = GameData.get_move("flare_blitz").duplicate(true)
		mv["effect_type"] = "move"
		var exp := _ref_damage(50, Battle.modify(120, 1.5), a.get_stat("atk"), d.get_stat("def"), roll, true, 2.0)  # Flame Domain 1.5x BP
		assert_eq(b.get_damage(a, d, mv), exp, "flare blitz roll %d" % roll)
		mv = GameData.get_move("close_combat").duplicate(true)
		mv["effect_type"] = "move"
		exp = _ref_damage(50, 120, a.get_stat("atk"), d.get_stat("def"), roll, false, 2.0)
		assert_eq(b.get_damage(a, d, mv), exp, "close combat roll %d" % roll)
		mv = GameData.get_move("u_turn").duplicate(true)
		mv["effect_type"] = "move"
		exp = _ref_damage(50, 70, a.get_stat("atk"), d.get_stat("def"), roll, false, 1.0)
		assert_eq(b.get_damage(a, d, mv), exp, "u-turn (neutral vs ice) roll %d" % roll)

func test_burn_halves_physical_and_life_orb() -> void:
	var b := BT.make([BT.s("renny", ["waterfall"], "life_orb")], [BT.s("jinpachi", ["tackle"])])
	var a := BT.p1(b)
	var d := BT.p2(b)
	b.set_status(a, "brn", a, null)
	var mv: Dictionary = GameData.get_move("waterfall").duplicate(true)
	mv["effect_type"] = "move"
	var exp := _ref_damage(50, 80, a.get_stat("atk"), d.get_stat("def"), 100, true, 2.0, 5324.0 / 4096.0, true)
	assert_eq(b.get_damage(a, d, mv), exp)

func test_crit_ignores_negative_attack_and_positive_defense() -> void:
	var b := BT.make([BT.s("renny", ["waterfall"])], [BT.s("jinpachi", ["tackle"])], {"no_crit": false})
	var a := BT.p1(b)
	var d := BT.p2(b)
	a.boosts["atk"] = -2
	d.boosts["def"] = 2
	var mv: Dictionary = GameData.get_move("waterfall").duplicate(true)
	mv["effect_type"] = "move"
	mv["will_crit"] = true
	var base := int(floor(int(floor(int(floor(2 * 50 / 5.0 + 2)) * 80 * a.stored_stats["atk"] / float(d.stored_stats["def"]))) / 50.0)) + 2
	base = int(floor(base * 1.5))
	base = Battle.modify(base, 1.5)
	base *= 2
	assert_eq(b.get_damage(a, d, mv), base)

func test_spread_and_weather_modifiers() -> void:
	var b := BT.make([BT.s("renny", ["surf"])], [BT.s("jinpachi", ["tackle"])])
	var a := BT.p1(b)
	var d := BT.p2(b)
	b.set_weather("rain", null, null)
	var mv: Dictionary = GameData.get_move("surf").duplicate(true)
	mv["effect_type"] = "move"
	var base := int(floor(int(floor(int(floor(2 * 50 / 5.0 + 2)) * 90 * a.get_stat("spa") / float(d.get_stat("spd")))) / 50.0)) + 2
	base = Battle.modify(base, 1.5)  # rain
	base = Battle.modify(base, 1.5)  # stab
	base *= 2
	assert_eq(b.get_damage(a, d, mv), base)
	b.set_weather("sun", null, null)
	mv = GameData.get_move("surf").duplicate(true)
	mv["effect_type"] = "move"
	base = int(floor(int(floor(int(floor(2 * 50 / 5.0 + 2)) * 90 * a.get_stat("spa") / float(d.get_stat("spd")))) / 50.0)) + 2
	base = Battle.modify(base, 0.5)
	base = Battle.modify(base, 1.5)
	base *= 2
	assert_eq(b.get_damage(a, d, mv), base)
