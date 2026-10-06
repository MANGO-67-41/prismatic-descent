"""Concept art and layouts for THE OVERGROWTH (region 1), in the game's pixel style. Not used by the game yet.
Run: python3 dev/overgrowth_art.py   -> dev/overgrowth/*.png
One screen = 480x272 px = 60x34 tiles of 8 px (the game camera shows 480x270), like a Rain World room screen."""
import colorsys, math, random, struct, zlib

TILE, SW, SH = 8, 480, 272
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
def hexc(s): return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
def lerp(a, b, t): return (int(a[0]+(b[0]-a[0])*t), int(a[1]+(b[1]-a[1])*t), int(a[2]+(b[2]-a[2])*t))
def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v); return (int(r*255), int(g*255), int(b*255))
def dith(t, x, y): return t > (BAYER[y & 3][x & 3] + .5) / 16
def hsh(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 2147483629) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0

SKY0 = [hexc(c) for c in ["c4875a", "a8583f", "7a3a3c", "4a2a40", "2e2238", "1b1d2e", "11202a", "0a1519"]]
SKY = list(SKY0)
INK, CREAM, DIM, RUST, RUSTD = hexc("120d14"), hexc("f2e2bc"), hexc("b9a888"), hexc("a8512d"), hexc("5a2a22")
TEAL = hexc("4fb3b3")

THEMES = {
 "overgrowth": dict(sky=["c4875a", "a8583f", "7a3a3c", "4a2a40", "2e2238", "1b1d2e", "11202a", "0a1519"], tint="1f4a44", haze=("4a2a40", "11202a"),
     moss_bg="5f7040", canopy=("34452e", "1c2a1c"), body=("1c1418", "251a1d", "120d10"), moss=(("6b7a3c", "9aa860"), ("3e5a3a", "6f9a5a")),
     vine=("2a3a20", "4a5a30"), grass=("141a12", "1c2a1c"), rim="7a4128", extra="", gears=1, canopy_n=1.0),
 "rustworks": dict(sky=["d08a4a", "b0602f", "8a4a30", "5a3430", "3a2630", "261c26", "1a141c", "100c12"], tint="3a2214", haze=("5a2a22", "1a1218"),
     moss_bg="8a5a2a", canopy=("4a2a1c", "2a1a14"), body=("2a1a18", "331f1c", "160d0d"), moss=(("8a5a2a", "c4803a"), ("6a4020", "a8602a")),
     vine=("3a2418", "7a4a24"), grass=("201410", "34201a"), rim="a8512d", extra="steam", gears=3, canopy_n=.4),
 "drowned": dict(sky=["9cc0b8", "7aa0a0", "5a8494", "42647c", "2c4460", "1e3048", "14223a", "0c1628"], tint="14323a", haze=("2c4460", "0c1628"),
     moss_bg="3a7a70", canopy=("2a5a50", "163a38"), body=("14202a", "1a2a32", "0c141a"), moss=(("3a7a70", "6ab0a0"), ("2a6a60", "58a898")),
     vine=("1a3a38", "3a7a70"), grass=("0e1c20", "16302e"), rim="3a5a60", extra="water", gears=1, canopy_n=.8),
 "bone": dict(sky=["dccfb2", "bcae94", "948672", "6c6058", "4c424a", "34303c", "24222e", "181820"], tint="2a2a30", haze=("4c424a", "181820"),
     moss_bg="a8a080", canopy=("5a5448", "383430"), body=("3a342f", "463f38", "22201e"), moss=(("a8a080", "d8d0b0"), ("8a8468", "c0b894")),
     vine=("4a4438", "8a8468"), grass=("2a2822", "3a3830"), rim="b9a888", extra="ribs", gears=0, canopy_n=.35),
 "lake": dict(sky=["3a3466", "2e2a58", "25224a", "1d1b3e", "171632", "121228", "0e0e20", "0a0a18"], tint="2a3a5a", haze=("2e2a58", "0a0a18"),
     moss_bg="7ab0c0", canopy=("2a3a50", "182434"), body=("1a1828", "221f33", "100e1a"), moss=(("6aa8b8", "a8e0e8"), ("5a98b0", "98d8e8")),
     vine=("2a4a58", "7ab8c8"), grass=("141a2a", "1e2a3a"), rim="8ab0d0", extra="lake", gears=0, canopy_n=0.0, scenery="cavern"),
 "ash": dict(sky=["6a3a50", "52304a", "3c2440", "2c1a34", "20142a", "160e20", "100a18", "0a060e"], tint="2a1020", haze=("3c2440", "0a060e"),
     moss_bg="6a4a50", canopy=("3a2a38", "20141e"), body=("1c1420", "251a28", "100a14"), moss=(("6a4a58", "9a6a70"), ("5a3a48", "8a5a64")),
     vine=("2a1a26", "5a3a48"), grass=("160e18", "22141e"), rim="7a4a5a", extra="embers", gears=1, canopy_n=.3),
}
TH = {}
def set_theme(name):
    global SKY, MOSS_BG
    TH.clear(); TH.update(THEMES[name])
    SKY[:] = [hexc(c) for c in TH["sky"]]
    MOSS_BG = hexc(TH["moss_bg"])
set_theme("overgrowth")

