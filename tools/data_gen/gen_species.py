#!/usr/bin/env python3
"""Generate data/species/*.json (19 roster species) + localization."""
import json, os
moves = json.load(open("data/moves/moves.json"))
L = json.load(open("data/localization/ja.json"))
S = {}
loc = {}
def sp(id, ja, types, hp, atk, df, spa, spd, spe, ability, hidden=None, level=(), tm=(), weight=30.0, height=1.0,
       base_form=None, form="", evolves_from=None, evolution=None, nfe=False, num=0, catch_rate=90, base_exp=150, growth="medium_fast", ev_yield=None, dex=""):
    lv = [{"level": l, "move": m} for (l, m) in level]
    for e in lv: assert e["move"] in moves, (id, e["move"])
    for m in tm: assert m in moves, (id, m)
    S[id] = {
        "num": num, "types": types,
        "base_stats": {"hp": hp, "atk": atk, "def": df, "spa": spa, "spd": spd, "spe": spe},
        "abilities": {"0": ability, "H": hidden} if hidden else {"0": ability},
        "weight_kg": weight, "height_m": height,
        "base_form": base_form or id, "form": form, "region_form": form != "",
        "evolves_from": evolves_from, "evolution": evolution, "nfe": nfe,
        "learnset": {"level": lv, "tm": sorted(set(tm))},
        "catch_rate": catch_rate, "base_exp": base_exp, "growth_rate": growth,
        "ev_yield": ev_yield or {}, "gender_ratio": 0.5, "sprite": id, "dex_key": id,
    }
    loc[id] = ja
    L.setdefault("dex", {})[id] = dex
    print(f"{id:16s} BST={hp+atk+df+spa+spd+spe}")

COMMON_TM = ["protect","substitute","rest","sleep_talk","facade","toxic","endure","attract","swagger","double_team"]
COMMON_TM = [m for m in COMMON_TM if m in moves]

# 1 レニィ みず H/A
sp("renny","レニィ",["water"],105,115,80,55,75,80,"awakened_lion",num=1,weight=85.0,height=1.4,catch_rate=45,base_exp=175,ev_yield={"atk":2},
   level=[(1,"tackle"),(1,"leer"),(4,"water_gun"),(8,"bite"),(12,"aqua_jet"),(16,"scary_face"),(20,"razor_shell"),(24,"yawn"),(28,"waterfall"),(32,"rest"),(36,"crunch"),(40,"liquidation"),(44,"aqua_cutter"),(48,"body_slam"),(52,"wave_crash"),(56,"sleep_talk"),(60,"crabhammer")],
   tm=COMMON_TM+["ice_fang","ice_punch","earthquake","stone_edge","rock_slide","flip_turn","aqua_tail","superpower","body_press","iron_head","bulk_up","dragon_tail","knock_off","snore","rain_dance","brick_break","low_kick","play_rough","zen_headbutt","chilling_water","surf","scald","heavy_slam","curse","taunt","roar","avalanche","ice_beam","hydro_pump"],
   dex="眠りから覚めた瞬間、獅子のような咆哮とともに全力の一撃を放つ。深い眠りほど目覚めは激しい。")
# 2 ジンパチ ほのお A/S
sp("jinpachi","ジンパチ",["fire"],70,105,70,85,70,110,"flame_domain",num=2,weight=55.0,height=1.5,catch_rate=45,base_exp=175,ev_yield={"spe":2},
   level=[(1,"scratch"),(1,"ember"),(5,"quick_attack"),(9,"howl"),(13,"flame_wheel"),(17,"fire_fang"),(21,"flame_charge"),(25,"will_o_wisp"),(29,"fire_punch"),(33,"swords_dance"),(37,"blaze_kick"),(41,"sunny_day"),(45,"flare_blitz"),(49,"heat_wave"),(53,"overheat"),(57,"fire_lash"),(61,"bitter_blade")],
   tm=COMMON_TM+["u_turn","close_combat","earthquake","iron_head","wild_charge","thunder_punch","play_rough","crunch","knock_off","bulk_up","taunt","roar","flamethrower","fire_blast","solar_beam","psychic_fangs","low_kick","brick_break","stone_edge","rock_slide","fake_out","trailblaze","body_slam","double_edge","snore","scorching_sands","zen_headbutt","heat_crash","agility","work_up","torch_song"],
   dex="周囲の空気を自身の炎の領域に変えてしまう。仲間の炎まで激しく燃え上がらせる。")
