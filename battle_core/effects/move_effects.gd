class_name MoveEffects
extends RefCounted
## Named move effect handlers referenced from move data via "effect": "<id>".
## Events: Try, TryMove, TryHit, PrepareHit, Hit, AfterHit, AfterSubDamage, ModifyMove,
##         BasePower, BasePowerCallback, DamageCallback, Effectiveness, MoveFail, Miss, ModifyType
## Handler signature: func(b, p, ev) -> Variant   (p = holder: the target pokemon for target-side events)
## In move events ev["target"] is the move target and ev["source"] is the user.

func build() -> Dictionary:
	return {
		"protect": {"onPrepareHit": _protect_prepare, "onHit": _protect_hit},
		"substitute": {"onTryHit": _substitute_try_hit, "onHit": _substitute_hit},
		"rest": {"onTry": _rest_try, "onHit": _rest_hit},
		"sleep_talk": {"onTry": _sleep_talk_try, "onHit": _sleep_talk_hit},
		"snore": {"onTry": _sleep_talk_try},
		"baton_pass": {"onTry": _needs_bench_try},
		"teleport": {"onTry": _needs_bench_try},
		"rapid_spin": {"onAfterHit": _rapid_spin_after, "onAfterSubDamage": _rapid_spin_after},
		"defog": {"onHit": _defog_hit},
		"haze": {"onHit": _haze_hit},
		"clear_smog": {"onHit": _clear_smog_hit},
		"heal_bell": {"onHit": _heal_bell_hit},
		"knock_off": {"onBasePowerCallback": _knock_off_bp, "onAfterHit": _knock_off_after},
		"trick": {"onTryHit": _trick_try_hit, "onHit": _trick_hit},
		"weather_heal": {"onHit": _weather_heal_hit},
		"shore_up": {"onHit": _shore_up_hit},
		"wish": {"onTry": _wish_try, "onHit": _wish_hit},
		"pain_split": {"onHit": _pain_split_hit},
		"yawn": {"onTryHit": _yawn_try_hit},
		"toxic": {"onModifyMove": _toxic_modify},
		"curse": {"onModifyMove": _curse_modify, "onTryHit": _curse_try_hit, "onHit": _curse_hit},
		"belly_drum": {"onHit": _belly_drum_hit},
		"counter": {"onDamageCallback": _counter_damage},
		"mirror_coat": {"onDamageCallback": _mirror_coat_damage},
		"final_gambit": {"onAfterHit": _final_gambit_after},
		"fake_out": {"onTry": _first_turn_try},
		"sucker_punch": {"onTry": _sucker_punch_try},
		"charge_move": {"onTryMove": _charge_try_move},
		"aurora_veil": {"onTry": _aurora_veil_try},
		"growth": {"onModifyMove": _growth_modify},
		"weather_ball": {"onModifyMove": _weather_ball_modify},
		"freeze_dry": {"onEffectiveness": _freeze_dry_eff},
		"psyblade": {"onBasePower": _psyblade_bp},
		"expanding_force": {"onBasePower": _expanding_force_bp, "onModifyMove": _expanding_force_modify},
		"grassy_glide": {},
		"misty_explosion": {"onBasePower": _misty_explosion_bp},
		"stone_axe": {"onAfterHit": _stone_axe_after, "onAfterSubDamage": _stone_axe_after},
		"ceaseless_edge": {"onAfterHit": _ceaseless_edge_after, "onAfterSubDamage": _ceaseless_edge_after},
		"brick_break": {"onTryHit": _brick_break_try_hit},
		"ice_spinner": {"onAfterHit": _ice_spinner_after},
		"stomping_tantrum": {"onBasePowerCallback": _stomping_tantrum_bp},
		"assurance": {"onBasePowerCallback": _assurance_bp},
		"fury_cutter": {"onBasePowerCallback": _fury_cutter_bp},
		"false_swipe": {"onDamage": null},
		"tri_attack": {"onHit": _tri_attack_hit},
		"dream_eater": {"onTryHit": _dream_eater_try_hit},
		"high_jump_kick": {"onMoveFail": _hjk_fail, "onMiss": _hjk_fail},
		"steel_beam": {"onAfterHit": _steel_beam_after, "onAfterSubDamage": _steel_beam_after, "onMiss": _steel_beam_after},
		"poltergeist": {"onTry": _poltergeist_try},
		"trap_move": {"onTryHit": _trap_move_try_hit},
		"perish_song": {"onHit": _perish_song_hit},
		"strength_sap": {"onHit": _strength_sap_hit},
		"heal_pulse": {"onHit": _heal_pulse_hit},
		"psych_up": {"onHit": _psych_up_hit},
		"soak": {"onHit": _soak_hit},
		"future_sight": {"onTry": _future_sight_try},
		"encore": {},
		"struggle": {"onAfterHit": _struggle_recoil, "onAfterSubDamage": _struggle_recoil},
		"self_destruct": {},
		"memento": {"onAfterHit": _faint_user_after},
		"lock_on": {},
		"electro_shot": {},
		"synchronoise": {},
		"acupressure": {"onHit": _acupressure_hit},
		"meteor_beam": {"onTryMove": _meteor_beam_try_move},
	}

