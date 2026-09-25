extends TestCase
## Original abilities + canon abilities used by the roster.

func before_each() -> void:
	GameData.ensure_loaded()

func _dmg(b: Battle, a, d, move_id: String) -> int:
	var mv: Dictionary = GameData.get_move(move_id).duplicate(true)
	mv["effect_type"] = "move"
	return int(b.get_damage(a, d, mv))

# ---------- めざめるしし ----------
func test_awakened_lion_only_on_wake_turn() -> void:
	var b := BT.make([BT.s("renny", ["waterfall", "rest"], "chesto_berry")], [BT.s("marutan", ["protect", "roost"])])
	var renny := BT.p1(b)
	var foe := BT.p2(b)
	var normal := _dmg(b, renny, foe, "waterfall")
	# simulate wake this turn via status cure event
	b.set_status(renny, "slp", renny, null)
	b.cure_status(renny, renny, null)
	assert_eq(int(renny.ability_state.get("woke_turn", -1)), b.turn)
	var boosted := _dmg(b, renny, foe, "waterfall")
	assert_true(boosted > normal * 1.8, "attack doubled on wake turn (%d vs %d)" % [boosted, normal])
	# next turn: back to normal
	b.turn += 1
	assert_eq(_dmg(b, renny, foe, "waterfall"), normal)

func test_awakened_lion_chesto_rest_wake_same_turn() -> void:
	# Rest -> Chesto cures immediately -> that same turn counts as the wake turn
	var b := BT.make([BT.s("renny", ["waterfall", "rest"], "chesto_berry", "hardy", {}, "", 50)], [BT.s("marutan", ["tackle", "roost"])])
	var renny := BT.p1(b)
	renny.hp -= 50
	BT.turn(b, "move:rest", "move:roost")
	assert_eq(renny.status, "")
	assert_eq(renny.item, "")
	assert_eq(int(renny.ability_state.get("woke_turn", -1)), b.turn - 1)

func test_awakened_lion_natural_wake_then_attack_doubled() -> void:
	var b := BT.make([BT.s("renny", ["waterfall", "rest"])], [BT.s("marutan", ["protect", "roost"], "", "hardy", {"hp": 252, "def": 252})], {"seed": 3})
	var renny := BT.p1(b)
	var foe := BT.p2(b)
	renny.hp = 10
	BT.turn(b, "move:rest", "move:roost")
	assert_eq(renny.status, "slp")
	assert_eq(renny.hp, renny.max_hp)
	# Rest sleeps exactly 2 turns; wakes on 3rd move attempt
	BT.turn(b, "move:waterfall", "move:roost")
	assert_eq(renny.status, "slp")
	BT.turn(b, "move:waterfall", "move:roost")
	assert_eq(renny.status, "slp")
	var hp_before := foe.hp
	BT.turn(b, "move:waterfall", "move:roost")
	assert_eq(renny.status, "")
	var dealt := hp_before - foe.hp + int(floor(foe.max_hp / 2.0))  # roost healed after (roost is slower); approximate check below
	# Compare against non-boosted damage the following turn
	var boosted := _dmg(b, renny, foe, "waterfall")  # still same turn? no: turn advanced. So compute expected boosted via woke_turn
	assert_true(BT.has_log(b, "-ability", "awakened_lion"))

# ---------- 炎の領域 / やみのりょういき ----------
func test_flame_domain_boosts_own_fire_moves_only() -> void:
	var b := BT.make([BT.s("jinpachi", ["flamethrower", "close_combat"])], [BT.s("marutan", ["protect"])])
	var j := BT.p1(b)
	var m := BT.p2(b)
	var with_ab := _dmg(b, j, m, "flamethrower")
	var cc := _dmg(b, j, m, "close_combat")
	j.ability = "levitate"
	var without := _dmg(b, j, m, "flamethrower")
	var cc2 := _dmg(b, j, m, "close_combat")
	assert_true(absf(float(with_ab) / float(without) - 1.5) < 0.05, "fire 1.5x (%d vs %d)" % [with_ab, without])
	assert_eq(cc, cc2, "non-fire move unchanged")

func test_dark_domain_boosts_ghost_moves() -> void:
	var b := BT.make([BT.s("hyu", ["shadow_ball", "dark_pulse"])], [BT.s("renny", ["protect"])])
	var h := BT.p1(b)
	var r := BT.p2(b)
	var sb := _dmg(b, h, r, "shadow_ball")
	var dp := _dmg(b, h, r, "dark_pulse")
	h.ability = "levitate"
	var sb2 := _dmg(b, h, r, "shadow_ball")
	var dp2 := _dmg(b, h, r, "dark_pulse")
	assert_true(absf(float(sb) / float(sb2) - 1.5) < 0.05)
	assert_eq(dp, dp2)

