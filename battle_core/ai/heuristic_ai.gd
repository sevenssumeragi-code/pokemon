class_name HeuristicAI
extends BattleAI
## Evaluation-function AI: expected damage, KO/speed logic, boosts, status, healing, hazards, switching.
## Works per active slot so it can be extended to doubles (targets chosen per move).

var temperature: float = 0.15  # probability of taking the 2nd best option (diversity)
var switch_threshold: float = 35.0
var known_moves_only: bool = false  # when true, foe damage estimates only use moves the foe has revealed
var _side_index: int = 0
var _b: Battle

func choose(battle, side_index: int, request: Dictionary) -> Array:
	_b = battle
	_side_index = side_index
	var side = battle.sides[side_index]
	if request.get("type") == "switch":
		return _choose_switches(side, request)
	var out: Array = []
	var used_bench := {}
	for a in request.get("active", []):
		var p = side.active[int(a["slot"])]
		if p == null:
			continue
		var foes: Array = p.foes()
		var options: Array = []  # [{score, choice}]
		for m in a["moves"]:
			if m["disabled"]:
				continue
			var best_t = null
			var best_s := -1e9
			var md := GameData.get_move(m["id"])
			var tgt_kind: String = str(md.get("target", "normal"))
			if foes.is_empty() or tgt_kind in ["self", "allySide", "allyTeam", "all", "foeSide", "allAdjacentFoes", "allAdjacent", "scripted", "randomNormal"]:
				var sc := _score_move(p, m["id"], foes[0] if not foes.is_empty() else null, foes)
				options.append({"score": sc, "choice": {"type": "move", "move": m["id"]}})
			else:
				for f in foes:
					var sc := _score_move(p, m["id"], f, foes)
					if sc > best_s:
						best_s = sc
						best_t = f
				var ch := {"type": "move", "move": m["id"]}
				if battle.slots_per_side > 1 and best_t != null:
					ch["target"] = best_t.position + 1
				options.append({"score": best_s, "choice": ch})
		# switching
		if not a["trapped"] and not a.get("locked", false):
			var best_alt = null
			var best_alt_score := -1e9
			for bp in side.team:
				if bp.active or bp.fainted or used_bench.has(bp.team_index):
					continue
				var sc := _matchup(bp, foes)
				if sc > best_alt_score:
					best_alt_score = sc
					best_alt = bp
			if best_alt != null:
				var cur := _matchup(p, foes)
				var sw_score := best_alt_score - cur - switch_threshold
				# heavy penalty when the current mon can KO or is healthy and fast
				if not options.is_empty():
					options.sort_custom(func(x, y): return x["score"] > y["score"])
					if options[0]["score"] >= 60:
						sw_score -= 40
				sw_score += _hazard_penalty(best_alt)
				options.append({"score": sw_score, "choice": {"type": "switch", "index": best_alt.team_index}})
		if options.is_empty():
			out.append({"type": "move", "move": "struggle"})
			continue
		options.sort_custom(func(x, y): return x["score"] > y["score"])
		var pick: Dictionary = options[0]
		if options.size() > 1 and rng.random_float() < temperature and options[1]["score"] > options[0]["score"] - 25:
			pick = options[1]
		if pick["choice"]["type"] == "switch":
			used_bench[pick["choice"]["index"]] = true
		out.append(pick["choice"])
	return out

func _choose_switches(side, request: Dictionary) -> Array:
	var out: Array = []
	var used := {}
	var foes: Array = side.foe.active_pokemon()
	for slot in request["slots"]:
		var best = null
		var best_s := -1e9
		for bp in side.team:
			if bp.active or bp.fainted or used.has(bp.team_index):
				continue
			var sc := _matchup(bp, foes) + _hazard_penalty(bp)
			if sc > best_s:
				best_s = sc
				best = bp
		if best != null:
			used[best.team_index] = true
			out.append({"type": "switch", "index": best.team_index})
	return out

# ------------------------------------------------------------------
# scoring helpers
# ------------------------------------------------------------------
func _acc_factor(md: Dictionary, user, target) -> float:
	var acc = md.get("accuracy", true)
	if _b.weather != "" and md.get("always_hit_in", []).has(_b.weather):
		return 1.0
	if typeof(acc) == TYPE_BOOL:
		return 1.0
	var a := float(acc) / 100.0
	if target != null:
		var boost: int = clampi(user.boosts["accuracy"] - target.boosts["evasion"], -6, 6)
		var f := StatCalc.acc_fraction(boost)
		a *= float(f.x) / float(f.y)
		if target.ability == "minimal_body":
			a /= 1.5
	if user.ability == "compound_eyes":
		a *= 1.3
	return clampf(a, 0.0, 1.0)

