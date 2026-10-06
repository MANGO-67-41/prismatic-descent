"""Draws the whole world on one sheet (.shots/world_map_full.png): the six regions side by side, each from its top to its bottom, built
from assets/world/map.png (1 px = 2x2 tiles) with the temples, key chambers, guardians, gates, scroll pedestals and resting places
marked. Run: python3 dev/make_world_poster.py"""
import json, struct, sys, zlib
sys.path.insert(0, "dev")
import overgrowth_art as oa
from overgrowth_art import Canvas, hexc, lerp, write_png

S = 16; Z = 2                                           # map pixel = 16 world px; drawn 2x
def read_png(path):
    d = open(path, "rb").read(); pos = 8; idat = b""; w = h = 0
    while pos < len(d):
        n, t = struct.unpack(">I4s", d[pos:pos + 8]); body = d[pos + 8:pos + 8 + n]; pos += 12 + n
        if t == b"IHDR": w, h = struct.unpack(">II", body[:8])
        elif t == b"IDAT": idat += body
    raw = zlib.decompress(idat); stride = w * 4 + 1
    return w, h, [[tuple(raw[y * stride + 1 + x * 4: y * stride + 5 + x * 4]) for x in range(w)] for y in range(h)]

W, H, img = read_png("assets/world/map.png")
rt = json.load(open("data/world_runtime.json"))
P = rt["pieces"]; R = rt["regions"]
COL = ["8f9d5e", "d0743a", "56a3a6", "d8c9a0", "a98bb0", "a8e0f0"]
BG = hexc("0d0910"); CREAM = hexc("f2e2bc"); DIM = hexc("b9a888"); RUST = hexc("a8512d")

