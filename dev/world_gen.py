"""Generates every room and shaft of the whole descent (5 regions), proves each is traversable with the hero's abilities
at that point, measures how forgiving it is, and writes the report. Run: python3 dev/world_gen.py [region_index ...]"""
import json, math, os, random, sys, time
from multiprocessing import Pool
sys.path.insert(0, os.path.dirname(__file__))
import world_physics as wp
from overgrowth_art import Room, TILE

HW = 6  # hole width in tiles

REGIONS = [
 ("THE OVERGROWTH", "overgrowth", [  # name, screens w, h, threat 0-8, food 0-5
   ("LANDING", 1, 1, 0, 1), ("ROOFTOP GARDEN", 2, 1, 0, 1), ("CABLE SHAFT", 1, 2, 0, 1), ("GREENHOUSE", 2, 1, 1, 2),
   ("STAIRWELL", 1, 2, 1, 2), ("PIPE CATHEDRAL", 2, 2, 2, 3), ("ROOTBED", 2, 1, 3, 4), ("VINE WELL", 1, 3, 3, 3),
   ("UNDERSTORY NEST", 2, 1, 4, 5), ("RUST GATE", 1, 1, 2, 2)]),
 ("THE RUSTWORKS", "rustworks", [
   ("FOUNDRY GATE", 1, 1, 2, 1), ("CONVEYOR HALL", 2, 1, 2, 1), ("SLAG SHAFT", 1, 2, 3, 2), ("BOILER ROW", 2, 1, 3, 2),
   ("GEAR TOWER", 1, 3, 4, 2), ("PRESS FLOOR", 2, 2, 4, 3), ("COOLING PIPES", 2, 1, 5, 4), ("SCRAP WELL", 1, 2, 5, 3),
   ("FURNACE NEST", 2, 1, 6, 5), ("DROWNED GATE", 1, 1, 4, 2)]),
 ("THE DROWNED WORKS", "drowned", [
   ("FLOODED STAIRS", 1, 1, 3, 1), ("LOCK CHAMBER", 2, 1, 3, 2), ("PUMP SHAFT", 1, 2, 4, 2), ("CISTERN", 2, 2, 4, 3),
   ("SLUICE HALL", 2, 1, 5, 3), ("DRIP TOWER", 1, 3, 5, 3), ("RESERVOIR", 2, 2, 6, 4), ("SILT BED", 2, 1, 6, 5),
   ("DEEP INTAKE", 1, 2, 7, 4), ("BONE GATE", 1, 1, 5, 2)]),
 ("THE BONE STACKS", "bone", [
   ("OSSUARY GATE", 1, 1, 4, 1), ("RIB HALL", 2, 1, 4, 2), ("SPINE SHAFT", 1, 3, 5, 2), ("SKULL VAULT", 2, 2, 5, 3),
   ("CHARNEL ROW", 2, 1, 6, 3), ("GRAVE WELL", 1, 2, 6, 3), ("MARROW HALL", 2, 1, 7, 4), ("TALL CRYPT", 1, 3, 7, 4),
   ("FEEDING GROUND", 2, 2, 8, 5), ("ASH GATE", 1, 1, 6, 2)]),
 ("THE ASH DEEP", "ash", [
   ("CINDER STEPS", 1, 1, 5, 1), ("EMBER HALL", 2, 1, 5, 2), ("SOOT SHAFT", 1, 3, 6, 2), ("KILN", 2, 2, 6, 3),
   ("SLAG FIELD", 2, 1, 7, 3), ("ASH WELL", 1, 2, 7, 3), ("CHARRED NAVE", 2, 2, 8, 4), ("GLASS HALL", 2, 1, 8, 4),
   ("LAST DESCENT", 1, 3, 8, 5), ("LAKE GATE", 1, 1, 6, 3)]),
 ("THE PRISMATIC LAKE", "lake", [("PRISMATIC LAKE", 3, 2, 0, 0)]),   # authored by dev/make_lake.py, not generated
]
N_ROOMS = sum(len(r[2]) for r in REGIONS[:5])
EXTRAS = 3
REST_AT = 5       # index of the room (per region) that holds a rest point

def lerp(a, b, t): return a + (b - a) * t

def params(d):
    return dict(rise=lerp(2.6, 4.4, d), gap_max=lerp(2.0, 10.5, d), gap_min=lerp(1.0, 5.5, d),
                w_min=int(lerp(7, 3, d)), w_max=int(lerp(14, 6, d)), obst=lerp(1.5, 4.4, d), pit_w=lerp(2.0, 10.0, d))

