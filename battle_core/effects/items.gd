class_name Items
extends RefCounted
## Item handlers. Items whose data declares "handler": "<name>" use the generic:<name> entry.
## Handler signature: func(b, p, ev) -> Variant

func build() -> Dictionary:
	return {
		"generic:choice": {"onStart": _choice_start, "onModifyMove": _choice_modify_move, "onDisableMove": _choice_disable, "onModifyAtkPriority": 1, "onModifyAtk": _choice_atk, "onModifySpAPriority": 1, "onModifySpA": _choice_spa, "onModifySpe": _choice_spe, "onEnd": _choice_end},
		"generic:type_boost": {"onBasePowerPriority": 15, "onBasePower": _type_boost_bp},
		"generic:resist_berry": {"onSourceModifyDamagePriority": -1, "onSourceModifyDamage": _resist_berry},
		"generic:status_berry": {"onUpdate": _status_berry_update},
		"generic:hp_berry": {"onUpdate": _hp_berry_update},
		"generic:pinch_berry": {"onUpdate": _pinch_berry_update},
		"generic:terrain_seed": {"onStart": _seed_check, "onTerrainChange": _seed_check},
		"generic:passive": {},
		"life_orb": {"onModifyDamage": _life_orb_damage, "onAfterMoveSecondarySelf": _life_orb_recoil},
		"focus_sash": {"onDamagePriority": -40, "onDamage": _focus_sash_damage},
		"leftovers": {"onResidualOrder": 5, "onResidualSubOrder": 4, "onResidual": _leftovers_residual},
		"black_sludge": {"onResidualOrder": 5, "onResidualSubOrder": 4, "onResidual": _black_sludge_residual},
		"lum_berry": {"onUpdate": _lum_update},
		"assault_vest": {"onModifySpDPriority": 1, "onModifySpD": _assault_vest_spd, "onDisableMove": _assault_vest_disable},
		"rocky_helmet": {"onDamagingHitOrder": 2, "onDamagingHit": _rocky_helmet_hit},
		"eviolite": {"onModifyDefPriority": 2, "onModifyDef": _eviolite_stat, "onModifySpDPriority": 2, "onModifySpD": _eviolite_stat},
		"weakness_policy": {"onDamagingHit": _weakness_policy_hit},
		"air_balloon": {"onStart": _air_balloon_start, "onDamagingHit": _air_balloon_pop, "onAfterSubDamage": _air_balloon_pop},
		"eject_button": {"onAfterHitPriority": 2, "onAfterHit": _eject_button_hit},
		"red_card": {"onAfterHit": _red_card_hit},
		"quick_claw": {"onFractionalPriority": _quick_claw},
		"bright_powder": {"onModifyAccuracyPriority": -2, "onModifyAccuracy": _bright_powder_acc},
		"wide_lens": {"onSourceModifyAccuracyPriority": -2, "onSourceModifyAccuracy": _wide_lens_acc},
		"expert_belt": {"onModifyDamage": _expert_belt_damage},
		"muscle_band": {"onBasePowerPriority": 16, "onBasePower": _muscle_band_bp},
		"wise_glasses": {"onBasePowerPriority": 16, "onBasePower": _wise_glasses_bp},
		"scope_lens": {"onModifyCritRatio": _crit_plus_one},
		"razor_claw": {"onModifyCritRatio": _crit_plus_one},
		"mental_herb": {"onUpdate": _mental_herb_update},
		"white_herb": {"onUpdate": _white_herb_update},
		"flame_orb": {"onResidualOrder": 28, "onResidualSubOrder": 3, "onResidual": _flame_orb_residual},
		"toxic_orb": {"onResidualOrder": 28, "onResidualSubOrder": 3, "onResidual": _toxic_orb_residual},
		"covert_cloak": {"onModifySecondaries": _covert_cloak},
		"clear_amulet": {"onTryBoostPriority": 1, "onTryBoost": _clear_amulet_try_boost},
		"shell_bell": {"onAfterMoveSecondarySelfPriority": -1, "onAfterMoveSecondarySelf": _shell_bell},
		"big_root": {"onTryHealPriority": 1, "onTryHeal": _big_root_heal},
		"loaded_dice": {"onModifyMultiHit": _loaded_dice},
		"metronome": {"onStart": _metronome_start, "onModifyDamage": _metronome_damage, "onAfterMove": _metronome_after_move},
	}

