#!/usr/bin/env python3
"""Generate maps (town / home / lab / field / cave), events, trainers and dialogue text."""
import json, os
os.makedirs("data/maps", exist_ok=True); os.makedirs("data/events", exist_ok=True); os.makedirs("data/trainers", exist_ok=True)
L = json.load(open("data/localization/ja.json"))
T = L.setdefault("text", {})
# ---------------- tileset ----------------
tileset = {
 "0": {"name":"grass","walkable":True,"color":"#6db36a"},
 "1": {"name":"tall_grass","walkable":True,"encounter":True,"color":"#3f8f45"},
 "2": {"name":"water","walkable":False,"color":"#4d7fd6"},
 "3": {"name":"wall","walkable":False,"color":"#8a6d4b"},
 "4": {"name":"path","walkable":True,"color":"#d9c28e"},
 "5": {"name":"tree","walkable":False,"color":"#2f6b33"},
 "6": {"name":"door","walkable":True,"color":"#b0552a"},
 "7": {"name":"cave_floor","walkable":True,"encounter":True,"color":"#7d7466"},
 "8": {"name":"rock","walkable":False,"color":"#4d4740"},
 "9": {"name":"sand","walkable":True,"color":"#e6d8a3"},
 "10": {"name":"floor","walkable":True,"color":"#c9b7a0"},
 "11": {"name":"mat","walkable":True,"color":"#a33d3d"},
 "12": {"name":"table","walkable":False,"color":"#6b4e2e"},
 "13": {"name":"flower","walkable":True,"color":"#d9a8d1"},
 "14": {"name":"fence","walkable":False,"color":"#a88b5c"},
 "15": {"name":"sign","walkable":False,"color":"#c7a35b"},
 "16": {"name":"roof","walkable":False,"color":"#b04a3a"},
 "17": {"name":"cave_path","walkable":True,"color":"#9c9385"},
 "18": {"name":"stairs","walkable":True,"color":"#5e5751"},
}
json.dump(tileset, open("data/maps/tileset.json","w"), indent=1)

def grid(rows):
    """rows: list of strings using single chars mapped below"""
    m = {".":0,"g":1,"w":2,"#":3,"p":4,"t":5,"d":6,"c":7,"r":8,"s":9,"f":10,"m":11,"T":12,"F":13,"|":14,"S":15,"R":16,"C":17,"E":18}
    return [[m[ch] for ch in row] for row in rows]

maps = {}
def mp(id, name, rows, **kw):
    tiles = grid(rows)
    d = {"id": id, "name_key": "map_"+id, "width": len(tiles[0]), "height": len(tiles), "tile_size": 32, "tiles": tiles}
    d.update(kw)
    for r in tiles: assert len(r) == d["width"], id
    maps[id] = d
    T["map_"+id] = name

# ---- town (20x16) ----
town = [
"tttttttttttttttttttt",
"t..RRRR....RRRRR...t",
"t..####....#####...t",
"t..#d##....##d##...t",
"t..pppp....ppppp...t",
"t..p..S....p.......t",
"t..pppppppppppppp..t",
"t..p.....F.F...p...t",
"t..p...RRRRR...p...t",
"t..p...#####...p...t",
"t..p...##d##...p...t",
"t..ppppppppppppp...t",
"t......p...........t",
"t......p....FF.....t",
"tttttttptttttttttttt",
"tttttttptttttttttttt",
]
mp("town","はじまりの町", town,
   warps=[{"x":4,"y":3,"map":"home","tx":4,"ty":6,"dir":"up"},{"x":13,"y":3,"map":"lab","tx":5,"ty":7,"dir":"up"},
          {"x":9,"y":10,"map":"shop","tx":4,"ty":6,"dir":"up"},{"x":7,"y":15,"map":"field","tx":9,"ty":1,"dir":"down"}],
   npcs=[{"id":"nurse","x":11,"y":5,"sprite":"npc_nurse","dir":"down","event":"nurse_heal"},
         {"id":"kid","x":14,"y":7,"sprite":"npc_kid","dir":"left","event":"kid_talk"},
         {"id":"blocker","x":7,"y":12,"sprite":"npc_old","dir":"up","event":"blocker_talk","hidden_flag":"got_starter"}],
   events=[{"id":"sign_town","x":6,"y":5,"trigger":"interact","event":"sign_town"},
           {"id":"town_intro","trigger":"auto","event":"town_first","once_flag":"town_intro_done"}])