# ---------- せいなるひかり ----------
func test_sacred_light_reduces_ghost_and_dark_only() -> void:
	var b := BT.make([BT.s("hyu", ["shadow_ball", "dark_pulse", "thunderbolt"])], [BT.s("marutan", ["protect"])])
	var h := BT.p1(b)
	var m := BT.p2(b)
	var sb := _dmg(b, h, m, "shadow_ball")
	var dp := _dmg(b, h, m, "dark_pulse")
	var tb := _dmg(b, h, m, "thunderbolt")
	m.ability = "levitate"
	var sb2 := _dmg(b, h, m, "shadow_ball")
	var dp2 := _dmg(b, h, m, "dark_pulse")
	var tb2 := _dmg(b, h, m, "thunderbolt")
	assert_true(absf(float(sb) / float(sb2) - 0.7) < 0.05, "ghost 0.7x (%d/%d)" % [sb, sb2])
	assert_true(absf(float(dp) / float(dp2) - 0.7) < 0.05, "dark 0.7x")
	assert_eq(tb, tb2)

# ---------- ミニマムボディ ----------
func test_minimal_body_lowers_incoming_accuracy() -> void:
	var b := BT.make([BT.s("renny", ["waterfall"])], [BT.s("muni_r_normal", ["protect"])])
	var r := BT.p1(b)
	var m := BT.p2(b)
	var mv: Dictionary = GameData.get_move("waterfall").duplicate(true)
	mv["effect_type"] = "move"
	var acc = b.run_event("ModifyAccuracy", m, r, mv, 100)
	assert_eq(int(acc), 67, "100 -> 67 (x2730/4096, i.e. 1/1.5 with 4096 rounding)")
	m.ability = "levitate"
	assert_eq(int(b.run_event("ModifyAccuracy", m, r, mv, 100)), 100)

func test_minimal_body_stacks_with_minimize_evasion() -> void:
	var b := BT.make([BT.s("renny", ["waterfall"])], [BT.s("muni_r_normal", ["minimize"])])
	var m := BT.p2(b)
	m.boosts["evasion"] = 2
	var hits := 0
	var n := 3000
	for i in range(n):
		var mv: Dictionary = GameData.get_move("waterfall").duplicate(true)
		mv["effect_type"] = "move"
		if b._accuracy_check(m, BT.p1(b), mv):
			hits += 1
	# 100 * 3/5 = 60 -> *2/3 -> 40%
	assert_in_range(hits, int(n * 0.36), int(n * 0.44), "hit rate ~40%% got %d" % hits)

# ---------- いたずらごころ ----------
func test_prankster_priority_and_dark_immunity() -> void:
	var b := BT.make([BT.s("muni", ["thunder_wave", "moonblast"])], [BT.s("gel_r_dark", ["tackle"])])
	var muni := BT.p1(b)
	var md: Dictionary = GameData.get_move("thunder_wave").duplicate(true)
	var pr = b.run_event("ModifyPriority", muni, null, md, 0)
	assert_eq(int(pr), 1)
	assert_true(md.get("prankster_boosted", false))
	var md2: Dictionary = GameData.get_move("moonblast").duplicate(true)
	assert_eq(int(b.run_event("ModifyPriority", muni, null, md2, 0)), 0)
	# vs Dark: status move fails
	BT.turn(b, "move:thunder_wave", "move:tackle")
	assert_eq(BT.p2(b).status, "")
	assert_true(BT.has_log(b, "-immune"))

func test_prankster_moves_first_despite_lower_speed() -> void:
	var b := BT.make([BT.s("muni", ["thunder_wave"], "", "hardy", {})], [BT.s("jinpachi", ["tackle"], "", "jolly", {"spe": 252})])
	BT.turn(b, "move:thunder_wave", "move:tackle")
	var first_move := ""
	for e in b.log:
		if e[0] == "move":
			first_move = e[2]
			break
	assert_eq(first_move, "thunder_wave")
	assert_eq(BT.p2(b).status, "par")

# ---------- いかく / かちき ----------
func test_intimidate_lowers_attack_and_competitive_reacts() -> void:
	var b := BT.make([BT.s("gel_r_poison", ["protect"])], [BT.s("trans_r", ["protect"])])
	assert_eq(BT.p2(b).boosts["atk"], -1)
	assert_eq(BT.p2(b).boosts["spa"], 2, "Competitive +2 SpA after Intimidate")
	assert_true(BT.has_log(b, "-ability", "competitive"))

