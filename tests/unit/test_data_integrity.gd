extends TestCase
## Data <-> code consistency and fixed-spec roster checks.

func before_each() -> void:
	GameData.ensure_loaded()

func test_all_species_learnset_moves_exist() -> void:
	for id in GameData.species:
		var sp: Dictionary = GameData.species[id]
		for e in sp["learnset"]["level"]:
			assert_true(GameData.moves.has(e["move"]), "%s level move %s" % [id, e["move"]])
		for m in sp["learnset"]["tm"]:
			assert_true(GameData.moves.has(m), "%s tm %s" % [id, m])

func test_all_abilities_and_items_have_implementations() -> void:
	var reg := EffectRegistry.get_instance()
	for id in GameData.abilities:
		assert_true(reg.has_effect("ability", id), "ability handler missing: " + id)
	for id in GameData.items:
		assert_true(reg.has_effect("item", id), "item handler missing: " + id)
	for id in GameData.species:
		for slot in GameData.species[id]["abilities"]:
			var ab = GameData.species[id]["abilities"][slot]
			assert_true(GameData.abilities.has(ab), "%s ability %s undefined" % [id, ab])

func test_all_move_effect_references_exist() -> void:
	var reg := EffectRegistry.get_instance()
	for id in GameData.moves:
		var m: Dictionary = GameData.moves[id]
		if m.has("effect"):
			assert_true(reg.has_effect("move_effect", m["effect"]), "move %s effect %s missing" % [id, m["effect"]])
		if m.has("volatile_status"):
			assert_true(reg.tables["volatile"].has(m["volatile_status"]), "move %s volatile %s missing" % [id, m["volatile_status"]])
		if m.has("side_condition"):
			assert_true(reg.tables["side"].has(m["side_condition"]), "move %s side %s missing" % [id, m["side_condition"]])
		if m.has("weather"):
			assert_true(GameData.weather.has(m["weather"]), "move %s weather" % id)
		if m.has("terrain"):
			assert_true(GameData.terrain.has(m["terrain"]), "move %s terrain" % id)
		if m.has("pseudo_weather"):
			assert_true(reg.tables["field"].has(m["pseudo_weather"]), "move %s field" % id)
		if m.has("status"):
			assert_true(reg.status_meta.has(m["status"]), "move %s status" % id)
		var sec_list: Array = []
		if m.has("secondary"): sec_list.append(m["secondary"])
		if m.has("secondaries"): sec_list.append_array(m["secondaries"])
		for s in sec_list:
			if s.has("volatile_status"):
				assert_true(reg.tables["volatile"].has(s["volatile_status"]), "move %s secondary volatile" % id)
			if s.has("status"):
				assert_true(reg.status_meta.has(s["status"]), "move %s secondary status" % id)
		assert_true(m["type"] == "???" or GameData.type_list.has(m["type"]), "move %s type" % id)
		assert_true(m["category"] in ["physical", "special", "status"], "move %s category" % id)

func test_localization_covers_all_ids() -> void:
	var L := GameData.localization
	for id in GameData.moves:
		assert_true(L["moves"].has(id), "ja name missing for move " + id)
	for id in GameData.species:
		assert_true(L["species"].has(id), "ja name missing for species " + id)
	for id in GameData.abilities:
		assert_true(L["abilities"].has(id), "ja name missing for ability " + id)
	for id in GameData.items:
		assert_true(L["items"].has(id), "ja name missing for item " + id)