func _me(id: String) -> Dictionary:
	return {"id": id, "effect_type": "move"}

# ---------------- protect family ----------------
func _protect_prepare(b, p, ev):
	var user = ev["source"]
	var will_act := false
	for a in b.queue:
		if a.get("choice") == "move":
			will_act = true
			break
	if not will_act:
		return false
	var r = b.run_event("StallMove", user)
	if Battle.is_false(r):
		return false
	return null

func _protect_hit(b, p, ev):
	var user = ev["source"]
	b.add_volatile(user, "stall", user, ev["move"])
	return null

# ---------------- substitute ----------------
func _substitute_try_hit(b, p, ev):
	var user = ev["source"]
	if user.volatiles.has("substitute"):
		b.add_log(["-fail", b.pid(user), "substitute"])
		return false
	if user.hp <= int(floor(user.max_hp / 4.0)) or user.max_hp == 1:
		b.add_log(["-fail", b.pid(user), "substitute", "[weak]"])
		return false
	return null

func _substitute_hit(b, p, ev):
	var user = ev["source"]
	var cost := int(floor(user.max_hp / 4.0))
	user.hp -= cost
	b.add_log(["-damage", b.pid(user), user.hp, user.max_hp, "substitute"])
	return null

# ---------------- rest / sleep talk ----------------
func _rest_try(b, p, ev):
	var user = ev["source"]
	if user.status == "slp":
		return false
	if user.hp >= user.max_hp:
		b.add_log(["-fail", b.pid(user), "heal"])
		return false
	if Battle.is_false(b.run_event("SetStatus", user, user, ev["move"], "slp")):
		return false
	return null

func _rest_hit(b, p, ev):
	var user = ev["source"]
	if not b.set_status(user, "slp", user, ev["move"], false, true):
		return false
	b.heal_pokemon(user, user.max_hp, user, ev["move"])
	return true

func _sleep_talk_try(b, p, ev):
	var user = ev["source"]
	if user.status != "slp":
		return false
	return null

func _sleep_talk_hit(b, p, ev):
	var user = ev["source"]
	var options: Array = []
	for m in user.moves:
		var md := GameData.get_move(m["id"])
		if md.is_empty() or md.get("no_sleep_talk", false) or m["id"] == ev["move"]["id"]:
			continue
		options.append(m["id"])
	if options.is_empty():
		return false
	var pick: String = b.rng.sample(options)
	b.run_move(user, pick, 0, {"external": true, "source_effect": "sleep_talk"})
	return true

func _needs_bench_try(b, p, ev):
	var user = ev["source"]
	if not user.side.has_alive_bench():
		return false
	return null

# ---------------- hazard removal ----------------
func _remove_hazards(b, side) -> bool:
	var did := false
	for h in ["spikes", "stealth_rock", "toxic_spikes", "sticky_web"]:
		if b.remove_side_condition(side, h):
			did = true
	return did