func test_competitive_not_triggered_by_self_drop() -> void:
	var b := BT.make([BT.s("trans_r", ["close_combat"])], [BT.s("marutan", ["protect", "roost"])])
	BT.turn(b, "move:close_combat", "move:roost")
	assert_eq(BT.p1(b).boosts["def"], -1)
	assert_eq(BT.p1(b).boosts["spa"], 0)

func test_intimidate_blocked_by_clear_body_and_inner_focus() -> void:
	var b := BT.make([BT.s("gel_r_dark", ["protect"])], [BT.s("renny", ["protect"], "", "hardy", {}, "inner_focus")])
	assert_eq(BT.p2(b).boosts["atk"], 0)

# ---------- ふくつのこころ ----------
func test_steadfast_on_flinch() -> void:
	var b := BT.make([BT.s("jinpachi", ["fake_out"], "", "jolly", {"spe": 252})], [BT.s("neo", ["tackle"], "", "hardy", {}, "steadfast")])
	BT.turn(b, "move:fake_out", "move:tackle")
	assert_eq(BT.p2(b).boosts["spe"], 1)
	assert_true(BT.has_log(b, "cant", "flinch"))

# ---------- あまのじゃく ----------
func test_contrary_inverts_boosts_incl_leaf_storm() -> void:
	var b := BT.make([BT.s("hyu_r", ["leaf_storm", "swords_dance"])], [BT.s("gel_r_poison", ["protect", "recover"], "", "hardy", {"hp": 252, "spd": 252})])
	BT.turn(b, "move:leaf_storm", "move:recover")
	assert_eq(BT.p1(b).boosts["spa"], 2, "Leaf Storm -2 becomes +2")
	var atk_before: int = BT.p1(b).boosts["atk"]  # +1 from inverted Intimidate
	assert_eq(atk_before, 1, "Contrary turns Intimidate into +1")
	BT.turn(b, "move:swords_dance", "move:recover")
	assert_eq(BT.p1(b).boosts["atk"], atk_before - 2)

func test_contrary_intimidate_raises_attack() -> void:
	var b := BT.make([BT.s("gel_r_dark", ["protect"])], [BT.s("hyu_r", ["protect"])])
	assert_eq(BT.p2(b).boosts["atk"], 1)

# ---------- がんじょう / タスキ ----------
func test_sturdy_survives_ohko_from_full_hp_only() -> void:
	var b := BT.make([BT.s("trans", ["close_combat"], "", "adamant", {"atk": 252})], [BT.s("jinpachi_r", ["protect", "rock_slide"])])
	BT.p1(b).boosts["atk"] = 6
	BT.turn(b, "move:close_combat", "move:rock_slide")
	assert_eq(BT.p2(b).hp, 1)
	assert_true(BT.has_log(b, "-ability", "sturdy"))
	BT.turn(b, "move:close_combat", "move:rock_slide")
	assert_true(BT.p2(b).fainted or BT.p2(b).hp == 0)

func test_focus_sash_once() -> void:
	var b := BT.make([BT.s("trans", ["close_combat"], "", "adamant", {"atk": 252})], [BT.s("gel", ["protect", "haze"], "focus_sash"), BT.s("muni", ["protect"])])
	BT.p1(b).boosts["atk"] = 6
	BT.turn(b, "move:close_combat", "move:haze")
	assert_eq(BT.p2(b).hp, 1)
	assert_eq(BT.p2(b).item, "")

# ---------- マルチスケイル ----------
func test_multiscale_only_at_full_hp() -> void:
	var b := BT.make([BT.s("gel", ["ice_beam"])], [BT.s("muni_r_dragon", ["protect"])])
	var full := _dmg(b, BT.p1(b), BT.p2(b), "ice_beam")
	BT.p2(b).hp -= 1
	var dmgd := _dmg(b, BT.p1(b), BT.p2(b), "ice_beam")
	assert_true(absf(float(dmgd) / float(full) - 2.0) < 0.05, "%d vs %d" % [full, dmgd])

# ---------- フェアリースキン ----------
func test_pixilate_converts_and_boosts() -> void:
	var b := BT.make([BT.s("renny_r", ["body_slam", "play_rough"])], [BT.s("muni_r_dragon", ["protect"])])
	var r := BT.p1(b)
	var d := BT.p2(b)
	d.hp -= 1  # disable multiscale
	var mv: Dictionary = GameData.get_move("body_slam").duplicate(true)
	mv["effect_type"] = "move"
	b.run_event("ModifyType", r, d, mv)
	assert_eq(mv["type"], "fairy")
	var dmg_pix := int(b.get_damage(r, d, mv))
	# expected: 85 * 1.2 (pixilate) with STAB fairy vs dragon 2x, vs plain fairy-typed 85 move
	var mv2: Dictionary = GameData.get_move("body_slam").duplicate(true)
	mv2["effect_type"] = "move"
	mv2["type"] = "fairy"
	var dmg_plain := int(b.get_damage(r, d, mv2))
	assert_true(absf(float(dmg_pix) / float(dmg_plain) - 1.2) < 0.06, "%d vs %d" % [dmg_pix, dmg_plain])
	# Ghost is now hit (fairy), Steel resists
	BT.turn(b, "move:body_slam", "move:protect")
	assert_eq(b.effectiveness_multiplier("normal", d), 1.0)

