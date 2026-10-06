"""Authors the expansion of the fixed world: for each of the five regions, three WING rooms built onto the side of an existing
room (a doorway cut through the host's side wall): a ruin hall (a scroll and a resting lantern), a key chamber (a climb to
the region's key; none in the Ash Deep, whose door is the lake's seal) and a guardian temple (the region's crystal guardian).
Also places scroll pedestals along the main path, the key gates and the lake seal (in the shafts), and writes data/scrolls.json.
Hosts come from data/world_before_wings/ (copied once), so this script can be re-run. Wings are data/world/wing_*.json.
Run: python3 dev/make_wings.py   then python3 dev/world_bake.py && python3 dev/world_verify.py
DO NOT run this any more: it starts again from data/world_before_wings/ (before the thinning, flat floors, filled holes and the shrines) and deletes every
wing_*.json. The lantern shrines are added by dev/make_shrines.py on top of the world as it is."""
import glob, json, os, shutil, sys
sys.path.insert(0, os.path.dirname(__file__))
import world_physics as wp
import world_gen as wg
from world_bake import load_room
from world_thin import meta_for

T = 8
BACKUP = "data/world_before_wings"
THEMES = ["overgrowth", "rustworks", "drowned", "bone", "ash"]
REGION = ["THE OVERGROWTH", "THE RUSTWORKS", "THE DROWNED WORKS", "THE BONE STACKS", "THE ASH DEEP"]
SHORT = ["OVERGROWTH", "RUSTWORKS", "DROWNED WORKS", "BONE STACKS", "ASH DEEP"]

# ------------------------------------------------------------------------------------------- the words on the scrolls
SCROLLS = {
 "s01": ("THE WAY DOWN", "Little one, the lake waits at the bottom of the world. Run with {move_left} and {move_right}. Jump with {jump}, and hold it to leap higher. Your bamboo stick swings with {attack}."),
 "s02": ("WALLS AND ROPES", "Press {jump} against a wall to leap away from it, again and again. Ropes and vines will carry you: {move_up} climbs, {pound} climbs down."),
 "s03": ("THE DASH", "Dash with {dash} to cross a wide gap. Touch ground or wall, and it comes back."),
 "s04": ("A PLACE TO REST", "Stand beside a resting lantern and press {interact} to mend your crystals. When you fall, you wake at the last one you rested by."),
 "s05": ("A GATE, A KEY", "Every region keeps a gate, and every gate wants a key. The key of the Overgrowth sleeps at the top of this ruin. Climb."),
 "s06": ("THE FIRST GUARDIAN", "A crystal guardian keeps this temple. Strike it with your bamboo stick ({attack}) and it reels for a moment, its heart bare. Fall upon the heart from above. When the ground shakes, jump ({jump})."),
 "s07": ("FIVE GUARDIANS", "Five crystal guardians keep the door to the lake, one in every region. Break them all, and the water will let you in."),
 "s08": ("GROUND POUND", "Press {pound} in the air to fall like a stone. A guardian's heart breaks twice as fast when you land on it."),
 "s09": ("THE RUSTWORKS", "Iron remembers the hands that bent it. A guardian sleeps deeper in the foundry. Find its temple, and the key that is kept beside it."),
 "s10": ("THE SECOND KEY", "Climb the broken beams. The key of the Rustworks waits at the very top, where the roof used to be."),
 "s11": ("THE SECOND GUARDIAN", "This one calls the ceiling down. Watch the floor: a light shows where each shard will land."),
 "s12": ("DOUBLE JUMP", "Press {jump} again in the air for one more leap. Use it to reach what a single jump cannot."),
 "s13": ("THE DROWNED WORKS", "The water rose and kept everything it was given. Another guardian waits in a temple the tide has not yet taken."),
 "s14": ("THE THIRD KEY", "Rest your jump ({jump}) between ledges, and do not look down. The key of the Drowned Works is high and dry."),
 "s15": ("THE THIRD GUARDIAN", "It is quicker than the last two. Stay in the air when it strikes, and come down on its heart."),
 "s16": ("UNTOUCHABLE DASH", "Nothing can hurt you while you dash ({dash}). Once it has been used, it needs three breaths to return."),
 "s17": ("THE BONE STACKS", "Whatever lived here was large. A guardian keeps the temple at the heart of the stacks, and a key rests in the ribs above."),
 "s18": ("THE FOURTH KEY", "The way up is made of old bones and fewer handholds than you would like. The key of the Bone Stacks is at the top."),
 "s19": ("THE FOURTH GUARDIAN", "It strikes in pairs. Dash ({dash}) through the second strike and fall upon its heart."),
 "s20": ("HEAL IN A HEARTBEAT", "Hold {eat} with a full circle to mend a crystal at once, instead of in a long and dangerous moment."),
 "s21": ("THE ASH DEEP", "Nothing grows here anymore. The last guardian keeps the last temple. When it falls, the lake's seal will open."),
 "s22": ("THE LAST GUARDIAN", "It knows everything the others knew. You know it too. Take your time, and take the heart."),
 "s23": ("THE LAKE", "Past the seal, the water is calm and nothing there will hurt you. Rest while you can."),
}