def text(cv, x, y, s, c, k=2):
    for ch in s.upper():
        g = oa.FONT.get(ch, oa.FONT[" "])
        for i, b in enumerate(g):
            if b == "1": cv.rect(x + (i % 3) * k, y + (i // 3) * k, k, k, c)
        x += 4 * k
    return x
def width(s, k): return len(s) * 4 * k

gap = 36; colw = W * Z
heights = []
for r in R: heights.append(((int(r["y1"]) - int(r["y0"])) // S + 2) * Z)
top = 150; bottom = 200
H_out = top + max(heights) + bottom; W_out = len(R) * colw + (len(R) + 1) * gap
cv = Canvas(W_out, H_out, BG)
title = "THE PRISMATIC DESCENT  -  WORLD MAP"
text(cv, (W_out - width(title, 5)) // 2, 22, title, CREAM, 5)
wing_n = sum(1 for p in P if p.get("wing")); lantern_n = sum(len(p["rest"]) for p in P); shrine_n = sum(1 for p in P if p.get("wing_kind") == "shrine")
sub = "%d PIECES  -  %d REGIONS  -  %d WING ROOMS  -  %d LANTERN ROOMS  -  %d RESTING LANTERNS  -  5 GUARDIANS  -  4 KEYS" % (len(P), len(R), wing_n, shrine_n, lantern_n)
text(cv, (W_out - width(sub, 3)) // 2, 70, sub, DIM, 3)
cols = []
for i, r in enumerate(R):
    x0 = gap + i * (colw + gap); y0m = int(r["y0"]) // S
    cols.append((x0, y0m))
    c = hexc(COL[i])
    nm = r["name"]
    text(cv, x0 + (colw - width(nm, 4)) // 2, top - 34, nm, c, 4)
    cv.rect(x0, top - 6, colw, 2, lerp(c, BG, .3))
    # the map slice
    hm = heights[i] // Z
    for my in range(hm):
        for mx in range(W):
            sy = y0m + my
            if sy >= H: continue
            px_ = img[sy][mx]
            if px_[3] == 0: continue
            col = px_[:3]
            for a in range(Z):
                for b in range(Z): cv.px(x0 + mx * Z + b, top + my * Z + a, col)
def pos(piece, x, y, i):
    x0, y0m = cols[i]
    return x0 + int((piece["x"] + x) / S * Z), top + int((piece["y"] + y) / S * Z) - y0m * Z

def diamond(cx, cy, r, c, hollow=False):
    for dy in range(-r, r + 1):
        for dx in range(-(r - abs(dy)), r - abs(dy) + 1):
            edge = abs(dx) + abs(dy) == r
            if not hollow or edge: cv.px(cx + dx, cy + dy, c)
def key_mark(cx, cy, c):
    cv.rect(cx - 3, cy - 5, 7, 7, BG); cv.rect(cx - 2, cy - 4, 5, 5, c); cv.rect(cx - 1, cy - 3, 3, 3, BG)
    cv.rect(cx, cy + 1, 1, 6, c); cv.rect(cx + 1, cy + 4, 2, 1, c); cv.rect(cx + 1, cy + 6, 2, 1, c)

counts = [dict(rooms=0, wings=0, lanterns=0) for _ in R]
for p in P:
    i = p["region"]
    if p["kind"] == "room" and not p.get("wing"): counts[i]["rooms"] += 1
    if p.get("wing"): counts[i]["wings"] += 1
    counts[i]["lanterns"] += len(p["rest"])
    for rest in p["rest"]:
        x, y = pos(p, rest[0], rest[1] - 4, i); diamond(x, y, 3, BG); diamond(x, y, 2, CREAM)
    for pr in p.get("props", []):
        c = hexc(COL[i])
        if pr["t"] == "key": x, y = pos(p, pr["x"], pr["y"] - 8, i); key_mark(x, y, c); key_mark(x + 1, y, c)
        elif pr["t"] == "guardian":
            x, y = pos(p, pr["x"], pr["y"] - 10, i); diamond(x, y, 11, BG); diamond(x, y, 10, hexc("e0483a")); diamond(x, y, 5, BG); diamond(x, y, 2, CREAM)
        elif pr["t"] == "door":
            x, y = pos(p, pr["x"], pr["y"], i); cv.rect(x - 13, y - 2, 26, 7, BG); cv.rect(x - 12, y - 1, 24, 5, hexc("a8e0f0") if pr["id"] == "seal" else c)
        elif pr["t"] == "scroll":
            x, y = pos(p, pr["x"], pr["y"] - 4, i); cv.rect(x - 3, y - 3, 7, 7, BG); cv.rect(x - 2, y - 2, 5, 5, hexc("f6dca8"))
# wings: an outline and a name, so the rooms built onto the sides stand out
for p in P:
    if not p.get("wing"): continue
    i = p["region"]; x, y = pos(p, 0, 0, i); w = p["w"] // S * Z; h = p["h"] // S * Z
    for t in (0, 1):
        cv.rect(x - t, y - t, w + 2 * t, 1, CREAM); cv.rect(x - t, y + h + t, w + 2 * t, 1, CREAM); cv.rect(x - t, y - t, 1, h + 2 * t, CREAM); cv.rect(x + w + t, y - t, 1, h + 2 * t, CREAM)
    nm = {"temple": "TEMPLE", "key": "KEY ROOM", "ruin": "OLD HALL", "ruin2": "QUIET SHRINE", "shrine": "LANTERN ROOM"}[p["wing_kind"]]
    ly_ = y - 14 if y - 14 > top + 4 else y + h + 5                       # under the box when there is no room above it
    text(cv, x + (w - width(nm, 2)) // 2, ly_, nm, CREAM, 2)
ABILITY = ["", "GROUND POUND", "DOUBLE JUMP", "INVINCIBLE DASH", "FAST HEAL", ""]
ROSTER = ["SPROUT  MOSS  BLOOM  BARK", "SPARK  KITE  HOUND  SLAG", "DRIP  ANGLER  MIRE  LEVIATHAN", "PALE  CRYPT  VULTURE  WORM", "WYRM  CINDER  VULTURE  WRAITH", ""]
for i, r in enumerate(R):
    x0, _ = cols[i]
    n_cr = sum(len(p.get("creatures", [])) for p in P if p["region"] == i)
    lines = ["%d ROOMS  +  %d WINGS" % (counts[i]["rooms"], counts[i]["wings"]) if counts[i]["wings"] else "%d ROOM" % counts[i]["rooms"],
             "%d RESTING LANTERN%s" % (counts[i]["lanterns"], "" if counts[i]["lanterns"] == 1 else "S")]
    if ABILITY[i]: lines.append("GIFT: " + ABILITY[i])
    if n_cr: lines.append("%d CREATURES" % n_cr)
    for k, t in enumerate(lines):
        text(cv, x0 + (colw - width(t, 3)) // 2, top + heights[i] + 12 + k * 18, t, DIM, 3)
    if ROSTER[i]:
        t = ROSTER[i]
        text(cv, x0 + (colw - width(t, 2)) // 2, top + heights[i] + 12 + len(lines) * 18 + 4, t, lerp(DIM, BG, .25), 2)
# legend
lx = 60; ly = H_out - 64
cv.rect(40, ly - 18, W_out - 80, 2, lerp(DIM, BG, .6))
def legend(x, draw, label):
    draw(x + 10, ly + 14); text(cv, x + 34, ly + 6, label, CREAM, 3); return x + 40 + width(label, 3)
x = lx
x = legend(x, lambda a, b: (diamond(a, b, 3, BG), diamond(a, b, 2, CREAM)), "RESTING PLACE")
x = legend(x + 30, lambda a, b: (cv.rect(a - 2, b - 2, 5, 5, BG), cv.rect(a - 1, b - 1, 3, 3, hexc("f6dca8"))), "SCROLL")
x = legend(x + 30, lambda a, b: key_mark(a, b + 2, hexc("d0743a")), "KEY")
x = legend(x + 30, lambda a, b: (diamond(a, b, 7, BG), diamond(a, b, 6, hexc("e0483a")), diamond(a, b, 3, BG), diamond(a, b, 1, CREAM)), "CRYSTAL GUARDIAN")
x = legend(x + 30, lambda a, b: (cv.rect(a - 8, b - 1, 16, 4, BG), cv.rect(a - 7, b, 14, 2, hexc("8f9d5e"))), "GATE: WANTS A KEY")
x = legend(x + 30, lambda a, b: (cv.rect(a - 8, b - 1, 16, 4, BG), cv.rect(a - 7, b, 14, 2, hexc("a8e0f0"))), "SEAL: FIVE GUARDIANS")
text(cv, lx, H_out - 26, "WINGS ARE THE ROOMS BUILT ONTO THE SIDES OF THE MAIN DESCENT - A RUINED HALL - A KEY CHAMBER - A GUARDIAN TEMPLE - AND THREE LANTERN ROOMS WITH NO ENEMIES AND ONE RESTING LANTERN EACH - IN EVERY REGION", DIM, 2)
write_png(".shots/world_map_full.png", cv, 1)
print("wrote .shots/world_map_full.png", W_out, "x", H_out)
