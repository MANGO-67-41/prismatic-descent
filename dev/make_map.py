"""Concept map of the whole descent, in the game's pixel style. Not used by the game: python3 dev/make_map.py
(the Rain World-style blob variant is dev/make_map_organic.py)"""
import colorsys, random, struct, zlib

W, H, SCALE = 256, 416, 3
rng = random.Random(7)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

def hexc(s): return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v); return (int(r*255), int(g*255), int(b*255))
def lerp(a, b, t): return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

INK, CREAM, DIM, RUST = hexc("120d14"), hexc("f2e2bc"), hexc("b9a888"), hexc("a8512d")
img = [[INK]*W for _ in range(H)]
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

TOP, BAND = 18, 58
REGIONS = [
 ("THE OVERGROWTH", hexc("8f9d5e"), hexc("1b2316"), None),
 ("THE RUSTWORKS", RUST, hexc("2b1819"), "GROUND POUND"),
 ("THE DROWNED WORKS", hexc("56a3a6"), hexc("0d2126"), "DOUBLE JUMP"),
 ("THE BONE STACKS", DIM, hexc("231e24"), "INVINCIBLE DASH"),
 ("THE ASH DEEP", hexc("8a7488"), hexc("1c1520"), "FAST HEAL"),
]
MAPX0, MAPX1 = 8, 168
open_ = [[-1]*W for _ in range(H)]

for ri, (_, _, fill, _) in enumerate(REGIONS):
    y0 = TOP + ri*BAND
    for y in range(y0, y0 + BAND):
        for x in range(MAPX0 - 4, MAPX1 + 5):
            t = 0.35 + 0.25*((y - y0)/BAND)
            if (BAYER[y & 3][x & 3] + .5)/16 < t*0.5: img[y][x] = lerp(INK, fill, 0.7)