# 3 ヒュウ ゴースト C/S
sp("hyu","ヒュウ",["ghost"],90,50,85,90,80,105,"dark_domain",num=3,weight=12.0,height=1.2,catch_rate=45,base_exp=175,ev_yield={"spa":2},
   level=[(1,"astonish"),(1,"lick"),(5,"confuse_ray"),(9,"night_shade"),(13,"shadow_sneak"),(17,"hex"),(21,"will_o_wisp"),(25,"shadow_ball"),(29,"curse"),(33,"nasty_plot"),(37,"dark_pulse"),(41,"pain_split"),(45,"phantom_force"),(49,"destiny_bond"),(53,"poltergeist"),(57,"bitter_malice"),(61,"shadow_claw")],
   tm=COMMON_TM+["psychic","sludge_bomb","dazzling_gleam","taunt","trick","calm_mind","disable","haze","icy_wind","thunder_wave","hypnosis","psyshock","giga_drain","shadow_punch","knock_off","sucker_punch","memento","trick_room","nightmare","dream_eater","snore","ominous_wind","hyper_voice","shadow_bone"],
   dex="夜の闇そのものを身にまとう。その領域の中では亡霊の力が何倍にもふくれあがる。")
# 4 ムニ フェアリー 平均低め
sp("muni","ムニ",["fairy"],85,40,70,85,80,80,"prankster",num=4,weight=4.5,height=0.4,catch_rate=190,base_exp=90,ev_yield={"spe":1},
   level=[(1,"pound"),(1,"charm"),(4,"fairy_wind"),(7,"baby_doll_eyes"),(10,"disarming_voice"),(13,"minimize"),(16,"sweet_kiss"),(19,"draining_kiss"),(22,"encore"),(25,"wish"),(28,"dazzling_gleam"),(31,"attract"),(34,"moonlight"),(37,"moonblast"),(40,"play_rough"),(43,"misty_terrain"),(46,"light_screen"),(49,"reflect"),(52,"thunder_wave"),(55,"tearful_look")],
   tm=COMMON_TM+["taunt","will_o_wisp","psychic","thunderbolt","shadow_ball","calm_mind","yawn","heal_bell","baton_pass","safeguard","stored_power","psych_up","helping_hand","trick","knock_off","u_turn","energy_ball","mystical_fire","nasty_plot","leech_seed","icy_wind","charge_beam","snore","fake_tears","tickle","screech","confuse_ray","hyper_voice","work_up","body_slam","spirit_break"],
   dex="小さないたずら好き。相手が動く前にちょこまかと動き回り、姿を小さくして攻撃をかわす。")
# 5 ゲル こおり C/S
sp("gel","ゲル",["ice"],80,60,85,90,85,100,"snow_warning",num=5,weight=32.0,height=1.1,catch_rate=60,base_exp=170,ev_yield={"spa":2},
   level=[(1,"powder_snow"),(1,"leer"),(5,"icy_wind"),(9,"water_gun"),(13,"aurora_beam"),(17,"haze"),(21,"ice_shard"),(25,"frost_breath"),(29,"aurora_veil"),(33,"freeze_dry"),(37,"ice_beam"),(41,"snowscape"),(45,"calm_mind"),(49,"blizzard"),(53,"mist"),(57,"moonblast"),],
   tm=COMMON_TM+["psychic","dazzling_gleam","shadow_ball","energy_ball","surf","hydro_pump","nasty_plot","light_screen","reflect","thunder_wave","icy_wind","water_pulse","weather_ball","hyper_voice","snore","taunt","encore","tri_attack","yawn","rain_dance","psyshock","flash_cannon","ice_spinner","avalanche","earth_power","chilling_water","haze"],
   dex="現れると周囲に雪を降らせる。雪の中では体表が硬く凍りつき、吹雪を自在に操る。")
