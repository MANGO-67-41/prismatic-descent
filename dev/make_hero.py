"""Draws the hero's sprite sheet as real pixel art from posed shapes (no anti-aliasing).
Output: assets/hero/hero_sheet.png (24x24 cells, one row per animation; see ANIMS) and dev/hero_preview.png (8x, labelled).
Run: python3 dev/make_hero.py"""
import math, os, struct, sys, zlib
sys.path.insert(0, os.path.dirname(__file__))

C = 24                     # cell size; the feet sit at (12, 22)
FUR, FUR_HI, SHADE, DEEP = (238, 234, 222), (255, 251, 242), (190, 182, 172), (150, 142, 140)
OUTLINE, EYE, EAR_IN = (29, 22, 32), (18, 13, 20), (214, 186, 178)
SCARF, SCARF_D = (168, 81, 45), (110, 46, 30)
LIGHT = (-0.55, -0.83)

ANIMS = [("idle", 8), ("run", 8), ("jump", 2), ("apex", 1), ("fall", 2), ("land", 2), ("wall", 2), ("climb", 4), ("dash", 2), ("ascend", 4), ("pound", 2), ("eat", 3)]

def ell(px, py, cx, cy, rx, ry, rot=0.0):
    x, y = px + .5 - cx, py + .5 - cy
    if rot:
        c, s = math.cos(rot), math.sin(rot); x, y = x * c + y * s, -x * s + y * c
    return (x / rx) ** 2 + (y / ry) ** 2 <= 1.0

def bez(p0, p1, p2, t):
    a = (1 - t) ** 2; b = 2 * (1 - t) * t; c = t * t
    return (a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1])

