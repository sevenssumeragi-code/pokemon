extends TestCase

func before_each() -> void:
	GameData.ensure_loaded()

func test_all_324_entries_present_and_valid() -> void:
	var n := 0
	for a in GameData.type_list:
		for d in GameData.type_list:
			var m := GameData.type_mod(a, d)
			assert_true(m in [0.0, 0.5, 1.0, 2.0], "%s->%s = %s" % [a, d, m])
			n += 1
	assert_eq(n, 324)

func test_known_matchups() -> void:
	var cases := {
		"fire>grass": 2, "fire>water": 0.5, "water>fire": 2, "grass>water": 2, "electric>ground": 0,
		"ground>flying": 0, "ground>electric": 2, "normal>ghost": 0, "ghost>normal": 0, "fighting>ghost": 0,
		"psychic>dark": 0, "poison>steel": 0, "dragon>fairy": 0, "fairy>dragon": 2, "fairy>steel": 0.5,
		"steel>fairy": 2, "ice>dragon": 2, "dragon>dragon": 2, "ghost>ghost": 2, "dark>ghost": 2,
		"fighting>normal": 2, "fighting>fairy": 0.5, "bug>psychic": 2, "bug>fairy": 0.5, "rock>flying": 2,
		"flying>fighting": 2, "ice>fire": 0.5, "fire>ice": 2, "water>dragon": 0.5, "grass>fire": 0.5,
		"electric>flying": 2, "poison>fairy": 2, "steel>rock": 2, "rock>fire": 2, "ground>rock": 2,
		"psychic>fighting": 2, "psychic>steel": 0.5, "dark>fairy": 0.5, "ghost>dark": 0.5, "fire>steel": 2,
		"steel>water": 0.5, "normal>steel": 0.5, "ice>steel": 0.5, "ice>water": 0.5, "grass>steel": 0.5,
	}
	for k in cases:
		var parts = k.split(">")
		assert_eq(GameData.type_mod(parts[0], parts[1]), float(cases[k]), k)

func test_immunity_count() -> void:
	var n := 0
	for a in GameData.type_list:
		for d in GameData.type_list:
			if GameData.type_mod(a, d) == 0.0:
				n += 1
	assert_eq(n, 8, "Gen 6+ chart has exactly 8 immunities")

func test_super_effective_count() -> void:
	var se := 0
	var nve := 0
	for a in GameData.type_list:
		for d in GameData.type_list:
			var m := GameData.type_mod(a, d)
			if m == 2.0: se += 1
			elif m == 0.5: nve += 1
	assert_eq(se, 51, "Gen 6+ chart has 51 super-effective entries")
	assert_eq(nve, 61, "Gen 6+ chart has 61 not-very-effective entries")

func test_dual_type_combination() -> void:
	assert_eq(GameData.effectiveness("ice", ["dragon", "ground"]), 4.0)
	assert_eq(GameData.effectiveness("electric", ["water", "ground"]), 0.0)
	assert_eq(GameData.effectiveness("fighting", ["steel", "flying"]), 1.0)
	assert_eq(GameData.effectiveness("ground", ["electric", "steel"]), 4.0)