func _expected_hits(md: Dictionary) -> float:
	if md.has("multihit"):
		var mh = md["multihit"]
		if mh is Array:
			return 3.1 if int(mh[1]) == 5 else (float(mh[0]) + float(mh[1])) / 2.0
		return float(mh)
	return 1.0

## Best expected % damage this pokemon can deal to target with one move.
func _best_damage_pct(user, target) -> Dictionary:
	var best := 0.0
	var best_move := ""
	var hidden: bool = known_moves_only and user.side.index != _side_index
	for m in user.moves:
		if m["pp"] <= 0:
			continue
		if hidden and not user.revealed_moves.has(m["id"]):
			continue
		var md := GameData.get_move(m["id"])
		if md["category"] == "status":
			continue
		var d := float(_b.estimate_damage(user, target, m["id"])) * _expected_hits(md) * _acc_factor(md, user, target)
		var pct := d / float(target.max_hp) * 100.0
		if pct > best:
			best = pct
			best_move = m["id"]
	if hidden and best_move == "" and user.revealed_moves.is_empty():
		# prior: an 80 BP STAB move of the foe's stronger attacking stat
		var t: String = user.get_types()[0]
		var phys: bool = user.get_stat("atk") >= user.get_stat("spa")
		var probe := {"id": "_probe", "type": t, "category": "physical" if phys else "special", "power": 80, "accuracy": 100, "pp": 1, "priority": 0, "target": "normal", "flags": [], "crit_ratio": 1, "effect_type": "move", "ignore_immunity": false}
		var prev := _b.estimating
		_b.estimating = true
		var pr := _b.debug_fixed_roll
		var pc := _b.debug_no_crit
		_b.debug_fixed_roll = 92
		_b.debug_no_crit = true
		var d = _b.get_damage(user, target, probe) if _b.run_immunity(target, t, probe) else 0
		_b.debug_fixed_roll = pr
		_b.debug_no_crit = pc
		_b.estimating = prev
		best = float(d if typeof(d) == TYPE_INT else 0) / float(target.max_hp) * 100.0
	return {"pct": best, "move": best_move}

func _faster(a, b) -> bool:
	var sa = a.get_stat("spe")
	var sb = b.get_stat("spe")
	if _b.has_pseudo_weather("trick_room"):
		return sa < sb
	return sa > sb

## Matchup value of `p` against foes: my best damage% minus their best damage% to me, HP-aware.
func _matchup(p, foes: Array) -> float:
	if foes.is_empty():
		return 0.0
	var total := 0.0
	for f in foes:
		var mine = _best_damage_pct(p, f)["pct"]
		var theirs = _best_damage_pct(f, p)["pct"]
		var my_hp = p.hp_fraction() * 100.0
		var their_hp = f.hp_fraction() * 100.0
		var turns_to_ko_them := ceili(their_hp / maxf(mine, 1.0))
		var turns_to_ko_me := ceili(my_hp / maxf(theirs, 1.0))
		var v := 0.0
		if turns_to_ko_them < turns_to_ko_me or (turns_to_ko_them == turns_to_ko_me and _faster(p, f)):
			v += 50.0
		else:
			v -= 50.0
		v += clampf(mine - theirs, -60.0, 60.0)
		v += (my_hp - 50.0) * 0.3
		total += v
	return total / float(foes.size())

func _hazard_penalty(p) -> float:
	var side = p.side
	var pen := 0.0
	if side.has_side_condition("stealth_rock") and not p.has_type("flying") or side.has_side_condition("stealth_rock"):
		var e := GameData.effectiveness("rock", p.get_types())
		pen -= 12.5 * e
	if side.has_side_condition("spikes") and p.is_grounded():
		pen -= 8.0 * int(side.side_conditions["spikes"].get("layers", 1))
	if side.has_side_condition("toxic_spikes") and p.is_grounded() and not p.has_type("poison") and not p.has_type("steel") and p.status == "":
		pen -= 15.0
	return pen

