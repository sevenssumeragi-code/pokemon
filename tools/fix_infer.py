#!/usr/bin/env python3
"""Auto-fix 'Cannot infer the type' parse errors by turning `:=` into `=` on reported lines."""
import re, subprocess, sys
for it in range(15):
    subprocess.run(["godot","--headless","--path",".","--import"],capture_output=True)
    out = subprocess.run(["godot","--headless","--path",".","-s","tests/test_runner.gd"],capture_output=True,text=True)
    txt = out.stdout + out.stderr
    errs = re.findall(r'Cannot infer the type of "(\w+)" variable.*?\n\s*at: GDScript::reload \(res://([^:]+):(\d+)\)', txt)
    if not errs:
        print("no inference errors left"); break
    seen=set()
    for var, path, line in errs:
        key=(path,line)
        if key in seen: continue
        seen.add(key)
        lines=open(path).read().split("\n")
        i=int(line)-1
        lines[i]=lines[i].replace(":=","=",1)
        open(path,"w").write("\n".join(lines))
        print("fixed",path,line,var)
