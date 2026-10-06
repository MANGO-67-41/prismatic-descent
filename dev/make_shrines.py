"""Adds the LANTERN SHRINES to the fixed world: three more wing rooms in every region (15 in all), each a quiet shrine with no
enemies and one resting lantern, after the photograph of a red torii at the foot of a long stone stair between cedars. They are
built onto the sides of main rooms exactly like the other wings (a doorway cut through the host's wall, floor level with the host's
floor), but on top of the world as it is now: this script does NOT start from data/world_before_wings/, so the flat floors and
everything else done since stay. Re-running it replaces its own shrines (data/world/wing_*_shrine*.json) and puts back the
doorways it cut (data/world_before_shrines/ holds the hosts as they were); never re-run make_wings.py after this.
The three shrines of a region are three layouts: THE LANTERN GATE (a great torii with the stair behind it), THE QUIET HALL
(a torii, a small hall, stone lanterns) and THE STAIR OF LAMPS (a torii and a lit stair climbing off to the side). Each region
paints them in its own colours (jade gates in the Drowned Works, bone-white lacquer in the Bone Stacks, and so on).
Run: python3 dev/make_shrines.py   then python3 dev/make_creatures.py && python3 dev/world_bake.py && python3 dev/world_verify.py"""
import glob, json, os, random, shutil, sys
sys.path.insert(0, os.path.dirname(__file__))
import make_wings as mw
from world_bake import load_room

T = 8
BASE = 26 * T                                  # the floor of a wing (row 26)
KINDS = [("gate_stair", "THE LANTERN GATE", .22), ("gate_hall", "THE QUIET HALL", .58), ("stair_vigil", "THE STAIR OF LAMPS", .82)]
BACKUP = "data/world_before_shrines"

def spaced(rng, n, lo, hi, gap):
    out = []
    for _ in range(400):
        x = rng.randint(lo, hi)
        if all(abs(x - o) >= gap for o in out): out.append(x)
        if len(out) == n: break
    return sorted(out)

def layout(variant, rng):
    """The deco list (back to front) and the rest lantern's x, in the frame where the door is on the LEFT."""
    d = [dict(t="shrine_back", x=0, y=BASE, shafts=[rng.randint(70, 130), rng.randint(190, 250), rng.randint(310, 370)])]
    for x in spaced(rng, 7, 60, 420, 34): d.append(dict(t="cedar", x=x, y=BASE, w=rng.randint(9, 13), top=30, fog=.42, s=rng.randint(1, 9999)))
    for x in spaced(rng, 4, 80, 400, 70): d.append(dict(t="cedar", x=x, y=BASE, w=rng.randint(15, 20), top=30, fog=.3, s=rng.randint(1, 9999)))
    if variant == "gate_stair":
        d += [dict(t="stairs", x=236, y=BASE, top=72, w0=96, w1=34), dict(t="torii", x=236, y=80, w=22, h=26, fog=.55)]
    elif variant == "stair_vigil":
        d += [dict(t="stairs", x=352, y=BASE, top=70, w0=88, w1=30), dict(t="torii", x=352, y=76, w=20, h=24, fog=.55)]
    d += [dict(t="cedar", x=64, y=BASE, w=30, top=30, fog=.05, s=rng.randint(1, 9999)), dict(t="cedar", x=420, y=BASE, w=28, top=30, fog=.05, s=rng.randint(1, 9999)),
          dict(t="canopy", x=0, y=0)]
    if variant == "gate_stair":
        rest = 382
        d += [dict(t="torii", x=236, y=BASE, w=112, h=120), dict(t="toro", x=140, y=BASE, h=44), dict(t="toro", x=332, y=BASE, h=44), dict(t="toro", x=412, y=BASE, h=38)]
    elif variant == "gate_hall":
        rest = 266
        d += [dict(t="torii", x=150, y=BASE, w=92, h=104), dict(t="toro", x=226, y=BASE, h=46), dict(t="hall", x=346, y=BASE), dict(t="toro", x=410, y=BASE, h=40)]
    else:
        rest = 258
        d += [dict(t="torii", x=186, y=BASE, w=84, h=96), dict(t="toro", x=96, y=BASE, h=40), dict(t="toro", x=304, y=BASE, h=44)]
    d += [dict(t="halo", x=rest, y=BASE - 12, r=30), dict(t="fireflies", x=0, y=0, n=14, x0=52, x1=428, y0=84, y1=196), dict(t="ground_mist", x=0, y=BASE, h=34, k=.7)]
    return d, rest

