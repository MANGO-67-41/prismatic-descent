"""Concept map of the whole descent, in the game's pixel style. Not used by the game: python3 dev/make_map.py"""
import colorsys, random, struct, zlib

W, H, SCALE = 232, 404, 3
rng = random.Random(7)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

def hexc(s): return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v); return (int(r*255), int(g*255), int(b*255))
def lerp(a, b, t): return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

INK, CREAM, DIM, RUST = hexc("120d14"), hexc("f2e2bc"), hexc("b9a888"), hexc("a8512d")
BG = hexc("1e1a22")
img = [[BG]*W for _ in range(H)]
def px(x, y, c):
    if 0 <= x < W and 0 <= y < H: img[y][x] = c

FONT = {
 'A':"010101111101101",'B':"110101110101110",'C':"011100100100011",'D':"110101101101110",'E':"111100110100111",
 'F':"111100110100100",'G':"011100101101011",'H':"101101111101101",'I':"111010010010111",'J':"001001001101010",
 'K':"101101110101101",'L':"100100100100111",'M':"101111111101101",'N':"110101101101101",'O':"010101101101010",
 'P':"110101110100100",'Q':"010101101110011",'R':"110101110101101",'S':"011100010001110",'T':"111010010010010",
 'U':"101101101101111",'V':"101101101101010",'W':"101101111111101",'X':"101101010101101",'Y':"101101010010010",
 'Z':"111001010100111",'0':"111101101101111",'1':"010110010010111",'2':"110001010100111",'3':"110001010001110",
 '4':"101101111001001",'5':"111100110001110",'-':"000000111000000",'.':"000000000000010",' ':"0"*15}
def text(x, y, s, c):
    for ch in s:
        g = FONT[ch]
        for i, b in enumerate(g):
            if b == '1': px(x + i % 3, y + i // 3, c)
        x += 4
    return x


import math
def disc(cx, cy, r, c):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5: px(x, y, c)

def tunnel(x0, y0, x1, y1, t, c, wob=2.0):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 1.5) + 1
    th = t; off = 0.0
    for i in range(n + 1):
        u = i / n
        off += rng.uniform(-.35, .35) * wob; off *= 0.93
        th = max(1.2, min(t * 1.8, th + rng.uniform(-.3, .3)))
        if abs(x1 - x0) >= abs(y1 - y0): x, y = x0 + (x1 - x0)*u, y0 + (y1 - y0)*u + off
        else: x, y = x0 + (x1 - x0)*u + off, y0 + (y1 - y0)*u
        disc(x, y, th, c)

def chamber(cx, cy, rx, ry, c):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 + rng.uniform(-.15, .15): px(x, y, c)

def region(cx, cy, span, c):
    """organic network: three stacked runs joined by shafts, with chambers (around cx, cy)"""
    runs = []
    for k, dy in enumerate((-13, 0, 13)):
        l = cx - span + rng.randint(-6, 10) * (1 if k else 0)
        r = cx + span - rng.randint(0, 16)
        tunnel(l, cy + dy, r, cy + dy + rng.randint(-3, 3), 2.0, c, 2.2)
        runs.append((l, r, cy + dy))
    for k in range(2):
        for _ in range(2):
            x = rng.randint(int(max(runs[k][0], runs[k+1][0])) + 5, int(min(runs[k][1], runs[k+1][1])) - 5)
            tunnel(x, runs[k][2], x + rng.randint(-3, 3), runs[k+1][2], 1.6, c, 1.0)
    for _ in range(6):
        run = rng.choice(runs)
        chamber(rng.randint(int(run[0]) + 8, int(run[1]) - 8), run[2] + rng.randint(-3, 3), rng.randint(6, 13), rng.randint(3, 6), c)
    for run in runs:
        tunnel(run[0], run[2], run[0] - rng.randint(3, 8), run[2] + rng.randint(-8, 8), 1.4, c, 1.0)
    return (int(min(r[0] for r in runs)), int(max(r[1] for r in runs)))

