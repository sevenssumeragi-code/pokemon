class_name Abilities
extends RefCounted
## Ability handlers. Original abilities read tunable params from data/abilities/*.json ("params").
## Handler signature: func(b, p, ev) -> Variant

func build() -> Dictionary:
	return {
		# ---- original abilities ----
		"awakened_lion": {"onStatusCure": _lion_cure, "onModifyAtkPriority": 5, "onModifyAtk": _lion_modify_atk},
		"flame_domain": {"onBasePowerPriority": 21, "onBasePower": _flame_domain_bp, "onAllyBasePowerPriority": 21, "onAllyBasePower": _flame_domain_bp},
		"dark_domain": {"onBasePowerPriority": 21, "onBasePower": _dark_domain_bp, "onAllyBasePowerPriority": 21, "onAllyBasePower": _dark_domain_bp},
		"sacred_light": {"onSourceBasePowerPriority": 21, "onSourceBasePower": _sacred_light_bp},
		"minimal_body": {"onModifyAccuracyPriority": -1, "onModifyAccuracy": _minimal_body_acc},
		# ---- canon abilities (Gen 9 behaviour) ----
		"prankster": {"onModifyPriority": _prankster_priority},
		"snow_warning": {"onStart": _snow_warning_start},
		"sharpness": {"onBasePowerPriority": 19, "onBasePower": _sharpness_bp},
		"steadfast": {"onFlinch": _steadfast_flinch},
		"static": {"onDamagingHit": _static_hit},
		"unburden": {"onAfterUseItem": _unburden_trigger, "onAfterTakeItem": _unburden_trigger, "onEnd": _unburden_end},
		"sturdy": {"onTryHit": _sturdy_try_hit, "onDamagePriority": -30, "onDamage": _sturdy_damage},
		"contrary": {"onChangeBoost": _contrary_change_boost},
		"pixilate": {"onModifyTypePriority": -1, "onModifyType": _pixilate_type, "onBasePowerPriority": 23, "onBasePower": _pixilate_bp},
		"multiscale": {"onSourceModifyDamage": _multiscale_damage},
		"compound_eyes": {"onSourceModifyAccuracyPriority": -1, "onSourceModifyAccuracy": _compound_eyes_acc},
		"intimidate": {"onStart": _intimidate_start},
		"competitive": {"onAfterEachBoost": _competitive_boost},
		"levitate": {},
		"inner_focus": {"onTryAddVolatile": _inner_focus_volatile},
		"regenerator": {"onSwitchOut": _regenerator_switch_out},
		"natural_cure": {"onSwitchOut": _natural_cure_switch_out},
		"technician": {"onBasePowerPriority": 30, "onBasePower": _technician_bp},
		"guts": {"onModifyAtkPriority": 5, "onModifyAtk": _guts_atk, "onBurnDamageReduction": _guts_burn},
		"thick_fat": {"onSourceModifyAtkPriority": 6, "onSourceModifyAtk": _thick_fat, "onSourceModifySpAPriority": 5, "onSourceModifySpA": _thick_fat},
		"clear_body": {"onTryBoostPriority": 1, "onTryBoost": _clear_body_try_boost},
	}

func _params(id: String) -> Dictionary:
	return GameData.get_ability(id).get("params", {})

func _activate(b, p, id: String) -> void:
	b.stat_inc("ability_activations", id)
	b.add_log(["-ability", b.pid(p), id])

func _ability_effect(id: String) -> Dictionary:
	return {"id": id, "effect_type": "ability"}

# ---------------- original ----------------
func _lion_cure(b, p, ev):
	if str(ev["value"]) == "slp":
		ev["state"]["woke_turn"] = b.turn
		_activate(b, p, "awakened_lion")
	return null

func _lion_modify_atk(b, p, ev):
	if int(ev["state"].get("woke_turn", -1)) == b.turn:
		b.chain_modify(float(_params("awakened_lion").get("multiplier", 2.0)))
	return null