# 6 ネオ かくとう A/C (進化前)
sp("neo","ネオ",["fighting"],60,100,55,60,55,90,"sharpness",hidden="steadfast",num=6,weight=20.0,height=0.9,nfe=True,evolution={"method":"level","level":34,"into":"trans"},catch_rate=120,base_exp=80,ev_yield={"atk":1},
   level=[(1,"scratch"),(1,"leer"),(4,"karate_chop"),(8,"cut"),(12,"fury_cutter"),(16,"focus_energy"),(20,"slash"),(24,"aerial_ace"),(28,"night_slash"),(32,"swords_dance"),(36,"x_scissor"),(40,"sacred_sword"),(44,"psycho_cut"),(48,"secret_sword"),(52,"close_combat")],
   tm=COMMON_TM+["brick_break","bulk_up","rock_slide","stone_edge","earthquake","knock_off","u_turn","aura_sphere","vacuum_wave","air_cutter","leaf_blade","stone_axe","ceaseless_edge","drain_punch","mach_punch","poison_jab","iron_head","taunt","work_up","body_press","low_kick","aqua_cutter","razor_shell","focus_blast","cross_poison","detect","counter","reversal","bullet_punch","snore"],
   dex="鋭い爪を研ぎ澄ますのが日課。まだ幼いが、切れ味だけは大人にも負けない。")
# 7 トランス かくとう/じめん
sp("trans","トランス",["fighting","ground"],90,120,80,105,75,70,"sharpness",hidden="steadfast",num=7,weight=95.0,height=1.8,evolves_from="neo",catch_rate=45,base_exp=190,ev_yield={"atk":3},
   level=[(1,"scratch"),(1,"leer"),(1,"karate_chop"),(1,"cut"),(12,"fury_cutter"),(16,"focus_energy"),(20,"slash"),(24,"aerial_ace"),(28,"night_slash"),(32,"swords_dance"),(34,"stone_axe"),(38,"x_scissor"),(42,"sacred_sword"),(46,"psycho_cut"),(50,"earth_power"),(54,"secret_sword"),(58,"close_combat"),(62,"high_horsepower")],
   tm=COMMON_TM+["brick_break","bulk_up","rock_slide","stone_edge","earthquake","knock_off","u_turn","aura_sphere","vacuum_wave","air_cutter","leaf_blade","ceaseless_edge","drain_punch","mach_punch","poison_jab","iron_head","taunt","work_up","body_press","low_kick","aqua_cutter","razor_shell","focus_blast","cross_poison","detect","counter","reversal","bullet_punch","snore","stomping_tantrum","bulldoze","scorching_sands","spikes","stealth_rock","superpower","headlong_rush","solar_blade","iron_defense","psyblade"],
   dex="大地の力を得た斬撃の達人。一振りで岩盤ごと相手を斬り裂くという。")
# 8 マルタン ひこう B/D
sp("marutan","マルタン",["flying"],95,60,110,90,110,65,"sacred_light",num=8,weight=28.0,height=1.3,catch_rate=60,base_exp=170,ev_yield={"spd":1,"def":1},
   level=[(1,"peck"),(1,"growl"),(5,"gust"),(9,"sand_attack"),(13,"wing_attack"),(17,"roost"),(21,"air_cutter"),(25,"tailwind"),(29,"air_slash"),(33,"defog"),(37,"cosmic_power"),(41,"whirlwind"),(45,"hurricane"),(49,"wish"),(53,"heal_bell"),(57,"brave_bird"),(61,"moonblast")],
   tm=COMMON_TM+["u_turn","toxic","heat_wave","dazzling_gleam","psychic","light_screen","reflect","safeguard","haze","thunder_wave","body_press","iron_defense","stored_power","calm_mind","hyper_voice","fly","dual_wingbeat","steel_wing","feather_dance","aerial_ace","snore","taunt","encore","baton_pass","air_cutter","chilling_water","mystical_fire","draining_kiss","foul_play","psych_up","nasty_plot"],
   dex="羽根から聖なる光を放つ。闇や亡霊の力を弱め、仲間を静かに守る。")
