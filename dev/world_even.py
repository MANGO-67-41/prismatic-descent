"""One-time pass over the fixed world: thins the chunky two-tile platforms (most become one tile thick, the rest keep a
ragged, tapered underside) and evens out rooms whose platforms all sit on one side, by adding a few ledges in the empty
part of the room and taking the same number out of the crowded part. Every change is kept only if the room still passes
the movement check (and rooms that were forgiving at 80% strength stay forgiving). Ropes hanging from a thinned platform
are lengthened so they still reach it. Edits data/world/*.json in place (backup in data/world_before_even/).
Run: python3 dev/world_even.py [--even-only]   (run twice with --even-only for a second, higher tier)   then python3 dev/world_bake.py && python3 dev/world_verify.py"""
import glob, json, os, random, sys, time
from multiprocessing import Pool
sys.path.insert(0, os.path.dirname(__file__))
import world_gen as wg
from world_bake import load_room
from world_thin import meta_for, components

T = 8
CELL_W, CELL_H = 30, 34          # half a screen wide, one screen tall
NEAR_OPENING = 6                 # keep the drop-in and drop-out columns clear

def passes(r, need80):
    ok, _ = wg.check(r, 1.0, False)
    if not ok or not need80: return ok
    return wg.check(r, 0.8, False)[0]

def comp_info(comp):
    xs = [p[0] for p in comp]; ys = [p[1] for p in comp]
    return min(xs), max(xs), min(ys), max(ys)