func _flame_domain_bp(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv["type"] == "fire":
		b.chain_modify(float(_params("flame_domain").get("multiplier", 1.5)))
		b.stat_inc("ability_activations", "flame_domain")
	return null

func _dark_domain_bp(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv["type"] == "ghost":
		b.chain_modify(float(_params("dark_domain").get("multiplier", 1.5)))
		b.stat_inc("ability_activations", "dark_domain")
	return null

func _sacred_light_bp(b, p, ev):
	var mv = ev["move"]
	if mv != null and (mv["type"] in _params("sacred_light").get("types", ["ghost", "dark"])):
		b.chain_modify(float(_params("sacred_light").get("multiplier", 0.7)))
		b.stat_inc("ability_activations", "sacred_light")
	return null

func _minimal_body_acc(b, p, ev):
	var mv = ev["move"]
	if mv == null or ev["source"] == p:
		return null
	if typeof(ev["value"]) == TYPE_BOOL:
		return null
	var mult := float(_params("minimal_body").get("evasion_multiplier", 1.5))
	b.chain_modify(1.0 / mult)
	b.stat_inc("ability_activations", "minimal_body")
	return null

# ---------------- canon ----------------
func _prankster_priority(b, p, ev):
	var mv = ev["effect"]
	if mv is Dictionary and mv.get("category") == "status":
		mv["prankster_boosted"] = true
		b.stat_inc("ability_activations", "prankster")
		return int(ev["value"]) + 1
	return null

func _snow_warning_start(b, p, _ev):
	if b.set_weather("snow", p, _ability_effect("snow_warning")):
		_activate(b, p, "snow_warning")
	return null

func _sharpness_bp(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("flags", []).has("slicing"):
		b.chain_modify(6144, 4096)
		b.stat_inc("ability_activations", "sharpness")
	return null

func _steadfast_flinch(b, p, _ev):
	_activate(b, p, "steadfast")
	b.boost(p, {"spe": 1}, p, _ability_effect("steadfast"))
	return null

func _static_hit(b, p, ev):
	var mv = ev["move"]
	var src = ev["source"]
	if mv != null and src != null and b.is_contact(mv, src) and b.rng.chance(3, 10):
		if b.set_status(src, "par", p, _ability_effect("static")):
			_activate(b, p, "static")
	return null

func _unburden_trigger(b, p, _ev):
	if p.ability == "unburden" and not p.volatiles.has("unburden"):
		p.volatiles["unburden"] = {"id": "unburden"}
		_activate(b, p, "unburden")
	return null

func _unburden_end(_b, p, _ev):
	if p != null:
		p.volatiles.erase("unburden")
	return null

func _sturdy_try_hit(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("ohko", false) and ev["source"] != p:
		_activate(b, p, "sturdy")
		b.add_log(["-immune", b.pid(p)])
		return false
	return null

func _sturdy_damage(b, p, ev):
	var eff = ev["effect"]
	if eff is Dictionary and eff.get("effect_type") == "move" and int(ev["value"]) >= p.hp and p.hp >= p.max_hp:
		_activate(b, p, "sturdy")
		return p.hp - 1
	return null

func _contrary_change_boost(b, p, ev):
	var boosts: Dictionary = ev["value"]
	var out := {}
	for k in boosts:
		out[k] = -int(boosts[k])
	b.stat_inc("ability_activations", "contrary")
	return out

func _pixilate_type(b, p, ev):
	var mv = ev["move"]
	if mv == null or mv.get("no_type_change", false):
		return null
	if mv["type"] == "normal":
		mv["type"] = "fairy"
		mv["type_changer_boosted"] = "pixilate"
		b.stat_inc("ability_activations", "pixilate")
	return null

func _pixilate_bp(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("type_changer_boosted", "") == "pixilate":
		b.chain_modify(4915, 4096)
	return null

func _multiscale_damage(b, p, ev):
	if p.hp >= p.max_hp:
		b.chain_modify(1, 2)
		b.stat_inc("ability_activations", "multiscale")
	return null

func _compound_eyes_acc(b, p, ev):
	var mv = ev["move"]
	if typeof(ev["value"]) == TYPE_BOOL or (mv != null and mv.get("ohko", false)):
		return null
	b.chain_modify(5325, 4096)
	b.stat_inc("ability_activations", "compound_eyes")
	return null

func _intimidate_start(b, p, _ev):
	_activate(b, p, "intimidate")
	for foe in p.adjacent_foes():
		var flags: Dictionary = GameData.get_ability(foe.ability).get("flags", {})
		if flags.get("intimidate_immune", false):
			b.add_log(["-immune", b.pid(foe), "[from] ability: " + foe.ability])
			continue
		if foe.volatiles.has("substitute"):
			continue
		b.boost(foe, {"atk": -1}, p, _ability_effect("intimidate"))
	return null

func _competitive_boost(b, p, ev):
	var delta := int(ev["value"])
	var src = ev["source"]
	if delta >= 0 or src == null or src == p or src.side == p.side:
		return null
	_activate(b, p, "competitive")
	b.boost(p, {"spa": 2}, p, _ability_effect("competitive"))
	return null

func _inner_focus_volatile(_b, _p, ev):
	if str(ev["value"]) == "flinch":
		return false
	return null

func _regenerator_switch_out(b, p, _ev):
	b.heal_pokemon(p, int(floor(p.max_hp / 3.0)), p, _ability_effect("regenerator"))
	return null

func _natural_cure_switch_out(b, p, _ev):
	b.cure_status(p, p, _ability_effect("natural_cure"), true)
	return null

func _technician_bp(b, p, ev):
	if int(ev["value"]) <= 60:
		b.chain_modify(3, 2)
	return null

func _guts_atk(b, p, _ev):
	if p.status != "":
		b.chain_modify(3, 2)
	return null

func _guts_burn(_b, _p, _ev):
	return false

func _thick_fat(b, _p, ev):
	var mv = ev["move"]
	if mv != null and mv["type"] in ["fire", "ice"]:
		b.chain_modify(1, 2)
	return null

func _clear_body_try_boost(b, p, ev):
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
		b.add_log(["-fail", b.pid(p), "unboost", "[from] ability: clear_body"])
	return boosts