# 9 なまずお でんき/はがね
sp("namazuo","なまずお",["electric","steel"],70,100,85,65,75,105,"static",num=9,weight=60.0,height=1.2,catch_rate=60,base_exp=170,ev_yield={"atk":2},
   level=[(1,"tackle"),(1,"thunder_shock"),(5,"metal_claw"),(9,"nuzzle"),(13,"spark"),(17,"cut"),(21,"iron_head"),(25,"thunder_wave"),(29,"slash"),(33,"swords_dance"),(37,"wild_charge"),(41,"night_slash"),(45,"iron_defense"),(49,"x_scissor"),(53,"zing_zap"),(57,"smart_strike"),(61,"volt_tackle")],
   tm=COMMON_TM+["volt_switch","thunderbolt","thunder","steel_beam","flash_cannon","aqua_cutter","psycho_cut","sacred_sword","leaf_blade","stone_axe","ceaseless_edge","aerial_ace","air_cutter","crunch","earthquake","rock_slide","stone_edge","brick_break","body_press","bulk_up","taunt","electric_terrain","magnet_rise","gyro_ball","heavy_slam","thunder_punch","ice_punch","fire_punch","snore","agility","u_turn","razor_shell","x_scissor","electroweb","charge"],
   dex="鋼のひげに静電気をため込む。触れた者はしびれてしまう。")
# 10 ほねばみ はがね/ひこう
sp("honebami","ほねばみ",["steel","flying"],75,100,80,65,75,105,"unburden",num=10,weight=18.0,height=1.0,catch_rate=60,base_exp=170,ev_yield={"spe":2},
   level=[(1,"peck"),(1,"leer"),(5,"metal_claw"),(9,"quick_attack"),(13,"wing_attack"),(17,"cut"),(21,"steel_wing"),(25,"aerial_ace"),(29,"slash"),(33,"swords_dance"),(37,"air_cutter"),(41,"iron_head"),(45,"night_slash"),(49,"acrobatics"),(53,"drill_peck"),(57,"smart_strike"),(61,"air_slash")],
   tm=COMMON_TM+["u_turn","tailwind","roost","knock_off","x_scissor","psycho_cut","sacred_sword","stone_axe","ceaseless_edge","aqua_cutter","leaf_blade","dual_wingbeat","drill_peck","fly","rock_slide","stone_edge","body_press","iron_defense","taunt","defog","brick_break","low_kick","agility","steel_beam","flash_cannon","bullet_punch","snore","hurricane","feather_dance","heavy_slam"],
   dex="骨のように軽い鋼の翼を持つ。荷物を捨てると風のような速さで飛び回る。")
# 11 ジンパチR いわ
sp("jinpachi_r","ジンパチ（リージョン）",["rock"],105,120,95,55,115,50,"sturdy",num=11,weight=130.0,height=1.6,base_form="jinpachi",form="R",catch_rate=45,base_exp=175,ev_yield={"atk":2},
   level=[(1,"tackle"),(1,"leer"),(5,"rock_throw"),(9,"howl"),(13,"rock_tomb"),(17,"bulldoze"),(21,"rock_slide"),(25,"iron_defense"),(29,"stealth_rock"),(33,"swords_dance"),(37,"stone_axe"),(41,"sandstorm"),(45,"stone_edge"),(49,"earthquake"),(53,"head_smash"),(57,"body_press"),(61,"rock_polish")],
   tm=COMMON_TM+["fire_punch","fire_fang","flare_blitz","heavy_slam","iron_head","superpower","close_combat","crunch","knock_off","bulk_up","taunt","roar","brick_break","stomping_tantrum","high_horsepower","accelerock","smack_down","curse","counter","ancient_power","snore","low_kick","zen_headbutt","salt_cure","rock_blast","body_slam","double_edge","stone_axe","wide_guard"],
   dex="火山地帯で岩の体を得た姿。動きは鈍いが、その体はどんな一撃にも一度は耐える。")
