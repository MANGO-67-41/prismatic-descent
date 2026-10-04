"""Gives the last few tight rooms their second rope by hanging it from a small stub (ceiling) or beam (open sky)."""
import glob, json, os, random, sys
sys.path.insert(0, os.path.dirname(__file__))
import world_gen as wg
from world_bake import load_room
from world_thin import meta_for
T = 8
for f in sorted(glob.glob("data/world/[0-9]*.json")):
    d = json.load(open(f)); want = 2 + (1 if d["sw"] * d["sh"] >= 2 else 0)
    if len(d["ropes"]) >= 2: continue
    r, _ = load_room(f); r.meta = meta_for(d, r); k = r.kind; tw, th = d["tw"], d["th"]; first = bool(d.get("first")); ct = 0 if first else 5
    kind = "vine" if d["theme"] == "overgrowth" else "rope"
    used = [int((rp[0] - 4) // T) for rp in d["ropes"]]
    rng = random.Random(d["index"]); xs = list(range(10, tw - 10)); rng.shuffle(xs)
    for x in xs:
        if any(abs(x - u) < 14 for u in used) or abs(x - d["entry_tile"]) < 8 or abs(x - d["exit_tile"]) < 8: continue
        y0 = 3 if first else ct       # beam rows 3-4 in the open sky / stub from the ceiling
        anchor = y0 + (2 if first else 3)
        L = 0
        while anchor + L < th - 9 and all(k[anchor + L][xx] == 0 for xx in (x - 1, x, x + 1)) and L < 14: L += 1
        if L < 8: continue
        # try it: add the stub, make sure the room still passes
        saved = [row[:] for row in k]
        for yy in range(y0, anchor):
            for xx in range(x - (2 if first else 1), x + (3 if first else 2)): k[yy][xx] = 2 if first else 1
        ok, _ = wg.check(r, 1.0, False)
        if not ok:
            r.kind[:] = saved; continue
        d["tiles"] = ["".join(str(v) for v in row) for row in k]
        d["ropes"].append([x * T + 4, anchor * T, L * T, kind]); used.append(x)
        if len(d["ropes"]) >= want: break
    json.dump(d, open(f, "w")); print(os.path.basename(f), len(d["ropes"]), "ropes")
