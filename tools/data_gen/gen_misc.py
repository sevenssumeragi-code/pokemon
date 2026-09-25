#!/usr/bin/env python3
"""Generate items / abilities / weather / terrain JSON + localization sections."""
import json, os
L = json.load(open("data/localization/ja.json")) if os.path.exists("data/localization/ja.json") else {}

# ---------------- ITEMS ----------------
items = {}
loc_items = {}
def item(id, ja, **kw):
    items[id] = kw
    loc_items[id] = ja
TYPES_JA = {"normal":"ノーマル","fire":"ほのお","water":"みず","electric":"でんき","grass":"くさ","ice":"こおり","fighting":"かくとう","poison":"どく","ground":"じめん","flying":"ひこう","psychic":"エスパー","bug":"むし","rock":"いわ","ghost":"ゴースト","dragon":"ドラゴン","dark":"あく","steel":"はがね","fairy":"フェアリー"}
item("choice_band","こだわりハチマキ",handler="choice",params={"stat":"atk"},is_choice=True)
item("choice_specs","こだわりメガネ",handler="choice",params={"stat":"spa"},is_choice=True)
item("choice_scarf","こだわりスカーフ",handler="choice",params={"stat":"spe"},is_choice=True)
item("life_orb","いのちのたま")
item("focus_sash","きあいのタスキ",consumable=True)
item("leftovers","たべのこし")
item("black_sludge","くろいヘドロ")
item("sitrus_berry","オボンのみ",is_berry=True,handler="hp_berry",params={"threshold":[1,2],"heal_fraction":[1,4]})
item("oran_berry","オレンのみ",is_berry=True,handler="hp_berry",params={"threshold":[1,2],"heal_flat":10})
item("lum_berry","ラムのみ",is_berry=True)
item("chesto_berry","カゴのみ",is_berry=True,handler="status_berry",params={"cures":["slp"]})
item("cheri_berry","クラボのみ",is_berry=True,handler="status_berry",params={"cures":["par"]})
item("pecha_berry","モモンのみ",is_berry=True,handler="status_berry",params={"cures":["psn","tox"]})
item("rawst_berry","チーゴのみ",is_berry=True,handler="status_berry",params={"cures":["brn"]})
item("aspear_berry","ナナシのみ",is_berry=True,handler="status_berry",params={"cures":["frz"]})
item("persim_berry","キーのみ",is_berry=True,handler="status_berry",params={"cures":["confusion"]})
resist = {"fire":("occa_berry","オッカのみ"),"water":("passho_berry","イトケのみ"),"electric":("wacan_berry","ソクノのみ"),"grass":("rindo_berry","リンドのみ"),
          "ice":("yache_berry","ヤチェのみ"),"fighting":("chople_berry","ヨプのみ"),"poison":("kebia_berry","ビアーのみ"),"ground":("shuca_berry","シュカのみ"),
          "flying":("coba_berry","バコウのみ"),"psychic":("payapa_berry","ウタンのみ"),"bug":("tanga_berry","タンガのみ"),"rock":("charti_berry","ヨロギのみ"),
          "ghost":("kasib_berry","カシブのみ"),"dragon":("haban_berry","ハバンのみ"),"dark":("colbur_berry","ナモのみ"),"steel":("babiri_berry","リリバのみ"),
          "fairy":("roseli_berry","ロゼルのみ"),"normal":("chilan_berry","ホズのみ")}
for t,(i,ja) in resist.items():
    item(i,ja,is_berry=True,handler="resist_berry",params={"type":t})
item("salac_berry","カムラのみ",is_berry=True,handler="pinch_berry",params={"boosts":{"spe":1}})
item("liechi_berry","チイラのみ",is_berry=True,handler="pinch_berry",params={"boosts":{"atk":1}})
item("petaya_berry","ヤタピのみ",is_berry=True,handler="pinch_berry",params={"boosts":{"spa":1}})
item("assault_vest","とつげきチョッキ")
item("rocky_helmet","ゴツゴツメット")
item("eviolite","しんかのきせき")
item("weakness_policy","じゃくてんほけん",consumable=True)
item("light_clay","ひかりのねんど",handler="passive",flags={"screen_extender":True})
item("heat_rock","あついいわ",handler="passive",extends_weather="sun")
item("damp_rock","しめったいわ",handler="passive",extends_weather="rain")
item("smooth_rock","さらさらいわ",handler="passive",extends_weather="sand")
item("icy_rock","つめたいいわ",handler="passive",extends_weather="snow")
item("terrain_extender","グランドコート",handler="passive",extends_terrain=True)
typeitems = {"normal":("silk_scarf","シルクのスカーフ"),"fire":("charcoal","もくたん"),"water":("mystic_water","しんぴのしずく"),"electric":("magnet","じしゃく"),
             "grass":("miracle_seed","きせきのタネ"),"ice":("never_melt_ice","とけないこおり"),"fighting":("black_belt","くろおび"),"poison":("poison_barb","どくバリ"),
             "ground":("soft_sand","やわらかいすな"),"flying":("sharp_beak","するどいくちばし"),"psychic":("twisted_spoon","まがったスプーン"),"bug":("silver_powder","ぎんのこな"),
             "rock":("hard_stone","かたいいし"),"ghost":("spell_tag","のろいのおふだ"),"dragon":("dragon_fang","りゅうのキバ"),"dark":("black_glasses","くろいメガネ"),
             "steel":("metal_coat","メタルコート"),"fairy":("fairy_feather","フェアリーのハネ")}
