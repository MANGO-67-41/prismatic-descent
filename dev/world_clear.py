"""One-time pass over the fixed world: clears out platforms so the rooms are easier to move through, and spreads what is left
evenly. The room is cut into cells of half a screen wide and one screen tall; a cell may keep at most CAP platforms, and the
platforms taken out are the ones in the most crowded cells, so a room that was heavy on one side ends up balanced. Cells left
empty in a room that still has platforms get one ledge. Every removal is kept only if the room still passes the movement check
(and rooms that were forgiving at 80% strength stay forgiving). Platforms that carry a rope, a mark or a prop are never taken out.
Backup of the rooms before: data/world_before_clear/. Run: python3 dev/world_clear.py [room name part ...]
then python3 dev/make_creatures.py && python3 dev/world_bake.py && python3 dev/world_verify.py"""
import glob, json, os, random, sys, time
from multiprocessing import Pool
sys.path.insert(0, os.path.dirname(__file__))
import world_gen as wg
from world_bake import load_room
from world_thin import meta_for, components
import world_even as we

T = 8
CELL_W, CELL_H = 30, 34
CAP = 2

def cell_of(comp, tw, th):
    cx = sum(p[0] for p in comp) / len(comp); cy = sum(p[1] for p in comp) / len(comp)
    return (min(max(1, tw // CELL_W) - 1, int(cx / CELL_W)), min(max(1, th // CELL_H) - 1, int(cy / CELL_H)))

def protected(comp, d):
    return we.anchors_rope(comp, d.get("ropes", [])) or we.carries_mark(comp, d) or \
        any(abs(int(p["x"]) // T - x) <= 1 and abs(int(p["y"]) // T - y) <= 1 for p in d.get("props", []) for (x, y) in comp)

def job(path):
    d = json.load(open(path)); t0 = time.time()
    r, _ = load_room(path); r.meta = meta_for(d, r); tw, th = d["tw"], d["th"]
    rng = random.Random(d["index"] * 41 + 9)
    if not wg.check(r, 1.0, False)[0]: return dict(file=os.path.basename(path), error="did not pass before")
    need80 = wg.check(r, 0.8, False)[0]
    before = len(components(r.kind, tw, th)); removed = 0; added = 0
    # take platforms out of the most crowded cell, again and again, until no cell holds more than CAP (or nothing more can go)
    skip = set()
    while time.time() - t0 < 150:
        comps = components(r.kind, tw, th); cells = {}
        for i, c in enumerate(comps): cells.setdefault(cell_of(c, tw, th), []).append(i)
        crowded = sorted(((len(v), k) for k, v in cells.items() if len(v) > CAP), reverse=True)
        progress = False
        for _, key in crowded:
            idx = [i for i in cells[key] if frozenset(comps[i]) not in skip and not protected(comps[i], d)]
            rng.shuffle(idx)
            for i in idx[:6]:
                comp = comps[i]
                for (x, y) in comp: r.kind[y][x] = 0
                if we.passes(r, need80): removed += 1; progress = True; break
                for (x, y) in comp: r.kind[y][x] = 2
                skip.add(frozenset(comp))
            if progress: break
        if not progress: break
    # an empty cell in a room that still has platforms gets one ledge
    comps = components(r.kind, tw, th); have = {cell_of(c, tw, th) for c in comps}
    nx, ny = max(1, tw // CELL_W), max(1, th // CELL_H)
    if len(comps) >= 3:
        for cy in range(ny):
            for cx in range(nx):
                if (cx, cy) in have or time.time() - t0 > 240: continue
                for (x0, y, w) in we.candidates(r, d, cx, cy, rng):
                    saved = [row[:] for row in r.kind]
                    we.place(r, x0, y, w, rng)
                    if we.passes(r, need80): added += 1; break
                    r.kind = saved
    r.poles = [p for p in r.poles if r.kind[max(0, int(p[1]) // T - 1)][int(p[0]) // T] != 0 or int(p[1]) // T >= th - 8]
    d["tiles"] = ["".join(str(v) for v in row) for row in r.kind]; d["poles"] = [list(p) for p in r.poles]
    # a rope hung from a platform that is gone would dangle (platforms carrying ropes are protected, so none should be lost)
    keep = []
    for rp in d.get("ropes", []):
        tx, ty = int(rp[0]) // T, int(rp[1]) // T
        if ty > 0 and r.kind[ty - 1][tx] != 0: keep.append(rp)
    d["ropes"] = keep
    open(path, "w").write(json.dumps(d))
    return dict(file=os.path.basename(path), before=before, removed=removed, added=added, after=len(components(r.kind, tw, th)), ropes=len(keep), secs=round(time.time() - t0))

if __name__ == "__main__":
    if not os.path.isdir("data/world_before_clear"):
        import shutil; shutil.copytree("data/world", "data/world_before_clear")
    files = [f for f in sorted(glob.glob("data/world/[0-9]*.json")) if not json.load(open(f)).get("final")]
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    if names: files = [f for f in files if any(a in f for a in names)]
    t0 = time.time(); tot_b = tot_a = 0
    with Pool(8) as pool:
        for res in pool.imap_unordered(job, files, chunksize=1):
            print(res, flush=True)
            tot_b += res.get("before", 0); tot_a += res.get("after", 0)
    print("platforms", tot_b, "->", tot_a, "in", round(time.time() - t0), "s")
