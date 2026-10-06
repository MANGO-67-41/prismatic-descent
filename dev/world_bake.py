"""Bakes the fixed world (data/world/*.json) into what the game loads:
  assets/world/art/p_NN.png   1x art for every room and shaft
  assets/world/map.png        the map picture (1 px = 2x2 tiles)
  data/world_runtime.json     piece positions, collision rectangles, rest points, region ranges
Run: python3 dev/world_bake.py   (then Godot --import)"""
import glob, json, os, struct, sys, zlib
from multiprocessing import Pool
sys.path.insert(0, os.path.dirname(__file__))
import overgrowth_art as oa
from overgrowth_art import Room, Canvas, write_png, hexc, lerp
import world_gen as wg

T = 8
REGION_COLOURS = ["8f9d5e", "d0743a", "56a3a6", "d8c9a0", "a98bb0", "a8e0f0"]

def load_room(path):
    d = json.load(open(path))
    r = Room(d["name"], d["sw"], d["sh"], d["depth"], d["threat"], d["foodcount"], d["seed"], tw=d["tw"], th=d["th"], theme=d["theme"])
    r.kind = [[int(c) for c in row] for row in d["tiles"]]
    r.poles = [tuple(p) for p in d["poles"]]; r.marks = [tuple(m) for m in d["marks"]]
    r.food_pos = [tuple(p) for p in d["food"]]; r.pound_food = [tuple(p) for p in d["pound_food"]]
    r.cracks = [tuple(c) for c in d["cracks"]]; r.enemies = []
    r.lake = d.get("lake")
    r.deco = d.get("deco", [])
    return r, d

def rects_of(tiles):
    """Greedy merge of solid tiles into rectangles (tile units). Cracked tiles (3) are left out: they break."""
    th, tw = len(tiles), len(tiles[0]); runs = []
    for y in range(th):
        x = 0
        while x < tw:
            if tiles[y][x] not in "034":
                x0 = x
                while x < tw and tiles[y][x] not in "034": x += 1
                runs.append((x0, y, x - x0))
            else: x += 1
    out = []; open_ = {}
    for (x, y, w) in runs:
        k = (x, w)
        if k in open_ and open_[k][1] + open_[k][3] == y: open_[k][3] += 1
        else:
            r = [x, y, w, 1]; out.append(r); open_[k] = r
    return out

def beams_of(tiles):
    """Runs of beam tiles (4) as [x, y, width] in tile units; they collide only along the top BEAM_H pixels of the tile."""
    out = []
    for y, row in enumerate(tiles):
        x = 0
        while x < len(row):
            if row[x] == "4":
                x0 = x
                while x < len(row) and row[x] == "4": x += 1
                out.append([x0, y, x - x0])
            else: x += 1
    return out

def render_piece(args):
    path, out = args
    r, d = load_room(path)
    oa.set_theme(d["theme"]); oa.JIT_AMP = 1
    write_png(out, oa.render(r), 1)
    return out