# 12 ヒュウR くさ
sp("hyu_r","ヒュウ（リージョン）",["grass"],85,55,75,100,80,105,"contrary",num=12,weight=10.0,height=1.2,base_form="hyu",form="R",catch_rate=45,base_exp=175,ev_yield={"spa":2},
   level=[(1,"absorb"),(1,"leer"),(5,"leafage"),(9,"leech_seed"),(13,"mega_drain"),(17,"sleep_powder"),(21,"magical_leaf"),(25,"synthesis"),(29,"giga_drain"),(33,"energy_ball"),(37,"grassy_terrain"),(41,"leaf_storm"),(45,"strength_sap"),(49,"solar_beam"),(53,"apple_acid"),(57,"petal_dance"),(61,"spore")],
   tm=COMMON_TM+["shadow_ball","psychic","dazzling_gleam","sludge_bomb","earth_power","knock_off","taunt","trick","hyper_voice","seed_bomb","grass_knot","stun_spore","light_screen","reflect","calm_mind","nasty_plot","hex","will_o_wisp","psyshock","weather_ball","snore","sunny_day","trailblaze","icy_wind","confuse_ray","leaf_tornado","struggle_bug","snarl"],
   dex="森の霊気を宿した姿。ひねくれた性質で、力を失う技を使うほど強くなっていく。")
# 13 レニィR フェアリー
sp("renny_r","レニィ（リージョン）",["fairy"],105,115,80,55,75,80,"pixilate",num=13,weight=70.0,height=1.4,base_form="renny",form="R",catch_rate=45,base_exp=175,ev_yield={"atk":2},
   level=[(1,"tackle"),(1,"leer"),(4,"fairy_wind"),(8,"quick_attack"),(12,"bite"),(16,"headbutt"),(20,"play_rough"),(24,"yawn"),(28,"body_slam"),(32,"rest"),(36,"crunch"),(40,"take_down"),(44,"hyper_voice"),(48,"double_edge"),(52,"sleep_talk"),(56,"boomburst")],
   tm=COMMON_TM+["ice_fang","ice_punch","earthquake","stone_edge","rock_slide","superpower","body_press","iron_head","bulk_up","knock_off","snore","brick_break","low_kick","zen_headbutt","heavy_slam","curse","taunt","roar","mega_kick","strength","retaliate","spirit_break","wish","charm","fire_fang","thunder_fang","drain_punch","fake_out","hyper_fang","population_bomb","slash","false_swipe"],
   dex="妖精の加護を受けた姿。放つ突進は妖精の光をまとい、竜すら退ける。")
# 14 ムニR竜 ドラゴン
sp("muni_r_dragon","ムニ（竜）",["dragon"],80,90,80,45,75,70,"multiscale",num=14,weight=9.0,height=0.5,base_form="muni",form="R竜",catch_rate=120,base_exp=100,ev_yield={"hp":1},
   level=[(1,"pound"),(1,"leer"),(4,"twister"),(7,"dragon_breath"),(10,"minimize"),(13,"scary_face"),(16,"dragon_tail"),(19,"dual_chop"),(22,"dragon_dance"),(25,"dragon_pulse"),(28,"roost"),(31,"dragon_claw"),(34,"breaking_swipe"),(37,"scale_shot"),(40,"draco_meteor"),(43,"outrage"),(46,"dragon_rush"),(49,"haze"),(52,"light_screen"),(55,"reflect")],
   tm=COMMON_TM+["thunderbolt","flamethrower","ice_beam","earthquake","iron_head","u_turn","taunt","encore","wish","baton_pass","calm_mind","stored_power","body_slam","play_rough","knock_off","aqua_tail","iron_tail","fire_fang","thunder_fang","ice_fang","snore","agility","work_up","hyper_voice","fire_punch","thunder_punch","psych_up","helping_hand","extreme_speed"],
   dex="小さな竜の鱗をまとった姿。傷ひとつない鱗は、どんな攻撃の勢いも半分に殺してしまう。")
