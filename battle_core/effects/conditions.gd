class_name Conditions
extends RefCounted
## Status conditions, volatiles, side/slot conditions, weather, terrain, field effects.
## Handler signature: func(b: Battle, p: BattlePokemon|null, ev: Dictionary) -> Variant

func build() -> Dictionary:
	return {
		"status": _statuses(),
		"volatile": _volatiles(),
		"side": _sides(),
		"slot": _slots(),
		"weather": _weathers(),
		"terrain": _terrains(),
		"field": _fields(),
		"status_meta": {
			"brn": {"immune_types": ["fire"]},
			"par": {"immune_types": ["electric"]},
			"slp": {"immune_types": []},
			"frz": {"immune_types": ["ice"]},
			"psn": {"immune_types": ["poison", "steel"]},
			"tox": {"immune_types": ["poison", "steel"]},
		},
		"volatile_meta": {
			"flinch": {"duration": 1}, "protect": {"duration": 1}, "endure": {"duration": 1},
			"roost": {"duration": 1}, "stall": {"duration": 2}, "must_recharge": {"duration": 2},
			"yawn": {"duration": 2}, "taunt": {"duration": 3}, "encore": {"duration": 3},
			"disable": {"duration": 4}, "magnet_rise": {"duration": 5}, "throat_chop": {"duration": 2},
			"heal_block": {"duration": 5}, "embargo": {"duration": 5}, "laser_focus": {"duration": 2},
			"charge": {"duration": 2}, "helping_hand": {"duration": 1}, "follow_me": {"duration": 1},
			"rage_powder": {"duration": 1}, "destiny_bond": {"duration": 2}, "grudge": {"duration": 2},
			"powder": {"duration": 1}, "electrify": {"duration": 1}, "kings_shield": {"duration": 1},
			"spiky_shield": {"duration": 1}, "baneful_bunker": {"duration": 1}, "silk_trap": {"duration": 1},
			"burning_bulwark": {"duration": 1}, "obstruct": {"duration": 1}, "quick_guard": {"duration": 1},
			"wide_guard": {"duration": 1}, "glaive_rush": {"duration": 2}, "syrup_bomb": {"duration": 3},
			"salt_cure": {}, "slow_start": {"duration": 5},
		},
		"side_meta": {
			"reflect": {"duration": 5}, "light_screen": {"duration": 5}, "aurora_veil": {"duration": 5},
			"safeguard": {"duration": 5}, "mist": {"duration": 5}, "tailwind": {"duration": 4},
			"lucky_chant": {"duration": 5}, "quick_guard": {"duration": 1}, "wide_guard": {"duration": 1},
		},
	}

# ============================================================
# helpers
# ============================================================
func _frac(max_hp: int, num: int, den: int) -> int:
	return maxi(1, int(floor(max_hp * num / float(den))))

func _cant(b, p, reason: String) -> void:
	b.add_log(["cant", b.pid(p), reason])

# ============================================================
# STATUS
# ============================================================
func _statuses() -> Dictionary:
	return {
		"brn": {"onResidualOrder": 10, "onResidual": _brn_residual},
		"par": {"onModifySpe": _par_modify_spe, "onBeforeMovePriority": 1, "onBeforeMove": _par_before_move},
		"slp": {"onStart": _slp_start, "onBeforeMovePriority": 10, "onBeforeMove": _slp_before_move},
		"frz": {"onBeforeMovePriority": 10, "onBeforeMove": _frz_before_move, "onHit": _frz_hit, "onModifyMove": _frz_modify_move},
		"psn": {"onResidualOrder": 9, "onResidual": _psn_residual},
		"tox": {"onStart": _tox_start, "onSwitchIn": _tox_switch_in, "onResidualOrder": 9, "onResidual": _tox_residual},
	}

func _brn_residual(b, p, _ev):
	b.damage_pokemon(p, _frac(p.max_hp, 1, 16), null, {"id": "brn", "effect_type": "status"})
	return null

func _par_modify_spe(b, p, _ev):
	if GameData.get_ability(p.ability).get("flags", {}).get("ignore_paralysis_speed", false):
		return null
	b.chain_modify(1, 2)
	return null

func _par_before_move(b, p, _ev):
	if b.rng.chance(1, 4):
		_cant(b, p, "par")
		return false
	return null

func _slp_start(b, p, ev):
	var st: Dictionary = ev["state"]
	if st.has("fixed_turns"):
		st["time"] = int(st["fixed_turns"])
	else:
		st["time"] = b.rng.range_int(2, 4)
	if GameData.get_ability(p.ability).get("flags", {}).get("early_bird", false):
		st["time"] = int(floor(st["time"] / 2.0))
	st["start_time"] = st["time"]
	return null

func _slp_before_move(b, p, ev):
	var st: Dictionary = ev["state"]
	st["time"] = int(st.get("time", 1)) - 1
	if int(st["time"]) <= 0:
		b.cure_status(p, p, {"id": "slp_wake", "effect_type": "status"})
		return null
	_cant(b, p, "slp")
	var mv = ev["move"]
	if mv != null and mv.get("sleep_usable", false):
		return null
	return false