class Room:
    def __init__(self, name, sw, sh, depth, threat, food, seed=1, tw=None, th=None, theme="overgrowth"):
        self.name, self.sw, self.sh, self.depth, self.threat, self.food, self.seed = name, sw, sh, depth, threat, food, seed
        self.theme, self.food_pos, self.cracks, self.pound_food = theme, None, [], []
        self.tw, self.th = tw or sw * 60, th or sh * 34
        self.W, self.H = self.tw * TILE, self.th * TILE
        self.kind = [[0]*self.tw for _ in range(self.th)]     # 0 air, 1 rock, 2 metal
        self.poles, self.enemies, self.bulbs, self.marks = [], [], [], []   # poles in px, marks: (kind, x, y)
    def fill(self, x, y, w, h, k):
        for yy in range(max(0, y), min(self.th, y + h)):
            for xx in range(max(0, x), min(self.tw, x + w)): self.kind[yy][xx] = k
    def rock(self, x, y, w, h): self.fill(x, y, w, h, 1)
    def metal(self, x, y, w, h, pole_to=None):
        self.fill(x, y, w, h, 2)
        if pole_to: self.poles.append(((x + w // 2) * TILE, (y + h) * TILE, pole_to * TILE))
    def pole(self, x, y0, y1): self.poles.append((x * TILE, y0 * TILE, y1 * TILE))

# ---------------------------------------------------------------- canvas helpers
class Canvas:
    def __init__(self, W, H, c=INK):
        self.W, self.H = W, H
        self.p = [[c]*W for _ in range(H)]
    def px(self, x, y, c):
        if 0 <= x < self.W and 0 <= y < self.H: self.p[y][x] = c
    def get(self, x, y): return self.p[y][x] if 0 <= x < self.W and 0 <= y < self.H else INK
    def rect(self, x, y, w, h, c):
        for yy in range(max(0, y), min(self.H, y + h)):
            row = self.p[yy]
            for xx in range(max(0, x), min(self.W, x + w)): row[xx] = c
    def line(self, x0, y0, x1, y1, c, th=1):
        dx, dy = abs(x1-x0), -abs(y1-y0); sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1); e = dx + dy
        while True:
            for a in range(th):
                for b in range(th): self.px(x0 + a, y0 + b, c)
            if x0 == x1 and y0 == y1: break
            e2 = 2 * e
            if e2 >= dy: e += dy; x0 += sx
            if e2 <= dx: e += dx; y0 += sy
    def disc(self, cx, cy, r, c):
        for y in range(int(cy-r), int(cy+r)+1):
            for x in range(int(cx-r), int(cx+r)+1):
                if (x-cx)**2 + (y-cy)**2 <= r*r + .5: self.px(x, y, c)
    def ring(self, cx, cy, r, th, c):
        for y in range(int(cy-r), int(cy+r)+1):
            for x in range(int(cx-r), int(cx+r)+1):
                d = math.hypot(x-cx, y-cy)
                if r - th <= d <= r: self.px(x, y, c)

def write_png(path, cv, scale=1):
    raw = bytearray()
    for row in cv.p:
        line = b"".join(bytes(c) * scale for c in row)
        for _ in range(scale): raw += b"\x00" + line
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", cv.W*scale, cv.H*scale, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))

# ---------------------------------------------------------------- sky and distant structures
def sky_at(r, x, y):
    yf = y / r.H
    glow = max(0.0, 1.0 - math.hypot(x - r.W * .62, y + 40) / (r.W * .55))
    t = max(0.0, min(1.0, 0.04 + r.depth * 0.46 + yf * 0.30 * (1 - r.depth * .4) - glow * 0.18 * (1 - r.depth))) * 7
    i = min(int(t), 6)
    c = SKY[i + 1] if dith(t - i, x, y) else SKY[i]
    return lerp(c, hexc(TH["tint"]), r.depth * .38) if r.depth > .3 else c

def fog_band(cv, r, y0, y1, strength, top_heavy=False):
    for y in range(max(0, y0), min(cv.H, y1)):
        u = (y - y0) / max(1, y1 - y0)
        t = strength * (1 - u if top_heavy else u)
        for x in range(cv.W):
            if dith(t, x, y):
                s = sky_at(r, x, y)
                cv.p[y][x] = lerp(cv.p[y][x], lerp(s, CREAM, .12), .55)

MOSS_BG = hexc("5f7040")
def fuzz(cv, x0, x1, y, c, amt=.5, rng=None):
    rng = rng or random
    for x in range(x0, x1):
        if rng.random() < amt:
            for m in range(rng.randint(1, 3)): cv.px(x, y - 1 - m, c if m < 2 else lerp(c, INK, .3))

def pipe_h(cv, x0, x1, y, th, c, hi):
    cv.rect(x0, y, x1 - x0, th, c); cv.rect(x0, y, x1 - x0, 1, hi); cv.rect(x0, y + th - 1, x1 - x0, 1, lerp(c, INK, .4))
    fuzz(cv, x0, x1, y, lerp(c, MOSS_BG, .5), .45)
    for fx in range(x0 + 20, x1, 46): cv.rect(fx, y - 2, 3, th + 4, lerp(c, INK, .25))
def pipe_v(cv, x, y0, y1, th, c, hi):
    cv.rect(x, y0, th, y1 - y0, c); cv.rect(x, y0, 1, y1 - y0, hi); cv.rect(x + th - 1, y0, 1, y1 - y0, lerp(c, INK, .4))
    for fy in range(y0 + 16, y1, 40): cv.rect(x - 2, fy, th + 4, 3, lerp(c, INK, .25))
def elbow(cv, x, y, th, c, hi, sx, sy):
    for a in range(th):
        for b in range(th):
            if a * a + b * b <= th * th: cv.px(x + a * sx, y + b * sy, c)

def tower(cv, rng, x, w, top, bot, c, hi, win):
    cv.rect(x, top, w, bot - top, c)
    cv.rect(x, top, w, 2, hi); cv.rect(x + w // 2 - 3, top - 6, 6, 6, c)
    fuzz(cv, x, x + w, top, lerp(c, MOSS_BG, .55), .6, rng)
    for vx in range(x, x + w, 5):
        if rng.random() < .5:
            for m in range(rng.randint(4, 22)): cv.px(vx + int(math.sin(m * .3 + vx) * 1.2), top + 2 + m, lerp(c, MOSS_BG, .45))
    for ty in range(top + 10, bot - 6, 9):
        if rng.random() < .8:
            for wx in range(x + 4, x + w - 5, 7):
                if rng.random() < .55: cv.rect(wx, ty, 3, 4, win if rng.random() < .15 else lerp(c, INK, .35))
    if rng.random() < .5: cv.rect(x - 3, top + rng.randint(12, 40), w + 6, 3, lerp(c, INK, .2))

def tank(cv, cx, cy, rr, c, hi):
    cv.disc(cx, cy, rr, c)
    for a in range(-rr, rr):
        cv.px(cx + a, cy - int(math.sqrt(max(0, rr*rr - a*a))), hi)
    for lx in (-rr * .6, 0, rr * .6): cv.rect(int(cx + lx) - 1, cy + rr - 2, 3, 40, c)
    cv.rect(cx - rr, cy + rr + 18, rr * 2, 2, c)

def gantry(cv, x0, x1, y, h, c, hi):
    cv.rect(x0, y, x1 - x0, 3, c); cv.rect(x0, y + h, x1 - x0, 3, c); cv.rect(x0, y, x1 - x0, 1, hi)
    fuzz(cv, x0, x1, y, lerp(c, MOSS_BG, .5), .35)
    for bx in range(x0, x1 - 12, 12):
        cv.line(bx, y + 3, bx + 12, y + h, c); cv.line(bx + 12, y + 3, bx, y + h, c)

def gear(cv, cx, cy, rr, c, hi):
    cv.ring(cx, cy, rr, 5, c); cv.ring(cx, cy, rr - 5, 1, hi); cv.disc(cx, cy, 6, c)
    for k in range(8):
        a = k * math.pi / 4 + .2
        cv.line(cx, cy, int(cx + math.cos(a) * rr), int(cy + math.sin(a) * rr), c, 2)
    for k in range(24):
        a = k * math.pi / 12
        cv.px(int(cx + math.cos(a) * (rr + 2)), int(cy + math.sin(a) * (rr + 2)), c)

def cable(cv, x0, y0, x1, y1, sag, c, rng, fuzz=True):
    n = abs(x1 - x0)
    pts = []
    for i in range(n + 1):
        u = i / max(1, n)
        x = x0 + (x1 - x0) * u; y = y0 + (y1 - y0) * u + sag * 4 * u * (1 - u)
        pts.append((int(x), int(y)))
    for (x, y) in pts:
        cv.px(x, y, c); cv.px(x, y + 1, c)
        if fuzz and rng.random() < .35: cv.px(x + rng.choice((-1, 1)), y + rng.randint(2, 4), lerp(c, hexc("4a5a30"), .5))
    return pts

def canopy(cv, r, rng, base, col, count, size, top_fuzz):
    for _ in range(count):
        cx = rng.randint(-10, cv.W + 10); cy = base - rng.randint(0, 14)
        for _ in range(rng.randint(10, 18)):
            dx, dy = rng.gauss(0, size), rng.gauss(-size * .5, size * .45)
            cv.disc(int(cx + dx), int(cy + dy), rng.randint(4, 8), col if rng.random() < .7 else lerp(col, MOSS_BG, .35))
        fuzz(cv, int(cx - size * 1.5), int(cx + size * 1.5), int(cy - size * .9), col, .1, rng)
    cv.rect(0, base, cv.W, cv.H - base, col)

def floor_top(r):
    for ty in range(r.th - 1, 0, -1):
        if sum(1 for v in r.kind[ty] if v) > r.tw * .5 and not sum(1 for v in r.kind[ty - 1] if v) > r.tw * .5:
            return ty * TILE
    return r.H - 40

def cavern_background(cv, r, rng):
    """The Prismatic Lake: a vast cave lit from below by the lake. Distant rock, giant crystal columns, light motes."""
    for y in range(cv.H):
        t = y / cv.H
        for x in range(cv.W):
            cv.p[y][x] = sky_at(r, x, int(cv.H * (1 - t) * 0.9))        # darker above, lit near the water
    def column(cx, base, w, h, hue, shade):
        for y in range(max(0, base - h), min(cv.H, base)):
            top = base - h
            taper = min(1.0, (y - top) / max(1, w * 0.8))
            half = int(w / 2 * taper)
            for x in range(cx - half, cx + half + 1):
                if 0 <= x < cv.W:
                    face = (x - cx) / max(1, half)
                    v = 0.55 + 0.25 * (1 - abs(face)) if face < 0.15 else 0.4
                    c = hsv(hue + face * 0.03, 0.35, v * shade)
                    cv.p[y][x] = lerp(cv.p[y][x], c, 0.55 * shade)
            if 0 <= cx - half < cv.W: cv.p[y][max(0, cx - half)] = lerp(cv.p[y][max(0, cx - half)], hsv(hue, 0.25, 0.95), 0.4 * shade)
    for layer, (count, shade) in enumerate(((10, 0.55), (6, 0.85))):
        for _ in range(count * r.sw):
            cx = rng.randint(0, cv.W); w = rng.randint(14, 30) * (layer + 1) // 2 + 6; h = rng.randint(80, cv.H - 40)
            column(cx, cv.H - 40, w, h, rng.uniform(0.5, 0.8), shade)
        fog_band(cv, r, cv.H // 3, cv.H, 0.5)
    # stalactites from the ceiling
    for _ in range(14 * r.sw):
        x = rng.randint(0, cv.W); L = rng.randint(10, 60); w = rng.randint(3, 8)
        for y in range(L):
            hw = int(w * (1 - y / L))
            for xx in range(x - hw, x + hw + 1):
                if 0 <= xx < cv.W and y < cv.H: cv.p[y][xx] = lerp(cv.p[y][xx], hexc("0c0a16"), 0.7)
    # light motes
    for _ in range(cv.W * cv.H // 700):
        x, y = rng.randint(0, cv.W - 1), rng.randint(0, cv.H - 1)
        cv.p[y][x] = hsv(rng.uniform(0.45, 0.85), 0.35, 1.0)

def background(cv, r, rng):
    if TH.get("scenery") == "cavern":
        return cavern_background(cv, r, rng)
    d = r.depth
    for y in range(cv.H):
        for x in range(cv.W): cv.p[y][x] = sky_at(r, x, y)
    haze = lerp(hexc(TH["haze"][0]), hexc(TH["haze"][1]), d)
    # far layer: pale towers, tanks, long pipes (strongly fogged)
    far = lerp(sky_at(r, cv.W // 2, cv.H // 2), haze, .28); farhi = lerp(far, CREAM, .12)
    base = cv.H - int(60 * (1 - d * .4))
    x = -10
    while x < cv.W:
        w = rng.randint(26, 52); top = base - rng.randint(70, 190 if r.sh > 1 else 130)
        tower(cv, rng, x, w, top, cv.H, far, farhi, lerp(far, hexc("c4875a"), .5))
        if rng.random() < .35: tank(cv, x + w // 2, top - 12, rng.randint(12, 18), far, farhi)
        x += w + rng.randint(-6, 22)
    pipe_h(cv, 0, cv.W, base - 52, 9, far, farhi)
    fog_band(cv, r, base - 120, cv.H, .8)
    ft = floor_top(r)
    canopy(cv, r, rng, ft + 4, lerp(sky_at(r, cv.W // 2, ft), hexc(TH["canopy"][0]), .55), int((5 + r.sw * 3) * TH["canopy_n"]), 26, True)
    fog_band(cv, r, ft - 70, ft + 6, .55)
    # mid layer: darker gantries, big pipes, gear, hanging cables
    mid = lerp(sky_at(r, cv.W // 2, cv.H // 2), haze, .5); midhi = lerp(mid, RUST, .35)
    for _ in range(max(2, r.sw * r.sh * 2)):
        gx = rng.randint(0, max(1, cv.W - 120)); gy = rng.randint(40, max(60, cv.H - 150))
        gantry(cv, gx, gx + rng.randint(90, 200), gy, rng.randint(16, 26), mid, midhi)
    for _ in range(r.sw * r.sh):
        px_ = rng.randint(min(60, cv.W // 3), max(cv.W // 3 + 1, cv.W - 60)); py_ = rng.randint(40, max(60, cv.H - 140)); L = rng.randint(80, 160)
        th = rng.randint(10, 14)
        pipe_h(cv, px_, px_ + L, py_, th, mid, midhi); pipe_v(cv, px_ + L - th, py_ + th, min(cv.H, py_ + th + rng.randint(60, 140)), th, mid, midhi)
        elbow(cv, px_ + L - th, py_, th, mid, midhi, 1, 1)
    for gi in range(TH["gears"] if (r.depth > .3 or TH["gears"] > 1) else 0):
        gear(cv, rng.randint(min(40, cv.W // 3), max(cv.W // 3 + 1, cv.W - 40)), rng.randint(36, max(60, cv.H // 2)), rng.randint(24, 40), lerp(mid, INK, .35), midhi)
    fog_band(cv, r, 0, cv.H, .35)
    canopy(cv, r, rng, ft + 6, lerp(sky_at(r, cv.W // 2, ft), hexc(TH["canopy"][1]), .72), int((4 + r.sw * 3) * TH["canopy_n"]), 20, True)
    # light shafts through the canopy (stronger near the surface)
    for _ in range(2 + r.sw):
        sx = rng.randint(0, cv.W); wd = rng.randint(14, 30); slope = rng.uniform(.25, .6)
        for y in range(cv.H):
            for x in range(int(sx + y * slope), int(sx + y * slope) + wd):
                if 0 <= x < cv.W and dith(.2 * (1 - y / cv.H * .6), x, y):
                    cv.p[y][x] = lerp(cv.p[y][x], lerp(CREAM, hexc("c4875a"), .4), .22)
    # sagging cables across the chamber
    near = lerp(INK, hexc("1c1418"), .5)
    for _ in range(r.sw + 1):
        x0 = rng.randint(0, cv.W // 2); x1 = rng.randint(cv.W // 2, cv.W)
        y0 = rng.randint(10, 70); cable(cv, x0, y0, x1, y0 + rng.randint(-20, 30), rng.randint(60, 120), lerp(near, hexc("2a2a22"), .4), rng)

# ---------------------------------------------------------------- terrain
JIT_AMP = 3
BEAM_H = 4   # pixels thick; the same number is the collision height in world.gd
def solid_masks(r):
    seed = r.seed
    def grid(k):
        return [[(1 if (r.kind[ty][tx] == k or (k == 1 and r.kind[ty][tx] == 3)) else 0) for tx in range(r.tw)] for ty in range(r.th)]
    rock, metal = grid(1), grid(2)
    def jit(vals, n, amp, s): return [int((hsh(i // 3, 0, s) - .5) * 2 * amp + .5) for i in range(n)]
    dx = jit(None, r.H, JIT_AMP, seed + 1); dy = jit(None, r.W, JIT_AMP, seed + 2)
    mask = [[0]*r.W for _ in range(r.H)]
    for y in range(r.H):
        for x in range(r.W):
            tx, ty = x // TILE, y // TILE
            if metal[ty][tx]: mask[y][x] = 2; continue
            if r.kind[ty][tx] == 4:                  # beam: a thin bar sprouting from the wall, the top half of its tile
                if y % TILE < BEAM_H: mask[y][x] = 2
                continue
            xx = min(r.W - 1, max(0, x + dx[y])); yy = min(r.H - 1, max(0, y + dy[x]))
            if rock[yy // TILE][xx // TILE]: mask[y][x] = 1
    return mask

def paint_terrain(cv, r, mask, rng):
    W, H = r.W, r.H
    body_a, body_b, mortar = [hexc(c) for c in TH["body"]]
    deep = r.depth
    moss = lerp(hexc(TH["moss"][0][0]), hexc(TH["moss"][1][0]), deep); moss_hi = lerp(hexc(TH["moss"][0][1]), hexc(TH["moss"][1][1]), deep)
    unders = []
    for y in range(H):
        row = mask[y]
        for x in range(W):
            k = row[x]
            if not k: continue
            up = mask[y - 1][x] if y else 0
            if k == 1:
                brick_row = (y // 8); off = 8 if brick_row % 2 else 0
                c = body_a if hsh(x // 16, y // 8, r.seed) < .55 else body_b
                if y % 8 == 0 or (x + off) % 16 == 0: c = mortar
                elif hsh(x, y, r.seed + 5) < .04: c = lerp(c, RUSTD, .6)
                # depth: deeper rooms take a green-black cast
                if deep > .4 and hsh(x, y, 9) < deep * .08: c = lerp(c, hexc("1c2a22"), .8)
                cv.p[y][x] = c
            else:
                c = hexc("3a201e")
                if y % 16 == 0 or x % 24 == 0: c = RUSTD
                elif (x % 24 in (3, 20)) and (y % 16 in (3, 12)): c = RUST
                elif hsh(x, y, r.seed + 7) < .05: c = hexc("4a2a22")
                cv.p[y][x] = c
    # edges: rim light on top, moss on top, hanging-vine anchors under overhangs
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            k = mask[y][x]
            if not k: continue
            if not mask[y - 1][x]:
                cv.p[y][x] = lerp(RUST, CREAM, .1) if k == 2 else lerp(hexc(TH["rim"]), moss_hi, deep * .6)
                if k == 2:
                    if hsh(x // 3, y, 31) < .75:
                        cv.p[y][x] = moss_hi
                        for m in range(1, 2 + int(hsh(x, y, 33) * 3)):
                            if y + m < H and mask[y + m][x] == 2: cv.p[y + m][x] = moss
                    if hsh(x, y, 35) < .22:
                        for m in range(rng.randint(2, 6)): cv.px(x, y - 1 - m, moss if m % 2 else lerp(moss, INK, .45))
                if k == 1:
                    for m in range(1, 3 + int(hsh(x, y, 3) * 4)):
                        if y + m < H and mask[y + m][x] and hsh(x, y + m, 4) < .8: cv.p[y + m][x] = moss if m > 1 else moss_hi
                    if hsh(x, y, 11) < .12:
                        for m in range(rng.randint(2, 5)): cv.px(x, y - 1 - m, moss if m % 2 else lerp(moss, INK, .5))
            elif not mask[y + 1][x]:
                cv.p[y][x] = lerp(cv.p[y][x], INK, .5)
                if hsh(x, y, 13) < .09: unders.append((x, y))
            if not mask[y][x - 1] or not mask[y][x + 1]:
                cv.p[y][x] = lerp(cv.p[y][x], INK, .45)
                if k == 1 and hsh(x, y, 17) < .1:
                    cv.px(x + (1 if not mask[y][x + 1] else -1), y, moss)
    return unders

def beam_drips(cv, r, rng):
    """Short dark moss threads hanging from the underside of every beam, so a thin bar reads as grown, not placed."""
    moss = lerp(hexc(TH["moss"][0][0]), hexc(TH["moss"][1][0]), r.depth)
    for ty in range(r.th):
        for tx in range(r.tw):
            if r.kind[ty][tx] != 4: continue
            y0 = ty * TILE + BEAM_H
            for x in range(tx * TILE, tx * TILE + TILE):
                h = hsh(x, ty, r.seed + 41)
                if h < .34:
                    L = 2 + int(hsh(x, ty, r.seed + 43) * 7)
                    for m in range(L):
                        cv.px(x, y0 + m, moss if m % 3 else lerp(moss, INK, .5))
                elif h < .5: cv.px(x, y0, lerp(moss, INK, .4))

def vines(cv, r, mask, unders, rng):
    ends = []
    vc, leaf = hexc(TH["vine"][0]), hexc(TH["vine"][1])
    rng.shuffle(unders)
    cap = 40 + int(r.depth * 60) * r.sw
    for (x, y) in unders[:cap]:
        L = rng.randint(8, 34 if r.sh == 1 else 52); ph = rng.random() * 6; cx = x
        for i in range(L):
            cx = x + int(math.sin(i * .25 + ph) * (1 + i * .04))
            cv.px(cx, y + 1 + i, vc)
            if i > 4 and rng.random() < .08: cv.px(cx + rng.choice((-1, 1)), y + 1 + i, leaf)
        ends.append((cx, y + L))
    return ends

def poles(cv, r):
    for (x, y0, y1) in r.poles:
        cv.rect(x - 1, y0, 2, y1 - y0, hexc("4a3a3a")); cv.rect(x - 1, y0, 1, y1 - y0, hexc("7a5a4a"))

def bulb(cv, x, y, big=False):
    c = hsv(0.5, .35, 1.0); mid = hsv(0.53, .55, .9); sh = hsv(0.58, .7, .62)
    for dy in range(-4, 5):                      # soft halo so food reads at a glance
        for dx in range(-4, 5):
            d = dx * dx + dy * dy
            if 9 < d <= 20 and dith(.5, x + dx, y + dy): cv.px(x + dx, y + dy, lerp(cv.get(x + dx, y + dy), hsv(.52, .5, 1), .35))
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx * dx + dy * dy <= 5: cv.px(x + dx, y + dy, mid if dy > 0 or dx > 0 else c)
    cv.px(x - 1, y - 1, (255, 255, 255)); cv.px(x + 1, y + 2, sh); cv.px(x, y + 2, sh)
    cv.px(x, y - 3, hexc("3a5a2a")); cv.px(x, y - 4, hexc("3a5a2a"))

def place_food(cv, r, mask, ends, rng):
    r.bulbs = []
    if r.food_pos is not None:
        for (x, y) in r.food_pos:
            vy = y - 4
            while vy > 0 and not mask[vy][x]: cv.px(x, vy, hexc(TH["vine"][1])); vy -= 1
            bulb(cv, x, y); r.bulbs.append((x, y))
        for (x, y) in r.pound_food: bulb(cv, x, y); r.bulbs.append((x, y))
        return
    spots = [e for e in ends if 0 < e[0] < r.W - 4 and e[1] < r.H - 16]
    rng.shuffle(spots)
    floor = []
    for x in range(8, r.W - 8, 6):
        for y in range(8, r.H - 2):
            if mask[y][x] and not mask[y - 1][x]: floor.append((x, y - 5)); break
    rng.shuffle(floor)
    for i in range(r.food * r.sw):
        pos = (spots[i // 2] if i % 2 == 0 and i // 2 < len(spots) else (floor[i % max(1, len(floor))] if floor else None))
        if pos: bulb(cv, pos[0], pos[1]); r.bulbs.append(pos)

def foreground(cv, r, mask, rng):
    g1, g2 = hexc(TH["grass"][0]), hexc(TH["grass"][1])
    for x in range(2, r.W - 2):
        for y in range(4, r.H - 1):
            if mask[y][x] and not mask[y - 1][x] and mask[y][x] == 1 and hsh(x, y, 21) < .35:
                h = rng.randint(3, 9 + int(r.depth * 6)); lean = rng.choice((-1, 0, 1))
                for i in range(h):
                    cv.px(x + (lean * i) // 3, y - 1 - i, g1 if i % 3 else g2)
                if h > 7 and rng.random() < .3:
                    for k in range(4): cv.px(x + (lean * h) // 3 + k - 1, y - h + abs(k - 1), g2)
                break
    # corner leaf clusters framing the screen
    for (cx, cy) in [(0, r.H), (r.W, r.H)] + ([(0, 0), (r.W, 0)] if r.depth > .5 else []):
        for _ in range(int(160 + 300 * r.depth)):
            a = rng.random() * math.tau; d = abs(rng.gauss(0, 30 + 40 * r.depth))
            cv.px(int(cx + math.cos(a) * d), int(cy + math.sin(a) * d), g1 if rng.random() < .6 else g2)

def crack(cv, x, y):
    c = hexc("5a2a22")
    for i in range(8):
        cv.px(x + i, y + 3 + (i * 7 % 3), INK); cv.px(x + 3, y + i, INK)
    cv.px(x + 1, y, hexc("a8512d")); cv.px(x + 6, y, hexc("a8512d"))

def extras(cv, r, mask, rng):
    kind = TH["extra"]
    if kind == "water":
        ft = floor_top(r); level = ft - 44
        for y in range(max(0, level), r.H):
            for x in range(r.W):
                if not mask[y][x] and (y > level + 1 or dith(.5, x, y)):
                    cv.p[y][x] = lerp(cv.p[y][x], hexc("2a8a86"), .42 if y > level + 3 else .7)
        for x in range(r.W):
            if not mask[level][x]: cv.px(x, level, hexc("9ad8cc")) if int(math.sin(x * .3) * 1.4) == 0 else cv.px(x, level + 1, hexc("9ad8cc"))
        for _ in range(r.W // 40):
            x = rng.randint(4, r.W - 4); y0 = rng.randint(4, max(5, level - 10))
            if not mask[y0][x]:
                for m in range(rng.randint(4, 12)): cv.px(x, y0 + m, hexc("9ad8cc"))
    elif kind == "lake":
        lake_extras(cv, r, mask, rng)
    elif kind == "embers":
        for _ in range(r.W * r.H // 600):
            x, y = rng.randint(0, r.W - 1), rng.randint(0, r.H - 1)
            if not mask[y][x]: cv.px(x, y, hexc("e08a4a") if rng.random() < .5 else hexc("8a7a80")); 
        for y in range(r.H):
            for x in range(r.W):
                if not mask[y][x] and dith(max(0, (y / r.H - .55)) * .5, x, y): cv.p[y][x] = lerp(cv.p[y][x], hexc("a8402a"), .35)
    elif kind == "ribs":
        for _ in range(3 + r.sw):
            cx = rng.randint(30, r.W - 30); top = rng.randint(30, max(40, r.H // 2)); rr = rng.randint(30, 60)
            for a in range(0, 181, 3):
                x = int(cx + math.cos(math.radians(a)) * rr); y = int(top + (1 - math.sin(math.radians(a))) * rr * .9)
                if 0 <= x < r.W and 0 <= y < r.H and not mask[y][x]: cv.rect(x, y, 2, 2, lerp(hexc("8a8468"), hexc(TH["haze"][0]), .55))
    elif kind == "steam":
        for _ in range(r.W // 18):
            x = rng.randint(6, r.W - 6); y = rng.randint(r.H // 3, r.H - 10)
            for m in range(rng.randint(10, 30)):
                px_, py_ = x + int(math.sin(m * .4) * 3), y - m
                if 0 <= py_ < r.H and not mask[py_][px_] and dith(.4, px_, py_): cv.p[py_][px_] = lerp(cv.p[py_][px_], hexc("d8c0a0"), .3)

def roof(cv, cx, y, hw, h, tile, hi, edge):
    """A pagoda roof: ridge on top, eaves sweeping out and lifting at the tips."""
    for x in range(-hw, hw + 1):
        u = abs(x) / hw
        bottom = y - int(round(7 * u ** 3))            # tips curl up
        top = y - int(round(h * (1 - u ** 1.6))) - int(round(7 * u ** 3)) - 2
        for yy in range(top, bottom + 1):
            c = tile if (x // 3) % 2 == 0 else lerp(tile, INK, 0.25)
            if yy <= top + 1: c = hi
            cv.px(cx + x, yy, c)
        cv.px(cx + x, bottom + 1, edge); cv.px(cx + x, bottom + 2, lerp(edge, INK, 0.5))
    for s_ in (-1, 1):                                   # little curled tips
        tx = cx + s_ * hw; ty = y - 8
        cv.px(tx, ty, edge); cv.px(tx + s_, ty - 1, edge); cv.px(tx + s_, ty - 2, edge)

def pagoda(cv, cx, base):
    wall, wall_d = hexc("d8d0c0"), hexc("a8a090"); wood = hexc("4a2a22"); red = hexc("a8402e"); red_d = hexc("6e2a20")
    tile, tile_hi, gold = hexc("2e3a4a"), hexc("5a6e86"), hexc("c8a24a")
    y = base
    tiers = [(86, 70, 124, 26), (68, 54, 100, 22), (52, 44, 78, 18)]  # body half-width, body height, roof half-width, roof height
    for i, (bw, bh, rw, rh) in enumerate(tiers):
        cv.rect(cx - bw - 2, y - 3, bw * 2 + 4, 3, wood)                    # floor beam
        cv.rect(cx - bw, y - bh, bw * 2, bh - 3, wall)
        cv.rect(cx - bw, y - bh, bw * 2, 2, wall_d)
        for px_ in range(cx - bw, cx + bw + 1, max(10, bw // 3)):          # vermilion pillars
            cv.rect(px_ - 2, y - bh, 4, bh - 3, red); cv.rect(px_ + 1, y - bh, 1, bh - 3, red_d)
        if i == 0:                                                           # glowing doorway
            cv.rect(cx - 15, y - 44, 30, 41, wood)
            for yy in range(y - 42, y - 3):
                for xx in range(cx - 13, cx + 13):
                    cv.px(xx, yy, hsv(0.5 + (yy - y) * 0.004 + (xx - cx) * 0.004, 0.35, 0.95 - (y - yy) * 0.008))
        else:                                                                # lattice windows
            for wx in (cx - bw // 2, cx + bw // 2):
                cv.rect(wx - 6, y - bh + 8, 12, bh - 18, wood)
                for k in range(3):
                    cv.rect(wx - 5 + k * 4, y - bh + 9, 1, bh - 20, hexc("e8c87a"))
        y -= bh
        roof(cv, cx, y + 2, rw, rh, tile, tile_hi, gold)
        y -= rh - 2
    cv.rect(cx - 1, y - 30, 3, 30, gold)                                     # spire with rings and a prism jewel
    for k in range(5): cv.rect(cx - 4, y - 8 - k * 5, 9, 2, gold)
    for dy in range(-4, 5):
        for dx in range(-(4 - abs(dy)), 5 - abs(dy)): cv.px(cx + dx, y - 36 + dy, hsv(0.52 + dy * 0.03, 0.5, 1.0))

def torii(cv, x, base):
    red, red_d, black = hexc("b0402e"), hexc("6e2a20"), hexc("1a1214")
    h = 92
    for px_ in (x - 34, x + 30):
        cv.rect(px_, base - h, 6, h, red); cv.rect(px_ + 4, base - h, 2, h, red_d); cv.rect(px_ - 1, base - 6, 8, 6, black)
    cv.rect(x - 40, base - h + 14, 82, 5, red)                               # nuki
    for xx in range(-50, 53):                                                # kasagi, lifting at the ends
        lift = int(round(4 * (abs(xx) / 50) ** 2))
        cv.rect(x + xx, base - h - lift, 1, 6, black if True else red)
        cv.px(x + xx, base - h - lift + 6, red)
    cv.rect(x - 3, base - h + 4, 6, 10, red)

def lantern(cv, x, base):
    stone, stone_d, glow = hexc("8a8478"), hexc("5a5650"), hexc("ffd9a0")
    cv.rect(x - 4, base - 4, 9, 4, stone_d); cv.rect(x - 1, base - 14, 3, 10, stone)
    cv.rect(x - 4, base - 20, 9, 6, stone); cv.rect(x - 2, base - 19, 5, 4, glow)
    cv.rect(x - 6, base - 23, 13, 3, stone_d); cv.px(x, base - 25, stone)

def lake_extras(cv, r, mask, rng):
    m = getattr(r, "lake", None)
    if not m: return
    (wx0, wx1, wy0, wy1) = m["water"]
    for y in range(wy0, wy1):
        for x in range(wx0, wx1):
            if mask[y][x]: continue
            band = math.sin(x * 0.05 + y * 0.6) * 0.5 + 0.5
            hue = 0.5 + 0.3 * ((x - wx0) / max(1, wx1 - wx0)) + 0.05 * band
            v = 0.85 - 0.5 * (y - wy0) / max(1, wy1 - wy0)
            c = hsv(hue, 0.45, v)
            if (y - wy0) < 2 or (dith(0.12, x, y) and band > 0.8): c = lerp(c, CREAM, 0.6)
            cv.p[y][x] = c
    (bx0, bx1, by) = m["bridge"]                                              # planks and railing over the walkway
    for x in range(bx0, bx1):
        cv.px(x, by, hexc("a8643a")); cv.px(x, by + 1, hexc("6a3a26"))
        for yy in range(by + 2, by + 8): cv.px(x, yy, hexc("4a2618") if x % 6 else hexc("6a3a26"))
        if (x - bx0) % 24 == 0:
            cv.rect(x, by - 12, 2, 12, hexc("8a4a2e"))
        cv.px(x, by - 11, hexc("b0402e"))
    torii(cv, m["torii"][0], m["torii"][1])
    pagoda(cv, m["temple"][0], m["temple"][1])
    for lx in m["lanterns"]: lantern(cv, lx, m["temple"][1])
    for (cx, cy, sz) in m["crystals"]:                                         # glowing crystal clusters on the rock
        for k in range(3):
            hgt = sz - k * 3; ox = (k - 1) * (sz // 3)
            for yy in range(hgt):
                hw = max(0, int((hgt - yy) / hgt * 3))
                for xx in range(-hw, hw + 1):
                    cv.px(cx + ox + xx, cy - yy, hsv(0.5 + k * 0.1 + xx * 0.02, 0.4, 0.95 if xx < 0 else 0.75))

def collision_overlay(cv, r, mask):
    for y in range(1, r.H - 1):
        for x in range(1, r.W - 1):
            if mask[y][x] and (not mask[y - 1][x] or not mask[y + 1][x] or not mask[y][x - 1] or not mask[y][x + 1]):
                cv.p[y][x] = TEAL
    for (x, y0, y1) in r.poles:
        cv.rect(x - 1, y0, 1, y1 - y0, TEAL)

# ---------------------------------------------------------------- rooms
def render(r, overlay=False):
    rng = random.Random(r.seed); cv = Canvas(r.W, r.H)
    background(cv, r, rng)
    mask = solid_masks(r)
    poles(cv, r)
    import shrine_art
    shrine_art.draw(cv, r, rng)                  # temple halls, ruins and door arches of the wing rooms (behind the terrain)
    unders = paint_terrain(cv, r, mask, rng)
    ends = vines(cv, r, mask, unders, rng)
    beam_drips(cv, r, rng)
    place_food(cv, r, mask, ends, rng)
    foreground(cv, r, mask, rng)
    extras(cv, r, mask, rng)
    for (tx, ty) in r.cracks: crack(cv, tx * TILE, ty * TILE)
    if overlay:
        collision_overlay(cv, r, mask)
        for (k, x, y) in r.marks: marker(cv, k, x, y)
        for (x, y) in r.bulbs: cv.ring(x, y + 1, 6, 1, hexc("7cd08a"))
        for (x, y, nm) in r.enemies: marker(cv, "enemy", x, y)
        label(cv, 6, 6, r.name, CREAM); label(cv, 6, 14, "THREAT %d  FOOD %d" % (r.threat, r.food), DIM)
    return cv

FONT = {
 'A':"010101111101101",'B':"110101110101110",'C':"011100100100011",'D':"110101101101110",'E':"111100110100111",
 'F':"111100110100100",'G':"011100101101011",'H':"101101111101101",'I':"111010010010111",'J':"001001001101010",
 'K':"101101110101101",'L':"100100100100111",'M':"101111111101101",'N':"110101101101101",'O':"010101101101010",
 'P':"110101110100100",'Q':"010101101110011",'R':"110101110101101",'S':"011100010001110",'T':"111010010010010",
 'U':"101101101101111",'V':"101101101101010",'W':"101101111111101",'X':"101101010101101",'Y':"101101010010010",
 'Z':"111001010100111",'0':"111101101101111",'1':"010110010010111",'2':"110001010100111",'3':"110001010001110",
 '4':"101101111001001",'5':"111100110001110",'6':"011100110101010",'7':"111001010100100",'8':"010101010101010",'9':"010101011001110",
 '-':"000000111000000",'.':"000000000000010",' ':"0"*15,'/':"001001010100100",':':"000010000010000",'+':"000010111010000"}
def label(cv, x, y, s, c):
    for ch in s.upper():
        g = FONT.get(ch, FONT[' '])
        for i, b in enumerate(g):
            if b == '1': cv.px(x + i % 3, y + i // 3, c)
        x += 4
    return x

def marker(cv, k, x, y):
    if k == "enemy":
        c = hexc("e0483a")
        for d in range(-5, 6):
            for e in range(-(5 - abs(d)), 6 - abs(d)): cv.px(x + d, y + e, c if abs(d) + abs(e) == 5 else lerp(c, INK, .6))
        label(cv, x - 2, y - 2, "!", CREAM)
    elif k == "rest":
        for d in range(-4, 5):
            for e in range(-(4 - abs(d)), 5 - abs(d)): cv.px(x + d, y + e, CREAM)
        label(cv, x - 8, y + 8, "REST", CREAM)
    elif k == "start":
        label(cv, x - 8, y - 12, "START", CREAM); cv.rect(x - 1, y - 6, 3, 6, CREAM)
    elif k.startswith("exit"):
        label(cv, x - 8, y - 12, "EXIT", CREAM)
        if k in ("exit_r", "exit_l"):
            sx = 1 if k == "exit_r" else -1
            for i in range(6): cv.px(x + i * sx, y - 3 + (i if i < 3 else 6 - i), CREAM)


# ---------------------------------------------------------------- authored rooms
def room_a():
    r = Room("02 ROOFTOP GARDEN", 2, 1, 0.04, 0, 1, seed=3)
    r.rock(0, 0, 6, 34); r.rock(6, 22, 3, 12); r.rock(6, 0, 16, 3)
    r.rock(0, 29, 120, 5); r.rock(70, 25, 16, 4); r.rock(76, 22, 6, 3)
    r.rock(114, 0, 6, 12); r.rock(114, 26, 6, 8); r.rock(108, 27, 6, 2)
    r.metal(22, 19, 7, 3, 29); r.metal(44, 14, 6, 3, 29); r.metal(96, 17, 7, 3, 29); r.metal(60, 8, 5, 2)
    r.marks = [("start", 12 * 8, 29 * 8), ("exit_r", 118 * 8, 24 * 8)]
    return r

def room_b():
    r = Room("06 PIPE CATHEDRAL", 2, 2, 0.5, 2, 3, seed=8)
    r.rock(0, 0, 7, 68); r.rock(113, 0, 7, 68)
    r.rock(7, 0, 45, 6); r.rock(68, 0, 45, 6); r.rock(52, 0, 3, 3); r.rock(65, 0, 3, 3)
    r.rock(7, 62, 77, 6); r.rock(96, 62, 17, 6); r.rock(7, 58, 10, 4); r.rock(100, 58, 13, 4)
    for (x, y, w, pole) in [(14, 50, 7, 62), (30, 42, 6, 62), (46, 34, 7, 62), (64, 44, 8, 62), (82, 36, 6, 62), (98, 48, 7, 62)]:
        r.metal(x, y, w, 3, pole)
    for (x, y, w) in [(22, 26, 7), (60, 20, 7), (92, 24, 8), (40, 13, 6)]:
        r.metal(x, y, w, 3)
    r.pole(76, 6, 36); r.pole(36, 6, 28)
    r.marks = [("rest", 40 * 8, 61 * 8), ("exit_d", 90 * 8, 64 * 8), ("start", 60 * 8, 6 * 8 + 14)]
    r.enemies = [(84 * 8, 40 * 8, "x"), (50 * 8, 52 * 8, "x")]
    return r

def room_c():
    r = Room("09 UNDERSTORY NEST", 2, 1, 0.88, 4, 5, seed=14)
    r.rock(0, 0, 6, 18); r.rock(0, 28, 6, 6); r.rock(114, 0, 6, 22); r.rock(114, 30, 6, 4)
    r.rock(6, 0, 108, 7)
    for (x, y, w, h) in [(20, 7, 6, 5), (48, 7, 8, 8), (80, 7, 5, 6), (100, 7, 7, 4), (30, 7, 4, 3)]: r.rock(x, y, w, h)
    r.rock(6, 28, 108, 6)
    for (x, y, w, h) in [(18, 25, 10, 3), (46, 24, 16, 4), (52, 21, 6, 3), (86, 25, 14, 3)]: r.rock(x, y, w, h)
    r.metal(34, 17, 6, 3); r.metal(70, 16, 7, 3, 24); r.metal(96, 14, 6, 3); r.metal(10, 14, 5, 3)
    r.marks = [("exit_l", 2 * 8, 26 * 8), ("exit_r", 118 * 8, 28 * 8)]
    r.enemies = [(56 * 8, 19 * 8, "x"), (90 * 8, 22 * 8, "x")]
    return r

# ---------------------------------------------------------------- region overview sheet
ROOMS = [  # name, screens w, h, threat 0-4, food 0-5
 ("LANDING", 1, 1, 0, 1), ("ROOFTOP GARDEN", 2, 1, 0, 1), ("CABLE SHAFT", 1, 2, 0, 1), ("GREENHOUSE", 2, 1, 1, 2),
 ("STAIRWELL", 1, 2, 1, 2), ("PIPE CATHEDRAL", 2, 2, 2, 3), ("ROOTBED", 2, 1, 3, 4), ("VINE WELL", 1, 3, 3, 3),
 ("UNDERSTORY NEST", 2, 1, 4, 5), ("RUST GATE", 1, 1, 2, 2)]

def overview():
    CW, CH, GAP, W = 28, 16, 9, 280
    total = sum(h for (_, _, h, _, _) in ROOMS) * CH + GAP * (len(ROOMS) - 1)
    H = total + 84
    cv = Canvas(W, H, hexc("120d14"))
    label(cv, 8, 6, "THE OVERGROWTH - ROOM LAYOUT", CREAM)
    label(cv, 8, 13, "1 CELL = 1 SCREEN (480X270)", DIM); label(cv, 8, 19, "SAFE AND SPARSE ABOVE, DANGEROUS AND RICH BELOW", DIM)
    y = 36; prev = None
    for i, (name, sw, sh, th, fd) in enumerate(ROOMS):
        x = (150 if i % 2 == 0 else 40) if sw == 1 else (110 if i % 2 == 0 else 20)
        x = min(x, 150 - (sw - 1) * 28 + 28)
        t = i / (len(ROOMS) - 1)
        border = lerp(hexc("8f9d5e"), hexc("4a5a30"), t); fill = lerp(hexc("2a3320"), hexc("141a12"), t)
        if prev:
            px_, py_ = prev; cx = x + sw * CW // 2
            cv.rect(px_, py_, 1, 5, DIM); cv.rect(min(px_, cx), py_ + 4, abs(cx - px_) + 1, 1, DIM); cv.rect(cx, py_ + 4, 1, GAP - 4, DIM)
        for cy in range(sh):
            for cx_ in range(sw):
                cv.rect(x + cx_ * CW, y + cy * CH, CW, CH, fill)
                for e in range(CW): cv.px(x + cx_ * CW + e, y + cy * CH, border); cv.px(x + cx_ * CW + e, y + cy * CH + CH - 1, border)
                for e in range(CH): cv.px(x + cx_ * CW, y + cy * CH + e, border); cv.px(x + cx_ * CW + CW - 1, y + cy * CH + e, border)
        for k in range(th):    # threat pips inside the room
            cv.rect(x + 4 + k * 5, y + 4, 3, 3, hexc("e0483a"))
        for k in range(fd):    # food pips
            bulb_c = hsv(0.52, .45, 1.0); cv.rect(x + 4 + k * 5, y + 9, 3, 3, bulb_c)
        txt = "%02d %s" % (i + 1, name)
        label(cv, x + sw * CW + 6 if x < 120 else x - len(txt) * 4 - 4, y + 3, txt, CREAM)
        if i in (5,): label(cv, x + sw * CW + 6, y + 10, "REST POINT", DIM)
        prev = (x + sw * CW // 2, y + sh * CH - 1); y += sh * CH + GAP
    # legend
    ly = H - 24
    cv.rect(8, ly, 3, 3, hexc("e0483a")); label(cv, 14, ly - 1, "THREAT 0-4 PREDATORS AND HAZARDS", DIM)
    cv.rect(8, ly + 8, 3, 3, hsv(0.52, .45, 1.0)); label(cv, 14, ly + 7, "FOOD 0-5 BULBS AND PREY", DIM)
    label(cv, 8, ly + 15, "ROOM NAMES AND CREATURES ARE PLACEHOLDERS", DIM)
    return cv

if __name__ == "__main__":
    import sys
    for fn, tag in ((room_a, "02_rooftop_garden"), (room_b, "06_pipe_cathedral"), (room_c, "09_understory_nest")):
        r = fn()
        write_png("dev/overgrowth/room_%s.png" % tag, render(r), 2)
        write_png("dev/overgrowth/room_%s_layout.png" % tag, render(r, overlay=True), 2)
        print("rendered", tag, r.W, r.H)
    write_png("dev/overgrowth/region_layout.png", overview(), 3)
    print("done")