# ------------------------------------------------------------------ construction
def hole(room, x, y0, y1, w=HW):
    room.fill(x - w // 2, y0, w, y1 - y0, 0)

def floor_profile(rng, P, tw, wl, wr, ft, clear, scale=1.0):
    top = [ft] * tw; level = 0; x = wl
    hmax = max(1, int(P["rise"] - .5))
    while x < tw - wr:
        if any(a <= x < b for a, b in clear):
            top[x] = ft; x += 1; level = 0; continue
        near_clear = min([a - x for a, b in clear if a > x] or [99])
        w = rng.random()
        pf = 0.5 - 0.3 * P["gap_max"] / 9
        if near_clear < 8: w = 0.0   # keep the approach to doors simple
        if w < pf:                                  # flat
            n = rng.randint(4, 9)
            for i in range(n):
                if x + i < tw - wr and not any(a <= x + i < b for a, b in clear): top[x + i] = ft - level
            x += n
        elif w < pf + .28:                          # step
            level = max(0, min(hmax, level + rng.choice((-1, 1)) * rng.randint(1, max(1, int(P["obst"] * scale)))))
            n = rng.randint(3, 7)
            for i in range(n):
                if x + i < tw - wr and not any(a <= x + i < b for a, b in clear): top[x + i] = ft - level
            x += n
        elif w < pf + .28 + .27 * scale:            # pit
            g = rng.randint(2, max(2, int(P["pit_w"] * scale))); pd = rng.randint(2, 3 + int(P["rise"] / 2))
            for i in range(g):
                if x + i < tw - wr - 6 and not any(a <= x + i < b for a, b in clear): top[x + i] = ft + pd
            x += g + rng.randint(2, 4)
        else:                                       # pillar
            n = rng.randint(2, 3); h = rng.randint(2, max(2, int(P["obst"]) + 1))
            for i in range(n):
                if x + i < tw - wr and not any(a <= x + i < b for a, b in clear): top[x + i] = ft - level - h
            x += n + rng.randint(2, 4)
    return top

def build_room(spec, idx, d, region_i, local_t, theme, first, rng):
    name, sw, sh, threat, food = spec
    r = Room(name, sw, sh, depth=0.04 + 0.86 * local_t, threat=threat, food=food, seed=idx * 7 + 3, theme=theme)
    tw, th = r.tw, r.th
    dirn = 1 if idx % 2 == 0 else -1
    wl = wr = 5; ct = 0 if first else 5; ft = th - 8
    x_in = wl + 10 if dirn > 0 else tw - wr - 10
    x_out = tw - wr - 10 if dirn > 0 else wl + 10
    P = params(d)
    r.rock(0, 0, wl, th); r.rock(tw - wr, 0, wr, th)
    if ct: r.rock(wl, 0, tw - wl - wr, ct)
    # --- the climbing route: ledges from the floor to the entry hole (so every room can be climbed back up)
    step = max(2, int(lerp(2.0, 3.6, d)))
    nodes = []
    if sh == 1:
        ys = []
        if ct:
            y = ct + 3
            while y < ft - step: ys.append(y); y += step
            ys.append(ft - step)
        side = 1
        for y in ys:
            nodes.append((x_in + side * 5, y, 5)); side = -side
    else:
        # tall rooms: switchback levels. Each level is a long run of ledges with jump gaps, ending at a wall where
        # a short stair (never more than `step` between ledges) leads down to the next level, which runs back the other way.
        H = step * 3 if step * 3 >= 6 else 6
        y = ct + 3 if ct else 8; side = 1 if dirn > 0 else -1   # side: direction the run travels
        while y < ft - H + 1:
            xs = wl + 2 if side > 0 else tw - wr - 2
            x = xs; end_side = tw - wr - 2 if side > 0 else wl + 2
            first = True
            while (x < end_side - 3) if side > 0 else (x > end_side + 3):
                wdt = rng.randint(P["w_min"], P["w_max"])
                g = 0 if first else rng.uniform(P["gap_min"], P["gap_max"])
                x0 = int(x + g) if side > 0 else int(x - g - wdt)
                if side > 0: x0 = min(x0, tw - wr - 2 - wdt)
                else: x0 = max(x0, wl + 2)
                dyr = 0 if first else rng.choice((-1, 0, 0, 1))
                nodes.append((x0 + wdt // 2, y + dyr, wdt))
                x = x0 + wdt if side > 0 else x0
                first = False
            # stair down at the wall we arrived at
            wall_x = (tw - wr - 2) if side > 0 else (wl + 2)
            for j in range(1, 3):
                ledge_x = wall_x - side * (3 if j % 2 else 9)
                nodes.append((ledge_x, y + j * step, 5))
            y += H
            side = -side
        yy = max(n[1] for n in nodes); j = 2
        while yy < ft - step:                     # last stair down to the floor, from the wall the last level ended at
            yy = min(yy + step, ft - step); j += 1
            nodes.append((wall_x + side * (3, 9, 15)[(j - 1) % 3], yy, 5))
    if sh > 1 and nodes:      # keep the exit hole away from where the final stair meets the floor
        last_x = max(nodes, key=lambda n: n[1])[0]
        x_out = (tw - wr - 10) if last_x < tw / 2 else (wl + 10)
    clear = [(x_in - 9, x_in + 9), (x_out - 9, x_out + 9)] + ([(last_x - 9, last_x + 9)] if (sh > 1 and nodes) else [])
    scale = 0.55 if (sh > 1 or sw * sh > 2) else 1.0
    top = floor_profile(rng, P, tw, wl, wr, ft, clear, scale)
    for x in range(wl, tw - wr):
        r.rock(x, top[x], 1, th - top[x])
    hole(r, x_out, ft - 1, th)                     # exit through the floor
    if ct: hole(r, x_in, 0, ct)                      # entry through the ceiling
    for (cx, y, w) in nodes:
        r.metal(max(wl, cx - w // 2), y, w, 2, pole_to=None)
    # --- extra decorative / alternative platforms in free air (kept clear of the climbing route)
    for _ in range(int(sw * sh * EXTRAS)):
        w = rng.randint(4, 9); x = rng.randint(wl + 3, tw - wr - w - 3); y = rng.randint(ct + 6, ft - 10)
        if all(r.kind[yy][xx] == 0 for yy in range(y - 4, y + 6) for xx in range(x - 2, x + w + 2) if 0 <= yy < th and 0 <= xx < tw):
            r.metal(x, y, w, 2, pole_to=rng.choice((None, None, ft)))
    r.meta = dict(dirn=dirn, x_in=x_in, x_out=x_out, ct=ct, ft=ft, wl=wl, wr=wr, first=first, top=top)
    # ground-pound pocket (regions 2+): cracked floor tiles over a hidden food stash
    if region_i >= 1:
        for x in range(wl + 4, tw - wr - 6):
            if all(top[x + i] == ft for i in range(6)) and not any(a - 2 <= x < b + 2 for a, b in clear):
                for i in range(4): r.kind[ft][x + 1 + i] = 3; r.cracks.append((x + 1 + i, ft))
                r.fill(x + 1, ft + 1, 4, 4, 0)
                r.pound_food = [(x * 8 + 20, (ft + 4) * 8 - 4), (x * 8 + 28, (ft + 4) * 8 - 4)]
                break
    return r

def openings(r):
    m = r.meta; ops = [(m["x_out"] - HW // 2, m["ft"] - 1, m["x_out"] + HW // 2, r.th + 4)]
    if m["first"]: ops.append((0, -40, r.tw, 0))
    else: ops.append((m["x_in"] - HW // 2, -40, m["x_in"] + HW // 2, m["ct"]))
    return ops

# ------------------------------------------------------------------ verification
def check(r, s, dj):
    m = r.meta; st = wp.Stats(s, dj); g = wp.Grid(r.kind, r.tw, r.th, openings(r)); T = wp.TILE
    exit_goal = [((m["x_out"] - 2) * T, m["ft"] * T + 6, (m["x_out"] + 2) * T, m["ft"] * T + 60)]
    if m["first"]: starts = [((m["wl"] + 4) * T, m["ft"] * T, False)]
    else: starts = [(m["x_in"] * T, (m["ct"] + 1) * T, True)]
    _, pts, got = wp.reach(g, st, starts, exit_goal, want={0})
    if 0 not in got: return False, pts
    if not m["first"]:
        lips = []
        for tx in (m["x_out"] - HW // 2 - 1, m["x_out"] + HW // 2):
            lips.append(((tx + .5) * T, m["top"][tx] * T, False))
        entry_goal = [((m["x_in"] - 2) * T, -400, (m["x_in"] + 2) * T, m["ct"] * T - 1)]
        _, pts2, got2 = wp.reach(g, st, lips, entry_goal, want={0})
        pts = pts + pts2
        if 0 not in got2: return False, pts
    return True, pts

def margin_of(r, dj):
    ok, pts = check(r, 1.0, dj)
    if not ok: return None, pts
    best = 1.0
    for s in (0.8, 0.65, 0.5):
        ok2, _ = check(r, s, dj)
        if ok2: best = s
        else: break
    return round(1 - best, 2), pts

def target_margin(d): return 0.45 * (1 - d) ** 1.3

# ------------------------------------------------------------------ extras: food, enemies, rest
def finish(r, pts, region_i, rest, rng):
    m = r.meta; T = TILE
    vis = {(int(x) // 4, int(y) // 4) for (x, y) in pts}
    def reachable(x, y): return any((x // 4 + a, y // 4 + b) in vis for a in range(-3, 4) for b in range(-3, 4))
    # food: bulbs hanging two tiles under a platform edge or lying on the floor, only where the hero can really get to
    cand = []
    for ty in range(m["ct"] + 3, r.th - 9):
        for tx in range(m["wl"] + 2, r.tw - m["wr"] - 2):
            if r.kind[ty][tx] == 0 and r.kind[ty - 1][tx] != 0 and r.kind[ty + 1][tx] == 0 and r.kind[ty + 2][tx] == 0:
                x, y = tx * T + 4, (ty + 2) * T
                if reachable(x, y) and abs(tx - m["x_in"]) > 4: cand.append((x, y))
    rng.shuffle(cand); chosen = []
    for (x, y) in cand:
        if all(abs(x - cx) + abs(y - cy) > 80 for cx, cy in chosen): chosen.append((x, y))
        if len(chosen) >= r.food * r.sw: break
    r.food_pos = chosen
    # enemies: on reachable ground away from doors and the rest point
    ground = []
    for (x, y) in {(int(a) // 12 * 12, int(b)) for a, b in pts}:
        tx, ty = x // T, int(y) // T
        if 0 < ty < r.th - 1 and r.kind[ty][tx] != 0 and r.kind[ty - 1][tx] == 0 if (0 <= tx < r.tw and 0 < ty < r.th) else False: ground.append((x, ty * T - 8))
    rng.shuffle(ground); en = []
    cap = min(r.threat, 2 + 2 * r.sw * r.sh)
    for (x, y) in ground:
        if abs(x - m["x_in"] * T) < 120 or abs(x - m["x_out"] * T) < 120: continue
        if all(abs(x - ex) + abs(y - ey) > 110 for ex, ey, _ in en): en.append((x, y, "x"))
        if len(en) >= cap: break
    r.enemies = en
    r.marks = []
    if m["first"]: r.marks.append(("start", (m["wl"] + 4) * T, m["ft"] * T))
    else: r.marks.append(("entry", m["x_in"] * T, (m["ct"] + 2) * T))
    r.marks.append(("exit_d", m["x_out"] * T, (m["ft"] + 2) * T))
    if rest:
        rx = m["x_in"] + m["dirn"] * 6
        r.marks.append(("rest", rx * T + 4, m["ft"] * T)); r.rest_x = rx
    return r

def generate_room(args):
    idx, spec, d0, region_i, local_t, theme, first, rest, dj = args
    best = None; t0 = time.time()
    for attempt in range(45):
        d = d0 * (1.0 if attempt < 25 else 0.85 if attempt < 35 else 0.7)
        rng = random.Random(idx * 1009 + attempt * 31)
        r = build_room(spec, idx, d, region_i, local_t, theme, first, rng)
        mg, pts = margin_of(r, False)
        if mg is None: continue
        score = abs(mg - target_margin(d))
        if best is None or score < best[0]: best = (score, r, mg, pts, attempt)
        if abs(mg - target_margin(d)) <= 0.1: break
    if best is None: return dict(idx=idx, error="no traversable layout found", name=spec[0])
    _, r, mg, pts, attempt = best
    finish(r, pts, region_i, rest, random.Random(idx))
    return dict(idx=idx, room=r, margin=mg, attempts=attempt + 1, secs=round(time.time() - t0, 1))

# ------------------------------------------------------------------ corridors (vertical shafts between rooms)
def generate_corridor(args):
    idx, d, region_i, theme, dj = args
    for attempt in range(20):
        rng = random.Random(idx * 77 + attempt)
        tw, th = 14, 16
        r = Room("SHAFT %02d" % (idx + 1), 1, 1, depth=min(.9, d), threat=0, food=0, seed=idx * 5 + 1, tw=tw, th=th, theme=theme)
        r.rock(0, 0, 3, th); r.rock(11, 0, 3, th)
        step = max(2, int(lerp(2.0, 3.6, d))); side = rng.choice((-1, 1)); y = 3; ys = []
        while y < th - 1: ys.append(y); y += step
        if th - ys[-1] > step: ys.append(ys[-1] + step)
        for y in ys:
            r.metal(3 if side < 0 else 8, y, 3, 2); side = -side
        ops = [(4, -40, 10, 0), (4, th, 10, th + 40)]
        T = wp.TILE
        ok = True; best = 1.0
        for s in (1.0, 0.8, 0.65, 0.5):
            st = wp.Stats(s, dj)
            g = wp.Grid(r.kind, tw, th, ops)
            _, _, got = wp.reach(g, st, [(7 * T, 0, True)], [(4 * T, th * T + 4, 10 * T, th * T + 60)], want={0})
            kind2 = [row[:] for row in r.kind] + [[1] * 3 + [0] * 8 + [1] * 3]
            kind2[th][3:11] = [1] * 8
            g2 = wp.Grid(kind2, tw, th + 1, [(4, -40, 10, 0)])
            _, _, got2 = wp.reach(g2, st, [(7 * T, th * T, False)], [(4 * T, -400, 10 * T, 0)], want={0})
            if 0 in got and 0 in got2: best = s
            else:
                if s == 1.0: ok = False
                break
        if ok: return dict(idx=idx, room=r, margin=round(1 - best, 2))
    return dict(idx=idx, error="no traversable shaft", name="shaft")

# ------------------------------------------------------------------ world
def world_jobs(only=None):
    rooms, cors = [], []; gi = 0
    for ri, (rname, theme, specs) in enumerate(REGIONS):
        if only is not None and ri not in only: gi += len(specs); continue
        for li, spec in enumerate(specs):
            d = 0.04 + 0.9 * gi / (N_ROOMS - 1)
            rooms.append((gi, spec, d, ri, li / (len(specs) - 1), theme, gi == 0, li == REST_AT, ri >= 2))
            if not (ri == len(REGIONS) - 1 and li == len(specs) - 1):
                cors.append((gi, d, ri, theme, ri >= 2))
            gi += 1
    return rooms, cors

def freeze(rooms, cors):
    """Write the fixed world to data/world/: one JSON per room and shaft. Hand-editable, never regenerated by the game."""
    os.makedirs("data/world", exist_ok=True)
    def dump(res, kind):
        if "room" not in res: return
        r = res["room"]; m = getattr(r, "meta", {})
        data = dict(kind=kind, index=res["idx"] + 1, name=r.name, theme=r.theme, tile=TILE, tw=r.tw, th=r.th,
                    tiles=["".join(str(v) for v in row) for row in r.kind],
                    poles=[list(p) for p in r.poles], marks=[list(k) for k in r.marks], enemies=[list(e[:2]) for e in r.enemies],
                    food=[list(p) for p in (r.food_pos or [])], pound_food=[list(p) for p in r.pound_food], cracks=[list(c) for c in r.cracks],
                    margin=res["margin"], threat=r.threat, entry_tile=m.get("x_in"), exit_tile=m.get("x_out"))
        name = "%02d_%s.json" % (res["idx"] + 1, r.name.lower().replace(" ", "_")) if kind == "room" else "shaft_%02d.json" % (res["idx"] + 1)
        open("data/world/" + name, "w").write(json.dumps(data))
    for x in rooms: dump(x, "room")
    for x in cors: dump(x, "shaft")

if __name__ == "__main__":
    only = [int(a) for a in sys.argv[1:]] or None
    rj, cj = world_jobs(only)
    t0 = time.time()
    with Pool(8) as pool:
        rooms = pool.map(generate_room, rj, chunksize=1)
        cors = pool.map(generate_corridor, cj, chunksize=1)
    import pickle
    os.makedirs("dev/world", exist_ok=True)
    freeze(rooms, cors)
    pickle.dump((rooms, cors), open("dev/world/_world.pkl", "wb"))
    bad = [x for x in rooms + cors if "error" in x]
    print("rooms", len(rooms), "corridors", len(cors), "failures", len(bad), "secs", round(time.time() - t0, 1))
    for x in rooms:
        if "room" in x: print("%02d %-18s margin %.2f attempts %d %ss" % (x["idx"], x["room"].name, x["margin"], x["attempts"], x["secs"]))
        else: print(x)
