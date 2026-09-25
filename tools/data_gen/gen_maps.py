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
# ---- route 2 (east of town, unlocked after the boss) 24x14 ----
route2 = [
"tttttttttttttttttttttttt",
"t......................t",
"t.ggggg......ggggg.....t",
"t.ggggg......ggggg.....t",
"pppppppppp...ggggg.....t",
"t........p.............t",
"t..S.....pppppppppp....t",
"t.................p....t",
"t..ggggggg........p....t",
"t..ggggggg........pppppp",
"t..ggggggg...ww........t",
"t............ww........t",
"t......................t",
"tttttttttttttttttttttttt",
]
mp("route2","うみべのみち", route2,
   warps=[{"x":0,"y":4,"map":"town","tx":18,"ty":6,"dir":"left"},{"x":23,"y":9,"map":"port","tx":1,"ty":7,"dir":"right"}],
   encounters={"rate":14,"table":[{"species":"honebami","min":16,"max":19,"weight":15},{"species":"namazuo","min":16,"max":19,"weight":15},
                                  {"species":"gel","min":15,"max":18,"weight":15},{"species":"hyu","min":15,"max":18,"weight":15},
                                  {"species":"trans_r","min":18,"max":20,"weight":5},{"species":"gel_r_dark","min":16,"max":19,"weight":15},
                                  {"species":"muni_r_bug","min":15,"max":18,"weight":20}]},
   npcs=[{"id":"trainer_c","x":9,"y":5,"sprite":"npc_trainer","dir":"down","event":"trainer_c"},
         {"id":"trainer_d","x":18,"y":8,"sprite":"npc_trainer","dir":"down","event":"trainer_d"}],
   events=[{"id":"sign_route2","x":3,"y":6,"trigger":"interact","event":"sign_route2"}])
# ---- port town 16x12 ----
port = [
"tttttttttttttttt",
"t....RRRRR.....t",
"t....#####.....t",
"t....##d##..F..t",
"t....ppppp.....t",
"t....p.........t",
"t....p...S.....t",
"pppppp.........t",
"t..............t",
"twwwwwwwwwwwwwwt",
"twwwwwwwwwwwwwwt",
"tttttttttttttttt",
]
mp("port","みなとまち", port,
   warps=[{"x":0,"y":7,"map":"route2","tx":22,"ty":9,"dir":"left"},{"x":7,"y":3,"map":"hall","tx":5,"ty":8,"dir":"up"}],
   npcs=[{"id":"rival","x":11,"y":7,"sprite":"npc_kid","dir":"left","event":"rival_talk"},
         {"id":"port_nurse","x":3,"y":5,"sprite":"npc_nurse","dir":"down","event":"nurse_heal"},
         {"id":"sailor","x":12,"y":5,"sprite":"npc_old","dir":"down","event":"sailor_talk"}],
   events=[{"id":"sign_port","x":9,"y":6,"trigger":"interact","event":"sign_port"}])
# ---- battle hall 12x10 (doubles) ----
hall = [
"############",
"#ffffffffff#",
"#ffTffffTff#",
"#ffffffffff#",
"#ffffffffff#",
"#ffffffffff#",
"#ffffffffff#",
"#ffffffffff#",
"#ffffmfffff#",
"############",
]
mp("hall","バトルホール", hall, warps=[{"x":5,"y":8,"map":"port","tx":7,"ty":4,"dir":"down"}],
   npcs=[{"id":"hall_master","x":5,"y":2,"sprite":"npc_boss","dir":"down","event":"hall_master"},
         {"id":"hall_guide","x":2,"y":6,"sprite":"npc_clerk","dir":"right","event":"hall_guide"}])