func _item_effect(id: String) -> Dictionary:
	return {"id": id, "effect_type": "item"}

func _idata(p) -> Dictionary:
	return GameData.get_item(p.item)

func _iparams(p) -> Dictionary:
	return _idata(p).get("params", {})

# -------- choice items --------
func _choice_start(_b, _p, ev):
	ev["state"]["locked"] = ""
	return null

func _choice_modify_move(_b, _p, ev):
	var mv = ev["move"]
	if mv != null and str(ev["state"].get("locked", "")) == "" and mv["id"] != "struggle":
		ev["state"]["locked"] = mv["id"]
	return null

func _choice_disable(_b, p, ev):
	var mv = ev["effect"]
	var locked := str(ev["state"].get("locked", ""))
	if mv is Dictionary and locked != "" and mv.get("id") != locked and p.has_move(locked):
		return false
	return null

func _choice_atk(b, p, _ev):
	if str(_iparams(p).get("stat", "")) == "atk":
		b.chain_modify(3, 2)
	return null

func _choice_spa(b, p, _ev):
	if str(_iparams(p).get("stat", "")) == "spa":
		b.chain_modify(3, 2)
	return null

func _choice_spe(b, p, _ev):
	if str(_iparams(p).get("stat", "")) == "spe":
		b.chain_modify(3, 2)
	return null

func _choice_end(_b, _p, ev):
	ev["state"]["locked"] = ""
	return null

