"""Checks every junction of the stitched world: from each room's floor, down its shaft into the next room, and BACK UP
(climbing out of the next room's ceiling hole, up the shaft, up through the floor hole into the room above).
Run: python3 dev/world_junctions.py"""
import glob, json, os, sys
from multiprocessing import Pool
sys.path.insert(0, os.path.dirname(__file__))
import world_physics as wp
T = 8

def tiles_of(p):
    name = p["src"]
    d = json.load(open(name)); return [[int(c) for c in row] for row in d["tiles"]]

def load():
    rt = json.load(open("data/world_runtime.json"))
    rooms = sorted(glob.glob("data/world/[0-9]*.json"))
    srcs = []
    for f in rooms:
        idx = int(os.path.basename(f).split("_")[0]); srcs.append(f)
        sh = "data/world/shaft_%02d.json" % idx
        if os.path.exists(sh): srcs.append(sh)
    main = rt["pieces"][:len(srcs)]            # the wings are appended after the main stack; they have no junctions
    for p, s in zip(main, srcs): p["src"] = s
    return main

def junction(args):
    pieces, i = args            # room i, shaft i+1, room i+2 (indices in pieces)
    trio = pieces[i:i + 3]
    x0 = min(p["x"] for p in trio) // T; x1 = max(p["x"] + p["w"] for p in trio) // T
    y0 = trio[0]["y"] // T; y1 = (trio[2]["y"] + trio[2]["h"]) // T
    W, H = x1 - x0, y1 - y0
    grid = [[1] * W for _ in range(H)]
    for p in trio:
        k = tiles_of(p); ox, oy = p["x"] // T - x0, p["y"] // T - y0
        for ty, row in enumerate(k):
            for tx, v in enumerate(row): grid[oy + ty][ox + tx] = v
    g = wp.Grid(grid, W, H)
    for p in trio:                                   # ropes and vines (the shaft's rope runs through both holes)
        for rp in p.get("ropes", []):
            g.ropes.append((p["x"] - x0 * T + rp[0], p["y"] - y0 * T + rp[1], p["y"] - y0 * T + rp[1] + rp[2]))
    st = wp.Stats(1.0, False)
    a, c = trio[0], trio[2]
    def floor_lips(p):
        k = tiles_of(p); ft = len(k) - 8; ex = p["exit"][0] // T
        out = []
        for tx in (ex - 4, ex + 3):
            ty = ft
            while ty > 0 and k[ty - 1][tx] != 0: ty -= 1
            out.append(((p["x"] // T - x0 + tx + .5) * T, (p["y"] // T - y0 + ty) * T, False))
        return out
    def room_floor_goal(p):
        return [((p["x"] // T - x0) * T, (p["y"] // T - y0) * T, (p["x"] // T - x0) * T + p["w"], (p["y"] // T - y0) * T + p["h"] - 7 * T)]
    _, _, down = wp.reach(g, st, floor_lips(a), room_floor_goal(c), want={0})
    _, _, up = wp.reach(g, st, floor_lips(c), room_floor_goal(a), want={0}, max_states=9000)
    return dict(junction=i, upper=a["name"], lower=c["name"], down=0 in down, up=0 in up)

if __name__ == "__main__":
    pieces = load()
    jobs = [(pieces, i) for i in range(0, len(pieces) - 2, 2)]
    with Pool(8) as pool: res = pool.map(junction, jobs, chunksize=1)
    bad = [r for r in res if not (r["up"] and r["down"])]
    print("junctions", len(res), "failing", len(bad))
    for r in bad: print("  ", r)
    json.dump(res, open("dev/world/_junctions.json", "w"))