func _rapid_spin_after(b, p, ev):
	var user = ev["source"]
	if user.fainted:
		return null
	if user.volatiles.has("leech_seed"):
		b.remove_volatile(user, "leech_seed")
	if user.volatiles.has("partially_trapped"):
		b.remove_volatile(user, "partially_trapped")
	_remove_hazards(b, user.side)
	return null

func _defog_hit(b, p, ev):
	var user = ev["source"]
	var target = ev["target"]
	var did := false
	for sc in ["reflect", "light_screen", "aurora_veil", "safeguard", "mist"]:
		if b.remove_side_condition(target.side, sc):
			did = true
	if _remove_hazards(b, target.side):
		did = true
	if _remove_hazards(b, user.side):
		did = true
	if b.terrain != "":
		b.clear_terrain()
		did = true
	return true if did else null

func _haze_hit(b, p, ev):
	for a in b.all_active():
		a.clear_boosts()
	b.add_log(["-clearallboost"])
	return true

func _clear_smog_hit(b, p, ev):
	var target = ev["target"]
	target.clear_boosts()
	b.add_log(["-clearboost", b.pid(target)])
	return null

func _heal_bell_hit(b, p, ev):
	var user = ev["source"]
	var did := false
	for m in user.side.team:
		if m.fainted:
			continue
		if m.status != "":
			if m.active:
				b.cure_status(m, user, ev["move"])
			else:
				m.status = ""
				m.status_state = {}
			did = true
	return true if did else false

# ---------------- items ----------------
func _knock_off_bp(b, p, ev):
	var target = ev["target"]
	var bp := int(ev["move"]["power"])
	if target != null and target.item != "" and not Battle.is_false(b.run_event("TakeItem", target, ev["source"], null, target.item)):
		return int(floor(bp * 1.5))
	return bp

func _knock_off_after(b, p, ev):
	var target = ev["target"]
	var user = ev["source"]
	if target == null or target.fainted or user.fainted or target.item == "":
		return null
	var item = b.take_item(target, user)
	if item != "":
		b.add_log(["-enditem", b.pid(target), item, "[from] move: knock_off"])
	return null

func _trick_try_hit(b, p, ev):
	var user = ev["source"]
	var target = ev["target"]
	if user.item == "" and target.item == "":
		return false
	return null

func _trick_hit(b, p, ev):
	var user = ev["source"]
	var target = ev["target"]
	var my = user.item
	var their = target.item
	if their != "" and Battle.is_false(b.run_event("TakeItem", target, user, null, their)):
		return false
	if my != "":
		b.single_event("End", "item", my, user.item_state, user)
	if their != "":
		b.single_event("End", "item", their, target.item_state, target)
	user.item = their
	user.item_state = {}
	target.item = my
	target.item_state = {}
	if their == "":
		user.last_item = my
		b.run_event("AfterTakeItem", user, target, null, my)
	if my == "":
		target.last_item = their
		b.run_event("AfterTakeItem", target, user, null, their)
	if user.item != "":
		b.single_event("Start", "item", user.item, user.item_state, user)
	if target.item != "":
		b.single_event("Start", "item", target.item, target.item_state, target)
	b.add_log(["-item", b.pid(user), user.item, "[from] move: trick"])
	b.add_log(["-item", b.pid(target), target.item, "[from] move: trick"])
	return true

# ---------------- healing ----------------
func _weather_heal_hit(b, p, ev):
	var user = ev["source"]
	var num := 1
	var den := 2
	if b.weather == "sun":
		num = 2; den = 3
	elif b.weather != "":
		num = 1; den = 4
	var healed = b.heal_pokemon(user, maxi(1, int(floor(user.max_hp * num / float(den)))), user, ev["move"])
	return true if healed > 0 else false

func _shore_up_hit(b, p, ev):
	var user = ev["source"]
	var num := 1
	var den := 2
	if b.weather == "sand":
		num = 2; den = 3
	var healed = b.heal_pokemon(user, maxi(1, int(floor(user.max_hp * num / float(den)))), user, ev["move"])
	return true if healed > 0 else false

func _wish_try(b, p, ev):
	var user = ev["source"]
	if user.side.slot_conditions.get(user.position, {}).has("wish"):
		return false
	return null