func _status_immune(target, status: String) -> bool:
	if target.status != "":
		return true
	var meta: Dictionary = _b.registry.status_meta.get(status, {})
	for t in target.get_types():
		if meta.get("immune_types", []).has(t):
			return true
	if target.volatiles.has("substitute"):
		return true
	if _b.terrain == "misty" and target.is_grounded():
		return true
	if _b.terrain == "electric" and status == "slp" and target.is_grounded():
		return true
	if target.side.has_side_condition("safeguard"):
		return true
	if status == "frz" and _b.weather == "sun":
		return true
	return false

func _is_physical_attacker(p) -> bool:
	var phys := 0
	var spec := 0
	for m in p.moves:
		var md := GameData.get_move(m["id"])
		if md["category"] == "physical": phys += 1
		elif md["category"] == "special": spec += 1
	return phys >= spec

func _score_move(user, move_id: String, target, foes: Array) -> float:
	var md := GameData.get_move(move_id)
	var score := 0.0
	var faster: bool = target != null and _faster(user, target)
	if user.ability == "prankster" and md["category"] == "status" and target != null and not target.has_type("dark"):
		faster = true  # Prankster: status moves go first
	# asleep: only sleep-usable moves matter unless we wake this turn (Rest sleep is a known 2 turns)
	if user.status == "slp":
		var wakes_now: bool = int(user.status_state.get("time", 2)) <= 1
		if not wakes_now:
			if md.get("sleep_usable", false):
				return 60.0
			return -100.0
		elif md.get("sleep_usable", false):
			return -100.0
	var their := 0.0
	if target != null:
		their = _best_damage_pct(target, user)["pct"]
	var my_hp = user.hp_fraction() * 100.0
	var in_danger = their >= my_hp  # foe can KO me this turn
	if md["category"] != "status":
		if target == null:
			return -100.0
		var acc := _acc_factor(md, user, target)
		var raw := float(_b.estimate_damage(user, target, move_id)) * _expected_hits(md)
		var pct := raw / float(target.max_hp) * 100.0
		var their_hp = target.hp_fraction() * 100.0
		var eff := minf(pct, their_hp)
		score = eff * acc
		if pct >= their_hp:
			score += 45.0 * acc
			if int(md.get("priority", 0)) > 0 or faster:
				score += 25.0 * acc
		if pct <= 0.5:
			score -= 30.0
		# recoil / self penalties
		if md.has("recoil"):
			score -= pct * float(md["recoil"][0]) / float(md["recoil"][1]) * 0.6
		if md.get("self_destruct", "") != "":
			score -= 80.0 if pct < their_hp else 30.0
			if user.side.alive_count() <= 1:
				score -= 100.0
		if md.has("self") and md["self"].has("boosts"):
			for k in md["self"]["boosts"]:
				var v := int(md["self"]["boosts"][k])
				if v < 0 and user.ability != "contrary":
					score -= 4.0 * -v
				elif v < 0 and user.ability == "contrary":
					score += 6.0 * -v
		if md.get("self_switch", false) and user.side.has_alive_bench():
			var cur := _matchup(user, foes)
			if cur < 0:
				score += 20.0
		if md.has("drain") and my_hp < 70:
			score += pct * 0.3
		if md.get("flags", []).has("recharge") and pct < their_hp:
			score -= 30.0
		if md.get("locked_move", false):
			score -= 8.0
		if md.get("effect", "") == "charge_move" and not (md.get("charge_skip_weather", "") == _b.weather):
			score -= 35.0 if in_danger else 15.0
		if md.get("effect", "") == "sucker_punch":
			score *= 0.6
		if md.get("effect", "") == "fake_out" and user.active_move_actions > 1:
			return -100.0
		if md.get("effect", "") == "counter" or md.get("effect", "") == "mirror_coat":
			score = 15.0 if not faster else 5.0
		if md.has("secondary") and md["secondary"].has("status") and int(md["secondary"].get("chance", 0)) >= 30 and not _status_immune(target, md["secondary"]["status"]):
			score += 5.0
		return score
	# ---------------- status moves ----------------
	if target != null and target.boosts["evasion"] >= 4 and md.get("target", "normal") == "normal" and typeof(md.get("accuracy", true)) != TYPE_BOOL:
		score -= 20.0
	if target != null and target.volatiles.has("substitute") and not md.get("flags", []).has("bypasssub") and md.get("target", "normal") == "normal":
		return -50.0
	var eff_id: String = str(md.get("effect", ""))
	if md.has("boosts") and md.get("target") == "self":
		var total := 0
		var relevant := false
		var phys := _is_physical_attacker(user)
		for k in md["boosts"]:
			var v := int(md["boosts"][k])
			if user.ability == "contrary":
				v = -v
			if v > 0:
				var cur: int = user.boosts[k]
				if cur >= 4:
					continue
				var w := 1.0
				if (k == "atk" and phys) or (k == "spa" and not phys) or k == "spe":
					relevant = true
				elif k in ["def", "spd"]:
					w = 0.6
				elif k == "evasion":
					w = 0.9
					relevant = true
				total += int(v * w * 10)
		if total <= 0:
			return -50.0
		if not relevant and total < 15:
			return 0.0
		score = float(total)
		if in_danger and not user.volatiles.has("substitute"):
			score -= 40.0
		elif their * 2.0 >= my_hp and not user.volatiles.has("substitute"):
			score -= 20.0  # 2HKO'd: setting up is usually a loss unless we already threaten
		if their < 20.0:
			score += 10.0
		if user.positive_boosts() >= 6:
			score -= 30.0
		return score
	if md.has("status") and target != null:
		var st: String = md["status"]
		if _status_immune(target, st):
			return -60.0
		score = 30.0 * _acc_factor(md, user, target)
		match st:
			"slp": score += 20.0
			"par": score += 10.0 if not faster else 0.0
			"brn": score += 12.0 if _is_physical_attacker(target) else -5.0
			"tox": score += 10.0 if their < 30.0 else 0.0
		if in_danger and not faster:
			score -= 25.0
		return score
	if md.has("volatile_status") and md.get("target") == "normal" and target != null:
		var v: String = md["volatile_status"]
		if target.volatiles.has(v):
			return -60.0
		match v:
			"confusion": score = 12.0
			"leech_seed": score = 25.0 if not target.has_type("grass") else -60.0
			"taunt": score = 22.0 if not _is_physical_attacker(target) and _has_status_moves(target) else 5.0
			"encore": score = 10.0
			"yawn": score = 20.0 if not _status_immune(target, "slp") else -60.0
			"attract": score = 10.0
			"trapped": score = 8.0
			"disable": score = 8.0
			_: score = 6.0
		return score
	if md.has("heal") or eff_id in ["weather_heal", "shore_up", "rest", "wish", "strength_sap", "pain_split"]:
		var missing = 100.0 - my_hp
		score = missing * 1.1 - 5.0
		if eff_id == "rest":
			score = missing * 1.2 - 10.0
			if user.status != "":
				score += 10.0
			if user.item != "chesto_berry" and not user.has_move("sleep_talk") and user.ability != "awakened_lion":
				score -= 15.0
			if user.status == "slp":
				return -100.0
		if eff_id == "wish":
			score = missing * 0.6
		if in_danger and their >= my_hp * 1.5:
			score -= 30.0
		if my_hp > 85:
			return -20.0
		return score
	if md.has("side_condition"):
		var sc: String = md["side_condition"]
		var side = user.side.foe if md.get("target") == "foeSide" else user.side
		if side.has_side_condition(sc) and sc not in ["spikes", "toxic_spikes"]:
			return -50.0
		match sc:
			"stealth_rock": score = 30.0 if user.side.foe.has_alive_bench() else 0.0
			"spikes": score = (20.0 - 6.0 * int(side.side_conditions.get(sc, {}).get("layers", 0))) if user.side.foe.has_alive_bench() else 0.0
			"toxic_spikes": score = 18.0 if user.side.foe.has_alive_bench() else 0.0
			"sticky_web": score = 20.0 if user.side.foe.has_alive_bench() else 0.0
			"reflect": score = 30.0 if (target != null and _is_physical_attacker(target)) else 12.0
			"light_screen": score = 30.0 if (target != null and not _is_physical_attacker(target)) else 12.0
			"aurora_veil": score = 30.0 if _b.is_weather(["snow", "hail"]) else -60.0
			"tailwind": score = 18.0
			"safeguard": score = 8.0
			_: score = 6.0
		if in_danger:
			score -= 15.0
		return score
	if md.has("weather"):
		if _b.weather == md["weather"]:
			return -50.0
		score = 15.0 + _weather_team_value(user.side, md["weather"])
		return score
	if md.has("terrain"):
		if _b.terrain == md["terrain"]:
			return -50.0
		return 14.0
	if md.has("pseudo_weather"):
		if _b.has_pseudo_weather(md["pseudo_weather"]):
			return -50.0
		if md["pseudo_weather"] == "trick_room":
			return 20.0 if not faster else -20.0
		return 5.0
	if md.has("boosts") and target != null and md.get("target") != "self":
		# stat drops on foe
		var v := 0.0
		if md.get("self_switch", false) and not user.side.has_alive_bench():
			v -= 10.0
		for k in md["boosts"]:
			var amt := int(md["boosts"][k])
			if amt < 0 and target.boosts[k] > -4:
				if (k == "atk" and _is_physical_attacker(target)) or (k == "spa" and not _is_physical_attacker(target)):
					v += 10.0 * -amt
				elif k == "evasion" or k == "accuracy":
					v += 4.0 * -amt
				else:
					v += 3.0 * -amt
		if target.ability == "contrary" or target.ability == "competitive" or target.ability == "clear_body":
			v = -30.0
		return v
	match eff_id:
		"protect":
			if user.volatiles.has("stall"):
				return -40.0
			score = 8.0
			if target != null and target.volatiles.has("two_turn_move"):
				score += 30.0
			if user.status in ["tox", "psn", "brn"] and user.item != "leftovers":
				score -= 5.0
			if user.item == "leftovers" or user.volatiles.has("leech_seed") == false and target != null and (target.status == "tox" or target.volatiles.has("leech_seed")):
				score += 10.0
			if user.volatiles.has("substitute"):
				score -= 5.0
			return score
		"substitute":
			if user.volatiles.has("substitute") or my_hp <= 30:
				return -60.0
			return 18.0 if (faster and not in_danger) else 4.0
		"haze":
			var foe_boosts := 0
			for f in foes:
				foe_boosts += f.positive_boosts()
			return 15.0 * foe_boosts - 10.0 * user.positive_boosts()
		"defog", "rapid_spin":
			var n := 0
			for h in ["stealth_rock", "spikes", "toxic_spikes", "sticky_web"]:
				if user.side.has_side_condition(h):
					n += 1
			return 12.0 * n + (4.0 if eff_id == "rapid_spin" else 0.0)
		"heal_bell":
			var n := 0
			for m in user.side.team:
				if m.status != "" and not m.fainted:
					n += 1
			return 15.0 * n
		"belly_drum":
			return 45.0 if (my_hp > 60 and not in_danger and user.boosts["atk"] < 2) else -60.0
		"trick":
			return 15.0 if (user.item in ["choice_scarf", "choice_specs", "choice_band"] and target != null and target.item not in ["choice_scarf", "choice_specs", "choice_band"]) else -20.0
		"baton_pass":
			return 25.0 if (user.positive_boosts() >= 2 and user.side.has_alive_bench()) else -30.0
		"teleport":
			return 15.0 if (_matchup(user, foes) < -20 and user.side.has_alive_bench()) else -30.0
		"sleep_talk":
			return 60.0 if user.status == "slp" else -100.0
		"curse":
			return 25.0 if not user.has_type("ghost") else 20.0
		"psych_up":
			return 10.0 * (target.positive_boosts() if target != null else 0)
		"perish_song":
			return 10.0
		"yawn":
			return 20.0
	if md.get("self_switch", false):
		if not user.side.has_alive_bench():
			return -20.0
		return 15.0 if _matchup(user, foes) < 0 else 0.0
	if md.has("force_switch") and target != null:
		return 10.0 + 8.0 * target.positive_boosts()
	return 3.0

func _has_status_moves(p) -> bool:
	for m in p.moves:
		if GameData.get_move(m["id"])["category"] == "status":
			return true
	return false

func _weather_team_value(side, w: String) -> float:
	var v := 0.0
	var wd: Dictionary = GameData.weather.get(w, {})
	for p in side.team:
		if p.fainted:
			continue
		for t in wd.get("boost", {}):
			if p.has_type(t):
				v += 6.0
		for t in wd.get("nerf", {}):
			if p.has_type(t):
				v -= 6.0
	return v