func _frz_before_move(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("flags", []).has("defrost"):
		b.cure_status(p, p, {"id": "frz_thaw", "effect_type": "status"})
		return null
	if b.rng.chance(1, 5):
		b.cure_status(p, p, {"id": "frz_thaw", "effect_type": "status"})
		return null
	_cant(b, p, "frz")
	return false

func _frz_modify_move(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("flags", []).has("defrost"):
		b.cure_status(p, p, {"id": "frz_thaw", "effect_type": "status"})
	return null

func _frz_hit(b, p, ev):
	var mv = ev["move"]
	if mv != null and (mv.get("thaws_target", false) or (mv["type"] == "fire" and mv["category"] != "status")):
		b.cure_status(p, ev["source"], mv)
	return null

func _psn_residual(b, p, _ev):
	b.damage_pokemon(p, _frac(p.max_hp, 1, 8), null, {"id": "psn", "effect_type": "status"})
	return null

func _tox_start(_b, _p, ev):
	ev["state"]["stage"] = 0
	return null

func _tox_switch_in(_b, _p, ev):
	ev["state"]["stage"] = 0
	return null

func _tox_residual(b, p, ev):
	var st: Dictionary = ev["state"]
	st["stage"] = mini(15, int(st.get("stage", 0)) + 1)
	b.damage_pokemon(p, _frac(p.max_hp, 1, 16) * int(st["stage"]), null, {"id": "tox", "effect_type": "status"})
	return null

# ============================================================
# VOLATILES
# ============================================================
func _volatiles() -> Dictionary:
	return {
		"confusion": {"onStart": _conf_start, "onBeforeMovePriority": 3, "onBeforeMove": _conf_before_move},
		"flinch": {"onBeforeMovePriority": 8, "onBeforeMove": _flinch_before_move},
		"attract": {"onStart": _attract_start, "onBeforeMovePriority": 2, "onBeforeMove": _attract_before_move},
		"leech_seed": {"onStart": _leech_start, "onResidualOrder": 8, "onResidual": _leech_residual},
		"substitute": {"onStart": _sub_start, "onTryHitPriority": -1},
		"protect": {"onStart": _protect_start, "onTryHitPriority": 3, "onTryHit": _protect_try_hit},
		"spiky_shield": {"onStart": _protect_start, "onTryHitPriority": 3, "onTryHit": _spiky_shield_try_hit},
		"baneful_bunker": {"onStart": _protect_start, "onTryHitPriority": 3, "onTryHit": _baneful_bunker_try_hit},
		"endure": {"onStart": _endure_start, "onDamagePriority": -10, "onDamage": _endure_damage},
		"stall": {"onStart": _stall_start, "onRestart": _stall_restart, "onStallMove": _stall_move},
		"taunt": {"onStart": _taunt_start, "onDisableMove": _taunt_disable, "onBeforeMovePriority": 5, "onBeforeMove": _taunt_before_move},
		"encore": {"onStart": _encore_start, "onDisableMove": _encore_disable, "onLockMove": _encore_lock, "onResidualOrder": 16, "onResidual": _encore_residual},
		"disable": {"onStart": _disable_start, "onDisableMove": _disable_disable, "onBeforeMovePriority": 7, "onBeforeMove": _disable_before_move},
		"yawn": {"onStart": _yawn_start, "onEnd": _yawn_end},
		"curse": {"onStart": _curse_start, "onResidualOrder": 12, "onResidual": _curse_residual},
		"nightmare": {"onStart": _nightmare_start, "onResidualOrder": 11, "onResidual": _nightmare_residual},
		"focus_energy": {"onStart": _focus_energy_start, "onModifyCritRatio": _focus_energy_crit},
		"locked_move": {"onStart": _locked_start, "onLockMove": _locked_lock, "onAfterMove": _locked_after_move, "onEnd": _locked_end},
		"must_recharge": {"onBeforeMovePriority": 11, "onBeforeMove": _recharge_before_move, "onLockMove": _recharge_lock},
		"two_turn_move": {"onLockMove": _two_turn_lock, "onEnd": _two_turn_end},
		"roost": {"onStart": _roost_start, "onEnd": _roost_end},
		"partially_trapped": {"onStart": _bind_start, "onResidualOrder": 13, "onResidual": _bind_residual, "onTrapPokemon": _trap},
		"trapped": {"onTrapPokemon": _trap},
		"aqua_ring": {"onStart": _aqua_ring_start, "onResidualOrder": 6, "onResidual": _aqua_ring_residual},
		"ingrain": {"onStart": _ingrain_start, "onResidualOrder": 7, "onResidual": _ingrain_residual, "onTrapPokemon": _trap, "onDragOut": _ingrain_dragout},
		"minimize": {},
		"destiny_bond": {"onStart": _destiny_start, "onFaint": _destiny_faint, "onBeforeMovePriority": -1, "onBeforeMove": _destiny_before_move},
		"perish_song": {"onStart": _perish_start, "onResidualOrder": 20, "onResidual": _perish_residual},
		"magnet_rise": {"onStart": _magnet_rise_start},
		"smack_down": {"onStart": _smack_down_start},
		"flash_fire": {"onStart": _flash_fire_start, "onModifyAtkPriority": 5, "onModifyAtk": _flash_fire_atk, "onModifySpAPriority": 5, "onModifySpA": _flash_fire_spa},
		"unburden": {"onModifySpe": _unburden_spe},
		"charge": {"onStart": _charge_start, "onBasePower": _charge_bp},
		"helping_hand": {"onStart": _hh_start, "onBasePowerPriority": 10, "onBasePower": _hh_bp},
		"follow_me": {"onStart": _follow_me_start},
		"rage_powder": {"onStart": _follow_me_start},
		"laser_focus": {"onStart": _laser_start, "onModifyCritRatio": _laser_crit},
		"salt_cure": {"onStart": _salt_start, "onResidualOrder": 13, "onResidual": _salt_residual},
		"throat_chop": {"onStart": _throat_start, "onDisableMove": _throat_disable, "onBeforeMovePriority": 6, "onBeforeMove": _throat_before_move},
		"glaive_rush": {"onAccuracy": _glaive_acc, "onSourceModifyDamage": _glaive_dmg, "onBeforeMove": _glaive_before_move},
		"heal_block": {"onStart": _heal_block_start, "onTryHeal": _heal_block_try_heal, "onDisableMove": _heal_block_disable},
		"_dragged": {},
		"electrify": {"onModifyTypePriority": -2, "onModifyType": _electrify_type},
		"powder": {"onTryMovePriority": -1, "onTryMove": _powder_try_move},
		"slow_start": {"onStart": _slow_start_start, "onModifyAtk": _slow_start_atk, "onModifySpe": _slow_start_spe},
	}

func _conf_start(b, p, ev):
	ev["state"]["time"] = b.rng.range_int(2, 5)
	b.add_log(["-start", b.pid(p), "confusion"])
	return null

func _conf_before_move(b, p, ev):
	var st: Dictionary = ev["state"]
	st["time"] = int(st.get("time", 1)) - 1
	if int(st["time"]) <= 0:
		b.remove_volatile(p, "confusion")
		b.add_log(["-end", b.pid(p), "confusion"])
		return null
	b.add_log(["-activate", b.pid(p), "confusion"])
	if not b.rng.chance(33, 100):
		return null
	# hit itself: 40 BP typeless physical
	var attack: int = StatCalc.apply_boost(p.stored_stats["atk"], p.boosts["atk"])
	var defense: int = StatCalc.apply_boost(p.stored_stats["def"], p.boosts["def"])
	var base := int(floor(int(floor(int(floor(2 * p.level / 5.0 + 2)) * 40 * attack / float(defense))) / 50.0)) + 2
	var dmg := maxi(1, int(floor(base * (100 - b.rng.next(16)) / 100.0)))
	b.damage_pokemon(p, dmg, p, {"id": "confusion", "effect_type": "volatile"})
	return false

func _flinch_before_move(b, p, _ev):
	_cant(b, p, "flinch")
	b.run_event("Flinch", p)
	return false

func _attract_start(b, p, ev):
	var src = ev["source"]
	if src == null or p.gender == "N" or src.gender == "N" or p.gender == src.gender:
		return false
	b.add_log(["-start", b.pid(p), "attract"])
	return null

func _attract_before_move(b, p, ev):
	var src = ev["state"].get("source")
	if src == null or src.fainted or not src.active:
		b.remove_volatile(p, "attract")
		return null
	if b.rng.chance(1, 2):
		_cant(b, p, "attract")
		return false
	return null

func _leech_start(b, p, ev):
	if p.has_type("grass"):
		b.add_log(["-immune", b.pid(p)])
		return false
	b.add_log(["-start", b.pid(p), "leech_seed"])
	return null

func _leech_residual(b, p, ev):
	var src = ev["state"].get("source")
	if src == null or src.fainted or not src.active:
		return null
	var dmg = b.damage_pokemon(p, _frac(p.max_hp, 1, 8), src, {"id": "leech_seed", "effect_type": "volatile"})
	if dmg > 0:
		if GameData.get_ability(p.ability).get("flags", {}).get("liquid_ooze", false):
			b.damage_pokemon(src, dmg, p, {"id": "liquid_ooze", "effect_type": "ability"})
		else:
			b.heal_pokemon(src, dmg, p, {"id": "leech_seed", "effect_type": "volatile"})
	return null

func _sub_start(b, p, ev):
	ev["state"]["hp"] = int(floor(p.max_hp / 4.0))
	b.add_log(["-start", b.pid(p), "substitute"])
	return null

func _protect_start(b, p, ev):
	b.add_log(["-singleturn", b.pid(p), ev["effect_id"]])
	return null

func _protect_try_hit(b, p, ev):
	var mv = ev["move"]
	if mv == null or ev["source"] == p:
		return null
	if not mv.get("flags", []).has("protect"):
		return null
	if mv.get("breaks_protect", false):
		b.remove_volatile(p, ev["effect_id"])
		b.add_log(["-activate", b.pid(p), "broke protect"])
		return null
	b.add_log(["-activate", b.pid(p), "protect"])
	var src = ev["source"]
	if src != null and src.volatiles.has("locked_move"):
		src.volatiles.erase("locked_move")
	return false

func _spiky_shield_try_hit(b, p, ev):
	var r = _protect_try_hit(b, p, ev)
	if Battle.is_false(r):
		var mv = ev["move"]
		var src = ev["source"]
		if mv.get("flags", []).has("contact") and src != null and not src.fainted:
			b.damage_pokemon(src, _frac(src.max_hp, 1, 8), p, {"id": "spiky_shield", "effect_type": "volatile"})
	return r

func _baneful_bunker_try_hit(b, p, ev):
	var r = _protect_try_hit(b, p, ev)
	if Battle.is_false(r):
		var mv = ev["move"]
		var src = ev["source"]
		if mv.get("flags", []).has("contact") and src != null and not src.fainted:
			b.set_status(src, "psn", p, {"id": "baneful_bunker", "effect_type": "volatile"})
	return r

func _endure_start(b, p, _ev):
	b.add_log(["-singleturn", b.pid(p), "endure"])
	return null

func _endure_damage(b, p, ev):
	var eff = ev["effect"]
	if eff is Dictionary and eff.get("effect_type") == "move" and int(ev["value"]) >= p.hp:
		b.add_log(["-activate", b.pid(p), "endure"])
		return p.hp - 1
	return null

func _stall_start(_b, _p, ev):
	ev["state"]["counter"] = 3
	return null

func _stall_restart(_b, _p, ev):
	var st: Dictionary = ev["state"]
	if int(st.get("counter", 3)) < 729:
		st["counter"] = int(st.get("counter", 3)) * 3
	st["duration"] = 2
	return true

func _stall_move(b, p, ev):
	var counter := int(ev["state"].get("counter", 1))
	var ok = b.rng.chance(1, counter)
	if not ok:
		p.volatiles.erase("stall")
	return ok

func _taunt_start(b, p, ev):
	# lasts 3 turns; 4 if the target hasn't moved yet this turn
	if p.active_turns > 0 and not _will_move(b, p):
		ev["state"]["duration"] = int(ev["state"].get("duration", 3)) + 1
	b.add_log(["-start", b.pid(p), "taunt"])
	return null

func _will_move(b, p) -> bool:
	for a in b.queue:
		if a.get("choice") == "move" and a.get("pokemon") == p:
			return true
	return false

func _taunt_disable(_b, _p, ev):
	var mv = ev["effect"]
	if mv is Dictionary and mv.get("category") == "status":
		return false
	return null

func _taunt_before_move(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("category") == "status":
		_cant(b, p, "taunt")
		return false
	return null

func _encore_start(b, p, ev):
	var lm: String = p.last_move
	var md := GameData.get_move(lm)
	if lm == "" or md.is_empty() or md.get("no_encore", false) or not p.has_move(lm) or p.last_move_used_turn < 0:
		return false
	var slot = p.get_move_slot(lm)
	if slot["pp"] <= 0:
		return false
	ev["state"]["move"] = lm
	if p.active_turns > 0 and not _will_move(b, p):
		ev["state"]["duration"] = int(ev["state"].get("duration", 3)) + 1
	# replace queued move this turn
	for a in b.queue:
		if a.get("choice") == "move" and a.get("pokemon") == p:
			a["move"] = lm
	b.add_log(["-start", b.pid(p), "encore"])
	return null

func _encore_disable(_b, _p, ev):
	var mv = ev["effect"]
	if mv is Dictionary and mv.get("id") != ev["state"].get("move"):
		return false
	return null

func _encore_lock(_b, _p, ev):
	return str(ev["state"].get("move", ""))

func _encore_residual(b, p, ev):
	var slot = p.get_move_slot(str(ev["state"].get("move", "")))
	if slot.is_empty() or slot["pp"] <= 0:
		b.remove_volatile(p, "encore")
	return null

func _disable_start(b, p, ev):
	var lm: String = p.last_move
	if lm == "" or lm == "struggle" or not p.has_move(lm):
		return false
	ev["state"]["move"] = lm
	if p.active_turns > 0 and not _will_move(b, p):
		ev["state"]["duration"] = int(ev["state"].get("duration", 4)) + 1
	b.add_log(["-start", b.pid(p), "disable", lm])
	return null

func _disable_disable(_b, _p, ev):
	var mv = ev["effect"]
	if mv is Dictionary and mv.get("id") == ev["state"].get("move"):
		return false
	return null

func _disable_before_move(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("id") == ev["state"].get("move"):
		_cant(b, p, "disable")
		return false
	return null

func _yawn_start(b, p, ev):
	if p.status != "":
		return false
	# check sleep immunity now (Insomnia, terrain, Safeguard handled at end)
	b.add_log(["-start", b.pid(p), "yawn"])
	return null

func _yawn_end(b, p, ev):
	if p == null or p.fainted:
		return null
	b.set_status(p, "slp", ev["state"].get("source"), {"id": "yawn", "effect_type": "volatile"})
	return null

func _curse_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "curse"])
	return null

func _curse_residual(b, p, _ev):
	b.damage_pokemon(p, _frac(p.max_hp, 1, 4), null, {"id": "curse", "effect_type": "volatile"})
	return null

func _nightmare_start(b, p, _ev):
	if p.status != "slp":
		return false
	b.add_log(["-start", b.pid(p), "nightmare"])
	return null

func _nightmare_residual(b, p, _ev):
	if p.status != "slp":
		b.remove_volatile(p, "nightmare")
		return null
	b.damage_pokemon(p, _frac(p.max_hp, 1, 4), null, {"id": "nightmare", "effect_type": "volatile"})
	return null

func _focus_energy_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "focus_energy"])
	return null

