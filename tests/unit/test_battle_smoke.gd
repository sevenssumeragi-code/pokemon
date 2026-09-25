extends TestCase

func before_each() -> void:
	GameData.ensure_loaded()

func test_data_loaded() -> void:
	assert_true(GameData.moves.size() > 100)
	assert_eq(GameData.species.size(), 19)
	assert_true(GameData.abilities.has("awakened_lion"))
	assert_eq(GameData.type_list.size(), 18)

func test_full_random_battle_ends() -> void:
	var t1 := [
		BattleRunner.make_set("renny", ["waterfall", "crunch", "rest", "sleep_talk"], "chesto_berry", "adamant", {"hp": 252, "atk": 252}),
		BattleRunner.make_set("jinpachi", ["flare_blitz", "close_combat", "swords_dance", "u_turn"], "life_orb", "jolly", {"atk": 252, "spe": 252}),
		BattleRunner.make_set("hyu", ["shadow_ball", "dark_pulse", "nasty_plot", "will_o_wisp"], "choice_specs", "timid", {"spa": 252, "spe": 252}),
	]
	var t2 := [
		BattleRunner.make_set("gel", ["blizzard", "freeze_dry", "aurora_veil", "protect"], "light_clay", "timid", {"spa": 252, "spe": 252}),
		BattleRunner.make_set("trans", ["sacred_sword", "stone_axe", "swords_dance", "psycho_cut"], "focus_sash", "adamant", {"atk": 252, "spe": 252}),
		BattleRunner.make_set("muni", ["minimize", "moonblast", "wish", "protect"], "leftovers", "bold", {"hp": 252, "def": 252}),
	]
	var b := Battle.new({"seed": 42, "teams": [t1, t2], "log": true})
	BattleRunner.run(b, RandomAI.new(1), RandomAI.new(2))
	assert_true(b.ended, "battle should end")
	assert_true(b.turn > 1, "should take more than one turn")
	var moves_used := 0
	for e in b.log:
		if e[0] == "move":
			moves_used += 1
	assert_true(moves_used > 3)
	if not b.ended:
		print(b.log_text())

func test_determinism_same_seed() -> void:
	var mk := func():
		return [[BattleRunner.make_set("namazuo", ["wild_charge", "iron_head", "swords_dance", "protect"], "life_orb", "jolly", {"atk": 252, "spe": 252}),
			BattleRunner.make_set("honebami", ["brave_bird", "iron_head", "swords_dance", "acrobatics"], "focus_sash", "jolly", {"atk": 252, "spe": 252})],
			[BattleRunner.make_set("gel_r_poison", ["poison_jab", "toxic", "recover", "haze"], "black_sludge", "impish", {"hp": 252, "def": 252}),
			BattleRunner.make_set("marutan", ["air_slash", "roost", "defog", "toxic"], "leftovers", "calm", {"hp": 252, "spd": 252})]]
	var b1 := Battle.new({"seed": 7, "teams": mk.call()})
	BattleRunner.run(b1, RandomAI.new(3), RandomAI.new(4))
	var b2 := Battle.new({"seed": 7, "teams": mk.call()})
	BattleRunner.run(b2, RandomAI.new(3), RandomAI.new(4))
	assert_eq(b1.log_text(), b2.log_text(), "same seed must reproduce identical battle")
	assert_eq(b1.winner, b2.winner)