## Fixed roster specification (types / abilities / signature moves) must never drift.
func test_roster_fixed_spec() -> void:
	var spec := {
		"renny": {"types": ["water"], "ability": "awakened_lion", "moves": ["waterfall", "rest"]},
		"jinpachi": {"types": ["fire"], "ability": "flame_domain", "moves": ["flamethrower", "flare_blitz"]},
		"hyu": {"types": ["ghost"], "ability": "dark_domain", "moves": ["shadow_ball"]},
		"muni": {"types": ["fairy"], "ability": "prankster", "moves": ["minimize"]},
		"gel": {"types": ["ice"], "ability": "snow_warning", "moves": ["blizzard", "ice_beam"]},
		"neo": {"types": ["fighting"], "ability": "sharpness", "hidden": "steadfast", "moves": ["swords_dance", "sacred_sword", "slash"]},
		"trans": {"types": ["fighting", "ground"], "ability": "sharpness", "hidden": "steadfast", "moves": ["swords_dance", "sacred_sword", "psycho_cut"]},
		"marutan": {"types": ["flying"], "ability": "sacred_light", "moves": ["roost"]},
		"namazuo": {"types": ["electric", "steel"], "ability": "static", "moves": ["swords_dance", "iron_head", "wild_charge", "night_slash"]},
		"honebami": {"types": ["steel", "flying"], "ability": "unburden", "moves": ["swords_dance", "iron_head", "drill_peck", "air_cutter"]},
		"jinpachi_r": {"types": ["rock"], "ability": "sturdy", "moves": ["stone_edge", "rock_slide"]},
		"hyu_r": {"types": ["grass"], "ability": "contrary", "moves": ["leaf_storm", "giga_drain"]},
		"renny_r": {"types": ["fairy"], "ability": "pixilate", "moves": ["body_slam", "double_edge"]},
		"muni_r_dragon": {"types": ["dragon"], "ability": "multiscale", "moves": ["dragon_pulse"]},
		"muni_r_bug": {"types": ["bug"], "ability": "compound_eyes", "moves": ["sleep_powder", "quiver_dance"]},
		"muni_r_normal": {"types": ["normal"], "ability": "minimal_body", "moves": ["minimize"]},
		"gel_r_poison": {"types": ["poison"], "ability": "intimidate", "moves": ["toxic", "recover"]},
		"gel_r_dark": {"types": ["dark"], "ability": "intimidate", "moves": ["knock_off"]},
		"trans_r": {"types": ["psychic"], "ability": "competitive", "moves": ["swords_dance", "psycho_cut"]},
	}
	for id in spec:
		var sp: Dictionary = GameData.species[id]
		assert_eq(sp["types"], spec[id]["types"], id + " types")
		assert_eq(sp["abilities"]["0"], spec[id]["ability"], id + " ability")
		if spec[id].has("hidden"):
			assert_eq(sp["abilities"].get("H", ""), spec[id]["hidden"], id + " hidden ability")
		var learn := PokemonSet.learnable_moves(id)
		for m in spec[id]["moves"]:
			assert_true(learn.has(m), "%s must learn %s" % [id, m])
	# slicing moves carry the flag for Sharpness
	for m in ["slash", "psycho_cut", "sacred_sword", "night_slash", "x_scissor", "air_cutter", "aqua_cutter", "leaf_blade", "cut", "stone_axe", "ceaseless_edge", "razor_shell", "kowtow_cleave", "solar_blade", "bitter_blade", "psyblade", "air_slash", "aerial_ace", "cross_poison", "fury_cutter", "razor_leaf", "population_bomb", "secret_sword"]:
		assert_true(GameData.moves[m]["flags"].has("slicing"), m + " must be slicing")

func test_bst_guidelines() -> void:
	for id in GameData.species:
		var bs: Dictionary = GameData.species[id]["base_stats"]
		var t := 0
		for k in bs:
			t += int(bs[k])
		if id == "neo":
			assert_in_range(t, 380, 420, id)
		elif id.begins_with("muni"):
			assert_in_range(t, 400, 440, id)
		else:
			assert_in_range(t, 500, 540, id)

func test_recommended_sets_are_legal() -> void:
	var sets := GameData._load_json("res://data/sets/sets.json")
	assert_eq(sets.size(), 19, "every species has sets")
	for sp in sets:
		assert_true(sets[sp].size() >= 2, sp + " needs >= 2 sets")
		for sd in sets[sp]:
			var ps := PokemonSet.from_dict({"species": sp, "moves": sd["moves"], "item": sd["item"], "nature": sd["nature"], "evs": sd["evs"], "ability": sd["ability"]})
			var errs := ps.validate()
			assert_true(errs.is_empty(), "%s/%s: %s" % [sp, sd["name"], str(errs)])