func _wish_hit(b, p, ev):
	var user = ev["source"]
	b.add_slot_condition(user.side, user.position, "wish", user, ev["move"], {"hp": int(floor(user.max_hp / 2.0))})
	return true

func _pain_split_hit(b, p, ev):
	var user = ev["source"]
	var target = ev["target"]
	var avg := int(floor((user.hp + target.hp) / 2.0))
	for x in [user, target]:
		if x.hp > avg:
			x.hp = avg
			b.add_log(["-sethp", b.pid(x), x.hp, x.max_hp, "pain_split"])
		elif x.hp < avg:
			b.heal_pokemon(x, avg - x.hp, user, ev["move"])
	return true

func _heal_pulse_hit(b, p, ev):
	var target = ev["target"]
	var healed = b.heal_pokemon(target, maxi(1, int(floor(target.max_hp / 2.0))), ev["source"], ev["move"])
	return true if healed > 0 else false

func _strength_sap_hit(b, p, ev):
	var user = ev["source"]
	var target = ev["target"]
	if target.boosts["atk"] <= -6:
		return false
	var atk = target.get_stat("atk")
	var ok = b.boost(target, {"atk": -1}, user, ev["move"])
	if not ok:
		return false
	b.heal_pokemon(user, atk, target, ev["move"])
	return true

# ---------------- status moves ----------------
func _yawn_try_hit(b, p, ev):
	var target = ev["target"]
	if target.status != "" or target.volatiles.has("yawn"):
		return false
	if Battle.is_false(b.run_event("SetStatus", target, ev["source"], ev["move"], "slp")):
		return false
	return null

func _toxic_modify(b, p, ev):
	var user = ev["source"]
	if user.has_type("poison"):
		ev["move"]["accuracy"] = true
	return null

func _curse_modify(b, p, ev):
	var user = ev["source"]
	if not user.has_type("ghost"):
		ev["move"]["target"] = "self"
	return null

func _curse_try_hit(b, p, ev):
	var user = ev["source"]
	var target = ev["target"]
	if user.has_type("ghost"):
		if target == user:
			return false
		if target.volatiles.has("curse"):
			return false
	return null

func _curse_hit(b, p, ev):
	var user = ev["source"]
	var target = ev["target"]
	if user.has_type("ghost"):
		if not b.add_volatile(target, "curse", user, ev["move"]):
			return false
		user.hp = maxi(0, user.hp - int(floor(user.max_hp / 2.0)))
		b.add_log(["-damage", b.pid(user), user.hp, user.max_hp, "curse"])
		if user.hp <= 0:
			b.faint(user, user, ev["move"])
		return true
	return b.boost(user, {"atk": 1, "def": 1, "spe": -1}, user, ev["move"])

func _belly_drum_hit(b, p, ev):
	var user = ev["source"]
	if user.hp <= int(floor(user.max_hp / 2.0)) or user.boosts["atk"] >= 6:
		return false
	user.hp -= int(floor(user.max_hp / 2.0))
	b.add_log(["-damage", b.pid(user), user.hp, user.max_hp, "belly_drum"])
	b.boost(user, {"atk": 12}, user, ev["move"])
	return true

func _tri_attack_hit(b, p, ev):
	var target = ev["target"]
	if target == null or target.fainted or b.rng.next(100) >= 20:
		return null
	var st: String = ["brn", "par", "frz"][b.rng.next(3)]
	b.set_status(target, st, ev["source"], ev["move"])
	return null

func _dream_eater_try_hit(b, p, ev):
	var target = ev["target"]
	if target.status != "slp":
		return false
	return null

func _trap_move_try_hit(b, p, ev):
	var target = ev["target"]
	if target.has_type("ghost"):
		b.add_log(["-immune", b.pid(target)])
		return false
	return null

func _perish_song_hit(b, p, ev):
	var did := false
	for a in b.all_active():
		if GameData.get_ability(a.ability).get("flags", {}).get("soundproof", false):
			continue
		if b.add_volatile(a, "perish_song", ev["source"], ev["move"]):
			did = true
	return true if did else false

