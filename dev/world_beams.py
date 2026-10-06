"""One-time pass over the fixed world: grows a few very thin beams (tile kind 4, 4 px thick, with hanging moss) out of
walls and cliff faces, in the emptiest parts of each room. A beam is kept only if the room still passes the movement
check with the beam counted as a full solid tile (the simulator is conservative: the real beam is thinner), so beams
are extras and never required. The opening room is left alone. Edits data/world/*.json in place (backup in data/world_before_beams/).
Run: python3 dev/world_beams.py   then python3 dev/world_bake.py && python3 dev/world_verify.py"""
import glob, json, os, random, sys, time
from multiprocessing import Pool
sys.path.insert(0, os.path.dirname(__file__))
import world_gen as wg
from world_bake import load_room
from world_thin import meta_for

T = 8
SPACING = 14        # tiles between a new beam and the nearest platform or beam
SOLID = (1, 2, 3)

def candidates(r, d, rng):
    m = r.meta; k = r.kind; out = []
    ropes = [(int(rp[0]) // T, int(rp[1]) // T, (int(rp[1]) + int(rp[2])) // T) for rp in d.get("ropes", [])]
    cracks = {int(c[0]) // T for c in d.get("cracks", [])}
    pts = [(int(m_[1]) // T, int(m_[2]) // T) for m_ in d["marks"]] + [(int(e[0]) // T, int(e[1]) // T) for e in d["enemies"]]
    have = [(x, y) for y in range(r.th) for x in range(r.tw) if k[y][x] in (2, 4)]
    rows = range(max(m["ct"] + 6, 8), r.th - 12)
    for y in rows:
        for x in range(2, r.tw - 2):
            if k[y][x] != 0: continue
            L = rng.randint(3, 5)
            if k[y][x - 1] in SOLID and x + L < r.tw - 2: out.append((list(range(x, x + L)), y, x - 1))        # grows rightwards
            if k[y][x + 1] in SOLID and x - L + 1 >= 2: out.append((list(range(x - L + 1, x + 1)), y, x + 1))  # grows leftwards
    good = []
    for xs, y, wall in out:
        # the face it grows from must run well above and below it, and the space around the beam must be open
        if any(k[yy][wall] not in SOLID for yy in range(y - 2, y + 3)): continue
        if any(k[yy][xx] != 0 for yy in range(y - 4, y + 5) for xx in range(xs[0] - 1, xs[-1] + 2) if xx != wall): continue
        if any(abs(xx - m["x_in"]) <= wg.HW // 2 + 2 or abs(xx - m["x_out"]) <= wg.HW // 2 + 2 for xx in xs): continue
        if any(xx in cracks for xx in range(xs[0] - 2, xs[-1] + 3)): continue
        if any(xs[0] - 2 <= rx <= xs[-1] + 2 and ry0 - 2 <= y <= ry1 + 1 for (rx, ry0, ry1) in ropes): continue
        if any(xs[0] - 2 <= px <= xs[-1] + 2 and y - 4 <= py <= y + 3 for (px, py) in pts): continue
        cx = (xs[0] + xs[-1]) / 2
        dist = min([((cx - px) ** 2 + ((y - py) * 1.6) ** 2) ** .5 for px, py in have] or [99])
        if dist < SPACING: continue
        good.append((dist + rng.random() * 4, xs, y))
    good.sort(key=lambda g: -g[0])
    return good

def job(path):
    d = json.load(open(path)); t0 = time.time()
    r, _ = load_room(path); r.meta = meta_for(d, r)
    rng = random.Random(d["index"] * 53 + 11)
    if not wg.check(r, 1.0, False)[0]: return dict(file=os.path.basename(path), error="did not pass before")
    need80 = wg.check(r, 0.8, False)[0]
    want = 2 if r.tw * r.th <= 2100 else 3 if r.tw * r.th <= 4200 else 4
    added = []
    for _ in range(want):
        if time.time() - t0 > 200: break
        for _, xs, y in candidates(r, d, rng)[:12]:
            for x in xs: r.kind[y][x] = 4
            ok = wg.check(r, 1.0, False)[0] and (not need80 or wg.check(r, 0.8, False)[0])
            if ok: added.append((xs[0], y, len(xs))); break
            for x in xs: r.kind[y][x] = 0
    d["tiles"] = ["".join(str(v) for v in row) for row in r.kind]
    open(path, "w").write(json.dumps(d))
    return dict(file=os.path.basename(path), beams=len(added), want=want, secs=round(time.time() - t0))

if __name__ == "__main__":
    files = [f for f in sorted(glob.glob("data/world/[0-9]*.json")) if not json.load(open(f)).get("final") and not json.load(open(f)).get("first")]
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    if names: files = [f for f in files if any(a in f for a in names)]
    t0 = time.time()
    with Pool(8) as pool:
        for res in pool.imap_unordered(job, files, chunksize=1): print(res, flush=True)
    print("done in", round(time.time() - t0), "s")
