"""Places the creatures in the fixed world. Every main room keeps the number of enemy spots the world generator gave it
(more the deeper you go: 18, 28, 32, 46, 51 per region) and each spot gets one of its region's four creatures, chosen so that
a region's harder creatures only show up further into it. The spot is then fitted to the creature: walkers stand on the floor,
fliers hover above it, hangers hang from the ceiling, eels swim in the flooded floor, worms wait under it. Key chambers past
the first region get one flier. No creatures in the first room, the shafts, the temples, the ruin halls or the lake.
Writes "creatures": [{"t", "x", "y", ...}] into data/world/*.json. Run: python3 dev/make_creatures.py then python3 dev/world_bake.py"""
import glob, json, random

T = 8
ORDER = [["sprout_lizard", "moss_lizard", "bloom_lizard", "bark_lizard"],
         ["spark_lizard", "carrion_kite", "furnace_hound", "slag_lizard"],
         ["drip_lizard", "lure_angler", "mire_lizard", "tide_leviathan"],
         ["pale_lizard", "crypt_lizard", "bone_vulture", "marrow_worm"],
         ["ash_wyrm", "cinder_lizard", "ember_vulture", "soot_wraith"]]
# where it lives, and how much room it needs: (span of flat floor in tiles, headroom in tiles) or (air box w, h)
ARCH = {"sprout_lizard": ("ground", 5, 3), "moss_lizard": ("ground", 7, 3), "bloom_lizard": ("ground", 7, 3), "bark_lizard": ("ground", 7, 3),
        "spark_lizard": ("ground", 7, 3), "carrion_kite": ("air", 9, 6), "furnace_hound": ("ground", 10, 5), "slag_lizard": ("ground", 7, 3),
        "drip_lizard": ("ground", 7, 3), "lure_angler": ("water", 14, 0), "mire_lizard": ("ground", 7, 3), "tide_leviathan": ("water", 16, 0),
        "pale_lizard": ("ground", 7, 3), "crypt_lizard": ("ground", 7, 3), "bone_vulture": ("air", 13, 9), "marrow_worm": ("under", 18, 12),
        "ash_wyrm": ("air", 11, 7), "cinder_lizard": ("ground", 7, 3), "ember_vulture": ("air", 13, 9), "soot_wraith": ("ground", 14, 6)}

def grid(d): return [[int(c) for c in row] for row in d["tiles"]]

def floor_top(k):
    th, tw = len(k), len(k[0])
    for ty in range(th - 1, 0, -1):
        if sum(1 for v in k[ty] if v) > tw * .5 and not sum(1 for v in k[ty - 1] if v) > tw * .5:
            return ty
    return th - 5

def down_to_floor(k, tx, ty):
    th = len(k)
    while ty < th and k[ty][tx] == 0: ty += 1
    return ty if ty < th else None

def clear(k, x0, x1, y0, y1):
    th, tw = len(k), len(k[0])
    return all(0 <= x < tw and 0 <= y < th and k[y][x] == 0 for x in range(x0, x1 + 1) for y in range(y0, y1 + 1))

def span_at(k, tx, fy, head):
    """The run of flat floor through column tx on floor row fy with `head` clear tiles above: (left, right) or None."""
    tw = len(k[0])
    def ok(x): return 0 <= x < tw and k[fy][x] != 0 and all(k[y][x] == 0 for y in range(max(0, fy - head), fy))
    if not ok(tx): return None
    l = tx
    while ok(l - 1): l -= 1
    r = tx
    while ok(r + 1): r += 1
    return (l, r)