# --------------------------------------------------------------------------------------------- wing layout (door on the left)
def shell(tw, th, fr):
    k = [[0] * tw for _ in range(th)]
    for y in range(th):
        for x in range(tw):
            if x < 5 or x >= tw - 5 or y < 5 or y >= fr: k[y][x] = 1
    for y in range(fr - 4, fr):
        for x in range(5): k[y][x] = 0          # the doorway tunnel through the wing's wall
    return k

def put(k, x0, x1, y, v):
    for x in range(x0, x1 + 1): k[y][x] = v

def beam(k, x0, x1, y): put(k, x0, x1, y, 4)
def slab(k, x0, x1, y): put(k, x0, x1, y, 2)

def make_wing(kind, region, fr, host_tile_y=None):
    """Returns the wing's data in the frame where its door is on the LEFT wall; main() mirrors it when needed."""
    theme = THEMES[region]; fy = fr * T
    tw = 60                                                               # one screen: the whole fight is always in view
    th = 34; k = shell(tw, th, fr)
    props, deco, marks, ropes, goal = [], [], [], [], None
    if kind == "ruin":
        beam(k, 14, 19, fr - 7); beam(k, 27, 33, fr - 10); slab(k, 38, 44, fr - 5)
        sid = {0: "s04", 1: "s09", 2: "s13", 3: "s17", 4: "s21"}[region]
        props.append(dict(t="scroll", id=sid, x=47 * T + 4, y=fy))
        marks.append(["rest", 30 * T, fy])
        deco += [dict(t="ruin_hall", x=29 * T, y=fy), dict(t="ruin_arch", x=12 * T, y=fy, w=44, h=60),
                 dict(t="pillar", x=21 * T, y=fy, h=46), dict(t="pillar", x=52 * T, y=fy, h=38), dict(t="lantern", x=44 * T, y=fy)]
        goal = (47 * T, fy)
    elif kind == "ruin2":                                                  # a second quiet hall (the Ash Deep has no key chamber)
        beam(k, 16, 22, fr - 8); slab(k, 33, 39, fr - 6)
        props.append(dict(t="scroll", id="s23", x=46 * T + 4, y=fy))
        deco += [dict(t="ruin_arch", x=26 * T, y=fy, w=48, h=64), dict(t="ruin_hall", x=44 * T, y=fy),
                 dict(t="pillar", x=14 * T, y=fy, h=50), dict(t="lantern", x=36 * T, y=fy)]
        goal = (46 * T, fy)
    elif kind == "key":
        slab(k, 14, 19, fr - 4); slab(k, 23, 28, fr - 8); slab(k, 32, 37, fr - 12); slab(k, 42, 52, fr - 15)
        beam(k, 6, 9, fr - 12)
        sid = {0: "s05", 1: "s10", 2: "s14", 3: "s18"}[region]
        props.append(dict(t="scroll", id=sid, x=9 * T + 4, y=fy))
        props.append(dict(t="key", id="key_%d" % region, region=region, x=48 * T, y=(fr - 15) * T))
        deco += [dict(t="ruin_arch", x=30 * T, y=fy, w=52, h=70), dict(t="pillar", x=47 * T, y=fy, h=60),
                 dict(t="pillar", x=11 * T, y=fy, h=34), dict(t="lantern", x=52 * T, y=(fr - 15) * T)]
        goal = (48 * T, (fr - 15) * T)
    elif kind == "temple":
        slab(k, 13, 19, fr - 5); slab(k, 41, 47, fr - 5); beam(k, 22, 27, fr - 9); beam(k, 33, 38, fr - 9)
        sid = {0: "s06", 1: "s11", 2: "s15", 3: "s19", 4: "s22"}[region]
        props.append(dict(t="scroll", id=sid, x=9 * T + 4, y=fy))
        props.append(dict(t="guardian", id="g_%d" % region, region=region, x=30 * T, y=fy, x0=6 * T, x1=(tw - 6) * T, top=5 * T))
        deco += [dict(t="temple", x=30 * T, y=fy), dict(t="lantern", x=15 * T, y=fy), dict(t="lantern", x=45 * T, y=fy),
                 dict(t="pillar", x=8 * T, y=fy, h=52), dict(t="pillar", x=52 * T, y=fy, h=44)]
        goal = (30 * T, fy)
    return dict(tw=tw, th=th, fr=fr, k=k, props=props, deco=deco, marks=marks, ropes=ropes, goal=goal, theme=theme)