func _focus_energy_crit(_b, _p, ev):
	return int(ev["value"]) + 2

func _locked_start(b, _p, ev):
	ev["state"]["duration"] = b.rng.range_int(2, 3)
	ev["state"]["move"] = str(ev["effect"].get("id", "")) if ev["effect"] is Dictionary else ""
	return null

func _locked_lock(_b, _p, ev):
	return str(ev["state"].get("move", ""))

func _locked_after_move(b, p, ev):
	var st: Dictionary = ev["state"]
	# duration counts remaining turns; when it reaches 1 after this move, ends next residual with confusion
	if int(st.get("duration", 0)) <= 1 or p.move_this_turn == "aborted":
		b.remove_volatile(p, "locked_move")
		if p.move_this_turn != "aborted":
			b.add_volatile(p, "confusion", p, {"id": "fatigue", "effect_type": "volatile"})
		return null
	return null

func _locked_end(_b, _p, _ev):
	return null

func _recharge_before_move(b, p, _ev):
	_cant(b, p, "recharge")
	b.remove_volatile(p, "must_recharge")
	return false

func _recharge_lock(_b, _p, _ev):
	return "recharge"

func _two_turn_lock(_b, _p, ev):
	return str(ev["state"].get("move", ""))

func _two_turn_end(_b, _p, _ev):
	return null