# 15 ムニR虫 むし
sp("muni_r_bug","ムニ（虫）",["bug"],65,50,60,90,75,100,"compound_eyes",num=15,weight=3.0,height=0.4,base_form="muni",form="R虫",catch_rate=120,base_exp=100,ev_yield={"spa":1},
   level=[(1,"pound"),(1,"string_shot"),(4,"struggle_bug"),(7,"supersonic"),(10,"sleep_powder"),(13,"stun_spore"),(16,"poison_powder"),(19,"gust"),(22,"psybeam"),(25,"minimize"),(28,"air_cutter"),(31,"bug_buzz"),(34,"rage_powder"),(37,"quiver_dance"),(40,"air_slash"),(43,"hurricane"),(46,"energy_ball")],
   tm=COMMON_TM+["psychic","shadow_ball","giga_drain","u_turn","tailwind","roost","light_screen","reflect","safeguard","thunder_wave","draining_kiss","dazzling_gleam","baton_pass","encore","taunt","sticky_web","infestation","hyper_voice","snore","icy_wind","electroweb","calm_mind","stored_power","psych_up","substitute","skitter_smack","pounce","leech_life","thunder","focus_blast","hydro_pump"],
   dex="複眼を持つ虫の姿。粉を撒く技を確実に当て、舞い踊るたびに強くなる。")
# 16 ムニRノ ノーマル
sp("muni_r_normal","ムニ（ノ）",["normal"],85,70,75,50,75,85,"minimal_body",num=16,weight=5.0,height=0.3,base_form="muni",form="Rノ",catch_rate=120,base_exp=100,ev_yield={"spd":1},
   level=[(1,"pound"),(1,"growl"),(4,"quick_attack"),(7,"sand_attack"),(10,"minimize"),(13,"double_team"),(16,"headbutt"),(19,"encore"),(22,"body_slam"),(25,"wish"),(28,"yawn"),(31,"soft_boiled"),(34,"baton_pass"),(37,"hyper_voice"),(40,"double_edge"),(43,"tearful_look"),(46,"extreme_speed"),(49,"boomburst")],
   tm=COMMON_TM+["thunderbolt","ice_beam","flamethrower","shadow_ball","psychic","thunder_wave","will_o_wisp","calm_mind","work_up","stored_power","taunt","knock_off","u_turn","light_screen","reflect","safeguard","heal_bell","charm","play_rough","fake_out","snore","tri_attack","seismic_toss","counter","psych_up","icy_wind","acrobatics","retaliate"],
   dex="ごく小さな体の姿。あまりに小さいため、狙いを定めるのがとても難しい。")
# 17 ゲルR毒 どく
sp("gel_r_poison","ゲル（毒）",["poison"],100,95,80,60,105,65,"intimidate",num=17,weight=45.0,height=1.1,base_form="gel",form="R毒",catch_rate=60,base_exp=170,ev_yield={"hp":1,"spd":1},
   level=[(1,"pound"),(1,"leer"),(5,"poison_gas"),(9,"acid_spray"),(13,"bite"),(17,"poison_tail"),(21,"toxic_spikes"),(25,"venoshock"),(29,"poison_jab"),(33,"toxic"),(37,"recover"),(41,"baneful_bunker"),(45,"coil"),(49,"gunk_shot"),(53,"haze"),(57,"cross_poison"),(61,"acid_armor")],
   tm=COMMON_TM+["earthquake","knock_off","crunch","body_press","iron_defense","taunt","roar","pain_split","sludge_bomb","sludge_wave","ice_punch","fire_punch","thunder_punch","drain_punch","brick_break","low_kick","aqua_tail","play_rough","snore","clear_smog","venoshock","stomping_tantrum","bulk_up","rock_slide","stone_edge","poison_fang","yawn","curse","body_slam","seismic_toss","counter","spikes","icy_wind","chilling_water"],
   dex="毒の沼で育った姿。強烈な威圧感で相手をひるませ、じわじわと毒で追いつめる。")