for t,(i,ja) in typeitems.items():
    item(i,ja,handler="type_boost",params={"type":t})
item("air_balloon","ふうせん",flags={"airborne":True})
item("eject_button","だっしゅつボタン",consumable=True)
item("red_card","レッドカード",consumable=True)
item("quick_claw","せんせいのツメ")
item("bright_powder","ひかりのこな")
item("wide_lens","こうかくレンズ")
item("expert_belt","たつじんのおび")
item("muscle_band","ちからのハチマキ")
item("wise_glasses","ものしりメガネ")
item("scope_lens","ピントレンズ")
item("shed_shell","きれいなぬけがら",handler="passive",flags={"prevents_trapping":True})
item("heavy_duty_boots","あつぞこブーツ",handler="passive",flags={"hazard_immune":True})
item("safety_goggles","ぼうじんゴーグル",handler="passive",flags={"powder_immune":True,"weather_immune":True})
item("protective_pads","ぼうごパット",handler="passive",flags={"no_contact":True})
item("mental_herb","メンタルハーブ",consumable=True)
item("white_herb","しろいハーブ",consumable=True)
item("power_herb","パワフルハーブ",handler="passive",consumable=True,flags={"skips_charge":True})
item("flame_orb","かえんだま")
item("toxic_orb","どくどくだま")
item("covert_cloak","おんみつマント")
item("clear_amulet","クリアチャーム")
item("shell_bell","かいがらのすず")
item("big_root","おおきなねっこ")
item("loaded_dice","いかさまダイス")
item("metronome","メトロノーム")
item("grip_claw","ねばりのかぎづめ",handler="passive",flags={"extends_binding":True})
item("binding_band","しめつけバンド",handler="passive",flags={"stronger_binding":True})
for k in items:
    items[k].setdefault("flags", {})
    items[k].setdefault("is_berry", False)
    items[k].setdefault("params", {})
    items[k]["pocket"] = "held"
os.makedirs("data/items", exist_ok=True)
json.dump(items, open("data/items/items.json","w"), ensure_ascii=False, indent=1)
L["items"] = loc_items

# ---------------- ABILITIES ----------------
abilities = {}
loc_ab = {}
def ab(id, ja, desc, original=False, **kw):
    abilities[id] = dict(original=original, **kw)
    loc_ab[id] = ja
    abilities[id]["desc_key"] = id
    L.setdefault("ability_desc", {})[id] = desc
ab("awakened_lion","めざめるしし","ねむり状態から回復したターンに限り、こうげきが2倍になる。",True,params={"multiplier":2.0})
ab("flame_domain","ほのおのりょういき","自分が場にいる間、自分と味方のほのお技の威力が1.5倍になる。",True,params={"multiplier":1.5})
ab("dark_domain","やみのりょういき","自分が場にいる間、自分と味方のゴースト技の威力が1.5倍になる。",True,params={"multiplier":1.5})
ab("sacred_light","せいなるひかり","自分が受けるゴースト技・あく技の威力が0.7倍になる。",True,params={"multiplier":0.7,"types":["ghost","dark"]})
ab("minimal_body","ミニマムボディ","場に出ている間、回避率が1.5倍になる（ランクとは別枠）。",True,params={"evasion_multiplier":1.5})
ab("prankster","いたずらごころ","変化技の優先度が+1される。あくタイプには無効。")
ab("snow_warning","ゆきふらし","場に出たとき天気をゆきにする。")
ab("sharpness","きれあじ","切る技の威力が1.5倍になる。")
ab("steadfast","ふくつのこころ","ひるんだとき素早さが1段階上がる。")
ab("static","せいでんき","接触技を受けると30%の確率で相手をまひにする。")
ab("unburden","かるわざ","持ち物を消費・失うと素早さが2倍になる。")
ab("sturdy","がんじょう","HP満タンなら一撃で倒されない。一撃必殺技が無効。")
ab("contrary","あまのじゃく","能力ランクの変化が逆になる。")
ab("pixilate","フェアリースキン","ノーマル技がフェアリー技になり威力1.2倍。")
ab("multiscale","マルチスケイル","HP満タンのとき受けるダメージが半分になる。")
ab("compound_eyes","ふくがん","技の命中率が1.3倍になる。")
ab("intimidate","いかく","場に出たとき相手のこうげきを1段階下げる。")
ab("competitive","かちき","相手に能力を下げられると特攻が2段階上がる。")
ab("levitate","ふゆう","じめん技を受けない。")
ab("inner_focus","せいしんりょく","ひるまない。いかくを受けない。",flags={"intimidate_immune":True})
ab("regenerator","さいせいりょく","交代で下がると最大HPの1/3回復する。")
ab("natural_cure","しぜんかいふく","交代で下がると状態異常が治る。")
ab("technician","テクニシャン","威力60以下の技の威力が1.5倍になる。")
ab("guts","こんじょう","状態異常のときこうげきが1.5倍。やけどの攻撃低下を受けない。")
ab("thick_fat","あついしぼう","ほのお技とこおり技のダメージが半分になる。")
ab("clear_body","クリアボディ","相手に能力を下げられない。")
for k in abilities:
    abilities[k].setdefault("params", {})
    abilities[k].setdefault("flags", {})