func _roost_start(b, p, _ev):
	if p.has_type("flying"):
		var nt: Array = []
		for t in p.types:
			if t != "flying":
				nt.append(t)
		if nt.is_empty():
			nt = ["normal"]
		p.types = nt
		b.add_log(["-singleturn", b.pid(p), "roost"])
	return null

func _roost_end(_b, p, _ev):
	if p != null and p.active:
		p.types = p.base_types.duplicate()
	return null

func _bind_start(b, p, ev):
	var src = ev["source"]
	var dur = b.rng.range_int(4, 5)
	if src != null and GameData.get_item(src.item).get("flags", {}).get("extends_binding", false):
		dur = 7
	ev["state"]["duration"] = dur
	ev["state"]["frac"] = 6 if (src != null and GameData.get_item(src.item).get("flags", {}).get("stronger_binding", false)) else 8
	b.add_log(["-activate", b.pid(p), "bind", b.pid(src)])
	return null

func _bind_residual(b, p, ev):
	var src = ev["state"].get("source")
	if src == null or src.fainted or not src.active:
		b.remove_volatile(p, "partially_trapped")
		return null
	b.damage_pokemon(p, _frac(p.max_hp, 1, int(ev["state"].get("frac", 8))), src, {"id": "partially_trapped", "effect_type": "volatile"})
	return null

