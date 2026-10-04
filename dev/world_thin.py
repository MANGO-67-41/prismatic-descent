"""One-time pass over the fixed world: removes about half the platforms in every room (only where the room still passes the
movement check, and early rooms stay forgiving), re-places food and enemies on what is left, and adds 2-3 climbable ropes or
vines per room. Edits data/world/*.json in place. Run: python3 dev/world_thin.py   then python3 dev/world_bake.py"""
import glob, json, os, random, sys, time
from multiprocessing import Pool
sys.path.insert(0, os.path.dirname(__file__))
import world_gen as wg
from world_bake import load_room

TILE = 8

def meta_for(d, r):
    tw, th = d["tw"], d["th"]; first = bool(d.get("first")); ft = th - 8; ct = 0 if first else 5
    top = []
    for x in range(tw):
        run = 0
        while run < th and r.kind[th - 1 - run][x] != 0: run += 1
        top.append(th - run)
    return dict(dirn=1, x_in=d["entry_tile"], x_out=d["exit_tile"], ct=ct, ft=ft, wl=5, wr=5, first=first, top=top)

def components(kind, tw, th):
    seen = set(); comps = []
    for y in range(th):
        for x in range(tw):
            if kind[y][x] == 2 and (x, y) not in seen:
                stack = [(x, y)]; comp = []; seen.add((x, y))
                while stack:
                    cx, cy = stack.pop(); comp.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < tw and 0 <= ny < th and kind[ny][nx] == 2 and (nx, ny) not in seen:
                            seen.add((nx, ny)); stack.append((nx, ny))
                comps.append(comp)
    return comps

def passes(r, orig_margin):
    ok, _ = wg.check(r, 1.0, False)
    if not ok: return False
    if orig_margin >= 0.2:                       # keep forgiving rooms forgiving
        ok2, _ = wg.check(r, 0.8, False)
        return ok2
    return True

def place_ropes(r, d, rng):
    m = r.meta; tw, th = r.tw, r.th; k = r.kind
    want = 2 + (1 if d["sw"] * d["sh"] >= 2 else 0)
    cands = []
    for x in range(m["wl"] + 2, tw - m["wr"] - 2):
        for y in range(max(m["ct"], 1), th - 9):
            if k[y][x] != 0 and k[y + 1][x] == 0:
                L = 0
                while y + 1 + L < th - 8 and all(k[y + 1 + L][xx] == 0 for xx in (x - 1, x, x + 1)) and L < 18: L += 1
                if L >= 8 and abs(x - m["x_in"]) > 5 and abs(x - m["x_out"]) > 5:
                    cands.append((x, y + 1, L))
    rng.shuffle(cands); cands.sort(key=lambda c: -min(c[2], 16) + rng.random() * 3)
    chosen = []
    for (x, y, L) in cands:
        if all(abs(x - cx) > 14 for cx, _, _ in chosen): chosen.append((x, y, L))
        if len(chosen) >= want: break
    kind = "vine" if d["theme"] == "overgrowth" else "rope"
    return [[x * TILE + 4, y * TILE, L * TILE, kind] for (x, y, L) in chosen]

def thin_room(path):
    d = json.load(open(path)); t0 = time.time()
    r, _ = load_room(path); r.meta = meta_for(d, r); tw, th = d["tw"], d["th"]
    orig = d.get("margin", 0); rng = random.Random(d["index"] * 17 + 5)
    ok, _ = wg.check(r, 1.0, False)
    comps = components(r.kind, tw, th); total = len(comps); removed = 0
    if ok:
        order = list(range(total)); rng.shuffle(order)
        for ci in order:
            if removed >= (total + 1) // 2 or time.time() - t0 > 150: break
            comp = comps[ci]
            for (x, y) in comp: r.kind[y][x] = 0
            if passes(r, orig): removed += 1
            else:
                for (x, y) in comp: r.kind[y][x] = 2
    # poles left hanging without their platform
    r.poles = [p for p in r.poles if r.kind[max(0, int(p[1]) // TILE - 1)][int(p[0]) // TILE] != 0 or int(p[1]) // TILE >= th - 8]
    mg, pts = wg.margin_of(r, False)
    if mg is None: return dict(path=path, error="lost traversability", removed=removed)
    rest = any(m[0] == "rest" for m in d["marks"])
    r.food = d["foodcount"]; r.threat = d["threat"]; r.sw, r.sh = d["sw"], d["sh"]; r.enemies = []; r.marks = []
    r.pound_food = [tuple(p) for p in d["pound_food"]]
    wg.finish(r, pts, 0, rest, random.Random(d["index"]))
    d["tiles"] = ["".join(str(v) for v in row) for row in r.kind]
    d["poles"] = [list(p) for p in r.poles]; d["marks"] = [list(m_) for m_ in r.marks]
    d["enemies"] = [list(e[:2]) for e in r.enemies]; d["food"] = [list(p) for p in (r.food_pos or [])]
    d["margin"] = mg; d["ropes"] = place_ropes(r, d, rng)
    open(path, "w").write(json.dumps(d))
    return dict(path=os.path.basename(path), platforms=total, removed=removed, left=total - removed, ropes=len(d["ropes"]), margin=mg, was=orig, secs=round(time.time() - t0))

if __name__ == "__main__":
    files = sorted(glob.glob("data/world/[0-9]*.json"))
    t0 = time.time()
    with Pool(8) as pool:
        for res in pool.imap_unordered(thin_room, files, chunksize=1): print(res, flush=True)
    print("done in", round(time.time() - t0), "s")