def main():
    files = sorted(glob.glob("data/world/[0-9]*.json")); pieces = []
    order = []
    for f in files:
        idx = int(os.path.basename(f).split("_")[0])
        order.append((idx, 0, f))
        sh = "data/world/shaft_%02d.json" % idx
        if os.path.exists(sh): order.append((idx, 1, sh))
    jobs = []; datas = []
    os.makedirs("assets/world/art", exist_ok=True)
    for n, (idx, is_shaft, f) in enumerate(order):
        d = json.load(open(f)); datas.append(d); jobs.append((f, "assets/world/art/p_%03d.png" % n))
    n_main = len(datas)
    wing_files = sorted(glob.glob("data/world/wing_*.json"), key=lambda f: ("shrine" in f, f))   # the lantern shrines come last, so no earlier wing's id moves
    for k, f in enumerate(wing_files):             # wings: rooms built onto the side of a main room, after all main pieces
        d = json.load(open(f)); datas.append(d); jobs.append((f, "assets/world/art/p_%03d.png" % (n_main + k)))
    # shafts and wings are rendered through the same Room path (they are Rooms too)
    with Pool(8) as pool: pool.map(render_piece, jobs, chunksize=1)
    # stitch: the exit hole of each piece lines up with the entry hole of the next
    xs = []; prev_out = 0; y = 0; ys = []
    for i, d in enumerate(datas[:n_main]):
        ent = (d["entry_tile"] or 0) * T if d["kind"] == "room" else 56
        ext = d["exit_tile"] * T if d["kind"] == "room" else 56
        x0 = 0 if i == 0 else prev_out - ent
        xs.append(x0); ys.append(y); prev_out = x0 + ext; y += d["th"] * T
    room_piece = {int(os.path.basename(f).split("_")[0]): n for n, (idx, is_shaft, f) in enumerate(order) if not is_shaft}
    for d in datas[n_main:]:                       # a wing sits beside its host, its floor level with the host's floor
        h = room_piece[d["host"]]; hw = datas[h]["tw"] * T
        xs.append(xs[h] - d["tw"] * T if d["side"] < 0 else xs[h] + hw)
        ys.append(ys[h] + int(d["host_dy"]) * T)
    minx = min(xs); pad = 0
    pcs = []; region_of = lambda d: wg_region(d)
    names = [r[0] for r in wg.REGIONS]; themes = [r[1] for r in wg.REGIONS]
    for i, d in enumerate(datas):
        ri = themes.index(d["theme"])
        wing = i >= n_main
        piece = dict(id=i, kind=d["kind"], name=d["name"], region=ri, x=xs[i] - minx, y=ys[i], w=d["tw"] * T, h=d["th"] * T,
                     art="res://assets/world/art/p_%03d.png" % i, rects=rects_of(d["tiles"]), beams=beams_of(d["tiles"]),
                     entry=[(d["entry_tile"] or 0) * T, 0] if d["kind"] == "room" else [56, 0],
                     exit=[0, d["th"] * T] if wing else [(d["exit_tile"] * T) if d["kind"] == "room" else 56, d["th"] * T],
                     rest=[[m[1], m[2]] for m in d["marks"] if m[0] == "rest"],
                     start=[[m[1], m[2]] for m in d["marks"] if m[0] == "start"], first=bool(d.get("first")),
                     margin=d.get("margin", 0), threat=d.get("threat", 0), ropes=d.get("ropes", []), theme=d["theme"],
                     props=d.get("props", []), creatures=d.get("creatures", []),
                     cracks=[[x, y] for y, row in enumerate(d["tiles"]) for x, c in enumerate(row) if c == "3"])
        if wing: piece.update(wing=True, wing_kind=d["wing_kind"], host=room_piece[d["host"]], side=d["side"])
        pcs.append(piece)
    W = max(p["x"] + p["w"] for p in pcs); H = y
    # map picture: 1 px = 2x2 tiles
    S = 16; mw, mh = W // S + 2, H // S + 2
    mp = Canvas(mw, mh, (0, 0, 0)); alpha = [[0] * mw for _ in range(mh)]
    for p, d in zip(pcs, datas):
        col = hexc(REGION_COLOURS[p["region"]]); wall = lerp(hexc("120d14"), col, .22); openc = lerp(hexc("120d14"), col, .55); plat = lerp(col, (255, 255, 255), .35)
        tiles = d["tiles"]
        for ty in range(0, d["th"] - 1, 2):
            for tx in range(0, d["tw"] - 1, 2):
                vals = [tiles[ty + a][tx + b] for a in (0, 1) for b in (0, 1)]
                rock = sum(1 for v in vals if v in "13"); metal = sum(1 for v in vals if v == "2")
                c = wall if rock >= 3 else (plat if metal >= 2 and rock == 0 else openc)
                mx, my = (p["x"] + tx * T) // S, (p["y"] + ty * T) // S
                if 0 <= mx < mw and 0 <= my < mh: mp.p[my][mx] = c; alpha[my][mx] = 1
    # PNG with alpha
    raw = bytearray()
    for y2 in range(mh):
        raw.append(0)
        for x2 in range(mw):
            c = mp.p[y2][x2]; raw += bytes(c) + (b"\xff" if alpha[y2][x2] else b"\x00")
    def chunk(t, dd):
        c = struct.pack(">I", len(dd)) + t + dd
        return c + struct.pack(">I", zlib.crc32(t + dd) & 0xffffffff)
    os.makedirs("assets/world", exist_ok=True)
    open("assets/world/map.png", "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", mw, mh, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
    regions = []
    for ri, name in enumerate(names):
        mine = [p for p in pcs if p["region"] == ri and not p.get("wing")]
        regions.append(dict(name=name, theme=themes[ri], colour="#" + REGION_COLOURS[ri], y0=mine[0]["y"], y1=mine[-1]["y"] + mine[-1]["h"], first=mine[0]["id"], last=mine[-1]["id"]))
    os.makedirs("data", exist_ok=True)
    json.dump(dict(tile=T, width=W, height=H, map_scale=S, map_size=[mw, mh], regions=regions, pieces=pcs), open("data/world_runtime.json", "w"), separators=(",", ":"))
    print("baked", len(pcs), "pieces, world", W, "x", H, "map", mw, "x", mh)

if __name__ == "__main__":
    main()