func _psych_up_hit(b, p, ev):
	var user = ev["source"]
	var target = ev["target"]
	for k in target.boosts:
		user.boosts[k] = target.boosts[k]
	b.add_log(["-copyboost", b.pid(user), b.pid(target)])
	return true

func _soak_hit(b, p, ev):
	var target = ev["target"]
	if target.get_types() == ["water"]:
		return false
	target.set_types(["water"])
	b.add_log(["-start", b.pid(target), "typechange", "water"])
	return true

func _acupressure_hit(b, p, ev):
	var target = ev["target"]
	var opts: Array = []
	for k in target.boosts:
		if target.boosts[k] < 6:
			opts.append(k)
	if opts.is_empty():
		return false
	var k: String = b.rng.sample(opts)
	return b.boost(target, {k: 2}, ev["source"], ev["move"])

# ---------------- damage callbacks ----------------
func _counter_damage(b, p, ev):
	var user = ev["source"]
	var la: Dictionary = user.last_attacked_by
	if la.is_empty() or la.get("turn") != b.turn or la.get("category") != "physical":
		return false
	var src = la.get("source")
	if src == null or src.fainted or src.side == user.side:
		return false
	return int(la["damage"]) * 2

func _mirror_coat_damage(b, p, ev):
	var user = ev["source"]
	var la: Dictionary = user.last_attacked_by
	if la.is_empty() or la.get("turn") != b.turn or la.get("category") != "special":
		return false
	var src = la.get("source")
	if src == null or src.fainted or src.side == user.side:
		return false
	return int(la["damage"]) * 2

func _final_gambit_after(b, p, ev):
	var user = ev["source"]
	b.faint(user, user, ev["move"])
	return null

func _faint_user_after(b, p, ev):
	var user = ev["source"]
	b.faint(user, user, ev["move"])
	return null

func _struggle_recoil(b, p, ev):
	var user = ev["source"]
	if user.fainted:
		return null
	b.damage_pokemon(user, maxi(1, int(floor(user.max_hp / 4.0))), user, {"id": "struggle_recoil", "effect_type": "recoil"}, true)
	return null

func _steel_beam_after(b, p, ev):
	var user = ev["source"]
	if user.fainted or ev["move"].get("_recoiled", false):
		return null
	ev["move"]["_recoiled"] = true
	b.damage_pokemon(user, maxi(1, int(floor(user.max_hp / 2.0))), user, {"id": "steel_beam", "effect_type": "recoil"}, true)
	return null

func _hjk_fail(b, p, ev):
	var user = ev["source"]
	if user.fainted:
		return null
	b.damage_pokemon(user, maxi(1, int(floor(user.max_hp / 2.0))), user, {"id": "crash", "effect_type": "recoil"}, true)
	return null

# ---------------- conditional power ----------------
func _first_turn_try(b, p, ev):
	var user = ev["source"]
	if user.active_move_actions > 1:
		return false
	return null

func _sucker_punch_try(b, p, ev):
	var target = ev["target"]
	if target == null:
		return false
	for a in b.queue:
		if a.get("choice") == "move" and a.get("pokemon") == target:
			var md := GameData.get_move(str(a.get("move", "")))
			if md.get("category") != "status" and not target.volatiles.has("must_recharge"):
				return null
	return false

func _poltergeist_try(b, p, ev):
	var target = ev["target"]
	if target == null or target.item == "":
		return false
	b.add_log(["-activate", b.pid(target), "poltergeist", target.item])
	return null

func _stomping_tantrum_bp(b, p, ev):
	var user = ev["source"]
	var bp := int(ev["move"]["power"])
	if user.volatiles.has("_last_move_failed"):
		return bp * 2
	return bp

func _assurance_bp(b, p, ev):
	var target = ev["target"]
	var bp := int(ev["move"]["power"])
	if target != null and target.hurt_this_turn > 0:
		return bp * 2
	return bp

func _fury_cutter_bp(b, p, ev):
	var user = ev["source"]
	var st: Dictionary = user.volatiles.get("fury_cutter", {})
	var n := int(st.get("count", 0))
	return mini(160, int(ev["move"]["power"]) * int(pow(2, n)))