# -------- generic data-driven --------
func _type_boost_bp(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv["type"] == str(_iparams(p).get("type", "")):
		b.chain_modify(4915, 4096)
	return null

func _resist_berry(b, p, ev):
	var mv = ev["move"]
	if mv == null:
		return null
	var t := str(_iparams(p).get("type", ""))
	if mv["type"] != t:
		return null
	if t != "normal" and int(mv.get("type_mod", 0)) <= 0:
		return null
	if not b.can_eat_berry(p):
		return null
	if b.estimating:
		b.chain_modify(1, 2)
		return null
	if b.use_item(p, ev["source"], mv):
		b.add_log(["-activate", b.pid(p), p.last_item, "weaken"])
		b.chain_modify(1, 2)
	return null

func _status_berry_update(b, p, _ev):
	var cures = _iparams(p).get("cures", [])
	var hit := false
	if p.status != "" and cures.has(p.status):
		hit = true
	if cures.has("confusion") and p.volatiles.has("confusion"):
		hit = true
	if hit and b.can_eat_berry(p):
		if b.use_item(p):
			if p.status != "" and cures.has(p.status):
				b.cure_status(p, p, _item_effect(p.last_item))
			if cures.has("confusion"):
				b.remove_volatile(p, "confusion")
	return null

func _hp_berry_update(b, p, _ev):
	var prm := _iparams(p)
	var thr = prm.get("threshold", [1, 2])
	if p.hp * int(thr[1]) <= p.max_hp * int(thr[0]) and b.can_eat_berry(p):
		if b.use_item(p):
			var heal_frac = prm.get("heal_fraction", null)
			var amt := int(prm.get("heal_flat", 10))
			if heal_frac != null:
				amt = maxi(1, int(floor(p.max_hp * float(heal_frac[0]) / float(heal_frac[1]))))
			b.heal_pokemon(p, amt, p, _item_effect(p.last_item))
	return null

func _pinch_berry_update(b, p, _ev):
	if p.hp * 4 <= p.max_hp and b.can_eat_berry(p):
		if b.use_item(p):
			b.boost(p, _iparams(p).get("boosts", {"spe": 1}), p, _item_effect(p.last_item))
	return null

func _seed_check(b, p, _ev):
	if b.terrain != "" and b.terrain == str(_iparams(p).get("terrain", "")):
		if b.use_item(p):
			b.boost(p, _iparams(p).get("boosts", {}), p, _item_effect(p.last_item))
	return null

# -------- specific --------
func _life_orb_damage(b, _p, _ev):
	b.chain_modify(5324, 4096)
	return null

func _life_orb_recoil(b, p, ev):
	var mv = ev["move"]
	if mv != null and int(mv.get("total_damage", 0)) > 0 and not mv.get("sheer_force_boosted", false):
		b.damage_pokemon(p, maxi(1, int(floor(p.max_hp / 10.0))), p, _item_effect("life_orb"))
		b.stat_inc("item_activations", "life_orb")
	return null

func _focus_sash_damage(b, p, ev):
	var eff = ev["effect"]
	if eff is Dictionary and eff.get("effect_type") == "move" and p.hp >= p.max_hp and int(ev["value"]) >= p.hp:
		if b.use_item(p):
			return p.hp - 1
	return null

func _leftovers_residual(b, p, _ev):
	b.heal_pokemon(p, maxi(1, int(floor(p.max_hp / 16.0))), p, _item_effect("leftovers"))
	return null

func _black_sludge_residual(b, p, _ev):
	if p.has_type("poison"):
		b.heal_pokemon(p, maxi(1, int(floor(p.max_hp / 16.0))), p, _item_effect("black_sludge"))
	else:
		b.damage_pokemon(p, maxi(1, int(floor(p.max_hp / 8.0))), p, _item_effect("black_sludge"))
	return null

func _lum_update(b, p, _ev):
	if (p.status != "" or p.volatiles.has("confusion")) and b.can_eat_berry(p):
		if b.use_item(p):
			b.cure_status(p, p, _item_effect("lum_berry"))
			b.remove_volatile(p, "confusion")
	return null

func _assault_vest_spd(b, _p, _ev):
	b.chain_modify(3, 2)
	return null

func _assault_vest_disable(_b, _p, ev):
	var mv = ev["effect"]
	if mv is Dictionary and mv.get("category") == "status":
		return false
	return null

func _rocky_helmet_hit(b, p, ev):
	var mv = ev["move"]
	var src = ev["source"]
	if mv != null and src != null and b.is_contact(mv, src) and not src.fainted:
		b.damage_pokemon(src, maxi(1, int(floor(src.max_hp / 6.0))), p, _item_effect("rocky_helmet"))
		b.stat_inc("item_activations", "rocky_helmet")
	return null

func _eviolite_stat(b, p, _ev):
	if GameData.get_species(p.species_id).get("nfe", false):
		b.chain_modify(3, 2)
	return null

func _weakness_policy_hit(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv["category"] != "status" and int(mv.get("type_mod", 0)) > 0:
		if b.use_item(p):
			b.boost(p, {"atk": 2, "spa": 2}, p, _item_effect("weakness_policy"))
	return null

func _air_balloon_start(b, p, _ev):
	b.add_log(["-item", b.pid(p), "air_balloon"])
	return null

func _air_balloon_pop(b, p, ev):
	var eff = ev["effect"]
	if eff is Dictionary and eff.get("effect_type") == "move" and ev["source"] != p:
		b.add_log(["-enditem", b.pid(p), "air_balloon"])
		p.last_item = p.item
		p.item = ""
		p.item_state = {}
		b.run_event("AfterUseItem", p, null, null, "air_balloon")
	return null

func _eject_button_hit(b, p, ev):
	var mv = ev["move"]
	var src = ev["source"]
	if mv == null or src == null or src == p or p.hp <= 0 or mv["category"] == "status":
		return null
	if not p.side.has_alive_bench() or p.force_switch_flag or p.switch_flag:
		return null
	if b.use_item(p):
		p.switch_flag = true
	return null

func _red_card_hit(b, p, ev):
	var mv = ev["move"]
	var src = ev["source"]
	if mv == null or src == null or src == p or p.hp <= 0 or src.hp <= 0 or mv["category"] == "status":
		return null
	if not src.side.has_alive_bench():
		return null
	if b.use_item(p, src):
		if not Battle.is_false(b.run_event("DragOut", src, p, mv)):
			src.force_switch_flag = true
	return null

func _quick_claw(b, p, _ev):
	if b.rng.chance(1, 5):
		b.add_log(["-activate", b.pid(p), "quick_claw"])
		b.stat_inc("item_activations", "quick_claw")
		return 0.1
	return null

func _bright_powder_acc(b, _p, ev):
	if typeof(ev["value"]) == TYPE_BOOL:
		return null
	b.chain_modify(3686, 4096)
	return null

func _wide_lens_acc(b, _p, ev):
	if typeof(ev["value"]) == TYPE_BOOL:
		return null
	b.chain_modify(4505, 4096)
	return null

func _expert_belt_damage(b, _p, ev):
	var mv = ev["move"]
	if mv != null and int(mv.get("type_mod", 0)) > 0:
		b.chain_modify(4915, 4096)
	return null

func _muscle_band_bp(b, _p, ev):
	var mv = ev["move"]
	if mv != null and mv["category"] == "physical":
		b.chain_modify(4505, 4096)
	return null

func _wise_glasses_bp(b, _p, ev):
	var mv = ev["move"]
	if mv != null and mv["category"] == "special":
		b.chain_modify(4505, 4096)
	return null

func _crit_plus_one(_b, _p, ev):
	return int(ev["value"]) + 1

func _mental_herb_update(b, p, _ev):
	for v in ["attract", "taunt", "encore", "disable", "torment", "heal_block"]:
		if p.volatiles.has(v):
			if b.use_item(p):
				b.remove_volatile(p, v)
			return null
	return null

func _white_herb_update(b, p, _ev):
	var any := false
	for k in p.boosts:
		if p.boosts[k] < 0:
			any = true
	if any and b.use_item(p):
		for k in p.boosts:
			if p.boosts[k] < 0:
				p.boosts[k] = 0
		b.add_log(["-clearnegativeboost", b.pid(p)])
	return null

func _flame_orb_residual(b, p, _ev):
	if b.set_status(p, "brn", p, _item_effect("flame_orb")):
		b.stat_inc("item_activations", "flame_orb")
	return null

func _toxic_orb_residual(b, p, _ev):
	if b.set_status(p, "tox", p, _item_effect("toxic_orb")):
		b.stat_inc("item_activations", "toxic_orb")
	return null

func _covert_cloak(b, p, ev):
	var secs: Array = ev["value"]
	var out: Array = []
	for s in secs:
		if s.has("self"):
			out.append({"chance": s.get("chance", 100), "self": s["self"]})
	return out

func _clear_amulet_try_boost(b, p, ev):
	var src = ev["source"]
	if src == null or src == p:
		return null
	var boosts: Dictionary = ev["value"]
	var blocked := false
	for k in boosts.keys():
		if int(boosts[k]) < 0:
			boosts.erase(k)
			blocked = true
	if blocked:
		b.add_log(["-fail", b.pid(p), "unboost", "[from] item: clear_amulet"])
	return boosts

func _shell_bell(b, p, ev):
	var mv = ev["move"]
	if mv != null and int(mv.get("total_damage", 0)) > 0:
		b.heal_pokemon(p, maxi(1, int(floor(int(mv["total_damage"]) / 8.0))), p, _item_effect("shell_bell"))
	return null

func _big_root_heal(b, _p, ev):
	var eff = ev["effect"]
	if eff is Dictionary and (eff.get("drain") != null or eff.get("id") in ["leech_seed", "ingrain", "aqua_ring", "strength_sap"]):
		b.chain_modify(5324, 4096)
	return null

func _loaded_dice(b, _p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("multihit") is Array and int(mv["multihit"][1]) == 5:
		return b.rng.range_int(4, 5)
	return null

func _metronome_start(_b, _p, ev):
	ev["state"]["last"] = ""
	ev["state"]["count"] = 0
	return null

func _metronome_damage(b, _p, ev):
	var n := int(ev["state"].get("count", 0))
	if n > 0:
		b.chain_modify(mini(4096 + 819 * n, 8192), 4096)
	return null

func _metronome_after_move(_b, p, ev):
	var mv = ev["effect"]
	if not (mv is Dictionary):
		return null
	if mv.get("id") == ev["state"].get("last", ""):
		ev["state"]["count"] = mini(5, int(ev["state"].get("count", 0)) + 1)
	else:
		ev["state"]["count"] = 0
	ev["state"]["last"] = mv.get("id")
	return null