def fit(kind, k, px, py, d, rng):
    """Turns a spot into a place this creature can really live (enough floor to walk, air to fly, ceiling to hang from), or None."""
    tw, th = len(k[0]), len(k)
    tx = max(6, min(tw - 7, int(px) // T)); ty = max(5, min(th - 2, int(py) // T))
    where, a, b = ARCH[kind]
    fy = down_to_floor(k, tx, ty)
    if fy is None: return None
    if where in ("ground", "under", "water"):
        sp = span_at(k, tx, fy, b if where == "ground" else 6)
        if sp is None or sp[1] - sp[0] + 1 < a: return None
        x = max(sp[0] + a // 2, min(sp[1] - a // 2, tx))
        e = {"t": kind, "x": x * T + 4, "y": fy * T}
        if where in ("water", "under"):
            ft = floor_top(k)
            if abs(fy - ft) > 1: return None
        if where == "water":
            level = ft * T - 44
            e.update(y=(level + ft * T) // 2 + 4, wy=level, fy=ft * T)
        return e
    if where == "air":
        y = fy - rng.randint(b // 2 + 3, b // 2 + 6)
        if not clear(k, tx - a // 2, tx + a // 2, y - b // 2, y + b // 2): return None
        return {"t": kind, "x": tx * T + 4, "y": y * T + 4}
    if where == "hang":
        y = ty
        while y > 0 and k[y][tx] == 0: y -= 1
        if fy - y < b or ty - y > 20: return None
        if not clear(k, tx - 1, tx + 1, y + 1, y + b - 2): return None
        return {"t": kind, "x": tx * T + 4, "y": (y + 1) * T + 26}
    return None

def pick(region, t, rng):
    pool = ORDER[region]
    allowed = [i for i in range(4) if t >= i * 0.18]
    weights = [1.0 + 2.5 * t * i for i in allowed]
    return pool[rng.choices(allowed, weights)[0]]

def candidates(kind, k, d, rng):
    """Every place in the room where this creature fits, one per stretch of floor (or column of air, or ceiling)."""
    tw, th = len(k[0]), len(k)
    out = []; seen = set()
    for x in range(6, tw - 6, 3):
        for y in range(5, th - 1):
            if k[y][x] != 0 and k[y - 1][x] == 0:          # a floor surface at (x, y)
                e = fit(kind, k, x * T + 4, (y - 2) * T, d, rng)
                if e is None: continue
                key = (e["x"] // (6 * T), e["y"] // (4 * T))
                if key in seen: continue
                seen.add(key); out.append(e)
    return out

def main():
    total = {}
    for f in sorted(glob.glob("data/world/[0-9]*.json")):
        d = json.load(open(f))
        d["creatures"] = []
        if d.get("first") or d.get("final"):
            json.dump(d, open(f, "w")); continue
        region = (d["index"] - 1) // 10; t = ((d["index"] - 1) % 10) / 9.0
        k = grid(d); rng = random.Random(d["index"] * 101 + 3)
        keep_away = [d["entry_tile"] * T] + [m[1] for m in d["marks"] if m[0] in ("rest", "start")] + [p["x"] for p in d.get("props", [])]
        cands = {kind: [e for e in candidates(kind, k, d, rng) if all(abs(e["x"] - a) >= 7 * T for a in keep_away)] for kind in ORDER[region]}
        allowed = [i for i in range(4) if t >= i * 0.18]
        for _ in d["enemies"]:
            # every kind that still fits somewhere in the room, weighted toward the harder ones deeper in the region and
            # toward kinds the world has seen less of, so all four of a region turn up
            options = []
            for i in allowed:
                kind = ORDER[region][i]
                if sum(1 for c in d["creatures"] if c["t"] == kind) >= max(2, (len(d["enemies"]) + 1) // 2): continue
                if ARCH[kind][0] in ("water", "under") and any(c["t"] == kind for c in d["creatures"]): continue   # one leviathan or worm per room
                pool = [e for e in cands[kind] if all(abs(e["x"] - c["x"]) >= 7 * T or abs(e["y"] - c["y"]) >= 5 * T for c in d["creatures"])]
                if pool: options.append((kind, pool, (1.0 + 2.5 * t * i) / (1.0 + 0.35 * total.get(kind, 0))))
            if not options: continue
            kind, pool, _w = rng.choices(options, [o[2] for o in options])[0]
            e = rng.choice(pool)
            d["creatures"].append(e); total[kind] = total.get(kind, 0) + 1
        json.dump(d, open(f, "w"))
    for f in sorted(glob.glob("data/world/wing_*.json")):
        d = json.load(open(f)); d["creatures"] = []
        region = int(f.split("_")[1]) - 1
        if d["wing_kind"] == "key" and region >= 1:
            k = grid(d); rng = random.Random(region * 7 + 1)
            for kind in ORDER[region]:
                if ARCH[kind][0] not in ("air", "hang"): continue
                c = candidates(kind, k, d, rng)
                if c:
                    d["creatures"].append(c[len(c) // 2]); total[kind] = total.get(kind, 0) + 1
                    break
        json.dump(d, open(f, "w"))
    by_region = [sum(total.get(c, 0) for c in row) for row in ORDER]
    print("placed", sum(total.values()), "creatures; per region", by_region)
    for row in ORDER: print("  ", {c: total.get(c, 0) for c in row})

if __name__ == "__main__":
    main()