home = [
"########",
"#ffffff#",
"#fTTfff#",
"#ffffff#",
"#ffffff#",
"#ffffff#",
"#ffffmf#",
"########",
]
mp("home","じぶんの家", home, warps=[{"x":4,"y":6,"map":"town","tx":4,"ty":4,"dir":"down"}],
   npcs=[{"id":"mom","x":2,"y":4,"sprite":"npc_mom","dir":"down","event":"mom_talk"}],
   events=[{"id":"home_intro","trigger":"auto","event":"game_intro","once_flag":"intro_done"}])
lab = [
"##########",
"#ffffffff#",
"#fTTTTTTf#",
"#ffffffff#",
"#ffffffff#",
"#ffffffff#",
"#ffffffff#",
"#ffffmfff#",
"##########",
]
mp("lab","研究所", lab, warps=[{"x":5,"y":7,"map":"town","tx":13,"ty":4,"dir":"down"}],
   npcs=[{"id":"prof","x":4,"y":3,"sprite":"npc_prof","dir":"down","event":"prof_talk"}])
shop = [
"########",
"#ffffff#",
"#TTTfff#",
"#ffffff#",
"#ffffff#",
"#ffffff#",
"#ffffmf#",
"########",
]
mp("shop","フレンドリィショップ", shop, warps=[{"x":4,"y":6,"map":"town","tx":9,"ty":11,"dir":"down"}],
   npcs=[{"id":"clerk","x":2,"y":3,"sprite":"npc_clerk","dir":"down","event":"shop_talk"}])
# ---- field (20x24) ----
field = [
"ttttttttpttttttttttt",
"t.......p..........t",
"t.ggg...p...ggg....t",
"t.ggg...p...ggg....t",
"t.......p..........t",
"t...S...p......ww..t",
"t.......p......ww..t",
"t.ggggg.p..........t",
"t.ggggg.pppppppp...t",
"t.ggggg........p...t",
"t..............p...t",
"t.....F........p...t",
"t..........gggggg..t",
"t..........gggggg..t",
"t..........gggggg..t",
"t...pppppppp...p...t",
"t...p..........p...t",
"t...p...ggg....p...t",
"t...p...ggg....p...t",
"t...pppppppppppp...t",
"t..............p...t",
"t..gggg........pppCt",
"t..gggg............t",
"tttttttttttttttttttt",
]
mp("field","みどりの草原", field,
   warps=[{"x":8,"y":0,"map":"town","tx":7,"ty":14,"dir":"up"},{"x":18,"y":21,"map":"cave","tx":1,"ty":1,"dir":"right"}],
   encounters={"rate":14,"table":[{"species":"muni","min":3,"max":6,"weight":35},{"species":"neo","min":4,"max":7,"weight":25},
                                  {"species":"marutan","min":4,"max":7,"weight":20},{"species":"renny","min":5,"max":8,"weight":12},{"species":"jinpachi","min":5,"max":8,"weight":8}]},
   npcs=[{"id":"trainer_a","x":8,"y":6,"sprite":"npc_trainer","dir":"down","event":"trainer_a"},
         {"id":"trainer_b","x":15,"y":17,"sprite":"npc_trainer","dir":"left","event":"trainer_b"},
         {"id":"hiker","x":16,"y":21,"sprite":"npc_old","dir":"left","event":"hiker_talk"}],
   events=[{"id":"sign_field","x":4,"y":5,"trigger":"interact","event":"sign_field"}])
# ---- cave (18x18) ----
cave = [
"rrrrrrrrrrrrrrrrrr",
"rCCCCcccrrrrccccrr",
"rrrrrcccrrrrccccrr",
"rrcccccccccccccrrr",
"rrcccrrrrrrcccrrrr",
"rrcccrrrrrrcccrrrr",
"rrccccccccccccccrr",
"rrrrrrrrccrrrrccrr",
"rrrccccccccrrrccrr",
"rrrccccccccrrrccrr",
"rrrccrrrrrcccccccr",
"rrrccrrrrrrrrrrccr",
"rrrccccccccccccccr",
"rrrrrrrrrrrrrrcccr",
"rrCCCCCCCCCCCCcccr",
"rrCrrrrrrrrrrrrrrr",
"rrCCCCCCCCEErrrrrr",
"rrrrrrrrrrrrrrrrrr",
]
mp("cave","リージョンのほら穴", cave,
   warps=[{"x":1,"y":1,"map":"field","tx":17,"ty":21,"dir":"left"}],
   encounters={"rate":16,"table":[{"species":"muni_r_dragon","min":8,"max":11,"weight":20},{"species":"muni_r_bug","min":8,"max":11,"weight":20},
                                  {"species":"muni_r_normal","min":8,"max":11,"weight":20},{"species":"hyu_r","min":9,"max":12,"weight":12},
                                  {"species":"gel_r_poison","min":9,"max":12,"weight":10},{"species":"jinpachi_r","min":9,"max":12,"weight":10},{"species":"renny_r","min":10,"max":12,"weight":8}]},
   npcs=[{"id":"boss","x":11,"y":16,"sprite":"npc_boss","dir":"left","event":"boss_talk"}],
   events=[])