func _trap(_b, _p, _ev):
	return false

func _aqua_ring_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "aqua_ring"])
	return null

func _aqua_ring_residual(b, p, _ev):
	b.heal_pokemon(p, _frac(p.max_hp, 1, 16), p, {"id": "aqua_ring", "effect_type": "volatile"})
	return null

func _ingrain_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "ingrain"])
	return null

func _ingrain_residual(b, p, _ev):
	b.heal_pokemon(p, _frac(p.max_hp, 1, 16), p, {"id": "ingrain", "effect_type": "volatile"})
	return null

func _ingrain_dragout(_b, _p, _ev):
	return false

func _destiny_start(b, p, _ev):
	b.add_log(["-singlemove", b.pid(p), "destiny_bond"])
	return null

func _destiny_faint(b, p, ev):
	var src = ev["source"]
	var eff = ev["effect"]
	if src == null or src == p or not (eff is Dictionary and eff.get("effect_type") == "move"):
		return null
	if not src.fainted and src.hp > 0:
		b.add_log(["-activate", b.pid(p), "destiny_bond"])
		b.faint(src, p, {"id": "destiny_bond", "effect_type": "volatile"})
	return null

func _destiny_before_move(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("id") != "destiny_bond":
		b.remove_volatile(p, "destiny_bond")
	return null

func _perish_start(b, p, ev):
	ev["state"]["count"] = 4
	b.add_log(["-start", b.pid(p), "perish_song", 3])
	return null

func _perish_residual(b, p, ev):
	var st: Dictionary = ev["state"]
	st["count"] = int(st.get("count", 4)) - 1
	b.add_log(["-start", b.pid(p), "perish", int(st["count"])])
	if int(st["count"]) <= 0:
		b.faint(p, null, {"id": "perish_song", "effect_type": "volatile"})
	return null

func _magnet_rise_start(b, p, _ev):
	if p.volatiles.has("ingrain") or p.volatiles.has("smack_down") or b.has_pseudo_weather("gravity"):
		return false
	b.add_log(["-start", b.pid(p), "magnet_rise"])
	return null

func _smack_down_start(b, p, ev):
	var was_grounded = p.is_grounded()
	p.volatiles.erase("magnet_rise")
	if was_grounded and not (p.has_type("flying") or p.ability == "levitate"):
		return false
	b.add_log(["-start", b.pid(p), "smack_down"])
	return null

func _flash_fire_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "flash_fire"])
	return null

func _flash_fire_atk(b, _p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("type") == "fire":
		b.chain_modify(3, 2)
	return null

func _flash_fire_spa(b, _p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("type") == "fire":
		b.chain_modify(3, 2)
	return null

func _unburden_spe(b, p, _ev):
	if p.item == "" and p.ability == "unburden":
		b.chain_modify(2)
	return null

func _charge_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "charge"])
	return null

func _charge_bp(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("type") == "electric":
		b.chain_modify(2)
		b.remove_volatile(p, "charge")
	return null

func _hh_start(b, p, _ev):
	b.add_log(["-singleturn", b.pid(p), "helping_hand"])
	return null

func _hh_bp(b, _p, _ev):
	b.chain_modify(3, 2)
	return null

func _follow_me_start(b, p, ev):
	b.add_log(["-singleturn", b.pid(p), ev["effect_id"]])
	return null

func _laser_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "laser_focus"])
	return null

func _laser_crit(_b, _p, _ev):
	return 4

func _salt_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "salt_cure"])
	return null

func _salt_residual(b, p, _ev):
	var den := 4 if (p.has_type("water") or p.has_type("steel")) else 8
	b.damage_pokemon(p, _frac(p.max_hp, 1, den), null, {"id": "salt_cure", "effect_type": "volatile"})
	return null

func _throat_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "throat_chop"])
	return null

func _throat_disable(_b, _p, ev):
	var mv = ev["effect"]
	if mv is Dictionary and mv.get("flags", []).has("sound"):
		return false
	return null

func _throat_before_move(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("flags", []).has("sound"):
		_cant(b, p, "throat_chop")
		return false
	return null

func _glaive_acc(_b, _p, _ev):
	return true

func _glaive_dmg(b, _p, _ev):
	b.chain_modify(2)
	return null

func _glaive_before_move(b, p, _ev):
	b.remove_volatile(p, "glaive_rush")
	return null

func _heal_block_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "heal_block"])
	return null