os.makedirs("data/abilities", exist_ok=True)
json.dump(abilities, open("data/abilities/abilities.json","w"), ensure_ascii=False, indent=1)
L["abilities"] = loc_ab

# ---------------- WEATHER ----------------
weather = {
 "sun": {"duration":5,"extended_duration":8,"boost":{"fire":1.5},"nerf":{"water":0.5},"prevents_status":["frz"],"weather_ball_type":"fire"},
 "rain": {"duration":5,"extended_duration":8,"boost":{"water":1.5},"nerf":{"fire":0.5},"weather_ball_type":"water"},
 "sand": {"duration":5,"extended_duration":8,"damage":[1,16],"immune_types":["rock","ground","steel"],"spd_boost_type":"rock","weather_ball_type":"rock"},
 "snow": {"duration":5,"extended_duration":8,"def_boost_type":"ice","weather_ball_type":"ice"},
}
os.makedirs("data/weather", exist_ok=True)
json.dump(weather, open("data/weather/weather.json","w"), ensure_ascii=False, indent=1)
L["weather"] = {"sun":"にほんばれ","rain":"あめ","sand":"すなあらし","snow":"ゆき"}

# ---------------- TERRAIN ----------------
terrain = {
 "electric": {"duration":5,"extended_duration":8,"boost_type":"electric","blocks_status":["slp"],"blocks_volatiles":["yawn"]},
 "grassy": {"duration":5,"extended_duration":8,"boost_type":"grass","heal":[1,16],"weakens_moves":["earthquake","bulldoze","magnitude"]},
 "misty": {"duration":5,"extended_duration":8,"weakens_types":["dragon"],"blocks_status":["all"],"blocks_volatiles":["confusion","yawn"]},
 "psychic": {"duration":5,"extended_duration":8,"boost_type":"psychic","blocks_priority":True},
}
os.makedirs("data/terrain", exist_ok=True)
json.dump(terrain, open("data/terrain/terrain.json","w"), ensure_ascii=False, indent=1)
L["terrain"] = {"electric":"エレキフィールド","grassy":"グラスフィールド","misty":"ミストフィールド","psychic":"サイコフィールド"}
L["field"] = {"trick_room":"トリックルーム","gravity":"じゅうりょく"}
L["types"] = TYPES_JA
L["types"]["???"] = "？？？"
L["status"] = {"brn":"やけど","par":"まひ","slp":"ねむり","frz":"こおり","psn":"どく","tox":"もうどく","confusion":"こんらん","flinch":"ひるみ","attract":"メロメロ","leech_seed":"やどりぎのタネ","substitute":"みがわり"}
L["stats"] = {"hp":"HP","atk":"こうげき","def":"ぼうぎょ","spa":"とくこう","spd":"とくぼう","spe":"すばやさ","accuracy":"めいちゅう","evasion":"かいひ"}
nat_ja = {"hardy":"がんばりや","lonely":"さみしがり","brave":"ゆうかん","adamant":"いじっぱり","naughty":"やんちゃ","bold":"ずぶとい","docile":"すなお","relaxed":"のんき","impish":"わんぱく","lax":"のうてんき","timid":"おくびょう","hasty":"せっかち","serious":"まじめ","jolly":"ようき","naive":"むじゃき","modest":"ひかえめ","mild":"おっとり","quiet":"れいせい","bashful":"てれや","rash":"うっかりや","calm":"おだやか","gentle":"おとなしい","sassy":"なまいき","careful":"しんちょう","quirky":"きまぐれ"}
L["natures"] = nat_ja
L["side_conditions"] = {"reflect":"リフレクター","light_screen":"ひかりのかべ","aurora_veil":"オーロラベール","safeguard":"しんぴのまもり","mist":"しろいきり","tailwind":"おいかぜ","spikes":"まきびし","stealth_rock":"ステルスロック","toxic_spikes":"どくびし","sticky_web":"ねばねばネット","quick_guard":"ファストガード","wide_guard":"ワイドガード"}
json.dump(L, open("data/localization/ja.json","w"), ensure_ascii=False, indent=1)
print("items", len(items), "abilities", len(abilities))
