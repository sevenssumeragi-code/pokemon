#!/usr/bin/env python3
import json, sys
a=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2]))
sa,sb=a["species"],b["species"]
print("| species | prev | now | diff | dmg | faint% | status |")
for k in sorted(sb, key=lambda k:-sb[k]["wins"]/sb[k]["games"]):
    r2=100*sa[k]["wins"]/sa[k]["games"]; r3=100*sb[k]["wins"]/sb[k]["games"]
    st="OK" if 42<=r3<=58 else ("HIGH" if r3>58 else "LOW")
    print(f"| {k:14s} | {r2:.1f} | {r3:.1f} | {r3-r2:+.1f} | {sb[k]['damage']/sb[k]['games']:.0f} | {100*sb[k]['fainted']/sb[k]['games']:.0f} | {st} |")
th=b["turns_hist"]; long=sum(v for k,v in th.items() if int(k)>=60); print("avg turns",round(b["avg_turns"],1),"60+ %.2f%%"%(100*long/b["battles"]), "ties", b["ties"])
print("\nsets (bottom/top 12):")
ss=sorted(b["sets"].items(), key=lambda kv:-kv[1]["wins"]/kv[1]["games"])
for k,v in ss[:12]+[("...",None)]+ss[-12:]:
    print(f"  {k:32s} {100*v['wins']/v['games']:.1f}" if v else "  ...")