def rope_cols(ropes):
    return [(int(rp[0]) // T, int(rp[1]) // T, (int(rp[1]) + int(rp[2])) // T) for rp in ropes]

def anchors_rope(comp, ropes):
    cells = set(comp)
    return any((x, y0 - 1) in cells for (x, y0, _) in rope_cols(ropes))

def carries_mark(comp, d):
    tops = {(x, y) for (x, y) in comp if (x, y - 1) not in set(comp)}
    pts = [m[1:3] for m in d["marks"]] + [e[:2] for e in d["enemies"]]
    return any((int(px) // T, int(py) // T) in tops or (int(px) // T, int(py) // T + 1) in tops for px, py in pts)

def thin(r, d, rng, need80):
    """Two-tile slabs become one tile, or keep a shorter, uneven underside; a slab the route leans on (a wall to jump
    off, say) is left alone. Returns how many changed."""
    changed = 0
    for comp in components(r.kind, r.tw, r.th):
        x0, x1, y0, y1 = comp_info(comp)
        if y1 - y0 != 1 or len(comp) != 2 * (x1 - x0 + 1): continue      # only plain rectangular slabs
        w = x1 - x0 + 1; roll = rng.random()
        if roll < 0.6 or w < 5: keep = []                                  # one tile thick
        else:                                                              # tapered underside, off-centre
            a = rng.randint(1, 2); b = rng.randint(1, 3) if rng.random() < .5 else rng.randint(0, 1)
            if rng.random() < .5: a, b = b, a
            keep = list(range(x0 + a, x1 + 1 - b))
            if len(keep) < 2: keep = []
        gone = [x for x in range(x0, x1 + 1) if x not in keep]
        for x in gone: r.kind[y1][x] = 0
        if passes(r, need80): changed += 1
        else:
            for x in gone: r.kind[y1][x] = 2
    return changed

def fix_ropes(r, ropes):
    out = []
    for rp in ropes:
        tx, ty = int(rp[0]) // T, int(rp[1]) // T
        y = ty
        while y > 0 and r.kind[y - 1][tx] == 0: y -= 1
        out.append([rp[0], y * T, rp[2] + (ty - y) * T] + list(rp[3:]))
    return out

def cells_of(r, comps):
    m = r.meta; cells = {}
    for ci, comp in enumerate(comps):
        x0, x1, y0, _ = comp_info(comp)
        key = (min(r.tw // CELL_W - 1, ((x0 + x1) // 2) // CELL_W), min(r.th // CELL_H - 1, y0 // CELL_H))
        cells.setdefault(key, []).append(ci)
    return cells

def floor_below(r, x, y):
    """Row of the first solid tile under (x, y)."""
    while y < r.th and r.kind[y][x] == 0: y += 1
    return y

def candidates(r, d, cx, cy, rng):
    m = r.meta; out = []
    ropes = rope_cols(d.get("ropes", []))
    cracks = {int(c[0]) // T for c in d.get("cracks", [])}
    xa = max(m["wl"] + 2, cx * CELL_W + 2); xb = min(r.tw - m["wr"] - 2, (cx + 1) * CELL_W - 2)
    ya = max(m["ct"] + 5, cy * CELL_H + 4); yb = min(r.th - 4, (cy + 1) * CELL_H - 2)
    for _ in range(400):
        w = rng.randint(3, 6); x0 = rng.randint(xa, max(xa, xb - w)); y = rng.randint(ya, max(ya, yb))
        cols = range(x0, x0 + w)
        if any(abs(c - m["x_in"]) <= NEAR_OPENING or abs(c - m["x_out"]) <= NEAR_OPENING for c in cols): continue
        if any(c in cracks for c in range(x0 - 2, x0 + w + 2)): continue
        if any(x0 - 2 <= rx <= x0 + w + 1 and ry0 - 1 <= y <= ry1 + 1 for (rx, ry0, ry1) in ropes): continue
        if any(r.kind[yy][xx] != 0 for yy in range(y - 5, y + 3) for xx in range(x0 - 2, x0 + w + 2)
               if 0 <= yy < r.th and 0 <= xx < r.tw): continue
        near = [xx for xx in range(x0 - 3, x0 + w + 3) if 0 <= xx < r.tw]
        drop = min(floor_below(r, xx, y + 1) for xx in near) - y        # how far above a surface it can be jumped from
        if not 4 <= drop <= 6: continue
        out.append((x0, y, w))
    rng.shuffle(out)
    return out[:8]

def place(r, x0, y, w, rng):
    for x in range(x0, x0 + w): r.kind[y][x] = 2
    if w >= 5 and rng.random() < .4:                                       # a little ragged underside
        a = rng.randint(1, 2); b = rng.randint(1, 2)
        for x in range(x0 + a, x0 + w - b): r.kind[y + 1][x] = 2

def even(r, d, rng, need80, t0):
    added = []; removed = 0
    comps = components(r.kind, r.tw, r.th); cells = cells_of(r, comps)
    ncx, ncy = max(1, r.tw // CELL_W), max(1, r.th // CELL_H)
    for cy in range(ncy):
        row = [len(cells.get((cx, cy), [])) for cx in range(ncx)]
        busiest = max(row)
        if busiest < 3: continue
        for cx in range(ncx):
            if row[cx] > busiest // 4 or time.time() - t0 > 240: continue
            want = 2
            got = 0
            for (x0, y, w) in candidates(r, d, cx, cy, rng):
                saved = [row_[:] for row_ in r.kind]
                place(r, x0, y, w, rng)
                if passes(r, need80): got += 1; added.append((cx, cy, x0, y, w))
                else: r.kind = saved
                if got: break
            if got and want > 1:                                       # a second ledge, stacked: a little climb
                _, cy_, x0, y, w = added[-1]
                for (nx, ny, nw) in candidates(r, d, cx, cy, rng):
                    if not (abs(ny - (y - 5)) <= 1 and 4 <= abs(nx - x0) <= 10): continue
                    saved = [row_[:] for row_ in r.kind]
                    place(r, nx, ny, nw, rng)
                    if passes(r, need80): added.append((cx, cy, nx, ny, nw)); break
                    r.kind = saved
    # take as many back out of the crowded cells
    ropes = d.get("ropes", [])
    for _ in range(len(added)):
        if time.time() - t0 > 300: break
        comps = components(r.kind, r.tw, r.th); cells = cells_of(r, comps)
        newcells = {(a[2], a[3]) for a in added}
        crowd = sorted(cells.items(), key=lambda kv: -len(kv[1]))
        done = False
        for key, idxs in crowd:
            if len(idxs) < 3: break
            order = idxs[:]; rng.shuffle(order)
            for ci in order:
                comp = comps[ci]
                if anchors_rope(comp, ropes) or carries_mark(comp, d): continue
                if any((x, y) in newcells for (x, y) in comp): continue
                for (x, y) in comp: r.kind[y][x] = 0
                if passes(r, need80): removed += 1; done = True; break
                for (x, y) in comp: r.kind[y][x] = 2
            if done: break
        if not done: break
    return added, removed

def job(path):
    d = json.load(open(path)); t0 = time.time()
    r, _ = load_room(path); r.meta = meta_for(d, r)
    rng = random.Random(d["index"] * 31 + 7)
    ok = wg.check(r, 1.0, False)[0]
    if not ok: return dict(file=os.path.basename(path), error="did not pass before")
    need80 = wg.check(r, 0.8, False)[0]
    n_thin = 0 if EVEN_ONLY else thin(r, d, rng, need80)
    ropes = fix_ropes(r, d.get("ropes", []))
    d["ropes"] = ropes
    added, removed = even(r, d, rng, need80, t0)
    r.poles = [p for p in r.poles if r.kind[max(0, int(p[1]) // T - 1)][int(p[0]) // T] != 0 or int(p[1]) // T >= r.th - 8]
    d["tiles"] = ["".join(str(v) for v in row) for row in r.kind]
    d["poles"] = [list(p) for p in r.poles]
    open(path, "w").write(json.dumps(d))
    return dict(file=os.path.basename(path), thinned=n_thin, added=len(added), removed=removed, need80=need80, secs=round(time.time() - t0))

EVEN_ONLY = "--even-only" in sys.argv

if __name__ == "__main__":
    files = [f for f in sorted(glob.glob("data/world/[0-9]*.json")) if not json.load(open(f)).get("final")]
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    if names: files = [f for f in files if any(a in f for a in names)]
    t0 = time.time()
    with Pool(8) as pool:
        for res in pool.imap_unordered(job, files, chunksize=1): print(res, flush=True)
    print("done in", round(time.time() - t0), "s")