# town: gate east to route2, blocked until boss beaten (row 6 col 19 is a tree; make it path)
town_tiles = maps["town"]["tiles"]
town_tiles[6][18] = 4; town_tiles[6][19] = 4
maps["town"]["warps"].append({"x":19,"y":6,"map":"route2","tx":1,"ty":4,"dir":"right"})
maps["town"]["npcs"].append({"id":"gatekeeper","x":18,"y":6,"sprite":"npc_old","dir":"left","event":"gate_talk","hidden_flag":"boss_beaten"})
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
T.update({
 "sign_route2":"うみべのみち　東：みなとまち","sign_port":"みなとまち　バトルホールで ダブルバトルに ちょうせん！",
 "gate_1":"この先は うみべのみち。 リージョンの守り手に みとめられた ひとしか とおせないよ。",
 "trainer_c_intro":"守り手を たおしたんだって？ ぼくも ためさせてもらう！","trainer_c_lose":"さすがだ…","trainer_c_after":"みなとまちの バトルホールは ダブルバトルだよ。",
 "trainer_d_intro":"うみかぜと ともに いくぞ！","trainer_d_lose":"かぜが やんだ…","trainer_d_after":"2たい同時の たたかいは あじかたを かんがえるのが コツさ。",
 "rival_intro":"やあ {player}！ 守り手に かったって ほんとう？ なら ぼくとも しょうぶだ！","rival_lose":"つよくなったね… また しょうぶしよう！","rival_after":"バトルホールの マスターは ダブルバトルの たつじんだよ。",
 "sailor_1":"ふねは まだ 出ないよ。 バトルホールで あそんでいきな。",
 "hall_guide_1":"ここは バトルホール。 マスターとの しょうぶは 2たい ずつ 出す ダブルバトルだ。 手持ちが 2たい いじょう ひつようだよ。",
 "hall_master_intro":"ようこそ バトルホールへ。 わたしの ダブルバトル、 うけてみるか？","hall_master_lose":"みごとな れんけいだ！ きみは ダブルバトルの たつじんだ。","hall_master_after":"また いつでも ちょうせんしに きなさい。",
 "hall_need_two":"ダブルバトルには 手持ちが 2たい いじょう ひつようだ。",
 "tr_c_name":"ハイカーの ゴウ","tr_d_name":"うみおとこの リク","rival_name":"ライバルの ハル","hall_master_name":"ホールマスター ミナ",
})
# ---------------- events ----------------
events = {
 "gate_talk": [{"cmd":"message","text":"gate_1"}],
 "sign_route2": [{"cmd":"message","text":"sign_route2"}], "sign_port": [{"cmd":"message","text":"sign_port"}], "sailor_talk": [{"cmd":"message","text":"sailor_1"}],
 "hall_guide": [{"cmd":"message","text":"hall_guide_1"}],
 "trainer_c": [{"cmd":"if","flag":"trainer_c_beaten","then":[{"cmd":"message","text":"trainer_c_after"}],
                "else":[{"cmd":"message","text":"trainer_c_intro"},{"cmd":"trainer_battle","trainer":"trainer_c","win":[{"cmd":"set_flag","flag":"trainer_c_beaten"},{"cmd":"message","text":"trainer_c_lose"},{"cmd":"give_money","amount":1200}]}]}],
 "trainer_d": [{"cmd":"if","flag":"trainer_d_beaten","then":[{"cmd":"message","text":"trainer_d_after"}],
                "else":[{"cmd":"message","text":"trainer_d_intro"},{"cmd":"trainer_battle","trainer":"trainer_d","win":[{"cmd":"set_flag","flag":"trainer_d_beaten"},{"cmd":"message","text":"trainer_d_lose"},{"cmd":"give_money","amount":1500}]}]}],
 "rival_talk": [{"cmd":"if","flag":"rival_beaten","then":[{"cmd":"message","text":"rival_after"}],
                "else":[{"cmd":"message","text":"rival_intro"},{"cmd":"trainer_battle","trainer":"rival","win":[{"cmd":"set_flag","flag":"rival_beaten"},{"cmd":"message","text":"rival_lose"},{"cmd":"give_money","amount":2500}]}]}],
 "hall_master": [{"cmd":"if","flag":"hall_beaten","then":[{"cmd":"message","text":"hall_master_after"},{"cmd":"trainer_battle","trainer":"hall_master","win":[{"cmd":"give_money","amount":2000}]}],
                  "else":[{"cmd":"message","text":"hall_master_intro"},{"cmd":"trainer_battle","trainer":"hall_master","win":[{"cmd":"set_flag","flag":"hall_beaten"},{"cmd":"message","text":"hall_master_lose"},{"cmd":"give_money","amount":5000},{"cmd":"badge"}]}]}],
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
 "trainer_c": {"name_key":"tr_c_name","team":[{"species":"jinpachi_r","level":19},{"species":"neo","level":18}],"money":1200,"ai":"heuristic"},
 "trainer_d": {"name_key":"tr_d_name","team":[{"species":"renny","level":20},{"species":"honebami","level":20},{"species":"marutan","level":19}],"money":1500,"ai":"heuristic","format":"doubles"},
 "rival": {"name_key":"rival_name","team":[{"species":"hyu","level":22},{"species":"namazuo","level":22},{"species":"trans","level":24,"item":"leftovers"}],"money":2500,"ai":"heuristic"},
 "hall_master": {"name_key":"hall_master_name","team":[{"species":"jinpachi","level":26,"item":"charcoal"},{"species":"hyu","level":26,"item":"spell_tag"},{"species":"gel_r_poison","level":25,"item":"black_sludge"},{"species":"muni","level":25,"item":"light_clay"}],"money":5000,"ai":"heuristic","format":"doubles"},
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
