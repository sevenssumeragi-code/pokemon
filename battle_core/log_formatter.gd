class_name LogFormatter
extends RefCounted
## Converts structured battle log entries into Japanese text via data/localization/ja.json.

static func nm(cat: String, id) -> String:
	return GameData.name_of(cat, str(id))

static func who(tag) -> String:
	# "p1a:renny" -> display name; use species name
	var s := str(tag)
	var idx := s.find(":")
	var name := s.substr(idx + 1) if idx >= 0 else s
	var side := s.substr(0, 2) if idx >= 0 else ""
	var disp := nm("species", name)
	if side == "p2":
		return "あいての " + disp
	return disp

static func stat(id) -> String:
	return nm("stats", id)

static func format(e: Array) -> String:
	if e.is_empty():
		return ""
	match str(e[0]):
		"start": return "しょうぶ かいし！"
		"turn": return "――― ターン %s ―――" % e[1]
		"switch": return "%s を くりだした！" % who(e[1])
		"drag": return "%s が ひきずりだされた！" % who(e[1])
		"move": return "%s の %s！" % [who(e[1]), nm("moves", e[2])]
		"cant":
			match str(e[2]):
				"par": return "%s は からだが しびれて うごけない！" % who(e[1])
				"slp": return "%s は ぐうぐう ねむっている" % who(e[1])
				"frz": return "%s は こおってしまって うごけない！" % who(e[1])
				"flinch": return "%s は ひるんで わざが だせない！" % who(e[1])
				"attract": return "%s は メロメロで わざが だせない！" % who(e[1])
				"recharge": return "%s は はんどうで うごけない！" % who(e[1])
				"taunt": return "%s は ちょうはつされて わざが だせない！" % who(e[1])
				"disable": return "%s の わざは かなしばりで だせない！" % who(e[1])
				_: return "%s は うごけない！" % who(e[1])
		"-hp": return ""
		"-damage": return "%s は %s の ダメージを うけた！" % [who(e[1]), _src(e)] if e.size() > 4 and str(e[4]) != "" else ""
		"-heal": return "%s の たいりょくが かいふくした！" % who(e[1])
		"-status": return "%s は %s！" % [who(e[1]), _status_text(e[2])]
		"-curestatus": return "%s の %s が なおった！" % [who(e[1]), nm("status", e[2])]
		"-boost": return "%s の %s が %s！" % [who(e[1]), stat(e[2]), _boost_amt(int(e[3]), true)]
		"-unboost": return "%s の %s が %s！" % [who(e[1]), stat(e[2]), _boost_amt(int(e[3]), false)]
		"-boost-fail": return "%s の %s は もう %s！" % [who(e[1]), stat(e[2]), "あがらない" if str(e[3]) == "max" else "さがらない"]
		"-crit": return "きゅうしょに あたった！"
		"-supereffective": return "こうかは ばつぐんだ！"
		"-resisted": return "こうかは いまひとつの ようだ"
		"-immune": return "%s には こうかが ないようだ…" % who(e[1])
		"-miss": return "%s には あたらなかった！" % who(e[2])
		"-fail": return "しかし うまく きまらなかった！"
		"-notarget": return "しかし あいてが いない！"
		"faint": return "%s は たおれた！" % who(e[1])
		"-ability": return "%s の %s！" % [who(e[1]), nm("abilities", e[2])]
		"-item": return "%s の %s！" % [who(e[1]), nm("items", e[2])]
		"-enditem": return "%s の %s が なくなった！" % [who(e[1]), nm("items", e[2])] if not (e.size() > 3 and str(e[3]) == "[eat]") else "%s は %s を たべた！" % [who(e[1]), nm("items", e[2])]
		"-weather":
			if str(e[1]) == "none":
				return "%s が おさまった！" % nm("weather", e[2])
			if e.size() > 2 and str(e[2]) == "[upkeep]":
				return ""
			return "%s になった！" % nm("weather", e[1])
		"-fieldstart": return "%s が はじまった！" % _field_name(e[1])
		"-fieldend": return "%s が おわった！" % _field_name(e[1])
		"-sidestart": return "%s の ばに %s！" % ["みかた" if str(e[1]) == "p1" else "あいて", nm("side_conditions", e[2])]
		"-sideend": return "%s の ばの %s が なくなった！" % ["みかた" if str(e[1]) == "p1" else "あいて", nm("side_conditions", e[2])]
		"-start": return "%s は %s じょうたいに なった！" % [who(e[1]), nm("status", e[2])] if GameData.localization.get("status", {}).has(str(e[2])) else "%s の %s！" % [who(e[1]), nm("moves", e[2])]
		"-end": return "%s の %s が なくなった！" % [who(e[1]), nm("status", e[2]) if GameData.localization.get("status", {}).has(str(e[2])) else nm("moves", e[2])]
		"-activate": return "%s の %s！" % [who(e[1]), nm("moves", e[2]) if GameData.moves.has(str(e[2])) else (nm("abilities", e[2]) if GameData.abilities.has(str(e[2])) else nm("items", e[2]) if GameData.items.has(str(e[2])) else nm("status", e[2]))]
		"-singleturn", "-singlemove": return "%s は %s の たいせいに はいった！" % [who(e[1]), nm("moves", e[2])]
		"-prepare": return "%s は %s の じゅんびを している！" % [who(e[1]), nm("moves", e[2])]
		"-hitcount": return "%s かい あたった！" % e[2]
		"-clearallboost": return "すべての のうりょくへんかが もとにもどった！"
		"-clearboost": return "%s の のうりょくへんかが もとにもどった！" % who(e[1])
		"-sethp": return ""
		"win": return "しょうぶ あり！" if int(e[1]) >= 0 else "ひきわけ！"
		"tie": return "ひきわけ！"
		"residual": return ""
	return ""

static func _src(e: Array) -> String:
	var id := str(e[4])
	if GameData.localization.get("status", {}).has(id):
		return nm("status", id)
	if GameData.items.has(id):
		return nm("items", id)
	if GameData.moves.has(id):
		return nm("moves", id)
	if GameData.weather.has(id):
		return nm("weather", id)
	if GameData.localization.get("side_conditions", {}).has(id):
		return nm("side_conditions", id)
	return id

static func _status_text(id) -> String:
	match str(id):
		"brn": return "やけどを おった"
		"par": return "まひして わざが でにくくなった"
		"slp": return "ねむってしまった"
		"frz": return "こおりついた"
		"psn": return "どくを あびた"
		"tox": return "もうどくを あびた"
	return nm("status", id) + " になった"

static func _boost_amt(n: int, up: bool) -> String:
	if n >= 3:
		return "ぐぐーんと あがった" if up else "がくーんと さがった"
	if n == 2:
		return "ぐーんと あがった" if up else "がくっと さがった"
	return "あがった" if up else "さがった"

static func _field_name(id) -> String:
	var s := str(id)
	if GameData.terrain.has(s):
		return nm("terrain", s)
	return nm("field", s)

static func format_all(log: Array) -> String:
	var out: PackedStringArray = []
	for e in log:
		var t := format(e)
		if t != "":
			out.append(t)
	return "\n".join(out)
