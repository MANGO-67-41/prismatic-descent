"""Re-checks the SAVED world (data/world/*.json): every room can be crossed entrance to exit and climbed back up,
every shaft can be fallen through and climbed, at full strength and at reduced strength. Also confirms ropes are 2-3 per room.
Run: python3 dev/world_verify.py"""
import glob, json, os, sys, time
from multiprocessing import Pool
sys.path.insert(0, os.path.dirname(__file__))
import world_gen as wg
import world_physics as wp
from world_bake import load_room
from world_thin import meta_for
T = 8

def check_final(path, d, r):
    """The last room has no exit: from the entrance the temple door must be reachable, and from the door the way back up."""
    g = wp.Grid(r.kind, r.tw, r.th, [(d["entry_tile"] - 3, -40, d["entry_tile"] + 3, 0)])
    for rp in d.get("ropes", []): g.ropes.append((rp[0], rp[1], rp[1] + rp[2]))
    rest = [m for m in d["marks"] if m[0] == "rest"][0]
    res = {}
    for s in (1.0, 0.8, 0.65):
        st = wp.Stats(s, False)
        _, _, a = wp.reach(g, st, [(d["entry_tile"] * T, 6 * T, True)], [(rest[1] - 24, rest[2] - 6, rest[1] + 24, rest[2] + 2)], want={0})
        _, _, b = wp.reach(g, st, [(rest[1], rest[2], False)], [((d["entry_tile"] - 2) * T, -400, (d["entry_tile"] + 2) * T, 2 * T)], want={0}, max_states=9000)
        res[s] = 0 in a and 0 in b
        if not res[s]: break
    return dict(file=os.path.basename(path), kind="room", name=d["name"], passes=res[1.0], p80=res.get(0.8, False), p65=res.get(0.65, False),
                ropes=len(d.get("ropes", [])), platforms=sum(row.count("2") for row in d["tiles"]))

def check_room(path):
    d = json.load(open(path)); r, _ = load_room(path)
    if d.get("final"): return check_final(path, d, r)
    r.meta = meta_for(d, r)
    res = {}
    for s in (1.0, 0.8, 0.65):
        ok, _ = wg.check(r, s, False); res[s] = ok
        if not ok: break
    margin = 0.0 if not res[1.0] else (0.5 if res.get(0.65) else 0.2 if res.get(0.8) else 0.0)
    ropes = len(d.get("ropes", []))
    return dict(file=os.path.basename(path), kind="room", name=d["name"], passes=res[1.0], p80=res.get(0.8, False), p65=res.get(0.65, False), ropes=ropes, platforms=sum(row.count("2") for row in d["tiles"]))

def check_shaft(path):
    d = json.load(open(path)); k = [[int(c) for c in row] for row in d["tiles"]]; tw, th = d["tw"], d["th"]
    ops = [(4, -40, 10, 0), (4, th, 10, th + 40)]
    out = {}
    for s in (1.0, 0.8):
        st = wp.Stats(s, False); g = wp.Grid(k, tw, th, ops)
        _, _, got = wp.reach(g, st, [(7 * T, 0, True)], [(4 * T, th * T + 4, 10 * T, th * T + 60)], want={0})
        k2 = [row[:] for row in k] + [[1] * 3 + [1] * 8 + [1] * 3]
        g2 = wp.Grid(k2, tw, th + 1, [(4, -40, 10, 0)])
        _, _, got2 = wp.reach(g2, st, [(7 * T, th * T, False)], [(4 * T, -400, 10 * T, 0)], want={0})
        out[s] = (0 in got) and (0 in got2)
    return dict(file=os.path.basename(path), kind="shaft", name=d["name"], passes=out[1.0], p80=out[0.8], p65=False, ropes=0, platforms=0)

def check_wing(path):
    """A wing: from its doorway to its scroll / key / guardian and back, with no abilities."""
    d = json.load(open(path)); r, _ = load_room(path)
    tw, th, fr = d["tw"], d["th"], d["floor_row"]
    g = wp.Grid(r.kind, tw, th, [])
    sx = (6 if d["door_side"] < 0 else tw - 7) * T; sy = fr * T
    goal = [p for p in d["props"] if p["t"] in ("key", "guardian")] or d["props"] or [dict(x=m[1], y=m[2]) for m in d["marks"] if m[0] == "rest"]     # a lantern shrine: its lantern
    gx, gy = goal[0]["x"], goal[0]["y"]
    res = {}
    for s_ in (1.0, 0.8):
        st = wp.Stats(s_, False)
        _, _, a = wp.reach(g, st, [(sx, sy, False)], [(gx - 10, gy - 8, gx + 10, gy + 2)], want={0}, max_states=9000)
        _, _, b = wp.reach(g, st, [(gx, gy, False)], [(sx - 12, sy - 8, sx + 12, sy + 2)], want={0}, max_states=9000)
        res[s_] = (0 in a) and (0 in b)
    return dict(file=os.path.basename(path), kind="wing", name=d["name"], passes=res[1.0], p80=res[0.8], p65=False, ropes=0, platforms=0)

def job(p):
    if "shaft_" in p: return check_shaft(p)
    return check_wing(p) if "wing_" in p else check_room(p)

if __name__ == "__main__":
    files = sorted(glob.glob("data/world/[0-9]*.json")) + sorted(glob.glob("data/world/shaft_*.json")) + sorted(glob.glob("data/world/wing_*.json"))
    t0 = time.time()
    with Pool(8) as pool: results = pool.map(job, files, chunksize=1)
    bad = [r for r in results if not r["passes"]]
    print("checked", len(results), "pieces in", round(time.time() - t0), "s;", len(bad), "cannot be completed at full strength")
    for r in bad: print("  FAIL", r["file"], r["name"])
    rooms = [r for r in results if r["kind"] == "room"]
    print("rooms passing at 80% strength:", sum(r["p80"] for r in rooms), "of", len(rooms), "| at 65%:", sum(r["p65"] for r in rooms))
    print("rooms with 2-3 ropes:", sum(2 <= r["ropes"] <= 3 for r in rooms), "of", len(rooms))
    json.dump(results, open("dev/world/_verify.json", "w"))
