"""One-time pass over the fixed world: makes the floor of every room flat. The floor of a room is the row th - 8 (the same row the
wing doorways and the creatures' homes are cut at). Steps, pillars and humps standing on it are cut down to it, pits are filled
up to it. Left alone: the wall columns, the hole in the floor where the room lets out (and the notches round it), and the cracked
patches with their pockets underneath (they are floor that gives way, and they sit at floor level). Everything that stood on a
step (lanterns, props, doorway arches, food) is moved to the new floor; ropes are lengthened or shortened so they end the same
height above whatever is under them. Platforms (the metal ledges) are not touched. The room is kept only if it still passes the
movement check; where taking a step away breaks the climb, the step comes back as a thin ledge at its old height.
Backup of the rooms before: data/world_before_flat/. The Prismatic Lake (its cliff stair and bridge are the point of it) and the
shafts are left as they are.
Run: python3 dev/world_flat.py [room name part ...]
then python3 dev/make_creatures.py && python3 dev/world_bake.py && python3 dev/world_verify.py"""
import glob, json, os, random, sys, time
from multiprocessing import Pool
sys.path.insert(0, os.path.dirname(__file__))
import world_gen as wg
from world_bake import load_room
from world_thin import meta_for, components
import world_even as we

T = 8

def top_of(k, x, th):
    y = th
    while y > 0 and k[y - 1][x] != 0: y -= 1
    return y

def first_solid_below(k, x, y, th):
    while y < th and k[y][x] == 0: y += 1
    return y

def job(path):
    d = json.load(open(path)); t0 = time.time()
    if d.get("kind") != "room" or d.get("final"):
        return dict(file=os.path.basename(path), skipped=True)
    r, _ = load_room(path); r.meta = meta_for(d, r); tw, th = d["tw"], d["th"]
    ft = th - 8
    rng = random.Random(d["index"] * 53 + 5)
    if not wg.check(r, 1.0, False)[0]: return dict(file=os.path.basename(path), error="did not pass before")
    need80 = wg.check(r, 0.8, False)[0]
    old = [row[:] for row in r.kind]
    k = r.kind
    xo = int(d["exit_tile"])
    protect = set(range(xo - 7, xo + 7))                                   # the exit hole and its notches
    for c in d.get("cracks", []):
        protect.update(range(int(c[0]) - 1, int(c[0]) + 2))                # cracked patches and their pockets
    old_top = {}; cut = filled = 0
    for x in range(5, tw - 5):
        if x in protect: continue
        top = top_of(old, x, th); old_top[x] = top
        if top < ft:                                                       # a step, pillar or hump: cut it down
            for y in range(top, ft):
                if k[y][x] in (1, 3):
                    k[y][x] = 0; cut += 1
        elif top > ft:                                                     # a pit: fill it
            fill = k[ft][x - 1] if x > 5 and k[ft][x - 1] in (1, 2) else 1
            for y in range(ft, top):
                k[y][x] = 1; filled += 1
    # a metal ledge lying right on the floor reads as a step too: take it out (unless it is part of the exit's protected stretch)
    for comp in components(k, tw, th):
        if any(yy == ft - 1 and xx not in protect for (xx, yy) in comp):
            for (xx, yy) in comp: k[yy][xx] = 0; cut += 1
    # things that stood on the old surface go to the new one
    def shift(x_px, y_px):
        x = int(x_px) // T
        if x not in old_top: return y_px
        top = old_top[x]
        if top != ft and abs(int(y_px) - top * T) <= 2 * T:
            return int(y_px) + (ft - top) * T
        return y_px
    d["marks"] = [m if m[0] in ("entry", "exit_d") else [m[0], m[1], shift(m[1], m[2])] + list(m[3:]) for m in d["marks"]]
    d["food"] = [[p[0], shift(p[0], p[1])] + list(p[2:]) for p in d.get("food", [])]
    d["pound_food"] = [[p[0], shift(p[0], p[1])] + list(p[2:]) for p in d.get("pound_food", [])]
    d["deco"] = [dict(e, y=shift(e["x"], e["y"])) if "x" in e and "y" in e else e for e in d.get("deco", [])]
    d["props"] = [dict(e, y=shift(e["x"], e["y"])) if "x" in e and "y" in e else e for e in d.get("props", [])]
    d["enemies"] = [[e[0], shift(e[0], e[1])] + list(e[2:]) for e in d.get("enemies", [])]
    ropes = []
    for rp in d.get("ropes", []):
        tx, by = int(rp[0]) // T, (int(rp[1]) + int(rp[2])) // T
        if 0 <= tx < tw:
            a = first_solid_below(old, tx, min(th - 1, by), th); b = first_solid_below(k, tx, min(th - 1, by), th)
            rp = [rp[0], rp[1], max(16, int(rp[2]) + (b - a) * T)] + list(rp[3:])
        ropes.append(rp)
    d["ropes"] = ropes
    added = 0; weaker = False
    # a step may have been what a high ledge was reached from: if the room no longer passes, the steps come back as thin ledges at
    # their old height (the floor under them stays flat), tallest first, until it does. Filling a pit can cost a wall jump that
    # made a room forgiving at 80% strength: if no ledges bring that back the room is kept as long as it passes at full strength.
    def settled(need):
        nonlocal added
        if we.passes(r, need): return True
        bumps = []; x = 5
        while x < tw - 5:
            t = old_top.get(x, ft)
            if t < ft:
                x1 = x
                while x1 + 1 < tw - 5 and old_top.get(x1 + 1, ft) == t: x1 += 1
                bumps.append((ft - t, x1 - x + 1, x, x1, t))
                x = x1 + 1
            else: x += 1
        base = [row[:] for row in r.kind]
        for n in range(1, len(bumps) + 1):
            r.kind = [row[:] for row in base]
            for (_, _, x0, x1, t) in sorted(bumps, reverse=True)[:n]:
                for xx in range(x0, x1 + 1): r.kind[t][xx] = 2
            if we.passes(r, need):
                added = n
                return True
        r.kind = base
        return False
    ok = settled(need80)
    if not ok and need80:
        ok = settled(False); weaker = ok
    if ok:
        d["tiles"] = ["".join(str(v) for v in row) for row in r.kind]
        open(path, "w").write(json.dumps(d))
    return dict(file=os.path.basename(path), cut=cut, filled=filled, ledges=added, ok=ok, weaker=weaker, secs=round(time.time() - t0))

if __name__ == "__main__":
    if not os.path.isdir("data/world_before_flat"):
        import shutil; shutil.copytree("data/world", "data/world_before_flat")
    files = [f for f in sorted(glob.glob("data/world/[0-9]*.json"))]
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    if names: files = [f for f in files if any(a in f for a in names)]
    t0 = time.time(); bad = []
    with Pool(8) as pool:
        for res in pool.imap_unordered(job, files, chunksize=1):
            print(res, flush=True)
            if res.get("ok") is False or "error" in res: bad.append(res["file"])
    print("rooms that could not be flattened and keep their floor:", bad or "none", "in", round(time.time() - t0), "s")
