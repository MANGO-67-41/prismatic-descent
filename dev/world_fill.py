"""One-time pass over the fixed world: fills in the holes under the floor. Every room had a few cracked patches (4 tiles each, floor
that gave way to a ground pound) with an empty pocket underneath. The patch becomes plain floor and the pocket is filled solid, so
the floor is one unbroken slab except for the hole where the room lets out. `cracks` is left empty in every room (the game code for
smashing them stays; nothing uses it). Backup of the rooms before: data/world_before_fill/.
Run: python3 dev/world_fill.py   then python3 dev/world_bake.py && python3 dev/world_verify.py && python3 dev/world_junctions.py"""
import glob, json, os, shutil

def job(path):
    d = json.load(open(path))
    cracks = d.get("cracks", [])
    if not cracks: return 0
    k = [[int(c) for c in row] for row in d["tiles"]]; th, tw = len(k), len(k[0])
    filled = 0
    for (cx, cy) in [(int(c[0]), int(c[1])) for c in cracks]:
        k[cy][cx] = 1
    seen = set(); stack = [(int(c[0]), int(c[1]) + 1) for c in cracks]
    while stack:                       # the pocket: the air under the patch (and any air joined to it that does not open to the room)
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < tw and 0 <= y < th) or k[y][x] != 0: continue
        seen.add((x, y))
        if len(seen) > 80: raise SystemExit("%s: the pocket under the cracks opens into something big; look at it" % path)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)): stack.append((nx, ny))
    for (x, y) in seen: k[y][x] = 1; filled += 1
    d["tiles"] = ["".join(str(v) for v in row) for row in k]; d["cracks"] = []
    open(path, "w").write(json.dumps(d))
    return filled

if __name__ == "__main__":
    if not os.path.isdir("data/world_before_fill"): shutil.copytree("data/world", "data/world_before_fill")
    total = rooms = 0
    for f in sorted(glob.glob("data/world/*.json")):
        n = job(f)
        if n: rooms += 1; total += n
    print("filled", total, "tiles under the floor in", rooms, "rooms")