def mirror(w):
    tw = w["tw"]; W = tw * T
    w["k"] = [row[::-1] for row in w["k"]]
    for p in w["props"]:
        p["x"] = W - p["x"]
        if "x0" in p: p["x0"], p["x1"] = W - p["x1"], W - p["x0"]
    for d in w["deco"]:
        d["x"] = W - d["x"]
    for m in w["marks"]: m[1] = W - m[1]
    for r in w["ropes"]: r[0] = W - r[0]
    w["goal"] = (W - w["goal"][0], w["goal"][1])
    return w

def check_wing(w, door_left):
    """Walk from the doorway to the wing's goal and back, with no abilities, at full and 80% strength."""
    tw, th, k, fr = w["tw"], w["th"], w["k"], w["fr"]
    g = wp.Grid(k, tw, th, [])
    for r in w["ropes"]: g.ropes.append((r[0], r[1], r[1] + r[2]))
    sx = (6 if door_left else tw - 7) * T; sy = fr * T; gx, gy = w["goal"]
    out = {}
    for s in (1.0, 0.8):
        st = wp.Stats(s, False)
        _, _, a = wp.reach(g, st, [(sx, sy, False)], [(gx - 10, gy - 8, gx + 10, gy + 2)], want={0}, max_states=9000)
        _, _, b = wp.reach(g, st, [(gx, gy, False)], [(sx - 12, sy - 8, sx + 12, sy + 2)], want={0}, max_states=9000)
        out[s] = (0 in a) and (0 in b)
    return out

# ---------------------------------------------------------------------------------------------------------- hosts
def floor_row(d, x):
    """Top row of the solid ground at column x, counting up from the bottom of the room."""
    k = d["k"]; y = d["th"]
    while y > 0 and k[y - 1][x] != 0: y -= 1
    return y

