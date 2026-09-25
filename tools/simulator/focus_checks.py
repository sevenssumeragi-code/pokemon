#!/usr/bin/env python3
"""Print the 10 focus checks (重点検証リスト) from merged report JSONs.
usage: focus_checks.py reports/balance_<tag>_3v3.json [reports/balance_<tag>_1v1.json]"""
import json, sys, collections
J3 = json.load(open(sys.argv[1]))
J1 = json.load(open(sys.argv[2])) if len(sys.argv) > 2 else None
loc = json.load(open("data/localization/ja.json"))["species"]
sp = J3["species"]; pairs = J3["pairs"]; B = J3["battles"]
def wr(x): s = sp[x]; return 100 * s["wins"] / max(1, s["games"])
def pair(x, y): p = pairs.get(f"{x}>{y}", {"wins": 0, "games": 0}); return 100 * p["wins"] / max(1, p["games"]), p["games"]
def dmg(x): s = sp[x]; return s["damage"] / max(1, s["games"])
def one(x, y):
    """1v1 win% of x vs y across all sets"""
    if not J1: return None
    w = n = 0
    for k, m in J1["matchups"].items():
        if m["a"] == x and m["b"] == y: w += m["wins_a"]; n += m["n"]
        elif m["a"] == y and m["b"] == x: w += m["wins_b"]; n += m["n"]
    return (100 * w / n) if n else None
print(f"# Focus checks — 3v3 {B} battles, avg turns {J3['avg_turns']:.1f}")
th = J3["turns_hist"]; long = sum(v for k, v in th.items() if int(k) >= 40)
print(f"1. ムニRノ(ミニマムボディ+ちいさくなる): team win {wr('muni_r_normal'):.1f}%, minimal_body activations/battle {J3['abilities'].get('minimal_body',0)/B:.2f}, battles >=40 turns: {100*long/B:.2f}%")
for k, v in sorted(J3["sets"].items()):
    if k.startswith("muni_r_normal"): print(f"     set {k}: {100*v['wins']/max(1,v['games']):.1f}% ({v['games']})")
print(f"2. ムニ(いたずらごころ): team win {wr('muni'):.1f}%, prankster activations/battle {J3['abilities'].get('prankster',0)/B:.2f}")
for k, v in sorted(J3["sets"].items()):
    if k.startswith("muni/"): print(f"     set {k}: {100*v['wins']/max(1,v['games']):.1f}% ({v['games']})")
print(f"3. ジンパチ(炎の領域2.25x): team win {wr('jinpachi'):.1f}%, dmg/game {dmg('jinpachi'):.0f} (avg of all species {sum(dmg(x) for x in sp)/len(sp):.0f}), KOs/game {sp['jinpachi']['kos']/sp['jinpachi']['games']:.2f}")
print(f"4. ヒュウR(あまのじゃく): team win {wr('hyu_r'):.1f}%, dmg/game {dmg('hyu_r'):.0f}, contrary activations/battle {J3['abilities'].get('contrary',0)/B:.2f}")
print(f"5. レニィ(めざめるしし): team win {wr('renny'):.1f}%, lion activations/battle {J3['abilities'].get('awakened_lion',0)/B:.2f}, dmg/game {dmg('renny'):.0f}")
for k, v in sorted(J3["sets"].items()):
    if k.startswith("renny/"): print(f"     set {k}: {100*v['wins']/max(1,v['games']):.1f}% ({v['games']})")
print(f"6. ゲル(ゆきふらし+ふぶき): team win {wr('gel'):.1f}%, dmg/game {dmg('gel'):.0f}, snow_warning/battle {J3['abilities'].get('snow_warning',0)/B:.2f}")
print(f"7. トランス(きれあじ+つるぎのまい): team win {wr('trans'):.1f}%, dmg/game {dmg('trans'):.0f}, sharpness activations/battle {J3['abilities'].get('sharpness',0)/B:.2f}")
print(f"8. マルタン(せいなるひかり): team win {wr('marutan'):.1f}%; vs ghost/dark users: hyu {pair('marutan','hyu')[0]:.0f}%, gel_r_dark {pair('marutan','gel_r_dark')[0]:.0f}%  (1v1: hyu {one('marutan','hyu')}, gel_r_dark {one('marutan','gel_r_dark')})")
print("9. いかく2体 vs 物理型:")
for phys in ["neo", "namazuo", "honebami", "jinpachi_r", "trans", "jinpachi", "renny_r"]:
    a = pair(phys, "gel_r_poison"); b = pair(phys, "gel_r_dark")
    print(f"     {loc[phys]:10s} vs ゲル毒 {a[0]:.0f}% ({a[1]})  vs ゲル悪 {b[0]:.0f}% ({b[1]})   1v1: {one(phys,'gel_r_poison')} / {one(phys,'gel_r_dark')}")
print(f"10. フェアリー vs ドラゴン: muni vs muni_r_dragon {pair('muni','muni_r_dragon')[0]:.0f}%, renny_r vs muni_r_dragon {pair('renny_r','muni_r_dragon')[0]:.0f}%  (1v1: {one('muni','muni_r_dragon')}, {one('renny_r','muni_r_dragon')}); muni_r_dragon team win {wr('muni_r_dragon'):.1f}%")
print("\nTeam win% by species:")
for x, s in sorted(sp.items(), key=lambda kv: -kv[1]["wins"] / max(1, kv[1]["games"])):
    print(f"  {loc[x]:14s} {wr(x):5.1f}%  dmg {dmg(x):4.0f}  KO {s['kos']/max(1,s['games']):.2f}  faint {100*s['fainted']/max(1,s['games']):.0f}%")
