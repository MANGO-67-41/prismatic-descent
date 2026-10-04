"""For each room or junction that cannot be climbed back up, tries small variants of the hole notches and an entry perch
under the ceiling hole, and keeps the first variant where the room itself AND both junctions it belongs to pass.
Edits data/world/*.json. Run: python3 dev/world_fix_junctions.py   then python3 dev/world_bake.py"""
import glob, json, os, sys, itertools
sys.path.insert(0, os.path.dirname(__file__))
import world_gen as wg, world_physics as wp
from overgrowth_art import Room
from world_thin import meta_for
import world_junctions as wj
T = 8

def room_from(d):
    r = Room(d["name"], d["sw"], d["sh"], d["depth"], d["threat"], d["foodcount"], d["seed"], tw=d["tw"], th=d["th"], theme=d["theme"])
    r.kind = [[int(c) for c in row] for row in d["tiles"]]; r.meta = meta_for(d, r); return r

def room_ok(d):
    return wg.check(room_from(d), 1.0, False)[0]

def set_tiles(d, cells, v):
    k = [list(row) for row in d["tiles"]]
    for (x, y) in cells:
        if 0 <= y < len(k) and 0 <= x < len(k[0]): k[y][x] = v
    d["tiles"] = ["".join(row) for row in k]

def ceiling_variants(d):
    """Lower room: notches inside the ceiling hole and a perch under it."""
    xi = d["entry_tile"]; base = json.loads(json.dumps(d))
    hole = [(x, y) for y in range(0, 5) for x in range(xi - 3, xi + 3)]
    notch_sets = [[], [(xi - 3, 4), (xi - 2, 4)], [(xi + 1, 1), (xi + 2, 1)], [(xi + 1, 4), (xi + 2, 4), (xi - 3, 1), (xi - 2, 1)],
                  [(xi - 3, 4), (xi - 2, 4), (xi + 1, 1), (xi + 2, 1)]]
    perches = [[], [(x, y) for x in range(xi - 8, xi - 3) for y in (8, 9)], [(x, y) for x in range(xi + 3, xi + 8) for y in (8, 9)],
               [(x, y) for x in range(xi - 1, xi + 3) for y in (9, 10)], [(x, y) for x in range(xi - 3, xi + 1) for y in (9, 10)]]
    for ns, pc in itertools.product(notch_sets, perches):
        v = json.loads(json.dumps(base)); set_tiles(v, hole, "0"); set_tiles(v, ns, "1")
        if pc and all(v["tiles"][y][x] == "0" for (x, y) in pc): set_tiles(v, pc, "2")
        elif pc: continue
        yield v

def floor_variants(d):
    xo = d["exit_tile"]; th = d["th"]; base = json.loads(json.dumps(d))
    hole = [(x, y) for y in range(th - 8, th) for x in range(xo - 3, xo + 3)]
    L, R = xo - 3, xo + 1
    sets = [[(L, th - 1), (R, th - 4), (L, th - 7)], [(R, th - 1), (L, th - 4), (R, th - 7)], [(L, th - 2), (R, th - 5)], [(R, th - 2), (L, th - 5)], []]
    for st in sets:
        v = json.loads(json.dumps(base)); set_tiles(v, hole, "0")
        set_tiles(v, [c for (x, y) in st for c in ((x, y), (x + 1, y))], "1")
        yield v

def main():
    pieces = wj.load(); files = [p["src"] for p in pieces]
    data = {f: json.load(open(f)) for f in files}
    def junction_ok(i):
        for k in range(3): pieces[i + k]["_tiles"] = data[files[i + k]]["tiles"]
        return wj_check(pieces, i)
    res = json.load(open("dev/world/_junctions.json"))
    bad_j = [r["junction"] for r in res if not (r["up"] and r["down"])]
    bad_rooms = [f for f in files if "shaft_" not in f and not room_ok(data[f])]
    todo = sorted(set(bad_j + [files.index(f) - 2 for f in bad_rooms if files.index(f) >= 2]))
    print("fixing junctions", todo)
    for i in todo:
        A, C = files[i], files[i + 2]; fixed = False
        for vc in ceiling_variants(data[C]):
            if not room_ok(vc): continue
            for va in floor_variants(data[A]):
                if not room_ok(va): continue
                old_a, old_c = data[A], data[C]; data[A], data[C] = va, vc
                ok = junction_ok(i) and (i + 2 in todo or i + 4 >= len(files) or junction_ok(i + 2)) and (i - 2 in todo or i < 2 or junction_ok(i - 2))
                if ok: fixed = True; break
                data[A], data[C] = old_a, old_c
            if fixed: break
        print("junction", i, data[A]["name"], "->", data[C]["name"], "fixed" if fixed else "NOT FIXED", flush=True)
    for f in files: json.dump(data[f], open(f, "w"))

def wj_check(pieces, i):
    trio = pieces[i:i + 3]
    x0 = min(p["x"] for p in trio) // T; x1 = max(p["x"] + p["w"] for p in trio) // T
    y0 = trio[0]["y"] // T; y1 = (trio[2]["y"] + trio[2]["h"]) // T
    W, H = x1 - x0, y1 - y0; grid = [[1] * W for _ in range(H)]
    for p in trio:
        k = [[int(c) for c in row] for row in p["_tiles"]]; ox, oy = p["x"] // T - x0, p["y"] // T - y0
        for ty, row in enumerate(k):
            for tx, v in enumerate(row): grid[oy + ty][ox + tx] = v
    g = wp.Grid(grid, W, H); st = wp.Stats(1.0, False)
    def lips(p):
        k = [[int(c) for c in row] for row in p["_tiles"]]; ft = len(k) - 8; ex = p["exit"][0] // T; out = []
        for tx in (ex - 4, ex + 3):
            ty = ft
            while ty > 0 and k[ty - 1][tx] != 0: ty -= 1
            out.append(((p["x"] // T - x0 + tx + .5) * T, (p["y"] // T - y0 + ty) * T, False))
        return out
    def goal(p): return [((p["x"] // T - x0) * T, (p["y"] // T - y0) * T, (p["x"] // T - x0) * T + p["w"], (p["y"] // T - y0) * T + p["h"] - 7 * T)]
    a, c = trio[0], trio[2]
    _, _, down = wp.reach(g, st, lips(a), goal(c), want={0})
    if 0 not in down: return False
    _, _, up = wp.reach(g, st, lips(c), goal(a), want={0}, max_states=9000)
    return 0 in up

if __name__ == "__main__":
    main()