for id, d in maps.items():
    json.dump(d, open(f"data/maps/{id}.json","w"), ensure_ascii=False, indent=None)

# ---------------- text ----------------
T.update({
 "got_item":"{item}を {n}こ 手に入れた！","got_money":"{n}円 手に入れた！","got_monster":"{name}を 手に入れた！（{where}）","where_party":"手持ち","where_box":"ボックス",
 "healed":"モンスターは すっかり 元気になった！","starter_prompt":"どの モンスターを えらぶ？","ending":"リージョンの守り手を たおした！\nこの地方の 平和は 守られた。\n\n― おしまい ―",
 "intro_1":"…{player}、そろそろ 起きなさい！","intro_2":"（きょうは 研究所へ 行く日だ。）",
 "mom_1":"研究所の はかせが 待っているわよ。","mom_2":"草むらに 入るなら モンスターを つれていくのよ。",
 "town_first":"はじまりの町。 北の 研究所へ 行こう。","sign_town":"はじまりの町　南：みどりの草原",
 "kid_1":"となりの町まで 行ける ひとは すごいなあ。","blocker_1":"モンスターを つれていないと 草むらは きけんだよ！",
 "nurse_1":"モンスターを 休ませますね。","nurse_2":"また どうぞ！",
 "prof_1":"よく来たね {player}！ わたしは はかせだ。","prof_2":"この地方の モンスターには リージョンフォームと よばれる 姿が いる。","prof_3":"きみに モンスターを 1匹 あげよう。 好きなのを えらびなさい。",
 "prof_4":"モンスターボールと キズぐすりも 持っていきなさい。","prof_5":"南の 草原の先、 ほら穴の 奥に リージョンの守り手が いるらしい。 会ってきてくれ！","prof_done":"守り手に 会えたかい？ きみなら できるさ。",
 "shop_1":"いらっしゃいませ！","sign_field":"みどりの草原　東：リージョンのほら穴",
 "trainer_a_intro":"モンスターを 持っているな！ しょうぶだ！","trainer_a_lose":"つよいなあ…","trainer_a_after":"きみ つよいね。 ほら穴は 東だよ。",
 "trainer_b_intro":"ここから先は とおさないぞ！","trainer_b_lose":"まけたー！","trainer_b_after":"ほら穴の モンスターは 姿が ちがうんだ。",
 "hiker_1":"ほら穴の中は くらいから 気をつけて。 リージョンフォームが 出るぞ。",
 "boss_intro":"わたしは リージョンの守り手。 この ほら穴を 守るもの…。\nちからを 見せてもらおう！","boss_lose":"みごとだ…。 きみに この地方を たくす。","boss_after":"きみの ちからは 本物だ。 これからも モンスターと ともに 歩め。",
 "lost_battle":"目の前が 真っ暗に なった…","whited_out":"{player}は あわてて 町に もどった。",
 "starter_renny":"レニィ（みず）","starter_jinpachi":"ジンパチ（ほのお）","starter_hyu":"ヒュウ（ゴースト）",
 "yes":"はい","no":"いいえ","shop_buy":"かう","shop_sell":"うる","shop_exit":"やめる",
})
# ---------------- events ----------------
events = {
 "game_intro": [{"cmd":"message","text":"intro_1"},{"cmd":"message","text":"intro_2"},{"cmd":"set_flag","flag":"intro_done"}],
 "mom_talk": [{"cmd":"if","flag":"got_starter","then":[{"cmd":"message","text":"mom_2"},{"cmd":"heal_party"}],"else":[{"cmd":"message","text":"mom_1"}]}],
 "town_first": [{"cmd":"message","text":"town_first"},{"cmd":"set_flag","flag":"town_intro_done"}],
 "sign_town": [{"cmd":"message","text":"sign_town"}],
 "kid_talk": [{"cmd":"message","text":"kid_1"}],
 "blocker_talk": [{"cmd":"message","text":"blocker_1"}],
 "nurse_heal": [{"cmd":"message","text":"nurse_1"},{"cmd":"heal_party"},{"cmd":"message","text":"nurse_2"}],
 "prof_talk": [{"cmd":"if","flag":"got_starter","then":[{"cmd":"message","text":"prof_done"}],
                "else":[{"cmd":"message","text":"prof_1"},{"cmd":"message","text":"prof_2"},{"cmd":"message","text":"prof_3"},
                        {"cmd":"starter_choice","text":"starter_prompt","options":[{"species":"renny","level":5,"text":"starter_renny"},{"species":"jinpachi","level":5,"text":"starter_jinpachi"},{"species":"hyu","level":5,"text":"starter_hyu"}]},
                        {"cmd":"set_flag","flag":"got_starter"},{"cmd":"message","text":"prof_4"},{"cmd":"give_item","item":"monster_ball","count":5},{"cmd":"give_item","item":"potion","count":3},{"cmd":"message","text":"prof_5"}]}],
 "shop_talk": [{"cmd":"message","text":"shop_1"},{"cmd":"shop","items":["potion","super_potion","antidote","awakening","monster_ball","great_ball","revive"]}],
 "sign_field": [{"cmd":"message","text":"sign_field"}],
 "trainer_a": [{"cmd":"if","flag":"trainer_a_beaten","then":[{"cmd":"message","text":"trainer_a_after"}],
                "else":[{"cmd":"message","text":"trainer_a_intro"},{"cmd":"trainer_battle","trainer":"trainer_a","win":[{"cmd":"set_flag","flag":"trainer_a_beaten"},{"cmd":"message","text":"trainer_a_lose"},{"cmd":"give_money","amount":400}]}]}],
 "trainer_b": [{"cmd":"if","flag":"trainer_b_beaten","then":[{"cmd":"message","text":"trainer_b_after"}],
                "else":[{"cmd":"message","text":"trainer_b_intro"},{"cmd":"trainer_battle","trainer":"trainer_b","win":[{"cmd":"set_flag","flag":"trainer_b_beaten"},{"cmd":"message","text":"trainer_b_lose"},{"cmd":"give_money","amount":600}]}]}],
 "hiker_talk": [{"cmd":"message","text":"hiker_1"},{"cmd":"if","flag":"got_charm","then":[],"else":[{"cmd":"give_item","item":"mind_stone","count":1},{"cmd":"set_flag","flag":"got_charm"}]}],
 "boss_talk": [{"cmd":"if","flag":"boss_beaten","then":[{"cmd":"message","text":"boss_after"}],
                "else":[{"cmd":"message","text":"boss_intro"},{"cmd":"trainer_battle","trainer":"boss","win":[{"cmd":"set_flag","flag":"boss_beaten"},{"cmd":"message","text":"boss_lose"},{"cmd":"give_money","amount":3000},{"cmd":"badge"},{"cmd":"end_game","text":"ending"}]}]}],
}
for id, cmds in events.items():
    json.dump({"id": id, "commands": cmds}, open(f"data/events/{id}.json","w"), ensure_ascii=False, indent=1)
# ---------------- trainers ----------------
trainers = {
 "trainer_a": {"name_key":"tr_a_name","team":[{"species":"muni","level":7},{"species":"neo","level":8}],"money":400,"ai":"heuristic"},
 "trainer_b": {"name_key":"tr_b_name","team":[{"species":"marutan","level":10},{"species":"renny","level":11}],"money":600,"ai":"heuristic"},
 "boss": {"name_key":"boss_name","team":[{"species":"hyu_r","level":14},{"species":"gel_r_dark","level":14},{"species":"trans_r","level":16,"item":"sitrus_berry"}],"money":3000,"ai":"heuristic","boss":True},
}
T.update({"tr_a_name":"たんぱんこぞうの ケン","tr_b_name":"ミニスカートの ミオ","boss_name":"リージョンの守り手 ソラ"})
for id, d in trainers.items():
    d["id"] = id
    json.dump(d, open(f"data/trainers/{id}.json","w"), ensure_ascii=False, indent=1)
json.dump(L, open("data/localization/ja.json","w"), ensure_ascii=False, indent=1)
print("maps", len(maps), "events", len(events), "trainers", len(trainers))