def render(P):
    """P: pose dict. Returns 24x24 list of RGBA tuples or None."""
    part = [[None] * C for _ in range(C)]   # (layer colour, shading centre, radius) per pixel
    def paint(test, colour, shade_c=None, r=1.0):
        for y in range(C):
            for x in range(C):
                if test(x, y): part[y][x] = (colour, shade_c, r)
    hx, hy, hr = P["head"]; bx, by, brx, bry = P["body"]
    def ear(base, ang, ln, w, colour):
        cx, cy = base[0] + math.cos(ang) * ln / 2, base[1] + math.sin(ang) * ln / 2
        paint(lambda x, y: ell(x, y, cx, cy, ln / 2, w, ang), colour)
    def tube(pts, w0, w1, colour):
        n = len(pts)
        def t(x, y):
            for i, (qx, qy) in enumerate(pts):
                r = w0 + (w1 - w0) * i / max(1, n - 1)
                if (x + .5 - qx) ** 2 + (y + .5 - qy) ** 2 <= r * r: return True
            return False
        paint(t, colour)
    def limb(a, b, w, colour):
        tube([(a[0] + (b[0] - a[0]) * i / 6, a[1] + (b[1] - a[1]) * i / 6) for i in range(7)], w, w * .9, colour)
    # back to front
    ear((hx - 2.0, hy - hr + 1.8), P["ear"] - 0.3, P["ear_len"] - 0.8, 1.5, SHADE)
    tail = [bez(*P["tail"], i / 18) for i in range(19)]
    tube(tail, P.get("tail_w", 2.3), 0.7, FUR)
    for (a, b) in P.get("legs_back", []): limb(a, b, 1.1, SHADE)
    for (a, b) in P.get("arms_back", []): limb(a, b, 0.8, SHADE)
    paint(lambda x, y: ell(x, y, bx, by, brx, bry, P.get("body_rot", 0.0)), FUR, (bx, by), max(brx, bry))
    for (a, b) in P.get("legs", []): limb(a, b, 1.2, FUR)
    paint(lambda x, y: ell(x, y, hx, hy, hr, hr * 0.95), FUR, (hx, hy), hr)
    ear((hx - 0.6, hy - hr + 1.3), P["ear"], P["ear_len"], 1.7, FUR)
    for (a, b) in P.get("arms", []): limb(a, b, 0.85, FUR)
    img = [[None] * C for _ in range(C)]
    for y in range(C):
        for x in range(C):
            p = part[y][x]
            if not p: continue
            col, sc, r = p
            if col == FUR and sc:
                dx, dy = (x + .5 - sc[0]) / r, (y + .5 - sc[1]) / r
                d = dx * LIGHT[0] + dy * LIGHT[1]
                col = FUR_HI if d > 0.55 else (SHADE if d < -0.45 else FUR)
            img[y][x] = col
    # shade the underside of every part (pixel with nothing below) for weight
    for y in range(C - 1):
        for x in range(C):
            if img[y][x] in (FUR, FUR_HI) and part[y + 1][x] is None: img[y][x] = SHADE
    # scarf: a band where head meets body, with a trailing end
    sy = P.get("scarf_y", hy + hr - 0.5)
    for x in range(C):
        for y in (int(sy), int(sy) + 1):
            if 0 <= y < C and img[y][x] is not None and abs(x + .5 - (bx + hx) / 2) < 4.2:
                img[y][x] = SCARF if y == int(sy) else SCARF_D
    sx0, sy0 = P.get("scarf_tail", (-3, 1))
    for i in range(4):
        tx = int(round((bx + hx) / 2 - 2.5 + sx0 * i / 3)); ty = int(round(sy + 1 + sy0 * i / 3))
        if 0 <= tx < C and 0 <= ty < C: img[ty][tx] = SCARF_D if i % 2 else SCARF
    # eyes: two big dark ovals on the face (the far one smaller), or closed
    ex, ey = hx + P.get("look", 1.0) * 0.5, hy + 0.3
    if P.get("blink"):
        for x in range(int(ex - 2), int(ex + 3)):
            if img[int(ey)][x]: img[int(ey)][x] = EYE
    else:
        # pixel-placed so they stay clean: two tall dark eyes, the near one a little bigger
        nx, ny = int(round(ex + 0.4)), int(round(ey - 1.5))
        for (x, y) in [(nx, ny), (nx + 1, ny), (nx, ny + 1), (nx + 1, ny + 1), (nx, ny + 2), (nx + 1, ny + 2), (nx + 1, ny + 3), (nx, ny + 3)]:
            if 0 <= x < C and 0 <= y < C and img[y][x]: img[y][x] = EYE
        fx = nx - 3
        for (x, y) in [(fx, ny + 1), (fx + 1, ny + 1), (fx, ny + 2), (fx + 1, ny + 2), (fx + 1, ny + 3), (fx + 1, ny)]:
            if 0 <= x < C and 0 <= y < C and img[y][x]: img[y][x] = EYE
    # inner ear tint on the near ear
    # outline: every empty pixel touching the silhouette
    out = [[None] * C for _ in range(C)]
    for y in range(C):
        for x in range(C):
            if img[y][x]: out[y][x] = img[y][x] + (255,)
            elif any(0 <= x + a < C and 0 <= y + b < C and img[y + b][x + a] for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = OUTLINE + (255,)
            else: out[y][x] = (0, 0, 0, 0)
    return out

# ------------------------------------------------------------------ poses (facing right, feet at y=22)
def base(**kw):
    P = dict(head=(13.0, 10.4, 4.6), body=(11.6, 17.6, 4.1, 4.3), ear=-2.2, ear_len=6.2,
             tail=((8.6, 19.5), (3.5, 21.0), (3.0, 13.5)), legs=[((11.0, 19.5), (10.6, 22.0))], legs_back=[((12.6, 19.5), (13.4, 22.0))],
             arms=[((13.0, 15.5), (14.6, 18.2))], scarf_tail=(-3, 1.5))
    P.update(kw); return P

def idle(i):
    s = math.sin(i / 8 * math.tau)
    return base(body=(11.6, 17.6 - s * 0.2, 4.1, 4.3 + s * 0.25), head=(13.0, 10.4 - s * 0.35, 4.6), ear=-2.2 + s * 0.12,
                tail=((8.6, 19.5), (3.5, 21.0 + s), (3.0 + s * 0.4, 13.5 + s * 1.2)), blink=(i == 5))

def run(i):
    p = i / 8 * math.tau; bob = abs(math.sin(p)) * 1.0
    f1 = (12.4 + 3.6 * math.cos(p), 22.0 - max(0.0, math.sin(p)) * 2.2)
    f2 = (12.4 - 3.6 * math.cos(p), 22.0 - max(0.0, -math.sin(p)) * 2.2)
    return base(body=(12.0, 17.4 - bob * .6, 4.3, 4.0), head=(14.4, 11.0 - bob, 4.5), ear=-2.75 + math.sin(p * 2) * 0.12, ear_len=6.8,
                legs=[((12.6, 19.0), f1)], legs_back=[((11.6, 19.0), f2)],
                arms=[((14.0, 15.6), (15.2 + 1.5 * math.cos(p + 3.1), 18.0))], arms_back=[((13.0, 15.6), (13.6 - 1.5 * math.cos(p + 3.1), 18.0))],
                tail=((8.8, 18.6), (4.0, 17.0 + math.sin(p) * 0.8), (0.6, 15.5 + math.sin(p + 1) * 1.3)), scarf_tail=(-4, -0.5 + math.sin(p)), look=1.4)

def jump(i):
    return base(body=(12.0, 16.4 - i * .4, 3.3, 4.5), head=(13.4, 9.6 - i * .4, 4.5), ear=-2.6, ear_len=6.8,
                legs=[((11.8, 19.5), (11.0, 21.6))], legs_back=[((12.6, 19.5), (13.6, 21.0))],
                arms=[((13.2, 14.6), (15.0, 12.6))], tail=((9.0, 19.0), (6.5, 22.5), (4.0, 23.0)), scarf_tail=(-2, 3))

def apex(i):
    return base(body=(12.0, 16.6, 3.9, 3.9), head=(13.3, 10.2, 4.6), ear=-2.95, ear_len=6.6,
                legs=[((11.6, 19.0), (11.0, 21.2))], legs_back=[((12.8, 19.0), (14.0, 20.8))],
                arms=[((13.2, 15.0), (16.0, 15.2))], tail=((8.8, 18.6), (4.5, 18.5), (1.5, 17.5)), scarf_tail=(-3, 0))

def fall(i):
    return base(body=(12.0, 16.8, 3.6, 4.2), head=(13.2, 10.4 + i * .3, 4.6), ear=-1.5 - i * .15, ear_len=6.9,
                legs=[((11.6, 19.5), (11.2, 22.5))], legs_back=[((12.8, 19.5), (13.8, 22.2))],
                arms=[((13.2, 14.8), (15.6, 11.8 + i))], arms_back=[((11.8, 14.8), (9.8, 11.8 + i))],
                tail=((8.8, 18.6), (5.0, 15.5), (4.5, 9.5 - i)), scarf_tail=(-2, -3))

def land(i):
    sq = 1.0 - i * 0.5
    return base(body=(11.8, 18.1 + sq * .5, 3.7 + sq * .7, 3.6 - sq * .5), head=(13.2, 11.6 + sq * 1.2, 4.6), ear=-2.4 + sq * .5,
                arms=[((13.0, 16.4), (15.0, 19.4))], tail=((8.6, 19.8), (3.5, 21.5), (2.5, 15.5 + sq)))

def wall(i):
    return base(body=(11.8, 17.0, 3.6, 4.1), head=(12.8, 10.2, 4.5), ear=-1.75 - i * .1, ear_len=6.7,
                arms=[((13.2, 14.6), (16.2, 12.2 + i))], arms_back=[((12.6, 15.0), (16.0, 15.6 - i))],
                legs=[((12.0, 19.6), (15.6, 21.2))], legs_back=[((11.2, 19.6), (14.6, 22.2))],
                tail=((8.8, 19.0), (5.5, 22.5), (6.5, 23.5)), scarf_tail=(-3, 2), look=1.6)

def climb(i):
    up = i % 2; hand_hi, hand_lo = (12.8, 5.4), (12.8, 9.0)
    a1, a2 = (hand_hi, hand_lo) if up else (hand_lo, hand_hi)
    return base(body=(10.6, 15.8 + (0.4 if up else 0), 3.5, 4.4), head=(11.4, 9.4 + (0.4 if up else 0), 4.5), ear=-1.9 + (0.1 if up else -0.1), ear_len=6.6,
                arms=[((11.8, 13.0), a1)], arms_back=[((11.0, 13.2), a2)],
                legs=[((11.0, 18.6), (12.6, 18.2 + (2 if up else 0)))], legs_back=[((10.2, 18.6), (12.4, 20.6 - (2 if up else 0)))],
                tail=((8.6, 18.6), (6.0, 22.0), (8.5 + (i - 1.5) * 0.6, 23.5)), scarf_tail=(-2, 3), look=0.6)

def dash(i):
    return base(body=(11.4, 17.2, 5.2, 3.0), head=(16.4, 15.2, 4.2), ear=-2.95 - i * .05, ear_len=7.4, body_rot=0.0,
                legs=[((9.4, 18.4), (6.6, 19.8))], legs_back=[((10.4, 18.6), (7.6, 20.6))],
                arms=[((14.4, 16.8), (17.6, 18.6))], tail=((6.6, 17.6), (3.0, 17.4 - i), (0.2, 17.0)), tail_w=2.0,
                scarf_tail=(-5, -0.5 + i), scarf_y=17.8, look=1.2)

def ascend(i):
    b = math.sin(i / 4 * math.tau) * 0.5
    return base(body=(12.0, 16.6 + b, 3.7, 4.6), head=(12.6, 9.6 + b, 4.6), ear=-1.45 + b * 0.1, ear_len=6.8, blink=True,
                arms=[((13.4, 14.0 + b), (17.6, 12.0 + b))], arms_back=[((10.8, 14.0 + b), (6.6, 12.0 + b))],
                legs=[((11.6, 20.0 + b), (11.2, 22.4))], legs_back=[((12.6, 20.0 + b), (13.2, 22.2))],
                tail=((10.0, 20.0 + b), (8.5, 23.0), (10.5 + b, 23.6)), scarf_tail=(-2, 3), look=0.0)

def pound(i):
    return base(body=(12.0, 17.2, 4.4, 4.0), head=(13.6, 13.0 + i * .3, 4.4), ear=-2.9, ear_len=7.2,
                legs=[((12.4, 19.6), (13.6, 21.4))], legs_back=[((11.4, 19.6), (10.2, 21.6))],
                arms=[((13.6, 16.8), (15.6, 19.6))], tail=((8.4, 17.4), (6.0, 12.0 - i), (8.0, 7.5 - i)), scarf_tail=(-1, -4), look=0.8)

def eat(i):
    chew = (0, 0.5, 0)[i]
    return base(body=(11.6, 17.8, 4.1, 4.1), head=(13.2, 11.2 + chew, 4.6), ear=-2.35 - chew * 0.1,
                arms=[((12.8, 15.2), (15.8, 13.6 + chew))], arms_back=[((12.0, 15.4), (15.2, 14.6 + chew))],
                tail=((8.6, 19.5), (3.5, 21.5), (2.6, 15.0 - chew)), blink=(i == 1))

POSES = {"ascend": ascend, "pound": pound, "eat": eat, "idle": idle, "run": run, "jump": jump, "apex": apex, "fall": fall, "land": land, "wall": wall, "climb": climb, "dash": dash}

def write_png(path, rows, w, h):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for px in row: raw += bytes(px)
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))

if __name__ == "__main__":
    cols = max(n for _, n in ANIMS); W, H = cols * C, len(ANIMS) * C
    sheet = [[(0, 0, 0, 0)] * W for _ in range(H)]
    for r, (name, n) in enumerate(ANIMS):
        for i in range(n):
            fr = render(POSES[name](i))
            for y in range(C):
                for x in range(C): sheet[r * C + y][i * C + x] = fr[y][x]
    write_png("assets/hero/hero_sheet.png", sheet, W, H)
    S = 8; bg = (52, 44, 56, 255); prev = [[bg] * (W * S) for _ in range(H * S)]
    for y in range(H * S):
        for x in range(W * S):
            p = sheet[y // S][x // S]
            if p[3]: prev[y][x] = p
            elif (x // S + y // S) % 2: prev[y][x] = (60, 52, 64, 255)
    write_png("dev/hero_preview.png", prev, W * S, H * S)
    print("sheet", W, "x", H)