rooms = []
for ri in range(5):
    y0 = TOP + ri*BAND
    for i in range(4):
        w, h = rng.randint(22, 44), rng.randint(10, 16)
        cx = (40 + 90*(i % 2)) + rng.randint(-14, 14)
        x = max(MAPX0 + 2, min(MAPX1 - w - 2, cx - w//2))
        y = y0 + 4 + i*13 + rng.randint(-1, 2)
        rooms.append((x, y, w, h, ri))
rooms.append((52, TOP + 5*BAND + 2, 64, 14, 4))

def carve(x0, y0, x1, y1, ri):
    for y in range(y0, y1):
        for x in range(x0, x1):
            if 0 <= x < W and 0 <= y < H and open_[y][x] < 0: open_[y][x] = ri
for i in range(len(rooms) - 1):
    a, b = rooms[i], rooms[i+1]
    ax, ay = a[0] + a[2]//2, a[1] + a[3]//2
    bx, by = b[0] + b[2]//2, b[1] + b[3]//2
    carve(min(ax, bx) - 1, ay, max(ax, bx) + 2, ay + 3, a[4])
    carve(bx - 1, ay, bx + 2, by + 1, b[4])
for (x, y, w, h, ri) in rooms: carve(x, y, x + w, y + h, ri)

for _ in range(14):
    x, y, w, h, ri = rng.choice(rooms)
    side = rng.choice([-1, 1]); ax = x - 10 if side < 0 else x + w
    if MAPX0 + 2 < ax < MAPX1 - 12: carve(ax, y + 3, ax + 10, y + 7, ri)

for y in range(H):
    for x in range(W):
        r = open_[y][x]
        if r < 0: continue
        img[y][x] = REGIONS[r][2]
for y in range(1, H - 1):
    for x in range(1, W - 1):
        r = open_[y][x]
        if r < 0: continue
        if any(open_[y+dy][x+dx] < 0 for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
            img[y][x] = REGIONS[r][1]
rng2 = random.Random(3)
for y in range(2, H - 2):
    for x in range(2, W - 2):
        r = open_[y][x]
        if r < 0: continue
        _, border, fill, _ = REGIONS[r]
        edge_top = open_[y-1][x] < 0
        if r == 0 and edge_top and rng2.random() < .35:
            for k in range(1, rng2.randint(2, 5)):
                if open_[y+k][x] == r and img[y+k][x] == fill: px(x, y+k, lerp(fill, border, .6))
        if r == 1 and edge_top and x % 7 == 0: px(x, y, hexc("d98a52"))
        if r == 2 and img[y][x] == fill and (y - (TOP + 2*BAND)) > BAND*0.5 and (x + y) % 2 == 0:
            px(x, y, lerp(fill, border, .35))
        if r == 3 and img[y][x] == fill and rng2.random() < .01: px(x, y, DIM)
        if r == 4 and img[y][x] == fill and rng2.random() < .02: px(x, y, hexc("c4875a"))
for (x, y, w, h, ri) in rooms[:-1]:
    if w > 26:
        px_y = y + h - 4; sx = x + 5
        for k in range(8): px(sx + k, px_y, lerp(REGIONS[ri][2], REGIONS[ri][1], .55))

# --- bake the in-game map art: rooms only, no text, lake or frame (assets/ui/world_map.png, 1x) ---
def write_png(path, rows, scale):
    w = len(rows[0])
    raw = bytearray()
    for row in rows:
        line = b"".join(bytes(c) * scale for c in row)
        for _ in range(scale): raw += b"\x00" + line
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w*scale, len(rows)*scale, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
BAKE_X1, BAKE_Y1 = MAPX1 + 8, TOP + 5*BAND + 20
write_png("assets/ui/world_map.png", [row[:BAKE_X1] for row in img[TOP:BAKE_Y1]], 1)
print("baked world_map.png", BAKE_X1, BAKE_Y1 - TOP)

text(8, 5, "THE PRISMATIC DESCENT", CREAM)
text(8, 11, "WORLD MAP - PLACEHOLDER REGION NAMES", DIM)
for ri, (name, border, fill, ability) in enumerate(REGIONS):
    y0 = TOP + ri*BAND
    for x in range(MAPX0 - 4, 252):
        if x % 3 == 0: px(x, y0 - 1, lerp(INK, border, .5))
    text(176, y0 + 2, str(ri + 1) + " " + name, border)
    if ability:
        gx, gy = 172, y0 + 12
        for d in range(-3, 4):
            for e in range(-(3 - abs(d)), 4 - abs(d)): px(gx + d, gy + e, CREAM)
        text(178, y0 + 10, ability, CREAM)
        text(178, y0 + 16, "GRANTED ON ENTRY", DIM)
    else:
        text(178, y0 + 10, "START - DUSK", DIM)

sx, sy = rooms[0][0] + rooms[0][2]//2, rooms[0][1] + 3
for dy, hw in enumerate([0, 0, 1, 1, 2, 2, 1]):
    for dx in range(-hw, hw + 1): px(sx + dx, sy + dy, CREAM)

ly0, ly1 = TOP + 5*BAND + 16, H - 10
cx = 84
for y in range(ly0, ly1):
    t = (y - ly0) / (ly1 - ly0)
    half = int(78 * (1 - (1 - t) ** 2.2) ** 0.5 * 0.9 + 2) if t > 0 else 0
    for x in range(cx - half, cx + half + 1):
        u = (x - (cx - 78)) / 156
        hue = 0.52 + 0.45*(u - .5) + 0.06*t
        v = 0.95 - 0.5*t
        base = hsv(hue, 0.55 - 0.15*t, v)
        shade = hsv(hue + .04, .7, v*0.55)
        img[y][x] = shade if (BAYER[y & 3][x & 3] + .5)/16 < t*0.9 + 0.1*(0.5 - abs(u - .5)) else base
    if half:
        px(cx - half - 1, y, CREAM); px(cx + half + 1, y, CREAM)
for x in range(cx - 4, cx + 5): px(x, ly0, CREAM)
text(176, ly0 + 18, "PRISMATIC LAKE", hsv(0.52, .45, 1.0))
text(176, ly0 + 24, "ETERNAL PEACE", DIM)

for x in range(W):
    px(x, 0, DIM); px(x, H - 1, DIM)
for y in range(H):
    px(0, y, DIM); px(W - 1, y, DIM)

raw = bytearray()
for row in img:
    line = b"".join(bytes(c) * SCALE for c in row)
    for _ in range(SCALE): raw += b"\x00" + line
def chunk(t, d):
    c = struct.pack(">I", len(d)) + t + d
    return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W*SCALE, H*SCALE, 8, 2, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
open("dev/map_concept.png", "wb").write(png)
print("ok", W*SCALE, H*SCALE)