WHITE = (255, 255, 255)
REG = [  # name, colour, centre, span, ability
 ("THE OVERGROWTH", hexc("8f9d5e"), (150, 52), 54, None),
 ("THE RUSTWORKS", hexc("d0743a"), (84, 116), 54, "GROUND POUND"),
 ("THE DROWNED WORKS", hexc("56a3a6"), (148, 180), 54, "DOUBLE JUMP"),
 ("THE BONE STACKS", hexc("d8c9a0"), (84, 244), 54, "INVINCIBLE DASH"),
 ("THE ASH DEEP", hexc("a98bb0"), (146, 308), 52, "FAST HEAL"),
]
LINE = hexc("5a505e")
def line(x0, y0, x1, y1):
    for y in range(min(y0, y1), max(y0, y1) + 1):
        if y % 2 == 0: px(x0, y, LINE)
    for x in range(min(x0, x1), max(x0, x1) + 1):
        if x % 2 == 0: px(x, y1, LINE)

# links first, so regions paint over them
ends = []
for name, c, (cx, cy), span, ab in REG: ends.append((cx - span + 6, cx + span - 6, cy))
for i in range(4):
    a, b = REG[i], REG[i + 1]
    x = a[2][0] + (-20 if i % 2 == 0 else 20)
    line(x, a[2][1] + 13, b[2][0] + (20 if i % 2 == 0 else -20), b[2][1] - 13)
spans = []
for name, c, (cx, cy), span, ab in REG: spans.append(region(cx, cy, span, c))

# lake: prism basin the last region drains into
LCX, LCY = 116, 372
line(REG[4][2][0] - 30, REG[4][2][1] + 3, LCX, LCY - 18) if False else None
for y in range(LCY - 18, LCY + 20):
    t = (y - (LCY - 18)) / 38
    half = int(70 * math.sqrt(max(0, 1 - (1 - t) ** 2.2)) * 0.85 + 2)
    for x in range(LCX - half, LCX + half + 1):
        u = (x - (LCX - 70)) / 140
        hue = 0.52 + 0.45*(u - .5) + 0.06*t
        v = 0.98 - 0.45*t
        base = hsv(hue, 0.5 - 0.1*t, v); shade = hsv(hue + .04, .7, v*0.55)
        px(x, y, shade if (BAYER[y & 3][x & 3] + .5)/16 < t*0.9 else base)
tunnel(REG[4][2][0] + 24, REG[4][2][1] + 14, LCX + 12, LCY - 17, 1.0, hsv(0.52, .45, 1.0), 0.6)

# labels
text(8, 6, "THE PRISMATIC DESCENT MAP", WHITE)
for (name, c, (cx, cy), span, ab) in REG:
    text(cx - span, cy - 27, name, WHITE)
    if ab:
        ex = spans[REG.index((name, c, (cx, cy), span, ab))][0]
        gx, gy = cx - span + 2, cy + 26
        for d in range(-2, 3):
            for e in range(-(2 - abs(d)), 3 - abs(d)): px(gx + d, gy + e, WHITE)
        text(gx + 5, gy - 2, ab, WHITE)
text(LCX + 52, LCY - 26, "PRISMATIC LAKE", hsv(0.52, .35, 1.0))
# start drop
sx, sy = REG[0][2][0] + 20, REG[0][2][1] - 25
for dy, hw in enumerate([0, 0, 1, 1, 2, 2, 1]):
    for dx in range(-hw, hw + 1): px(sx + dx, sy + dy, WHITE)
text(sx + 5, sy, "START", WHITE)

for x in range(W): px(x, 0, DIM); px(x, H - 1, DIM)
for y in range(H): px(0, y, DIM); px(W - 1, y, DIM)

# PNG out
raw = bytearray()
for row in img:
    line = b"".join(bytes(c) * SCALE for c in row)
    for _ in range(SCALE): raw += b"\x00" + line
def chunk(t, d):
    c = struct.pack(">I", len(d)) + t + d
    return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W*SCALE, H*SCALE, 8, 2, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
open("dev/map_organic.png", "wb").write(png)
print("ok", W*SCALE, H*SCALE)