func _heal_block_try_heal(_b, _p, ev):
	var eff = ev["effect"]
	if eff is Dictionary and eff.get("effect_type") == "move" and eff.get("drain") != null:
		return false
	if eff is Dictionary and eff.get("effect_type") == "move":
		return false
	return null

func _heal_block_disable(_b, _p, ev):
	var mv = ev["effect"]
	if mv is Dictionary and mv.get("flags", []).has("heal"):
		return false
	return null

func _electrify_type(_b, _p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("category") != "status":
		mv["type"] = "electric"
	return null

func _powder_try_move(b, p, ev):
	var mv = ev["move"]
	if mv != null and mv.get("type") == "fire":
		b.add_log(["-activate", b.pid(p), "powder"])
		b.damage_pokemon(p, _frac(p.max_hp, 1, 4), p, {"id": "powder", "effect_type": "volatile"})
		return false
	return null

func _slow_start_start(b, p, _ev):
	b.add_log(["-start", b.pid(p), "slow_start"])
	return null

func _slow_start_atk(b, _p, _ev):
	b.chain_modify(1, 2)
	return null

func _slow_start_spe(b, _p, _ev):
	b.chain_modify(1, 2)
	return null

# ============================================================
# SIDE CONDITIONS
# ============================================================
func _sides() -> Dictionary:
	return {
		"reflect": {"onStart": _screen_start, "onSourceModifyDamage": _reflect_damage},
		"light_screen": {"onStart": _screen_start, "onSourceModifyDamage": _light_screen_damage},
		"aurora_veil": {"onStart": _screen_start, "onSourceModifyDamage": _aurora_veil_damage},
		"safeguard": {"onStart": _side_generic_start, "onSetStatus": _safeguard_set_status, "onTryAddVolatile": _safeguard_volatile},
		"mist": {"onStart": _side_generic_start, "onTryBoost": _mist_try_boost},
		"tailwind": {"onStart": _side_generic_start, "onModifySpe": _tailwind_spe},
		"spikes": {"onStart": _spikes_start, "onRestart": _spikes_restart, "onEntryHazard": _spikes_hazard},
		"stealth_rock": {"onEntryHazard": _rocks_hazard},
		"toxic_spikes": {"onStart": _tspikes_start, "onRestart": _tspikes_restart, "onEntryHazard": _tspikes_hazard},
		"sticky_web": {"onEntryHazard": _web_hazard},
		"lucky_chant": {"onStart": _side_generic_start, "onCriticalHit": _lucky_chant_crit},
		"quick_guard": {"onStart": _side_generic_start, "onTryHitPriority": 4, "onTryHit": _quick_guard_try_hit},
		"wide_guard": {"onStart": _side_generic_start, "onTryHitPriority": 4, "onTryHit": _wide_guard_try_hit},
	}

func _side_of(b, p, ev):
	if p != null:
		return p.side
	return ev.get("side", ev.get("target"))

func _screen_start(b, p, ev):
	var src = ev["source"]
	var dur := int(b.registry.side_meta.get(ev["effect_id"], {}).get("duration", 5))
	if src != null and GameData.get_item(src.item).get("flags", {}).get("screen_extender", false):
		dur = 8
	ev["state"]["duration"] = dur
	return null

func _side_generic_start(b, _p, ev):
	ev["state"]["duration"] = int(b.registry.side_meta.get(ev["effect_id"], {}).get("duration", 5))
	return null

func _screen_applies(b, p, ev) -> bool:
	var mv = ev["move"]
	if mv == null or mv.get("crit", false):
		return false
	var attacker = ev["target"]
	if attacker != null and GameData.get_ability(attacker.ability).get("flags", {}).get("infiltrator", false):
		return false
	if attacker == p:
		return false
	return true

func _screen_mod(b, p) -> void:
	if p != null and p.side.active_pokemon().size() > 1:
		b.chain_modify(2732, 4096)
	else:
		b.chain_modify(1, 2)

func _reflect_damage(b, p, ev):
	if _screen_applies(b, p, ev) and ev["move"]["category"] == "physical":
		_screen_mod(b, p)
	return null

func _light_screen_damage(b, p, ev):
	if _screen_applies(b, p, ev) and ev["move"]["category"] == "special":
		_screen_mod(b, p)
	return null

func _aurora_veil_damage(b, p, ev):
	if p != null and (p.side.has_side_condition("reflect") and ev["move"] != null and ev["move"]["category"] == "physical"):
		return null
	if p != null and (p.side.has_side_condition("light_screen") and ev["move"] != null and ev["move"]["category"] == "special"):
		return null
	if _screen_applies(b, p, ev):
		_screen_mod(b, p)
	return null

func _safeguard_set_status(b, p, ev):
	var src = ev["source"]
	var eff = ev["effect"]
	if src == null or src == p:
		return null
	if eff is Dictionary and eff.get("effect_type") in ["move", "ability"]:
		if src.ability == "infiltrator" or GameData.get_ability(src.ability).get("flags", {}).get("infiltrator", false):
			return null
		b.add_log(["-activate", b.pid(p), "safeguard"])
		return false
	return null

func _safeguard_volatile(b, p, ev):
	if str(ev["value"]) != "confusion":
		return null
	var src = ev["source"]
	if src == null or src == p:
		return null
	var eff = ev["effect"]
	if eff is Dictionary and eff.get("id") == "fatigue":
		return null
	b.add_log(["-activate", b.pid(p), "safeguard"])
	return false

func _mist_try_boost(b, p, ev):
	var src = ev["source"]
	if src == null or src == p or src.side == p.side:
		return null
	var eff = ev["effect"]
	if eff is Dictionary and GameData.get_ability(str(eff.get("id", ""))).get("flags", {}).get("infiltrator", false):
		return null
	var boosts: Dictionary = ev["value"]
	var blocked := false
	for k in boosts.keys():
		if int(boosts[k]) < 0:
			boosts.erase(k)
			blocked = true
	if blocked:
		b.add_log(["-activate", b.pid(p), "mist"])
	return boosts

func _tailwind_spe(b, _p, _ev):
	b.chain_modify(2)
	return null

func _spikes_start(_b, _p, ev):
	ev["state"]["layers"] = 1
	return null

func _spikes_restart(_b, _p, ev):
	if int(ev["state"].get("layers", 1)) >= 3:
		return false
	ev["state"]["layers"] = int(ev["state"]["layers"]) + 1
	return true

func _hazard_immune(p) -> bool:
	return GameData.get_item(p.item).get("flags", {}).get("hazard_immune", false)

func _spikes_hazard(b, p, ev):
	if not p.is_grounded() or _hazard_immune(p):
		return null
	var layers := int(ev["state"].get("layers", 1))
	var den = [8, 6, 4][layers - 1]
	b.damage_pokemon(p, _frac(p.max_hp, 1, den), null, {"id": "spikes", "effect_type": "side"})
	return null

func _rocks_hazard(b, p, _ev):
	if _hazard_immune(p):
		return null
	var mod = b.run_effectiveness(p, {"type": "rock", "id": "stealth_rock", "effect_type": "move", "flags": []})
	var dmg := int(floor(p.max_hp * pow(2.0, mod) / 8.0))
	b.damage_pokemon(p, maxi(1, dmg), null, {"id": "stealth_rock", "effect_type": "side"})
	return null

func _tspikes_start(_b, _p, ev):
	ev["state"]["layers"] = 1
	return null

func _tspikes_restart(_b, _p, ev):
	if int(ev["state"].get("layers", 1)) >= 2:
		return false
	ev["state"]["layers"] = 2
	return true

func _tspikes_hazard(b, p, ev):
	if not p.is_grounded():
		return null
	if p.has_type("poison"):
		b.remove_side_condition(p.side, "toxic_spikes")
		return null
	if p.has_type("steel") or _hazard_immune(p):
		return null
	var layers := int(ev["state"].get("layers", 1))
	b.set_status(p, "tox" if layers >= 2 else "psn", null, {"id": "toxic_spikes", "effect_type": "side"})
	return null

func _web_hazard(b, p, ev):
	if not p.is_grounded() or _hazard_immune(p):
		return null
	b.add_log(["-activate", b.pid(p), "sticky_web"])
	b.boost(p, {"spe": -1}, ev["state"].get("source"), {"id": "sticky_web", "effect_type": "side"})
	return null

func _lucky_chant_crit(_b, _p, _ev):
	return false

func _quick_guard_try_hit(b, p, ev):
	var mv = ev["move"]
	var src = ev["source"]
	if mv == null or src == null or src.side == p.side:
		return null
	if int(b.current_action.get("priority", 0)) > 0 and mv.get("flags", []).has("protect"):
		b.add_log(["-activate", b.pid(p), "quick_guard"])
		return false
	return null

func _wide_guard_try_hit(b, p, ev):
	var mv = ev["move"]
	var src = ev["source"]
	if mv == null or src == null or src.side == p.side:
		return null
	if mv.get("target") in ["allAdjacentFoes", "allAdjacent"]:
		b.add_log(["-activate", b.pid(p), "wide_guard"])
		return false
	return null

# ============================================================
# SLOT CONDITIONS
# ============================================================
func _slots() -> Dictionary:
	return {
		"wish": {"onStart": _wish_start, "onEnd": _wish_end},
		"future_move": {"onStart": _future_start, "onEnd": _future_end},
	}

func _wish_start(_b, _p, ev):
	ev["state"]["duration"] = 2
	return null

func _wish_end(b, p, ev):
	if p == null or p.fainted:
		return null
	b.heal_pokemon(p, int(ev["state"].get("hp", 1)), ev["state"].get("source"), {"id": "wish", "effect_type": "slot"})
	return null

func _future_start(_b, _p, ev):
	ev["state"]["duration"] = 3
	return null

func _future_end(b, p, ev):
	if p == null or p.fainted:
		return null
	var src = ev["state"].get("source")
	var mv: Dictionary = GameData.get_move(str(ev["state"].get("move", ""))).duplicate(true)
	mv["effect_type"] = "move"
	mv["ignore_immunity"] = false
	mv["future_hit"] = true
	mv.erase("effect")
	b.add_log(["-end", b.pid(p), mv["id"]])
	if src == null:
		return null
	var dmg = b.get_damage(src, p, mv)
	if typeof(dmg) == TYPE_INT and dmg > 0 and b.run_immunity(p, mv["type"], mv):
		b.damage_pokemon(p, dmg, src, mv)
	return null

# ============================================================
# WEATHER (generic, data-driven from data/weather/*.json)
# ============================================================
func _weathers() -> Dictionary:
	return {
		"generic": {
			"onStart": _weather_start,
			"onResidualOrder": 1, "onResidual": _weather_residual,
			"onWeatherModifyDamage": _weather_modify_damage,
			"onModifySpDPriority": 10, "onModifySpD": _weather_modify_spd,
			"onModifyDefPriority": 10, "onModifyDef": _weather_modify_def,
			"onSetStatus": _weather_set_status,
		}
	}

func _wdef(b) -> Dictionary:
	return GameData.weather.get(b.weather, {})

func _weather_start(_b, _p, _ev):
	return null

func _weather_residual(b, _p, _ev):
	var w := _wdef(b)
	b.add_log(["-weather", b.weather, "[upkeep]"])
	if not w.has("damage"):
		return null
	var actives = b.all_active()
	actives.sort_custom(func(x, y): return x.speed > y.speed)
	for p in actives:
		if p.fainted:
			continue
		var immune := false
		for t in w.get("immune_types", []):
			if p.has_type(t):
				immune = true
		var af: Dictionary = GameData.get_ability(p.ability).get("flags", {})
		if af.get("weather_immune", []).has(b.weather) or af.get("overcoat", false):
			immune = true
		if GameData.get_item(p.item).get("flags", {}).get("weather_immune", false):
			immune = true
		if p.volatiles.has("two_turn_move") and p.volatiles["two_turn_move"].get("invulnerable", false):
			immune = true
		if immune:
			continue
		var d: Array = w["damage"]
		b.damage_pokemon(p, _frac(p.max_hp, int(d[0]), int(d[1])), null, {"id": b.weather, "effect_type": "weather"})
	return null

func _weather_modify_damage(b, _p, ev):
	var w := _wdef(b)
	var mv = ev["move"]
	if mv == null:
		return null
	var t: String = mv["type"]
	var boost: Dictionary = w.get("boost", {})
	var nerf: Dictionary = w.get("nerf", {})
	if boost.has(t):
		b.chain_modify(float(boost[t]))
	elif nerf.has(t):
		b.chain_modify(float(nerf[t]))
	return null

func _weather_modify_spd(b, p, _ev):
	var w := _wdef(b)
	if w.has("spd_boost_type") and p != null and p.has_type(str(w["spd_boost_type"])):
		b.chain_modify(3, 2)
	return null

func _weather_modify_def(b, p, _ev):
	var w := _wdef(b)
	if w.has("def_boost_type") and p != null and p.has_type(str(w["def_boost_type"])):
		b.chain_modify(3, 2)
	return null

func _weather_set_status(b, _p, ev):
	var w := _wdef(b)
	if w.get("prevents_status", []).has(str(ev["value"])):
		return false
	return null

# ============================================================
# TERRAIN (generic, data-driven from data/terrain/*.json)
# ============================================================
func _terrains() -> Dictionary:
	return {
		"generic": {
			"onBasePowerPriority": 6, "onBasePower": _terrain_base_power,
			"onResidualOrder": 5, "onResidual": _terrain_residual,
			"onSetStatus": _terrain_set_status,
			"onTryAddVolatile": _terrain_try_volatile,
			"onTryHitPriority": 4, "onTryHit": _terrain_try_hit,
		}
	}

func _tdef(b) -> Dictionary:
	return GameData.terrain.get(b.terrain, {})

func _terrain_base_power(b, p, ev):
	var t := _tdef(b)
	var mv = ev["move"]
	if mv == null or p == null:
		return null
	var defender = ev["source"]
	if t.has("boost_type") and mv["type"] == t["boost_type"] and p.is_grounded():
		b.chain_modify(5325, 4096)
	if t.get("weakens_types", []).has(mv["type"]) and defender != null and defender.is_grounded():
		b.chain_modify(1, 2)
	if t.get("weakens_moves", []).has(mv["id"]) and defender != null and defender.is_grounded():
		b.chain_modify(1, 2)
	return null

func _terrain_residual(b, _p, _ev):
	var t := _tdef(b)
	if not t.has("heal"):
		return null
	var actives = b.all_active()
	actives.sort_custom(func(x, y): return x.speed > y.speed)
	for p in actives:
		if p.fainted or not p.is_grounded():
			continue
		b.heal_pokemon(p, _frac(p.max_hp, int(t["heal"][0]), int(t["heal"][1])), p, {"id": b.terrain, "effect_type": "terrain"})
	return null

func _terrain_set_status(b, p, ev):
	var t := _tdef(b)
	if p == null or not p.is_grounded():
		return null
	var blocked: Array = t.get("blocks_status", [])
	if blocked.has(str(ev["value"])) or blocked.has("all"):
		b.add_log(["-activate", b.pid(p), b.terrain])
		return false
	return null

func _terrain_try_volatile(b, p, ev):
	var t := _tdef(b)
	if p == null or not p.is_grounded():
		return null
	if t.get("blocks_volatiles", []).has(str(ev["value"])):
		b.add_log(["-activate", b.pid(p), b.terrain])
		return false
	return null

func _terrain_try_hit(b, p, ev):
	var t := _tdef(b)
	if not t.get("blocks_priority", false):
		return null
	var mv = ev["move"]
	var src = ev["source"]
	if mv == null or src == null or src == p or src.side == p.side:
		return null
	if not p.is_grounded():
		return null
	if int(b.current_action.get("priority", 0)) > 0 and b.current_action.get("pokemon") == src:
		b.add_log(["-activate", b.pid(p), b.terrain])
		return false
	return null

# ============================================================
# FIELD (pseudo weather)
# ============================================================
func _fields() -> Dictionary:
	return {
		"trick_room": {"onStart": _tr_start, "onRestart": _tr_restart},
		"gravity": {"onStart": _gravity_start, "onModifyAccuracy": _gravity_acc},
	}

func _tr_start(_b, _p, ev):
	ev["state"]["duration"] = 5
	return null

func _tr_restart(b, _p, _ev):
	b.remove_pseudo_weather("trick_room")
	return true

func _gravity_start(_b, _p, ev):
	ev["state"]["duration"] = 5
	return null

func _gravity_acc(b, _p, _ev):
	b.chain_modify(6840, 4096)
	return null
