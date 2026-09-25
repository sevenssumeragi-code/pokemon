extends TestCase
## MapData queries, event interpreter, content consistency.

func before_each() -> void:
	GameData.ensure_loaded()
	MapData.clear_cache()

func test_all_maps_load_and_warps_are_consistent() -> void:
	var ids := MapData.all_map_ids()
	assert_true(ids.size() >= 5, "maps: " + str(ids))
	for id in ids:
		var m := MapData.load_map(id)
		assert_not_null(m, id)
		assert_eq(m.tiles.size(), m.height, id)
		for w in m.warps:
			assert_true(bool(m.tile_def(int(w["x"]), int(w["y"])).get("walkable", false)), "%s warp tile walkable" % id)
			var dest := MapData.load_map(str(w["map"]))
			assert_not_null(dest, "%s -> %s exists" % [id, w["map"]])
			assert_true(dest.in_bounds(int(w["tx"]), int(w["ty"])) and bool(dest.tile_def(int(w["tx"]), int(w["ty"])).get("walkable", false)), "%s -> %s (%d,%d) walkable" % [id, w["map"], w["tx"], w["ty"]])
		for n in m.npcs:
			assert_true(m.in_bounds(int(n["x"]), int(n["y"])), "%s npc %s in bounds" % [id, n["id"]])
			assert_true(FileAccess.file_exists("res://data/events/%s.json" % n["event"]), "%s npc event %s exists" % [id, n["event"]])
		for e in m.events:
			assert_true(FileAccess.file_exists("res://data/events/%s.json" % e["event"]), "%s event %s exists" % [id, e["event"]])
		for e in m.encounters.get("table", []):
			assert_true(GameData.species.has(e["species"]), "%s encounter species %s" % [id, e["species"]])

func test_event_text_and_trainers_exist() -> void:
	var dir := DirAccess.open("res://data/events")
	dir.list_dir_begin()
	var f := dir.get_next()
	var text: Dictionary = GameData.localization.get("text", {})
	while f != "":
		if f.ends_with(".json"):
			_check_cmds(EventRunner.load_event(f.get_basename()), text, f)
		f = dir.get_next()

func _check_cmds(cmds: Array, text: Dictionary, src: String) -> void:
	for c in cmds:
		if c.has("text") and c["cmd"] != "starter_choice":
			assert_true(text.has(c["text"]), "%s text key %s" % [src, c["text"]])
		if c["cmd"] == "trainer_battle":
			assert_true(FileAccess.file_exists("res://data/trainers/%s.json" % c["trainer"]), "trainer %s" % c["trainer"])
		if c["cmd"] == "give_item":
			assert_true(GameData.items.has(c["item"]), "item %s" % c["item"])
		for k in ["then", "else", "win", "lose"]:
			if c.has(k):
				_check_cmds(c[k], text, src)
		if c.has("results"):
			for r in c["results"]:
				_check_cmds(r, text, src)

func test_walkability_and_encounter_roll() -> void:
	var m := MapData.load_map("field")
	assert_false(m.is_walkable(0, 0), "tree border")
	assert_true(m.is_walkable(8, 1), "path")
	assert_true(m.is_encounter_tile(2, 2), "tall grass")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var hits := 0
	var species := {}
	for i in range(2000):
		var e := m.roll_encounter(rng)
		if not e.is_empty():
			hits += 1
			species[e["species"]] = true
			assert_in_range(e["level"], 3, 8)
	assert_in_range(hits, 200, 360, "rate 14%%: %d/2000" % hits)
	assert_true(species.size() >= 4)

func test_npc_hidden_by_flag() -> void:
	var m := MapData.load_map("town")
	var g := GameState.new()
	assert_not_null(m.npc_at(7, 12, g), "blocker present before starter")
	g.set_flag("got_starter", true)
	assert_true(m.npc_at(7, 12, g) == null, "blocker gone after starter")

func test_event_runner_prof_flow() -> void:
	var g := GameState.new()
	var r := EventRunner.new(g)
	r.start("prof_talk")
	var req := r.next()
	assert_eq(req["type"], "message")
	assert_true(req["text"].contains("はかせ"))
	r.resume()
	req = r.next(); r.resume()
	req = r.next(); r.resume()
	req = r.next()
	assert_eq(req["type"], "starter_choice")
	assert_eq(req["options"].size(), 3)
	r.resume(1)  # jinpachi
	assert_eq(g.party.size(), 1)
	assert_eq(g.party[0].species, "jinpachi")
	assert_eq(g.party[0].level, 5)
	req = r.next()  # prof_4 message
	assert_eq(req["type"], "message"); r.resume()
	req = r.next()  # give balls
	assert_eq(req["type"], "message"); r.resume()
	assert_eq(int(g.bag.get("monster_ball", 0)), 5)
	req = r.next(); r.resume()  # potions
	req = r.next(); r.resume()  # prof_5
	req = r.next()
	assert_eq(req["type"], "done")
	assert_true(bool(g.flag("got_starter")))
	# second visit branches
	r.start("prof_talk")
	req = r.next()
	assert_true(req["text"].contains("守り手"))

func test_event_runner_battle_branches() -> void:
	var g := GameState.new()
	var r := EventRunner.new(g)
	r.start("trainer_a")
	var req := r.next(); r.resume()
	req = r.next()
	assert_eq(req["type"], "trainer_battle")
	r.resume(true)
	req = r.next()
	assert_eq(req["type"], "message")
	r.resume()
	req = r.next()
	assert_eq(req["type"], "message", "money message")
	r.resume()
	assert_eq(g.money, 3400)
	assert_true(bool(g.flag("trainer_a_beaten")))
	var g2 := GameState.new()
	var r2 := EventRunner.new(g2)
	r2.start("trainer_a")
	r2.next(); r2.resume()
	r2.next(); r2.resume(false)
	assert_eq(r2.next()["type"], "done")
	assert_false(bool(g2.flag("trainer_a_beaten")))

func test_doubles_trainer_builds_doubles_battle() -> void:
	var g := GameState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	g.party = [PokemonSet.generate("renny", 20, rng), PokemonSet.generate("gel", 20, rng)]
	var b := BattleFlow.make_trainer_battle(g, "hall_master", rng)
	assert_eq(b.slots_per_side, 2)
	b.start()
	assert_eq(b.sides[1].active_pokemon().size(), 2)
	assert_eq(b.sides[0].active_pokemon().size(), 2)
	var t := BattleFlow.make_trainer_battle(g, "boss", rng)
	assert_eq(t.slots_per_side, 1)