func _freeze_dry_eff(b, p, ev):
	var d = ev["value"]
	if typeof(d) == TYPE_DICTIONARY and d["type"] == "water":
		return {"type": "water", "value": 1}
	return null

func _psyblade_bp(b, p, ev):
	var user = ev["source"]
	if b.terrain == "electric" and user.is_grounded():
		b.chain_modify(6144, 4096)
	return null

func _expanding_force_bp(b, p, ev):
	var user = ev["source"]
	if b.terrain == "psychic" and user.is_grounded():
		b.chain_modify(6144, 4096)
	return null

func _expanding_force_modify(b, p, ev):
	var user = ev["source"]
	if b.terrain == "psychic" and user.is_grounded():
		ev["move"]["target"] = "allAdjacentFoes"
	return null

func _misty_explosion_bp(b, p, ev):
	var user = ev["source"]
	if b.terrain == "misty" and user.is_grounded():
		b.chain_modify(6144, 4096)
	return null

func _growth_modify(b, p, ev):
	if b.weather == "sun":
		ev["move"]["boosts"] = {"atk": 2, "spa": 2}
	return null

func _weather_ball_modify(b, p, ev):
	if b.weather == "":
		return null
	var wdef: Dictionary = GameData.weather.get(b.weather, {})
	ev["move"]["type"] = str(wdef.get("weather_ball_type", "normal"))
	ev["move"]["power"] = 100
	return null

func _aurora_veil_try(b, p, ev):
	if not b.is_weather(["snow", "hail"]):
		return false
	return null

# ---------------- charge / two-turn ----------------
func _charge_try_move(b, p, ev):
	var user = ev["source"]
	var mv = ev["move"]
	var st: Dictionary = user.volatiles.get("two_turn_move", {})
	if not st.is_empty() and st.get("move") == mv["id"]:
		b.remove_volatile(user, "two_turn_move")
		return null
	# instant in matching weather (Solar Beam in sun)
	if mv.get("charge_skip_weather", "") != "" and b.weather == mv["charge_skip_weather"]:
		return null
	b.add_log(["-prepare", b.pid(user), mv["id"]])
	if b.item_flag(user, "skips_charge"):
		if b.use_item(user):
			return null
	b.add_volatile(user, "two_turn_move", user, mv, {"move": mv["id"], "invulnerable": mv.get("semi_invulnerable", ""), "duration": 2})
	return false

func _meteor_beam_try_move(b, p, ev):
	var user = ev["source"]
	var mv = ev["move"]
	var st: Dictionary = user.volatiles.get("two_turn_move", {})
	if not st.is_empty() and st.get("move") == mv["id"]:
		b.remove_volatile(user, "two_turn_move")
		return null
	b.add_log(["-prepare", b.pid(user), mv["id"]])
	b.boost(user, {"spa": 1}, user, mv)
	b.add_volatile(user, "two_turn_move", user, mv, {"move": mv["id"], "invulnerable": "", "duration": 2})
	return false

func _future_sight_try(b, p, ev):
	var user = ev["source"]
	var target = ev["target"]
	if target == null:
		return false
	if target.side.slot_conditions.get(target.position, {}).has("future_move"):
		return false
	b.add_slot_condition(target.side, target.position, "future_move", user, ev["move"], {"move": ev["move"]["id"]})
	b.add_log(["-start", b.pid(user), ev["move"]["id"]])
	return false

# ---------------- hazards from moves ----------------
func _stone_axe_after(b, p, ev):
	var user = ev["source"]
	b.add_side_condition(user.side.foe, "stealth_rock", user, ev["move"])
	return null

func _ceaseless_edge_after(b, p, ev):
	var user = ev["source"]
	b.add_side_condition(user.side.foe, "spikes", user, ev["move"])
	return null

func _brick_break_try_hit(b, p, ev):
	var target = ev["target"]
	if target == null or target == ev["source"]:
		return null
	for sc in ["reflect", "light_screen", "aurora_veil"]:
		b.remove_side_condition(target.side, sc)
	return null

func _ice_spinner_after(b, p, ev):
	if b.terrain != "":
		b.clear_terrain()
	return null