# 18 ゲルR悪 あく
sp("gel_r_dark","ゲル（悪）",["dark"],120,85,90,80,90,75,"intimidate",num=18,weight=40.0,height=1.1,base_form="gel",form="R悪",catch_rate=60,base_exp=170,ev_yield={"hp":2},
   level=[(1,"pound"),(1,"leer"),(5,"bite"),(9,"fake_tears"),(13,"snarl"),(17,"taunt"),(21,"knock_off"),(25,"night_slash"),(29,"foul_play"),(33,"dark_pulse"),(37,"recover"),(41,"parting_shot"),(45,"crunch"),(49,"nasty_plot"),(53,"haze"),(57,"sucker_punch"),(61,"kowtow_cleave")],
   tm=COMMON_TM+["ice_beam","thunderbolt","flamethrower","earthquake","body_press","iron_defense","roar","pain_split","ice_punch","fire_punch","thunder_punch","drain_punch","brick_break","low_kick","aqua_tail","play_rough","snore","stomping_tantrum","bulk_up","calm_mind","rock_slide","stone_edge","yawn","curse","body_slam","seismic_toss","counter","icy_wind","chilling_water","u_turn","psychic","shadow_ball","hyper_voice","thunder_wave","will_o_wisp","encore","memento","assurance","payback","throat_chop"],
   dex="夜の湿地で生きる姿。にらみで相手を萎縮させ、持ち前のタフさで戦いを長引かせる。")
# 19 トランスR エスパー
sp("trans_r","トランス（リージョン）",["psychic"],90,115,75,110,75,75,"competitive",num=19,weight=80.0,height=1.8,base_form="trans",form="R",catch_rate=45,base_exp=190,ev_yield={"atk":2,"spa":1},
   level=[(1,"scratch"),(1,"leer"),(1,"confusion"),(1,"cut"),(12,"fury_cutter"),(16,"focus_energy"),(20,"slash"),(24,"aerial_ace"),(28,"psybeam"),(32,"swords_dance"),(34,"psycho_cut"),(38,"night_slash"),(42,"calm_mind"),(46,"psychic"),(50,"sacred_sword"),(54,"psyblade"),(58,"expanding_force"),(62,"psyshock")],
   tm=COMMON_TM+["brick_break","bulk_up","rock_slide","stone_edge","earthquake","knock_off","u_turn","aura_sphere","vacuum_wave","air_cutter","leaf_blade","ceaseless_edge","stone_axe","drain_punch","mach_punch","poison_jab","iron_head","taunt","work_up","body_press","low_kick","aqua_cutter","razor_shell","focus_blast","cross_poison","detect","counter","reversal","bullet_punch","snore","trick_room","psychic_terrain","light_screen","reflect","trick","stored_power","dazzling_gleam","shadow_ball","thunderbolt","ice_punch","thunder_punch","fire_punch","secret_sword","x_scissor","close_combat","teleport","agility","nasty_plot"],
   dex="精神の力に目覚めた姿。挑発されるほど闘志と念力が高まる。")

os.makedirs("data/species", exist_ok=True)
for id, d in S.items():
    json.dump({id: d}, open(f"data/species/{id}.json", "w"), ensure_ascii=False, indent=1)
L["species"] = loc
json.dump(L, open("data/localization/ja.json", "w"), ensure_ascii=False, indent=1)
print("species", len(S))