def host_door(d, r, side):
    """Floor row (always th - 8, the room's floor) where a doorway can be cut into the host's wall on `side` (-1 left, 1 right),
    or None if the spot is unsuitable. An uneven floor beside the wall is levelled first; the change is kept only if the room
    still passes the movement check."""
    tw, th = d["tw"], d["th"]
    if d.get("first") or d.get("final"): return None
    target = th - 8
    cols = list(range(5, 11)) if side < 0 else list(range(tw - 11, tw - 5))
    edge = 5 if side < 0 else tw - 6
    if abs(d["exit_tile"] - edge) < 9: return None
    for rp in d.get("ropes", []):
        if abs(int(rp[0]) // T - edge) < 3: return None
    if any(abs(int(c[0]) // T - edge) < 6 for c in d.get("cracks", [])): return None
    if any(abs(int(m[1]) // T - edge) < 6 for m in d["marks"]): return None
    tops = [floor_row(d, c) for c in cols]
    if tops != [target] * len(cols):
        dd = dict(d); r.meta = meta_for(dd, r)
        need80 = wg.check(r, 0.8, False)[0]
        saved = [row[:] for row in r.kind]
        for c in cols:
            for y in range(max(5, target - 8), th): r.kind[y][c] = 0 if y < target else 1
        r.meta = meta_for(dd, r)
        if not (wg.check(r, 1.0, False)[0] and (not need80 or wg.check(r, 0.8, False)[0])):
            r.kind[:] = saved; return None
    front = [(x, y) for y in range(target - 6, target) for x in (range(5, 12) if side < 0 else range(tw - 12, tw - 5))]
    if any(r.kind[y][x] in (1, 2, 3) for x, y in front): return None       # a wall ledge or platform in the way: not here
    for x, y in front:
        if r.kind[y][x] == 4: r.kind[y][x] = 0                              # beams are extras: take them out of the doorway
    return target

def main():
    if not os.path.isdir(BACKUP): shutil.copytree("data/world", BACKUP)
    for f in glob.glob("data/world/wing_*.json"): os.remove(f)
    for f in glob.glob(BACKUP + "/[0-9]*.json") + glob.glob(BACKUP + "/shaft_*.json"):
        shutil.copy(f, "data/world/" + os.path.basename(f))
    files = {int(os.path.basename(f).split("_")[0]): f for f in sorted(glob.glob("data/world/[0-9]*.json"))}
    rooms = {}
    for i, f in files.items():
        d = json.load(open(f)); r, _ = load_room(f); d["k"] = r.kind; d["_r"] = r; d["_f"] = f; rooms[i] = d
    used = set(); wings = []
    for region in range(5):
        rids = [i for i in range(region * 10 + 1, region * 10 + 11)]
        kinds = [("ruin", 0.12), ("key", 0.5), ("temple", 0.95)] if region < 4 else [("ruin", 0.12), ("ruin2", 0.45), ("temple", 0.95)]
        for kind, pos in kinds:
            order = sorted(rids, key=lambda i: abs((i - region * 10 - 1) / 9 - pos))
            done = False
            for h in order:
                for side in ((-1, 1) if (h + region) % 2 else (1, -1)):
                    if (h, side) in used: continue
                    top = host_door(rooms[h], rooms[h]["_r"], side)
                    if top is None: continue
                    w = make_wing(kind, region, 26)
                    door_left = (side > 0)                                  # wing sits on the host's right: its door is on ITS left
                    if not door_left: mirror(w)
                    res = check_wing(w, door_left)
                    if not res[1.0] or (kind == "key" and not res[0.8]):
                        print("  wing does not pass", kind, region, h, side, res); continue
                    used.add((h, side)); wings.append((region, kind, h, side, top, w)); done = True
                    break
                if done: break
            if not done: print("NO HOST for", kind, region)
    # cut doorways, arches and write wings
    n = 0
    for region, kind, h, side, top, w in wings:
        d = rooms[h]; k = d["k"]; tw = d["tw"]
        cols = range(0, 5) if side < 0 else range(tw - 5, tw)
        for y in range(top - 4, top):
            for x in cols: k[y][x] = 0
        d.setdefault("deco", []).append(dict(t="door_arch", x=(5 if side < 0 else tw - 5) * T, y=top * T, side=side))
        n += 1
        name = {"ruin": "THE OLD HALL", "ruin2": "THE QUIET SHRINE", "key": "THE KEY CHAMBER", "temple": "GUARDIAN TEMPLE"}[kind]
        wd = dict(kind="room", wing=True, wing_kind=kind, host=h, side=side, index=100 + n, name=name, theme=w["theme"], tile=T, tw=w["tw"], th=w["th"],
                  sw=w["tw"] // 60, sh=1, depth=min(0.95, d["depth"] + 0.02), seed=300 + n,
                  tiles=["".join(str(v) for v in row) for row in w["k"]], poles=[], marks=w["marks"], enemies=[], food=[], pound_food=[], cracks=[],
                  margin=0.5, threat=0, foodcount=0, entry_tile=None, exit_tile=None, first=False, ropes=w["ropes"], props=w["props"],
                  deco=w["deco"] + [dict(t="door_arch", x=(5 if side > 0 else w["tw"] - 5) * T, y=26 * T, side=-side)],
                  floor_row=26, host_dy=d["th"] - 34, door_side=-side)
        json.dump(wd, open("data/world/wing_%02d_%s.json" % (region + 1, kind), "w"))
    # scroll pedestals on the main path, gates and the lake seal
    add_props(rooms, wings)
    for i, d in rooms.items():
        out = {k_: v for k_, v in d.items() if k_ not in ("k", "_r", "_f")}
        out["tiles"] = ["".join(str(v) for v in row) for row in d["k"]]
        json.dump(out, open(d["_f"], "w"))
    # the words
    json.dump({k_: dict(title=v[0], pages=[v[1]]) for k_, v in SCROLLS.items()}, open("data/scrolls.json", "w"), indent=1)
    print("wings:", len(wings), [(w[0] + 1, w[1], w[2], w[3]) for w in wings])

def flat_spot(d, r, want_x, span=6):
    """Column (tile) near want_x where `span` columns share one floor row, away from the exit hole and the ropes."""
    th = d["th"]; tw = d["tw"]; m = meta_for(d, r); best = None
    for x in range(7, tw - 7 - span):
        tops = m["top"][x:x + span]
        if len(set(tops)) != 1 or tops[0] < th - 14: continue
        if abs(x + span // 2 - m["x_out"]) < 7 or any(abs(int(rp[0]) // T - (x + span // 2)) < 3 for rp in d.get("ropes", [])): continue
        if any(x - 1 <= int(c[0]) // T <= x + span for c in d.get("cracks", [])): continue
        score = abs(x + span // 2 - want_x)
        if best is None or score < best[0]: best = (score, x + span // 2, tops[0])
    return best

def add_props(rooms, wings):
    placements = [("s01", 1, None), ("s02", 2, 0.2), ("s03", 4, 0.8), ("s07", 10, 0.5),
                  ("s08", 11, 0.5), ("s12", 21, 0.5), ("s16", 31, 0.5), ("s20", 41, 0.5)]
    for sid, ri, want in placements:
        d = rooms[ri]; r = d["_r"]
        if ri == 1:
            st = [m for m in d["marks"] if m[0] == "start"][0]; want_x = int(st[1]) // T + 7
        else:
            want_x = int(d["entry_tile"]) + 10 if want is None else int(d["tw"] * want)
        spot = flat_spot(d, r, want_x)
        if spot is None: print("no spot for scroll", sid, ri); continue
        _, cx, top = spot
        d.setdefault("props", []).append(dict(t="scroll", id=sid, x=cx * T + 4, y=top * T))
    # gates: in the shaft under the last room of each region; the lake seal under the last room of the Ash Deep
    for g in range(5):
        path = "data/world/shaft_%02d.json" % ((g + 1) * 10)
        d = json.load(open(path))
        door = dict(t="door", id="gate_%d" % g if g < 4 else "seal", x=56, y=96, w=64)
        if g < 4: door["key"] = g
        else: door["need"] = "guardians"
        d["props"] = [door]
        json.dump(d, open(path, "w"))

if __name__ == "__main__":
    main()