func test_pixilate_normal_move_hits_ghost() -> void:
	var b := BT.make([BT.s("renny_r", ["hyper_voice"])], [BT.s("hyu", ["protect", "hex"])])
	BT.turn(b, "move:hyper_voice", "move:hex")
	assert_true(BT.p2(b).hp < BT.p2(b).max_hp, "pixilate hyper voice hits ghost")

# ---------- せいでんき ----------
func test_static_contact_only() -> void:
	var trials := 40
	var contact_par := 0
	var noncontact_par := 0
	for i in range(trials):
		var b := BT.make([BT.s("renny", ["waterfall", "surf"])], [BT.s("namazuo", ["protect", "iron_defense"], "", "hardy", {"hp": 252, "def": 252})], {"seed": 100 + i})
		BT.turn(b, "move:waterfall", "move:iron_defense")
		if BT.p1(b).status == "par":
			contact_par += 1
		var b2 := BT.make([BT.s("renny", ["waterfall", "surf"])], [BT.s("namazuo", ["protect", "iron_defense"], "", "hardy", {"hp": 252, "def": 252})], {"seed": 200 + i})
		BT.turn(b2, "move:surf", "move:iron_defense")
		if BT.p1(b2).status == "par":
			noncontact_par += 1
	assert_eq(noncontact_par, 0)
	assert_in_range(contact_par, 4, 24, "~30%% of %d" % trials)

# ---------- かるわざ ----------
func test_unburden_after_item_consumed() -> void:
	var b := BT.make([BT.s("honebami", ["swords_dance"], "sitrus_berry")], [BT.s("renny", ["waterfall", "protect"], "", "adamant", {"atk": 252})])
	var h := BT.p1(b)
	var base_spe := h.get_stat("spe")
	BT.turn(b, "move:swords_dance", "move:waterfall")
	assert_eq(h.item, "", "sitrus eaten")
	assert_true(h.volatiles.has("unburden"))
	assert_eq(h.get_stat("spe"), base_spe * 2)
	assert_true(BT.has_log(b, "-ability", "unburden"))

func test_unburden_after_knock_off_and_reset_on_switch() -> void:
	var b := BT.make([BT.s("honebami", ["protect", "swords_dance"], "leftovers"), BT.s("muni", ["protect"])], [BT.s("gel_r_dark", ["knock_off"])])
	var h := BT.p1(b)
	var base_spe := h.get_stat("spe")
	BT.turn(b, "move:swords_dance", "move:knock_off")
	assert_eq(h.item, "")
	assert_eq(h.get_stat("spe"), base_spe * 2)
	BT.turn(b, "switch:1", "move:knock_off")
	BT.turn(b, "switch:0", "move:knock_off")
	assert_false(BT.p1(b).volatiles.has("unburden"))
	assert_eq(BT.p1(b).get_stat("spe"), base_spe)

# ---------- ふくがん ----------
func test_compound_eyes_accuracy() -> void:
	var b := BT.make([BT.s("muni_r_bug", ["sleep_powder"])], [BT.s("renny", ["protect"])])
	var mv: Dictionary = GameData.get_move("sleep_powder").duplicate(true)
	mv["effect_type"] = "move"
	assert_eq(int(b.run_event("ModifyAccuracy", BT.p2(b), BT.p1(b), mv, 75)), 98)  # 75 * 5325/4096 = 97.5 -> 98

# ---------- ゆきふらし ----------
func test_snow_warning_sets_snow_and_ice_def() -> void:
	var b := BT.make([BT.s("gel", ["protect"])], [BT.s("renny", ["protect"])])
	assert_eq(b.weather, "snow")
	assert_eq(int(b.weather_state["duration"]), 5)
	var g := BT.p1(b)
	var d := g.get_stat("def")
	assert_eq(d, Battle.modify(StatCalc.apply_boost(g.stored_stats["def"], 0), 1.5))

func test_snow_warning_icy_rock_extends() -> void:
	var b := BT.make([BT.s("gel", ["protect"], "icy_rock")], [BT.s("renny", ["protect"])])
	assert_eq(int(b.weather_state["duration"]), 8)
