#!/usr/bin/env python3
"""Merge simulator JSON outputs into a markdown balance report with pass/fail checks."""
import json, sys, argparse, collections, os
ap = argparse.ArgumentParser()
ap.add_argument("files", nargs="+")
ap.add_argument("--out", default=None)
ap.add_argument("--baseline", default=None, help="previous report json for diff")
a = ap.parse_args()
loc = json.load(open("data/localization/ja.json"))
JA = loc["species"]; JAB = loc["abilities"]; JIT = loc["items"]
def merge(files):
    M = {"battles": 0, "species": {}, "sets": {}, "stalls": collections.Counter(), "abilities": collections.Counter(), "items": collections.Counter(), "turns_hist": collections.Counter(), "ties": 0, "matchups": {}, "pairs": {}, "turns_sum": 0.0, "mode": None}
    for f in files:
        d = json.load(open(f))
        M["mode"] = d["mode"]
        M["battles"] += d["battles"]
        M["ties"] += d.get("ties", 0)
        M["turns_sum"] += d.get("avg_turns", 0) * d["battles"]
        for k, v in d.get("species", {}).items():
            s = M["species"].setdefault(k, collections.Counter()); s.update(v)
        for k, v in d.get("sets", {}).items():
            s = M["sets"].setdefault(k, collections.Counter()); s.update(v)
        for k, v in d.get("pairs", {}).items():
            s = M["pairs"].setdefault(k, collections.Counter()); s.update(v)
        M["abilities"].update(d.get("abilities", {})); M["items"].update(d.get("items", {})); M["stalls"].update(d.get("stalls", {}))
        M["turns_hist"].update({int(k): v for k, v in d.get("turns_hist", {}).items()})
        for k, v in d.get("matchups", {}).items():
            m = M["matchups"].setdefault(k, dict(v, wins_a=0, wins_b=0, ties=0, turns=0.0, n=0))
            m["wins_a"] += v["wins_a"]; m["wins_b"] += v["wins_b"]; m["ties"] += v["ties"]
            n = v["wins_a"] + v["wins_b"] + v["ties"]; m["turns"] += v["avg_turns"] * n; m["n"] += n
    return M
M = merge(a.files)
mode = M["mode"]
lines = []
P = lines.append
P(f"# Balance report ({mode}) — {M['battles']} battles")
P("")
fails = []
if mode == "1v1":
    P("## 1v1 per-species win rate (all sets, all opponents)")
    P("| species | 種族 | games | win% |"); P("|---|---|---|---|")
    for sp, s in sorted(M["species"].items(), key=lambda kv: -kv[1]["wins"]/max(1,kv[1]["games"])):
        P(f"| {sp} | {JA.get(sp,sp)} | {s['games']} | {100*s['wins']/max(1,s['games']):.1f} |")
    fixed = [(k, m) for k, m in M["matchups"].items() if m["n"] >= 30 and (m["wins_a"] == 0 or m["wins_b"] == 0)]
    P(""); P(f"## Fixed (100%/0%) set matchups: {len(fixed)} / {len(M['matchups'])} ({100*len(fixed)/max(1,len(M['matchups'])):.1f}%)")
    sp_fixed = collections.Counter()
    for k, m in fixed:
        winner = m["a"] if m["wins_b"] == 0 else m["b"]; loser = m["b"] if winner == m["a"] else m["a"]
        sp_fixed[(winner, loser)] += 1
    # species pairs where EVERY set combination is fixed in the same direction
    combos = collections.defaultdict(list)
    for k, m in M["matchups"].items():
        combos[(m["a"], m["b"])].append(m)
    hard = []
    for (x, y), ms in combos.items():
        if all(mm["wins_b"] == 0 for mm in ms): hard.append((x, y))
        if all(mm["wins_a"] == 0 for mm in ms): hard.append((y, x))
    P(f"Species pairs fixed across all sets: {len(hard)} / {len(combos)}")
    for x, y in hard: P(f"- {JA.get(x,x)} always beats {JA.get(y,y)}")
    if len(hard) > len(combos) * 0.15: fails.append(f"too many fixed species matchups: {len(hard)}/{len(combos)}")
    P(""); P("## Species vs species (win% of row vs column, all sets)")
    ids = sorted(M["species"].keys())
    grid = collections.defaultdict(lambda: [0, 0])
    for k, m in M["matchups"].items():
        grid[(m["a"], m["b"])][0] += m["wins_a"]; grid[(m["a"], m["b"])][1] += m["n"]
        grid[(m["b"], m["a"])][0] += m["wins_b"]; grid[(m["b"], m["a"])][1] += m["n"]
    P("| | " + " | ".join(JA.get(i,i)[:4] for i in ids) + " |"); P("|---|" + "---|" * len(ids))
    for x in ids:
        row = []
        for y in ids:
            if x == y: row.append("-")
            else:
                w, n = grid[(x, y)]; row.append(f"{100*w/max(1,n):.0f}")
        P(f"| {JA.get(x,x)} | " + " | ".join(row) + " |")