def make_shrine(variant, region, rng):
    tw, th, fr = 60, 34, 26
    k = mw.shell(tw, th, fr)
    deco, rest = layout(variant, rng)
    return dict(tw=tw, th=th, fr=fr, k=k, props=[], deco=deco, marks=[["rest", rest, BASE]], ropes=[], goal=(rest, BASE), theme=mw.THEMES[region])

def main():
    if not os.path.isdir(BACKUP): shutil.copytree("data/world", BACKUP)
    for f in glob.glob("data/world/wing_*_shrine*.json"): os.remove(f)
    for f in glob.glob(BACKUP + "/[0-9]*.json"): shutil.copy(f, "data/world/" + os.path.basename(f))     # the hosts as they were before any shrine
    rooms = {}
    for f in sorted(glob.glob("data/world/[0-9]*.json")):
        i = int(os.path.basename(f).split("_")[0]); d = json.load(open(f)); r, _ = load_room(f)
        d["k"] = r.kind; d["_r"] = r; d["_f"] = f; rooms[i] = d
    used = set()
    for f in glob.glob("data/world/wing_*.json"):
        w = json.load(open(f)); used.add((int(w["host"]), int(w["side"])))
    runtime = json.load(open("data/world_runtime.json"))["pieces"]
    by_name = {}
    for p in runtime:
        if p["kind"] == "room" and not p.get("wing"): by_name[p["name"]] = p
    other = [(p["x"], p["y"], p["w"], p["h"]) for p in runtime]
    made = []
    for region in range(5):
        for v, (variant, name, pos) in enumerate(KINDS):
            order = sorted(range(region * 10 + 1, region * 10 + 11), key=lambda i: abs((i - region * 10 - 1) / 9 - pos))
            done = False
            for h in order:
                for side in ((-1, 1) if (h + region) % 2 else (1, -1)):
                    if (h, side) in used: continue
                    hp = by_name.get(rooms[h]["name"])
                    if hp is None: continue
                    wx = hp["x"] - 480 if side < 0 else hp["x"] + hp["w"]; wy = hp["y"] + hp["h"] - 272
                    if any(wx < ox + ow and ox < wx + 480 and wy < oy + oh and oy < wy + 272 for (ox, oy, ow, oh) in other): continue    # something is in the way
                    top = mw.host_door(rooms[h], rooms[h]["_r"], side)
                    if top is None: continue
                    w = make_shrine(variant, region, random.Random(region * 100 + v * 7 + 3))
                    door_left = side > 0
                    if not door_left: mw.mirror(w)
                    res = mw.check_wing(w, door_left)
                    if not (res[1.0] and res[0.8]): print("  shrine does not pass", variant, region, h, side, res); continue
                    used.add((h, side)); other.append((wx, wy, 480, 272)); made.append((region, v, variant, name, h, side, top, w)); done = True
                    break
                if done: break
            if not done: print("NO HOST for", variant, region)
    n = 0
    for region, v, variant, name, h, side, top, w in made:
        d = rooms[h]; k = d["k"]; tw = d["tw"]
        for y in range(top - 4, top):
            for x in (range(0, 5) if side < 0 else range(tw - 5, tw)): k[y][x] = 0
        d.setdefault("deco", []).append(dict(t="door_arch", x=(5 if side < 0 else tw - 5) * T, y=top * T, side=side))
        n += 1
        wd = dict(kind="room", wing=True, wing_kind="shrine", host=h, side=side, index=130 + n, name=name, theme=w["theme"], tile=T, tw=w["tw"], th=w["th"],
                  sw=1, sh=1, depth=min(0.95, d["depth"] + 0.02), seed=400 + n,
                  tiles=["".join(str(c) for c in row) for row in w["k"]], poles=[], marks=w["marks"], enemies=[], food=[], pound_food=[], cracks=[],
                  margin=0.5, threat=0, foodcount=0, entry_tile=None, exit_tile=None, first=False, ropes=[], props=[],
                  deco=w["deco"] + [dict(t="door_arch", x=(5 if side > 0 else w["tw"] - 5) * T, y=26 * T, side=-side)],
                  floor_row=26, host_dy=d["th"] - 34, door_side=-side, creatures=[])
        json.dump(wd, open("data/world/wing_%02d_shrine%d.json" % (region + 1, v + 1), "w"))
    for i, d in rooms.items():
        out = {k_: v for k_, v in d.items() if k_ not in ("k", "_r", "_f")}
        out["tiles"] = ["".join(str(c) for c in row) for row in d["k"]]
        json.dump(out, open(d["_f"], "w"))
    print("shrines:", len(made), [(m[0] + 1, m[2], m[4], m[5]) for m in made])

if __name__ == "__main__":
    main()