else:
    avg_turns = M["turns_sum"] / max(1, M["battles"])
    P(f"AI: heuristic vs heuristic, mode {mode}, team size {6 if mode=='6v6' else (4 if mode=='doubles' else 3)}, avg turns {avg_turns:.1f}, ties {M['ties']}")
    P("")
    P("## Per-species (team-inclusion win rate)")
    P("| species | 種族 | games | team win% | avg dmg/game | KOs/game | faint% | first-move% | avg turns | long-game% | status |")
    P("|---|---|---|---|---|---|---|---|---|---|---|")
    for sp, s in sorted(M["species"].items(), key=lambda kv: -kv[1]["wins"]/max(1,kv[1]["games"])):
        g = max(1, s["games"]); wr = 100*s["wins"]/g
        st = "OK" if 42 <= wr <= 58 else ("HIGH" if wr > 58 else "LOW")
        if st != "OK": fails.append(f"{sp} team win rate {wr:.1f}%")
        P(f"| {sp} | {JA.get(sp,sp)} | {s['games']} | {wr:.1f} | {s['damage']/g:.0f} | {s['kos']/g:.2f} | {100*s['fainted']/g:.0f} | {100*s['first_move']/max(1,s['turns_present']):.0f} | {s.get('turns',0)/g:.1f} | {100*s.get('long_games',0)/g:.1f} | {st} |")
    P(""); P("## Per-set")
    P("| set | games | win% |"); P("|---|---|---|")
    for k, s in sorted(M["sets"].items(), key=lambda kv: -kv[1]["wins"]/max(1,kv[1]["games"])):
        P(f"| {k} | {s['games']} | {100*s['wins']/max(1,s['games']):.1f} |")
    P(""); P("## Ability activations (total)")
    P("| ability | 特性 | count | per battle |"); P("|---|---|---|---|")
    for k, v in M["abilities"].most_common():
        P(f"| {k} | {JAB.get(k,k)} | {v} | {v/max(1,M['battles']):.2f} |")
    P(""); P("## Item activations (total)")
    P("| item | count |"); P("|---|---|")
    for k, v in M["items"].most_common(): P(f"| {JIT.get(k,k)} | {v} |")
    P(""); P("## Turn distribution")
    P("| turns | battles |"); P("|---|---|")
    for t in sorted(M["turns_hist"]): P(f"| {t}{'+' if t>=150 else ''} | {M['turns_hist'][t]} |")
    six = (mode == "6v6")
    if avg_turns > (60 if six else 40): fails.append(f"average turns too long: {avg_turns:.1f}")
    LONG = 100 if six else 60
    long = sum(v for t, v in M["turns_hist"].items() if t >= LONG)
    if long / max(1, M["battles"]) > 0.03: fails.append(f"{100*long/M['battles']:.1f}% of battles reach {LONG}+ turns")
    P(""); P("## Most frequent long-game (60+ turns in 3v3 / 100+ in 6v6) set combinations")
    for k, v in M["stalls"].most_common(15): P(f"- {v}x {k}")
    P(""); P("## Species-vs-species team win% (row species' team vs column species' team)")
    ids = sorted(M["species"].keys())
    P("| | " + " | ".join(JA.get(i,i)[:4] for i in ids) + " |"); P("|---|" + "---|" * len(ids))
    for x in ids:
        row = []
        for y in ids:
            if x == y: row.append("-")
            else:
                p = M["pairs"].get(f"{x}>{y}", {"wins": 0, "games": 0}); row.append(f"{100*p['wins']/max(1,p['games']):.0f}")
        P(f"| {JA.get(x,x)} | " + " | ".join(row) + " |")
P(""); P("## Pass criteria")
if fails:
    P("**FAIL**"); [P(f"- {f}") for f in fails]
else:
    P("**PASS**")
txt = "\n".join(lines)
if a.out:
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    open(a.out, "w").write(txt)
    json.dump({"mode": mode, "species": {k: dict(v) for k, v in M["species"].items()}, "sets": {k: dict(v) for k, v in M["sets"].items()}, "battles": M["battles"],
               "pairs": {k: dict(v) for k, v in M["pairs"].items()}, "abilities": dict(M["abilities"]), "items": dict(M["items"]),
               "turns_hist": {str(k): v for k, v in M["turns_hist"].items()}, "avg_turns": M["turns_sum"] / max(1, M["battles"]), "ties": M["ties"],
               "matchups": {k: {kk: vv for kk, vv in m.items()} for k, m in M["matchups"].items()}}, open(a.out.replace(".md", ".json"), "w"))
    print("wrote", a.out)
print(txt[:3000])
