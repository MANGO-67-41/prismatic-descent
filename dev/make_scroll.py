"""Draws assets/ui/scroll_panel.png: the parchment scroll the player reads (384 x 216 = 80% of the 480 x 270 screen).
A rolled bar at the top and bottom, a sheet with ragged, burnt edges between them, soft shading and paper fibres.
Pure Python PNG writer (RGBA). Run: python3 dev/make_scroll.py"""
import struct, zlib

W, H = 384, 216
def hexc(s): return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)
def mix(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))
def hsh(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0

PARCH_HI, PARCH, PARCH_LO = hexc("f0d3a0"), hexc("e6bd84"), hexc("cf9a62")
EDGE, OUTLINE, BURN = hexc("b27640"), hexc("5e3520"), hexc("8a5330")
ROLL = [hexc(c) for c in ["5e3520", "fdecc4", "fbe6b8", "f6dca8", "f1d19a", "ecc88e", "e6bd84", "dfb07a", "d7a46e", "cc9763", "bf8a58", "b27e4e", "a07044", "8c5e38", "6e4426", "5e3520"]]
CAP, CAP_RING = hexc("c4905a"), hexc("7a4a2a")
RH = 16                                   # roll height
px = [[(0, 0, 0, 0)] * W for _ in range(H)]

def put(x, y, c):
    if 0 <= x < W and 0 <= y < H: px[y][x] = c

# --- the sheet ---------------------------------------------------------------------------------------------
top, bot = RH - 4, H - RH + 4
def left_edge(y):  return 18 + int(hsh(y // 2, 1, 5) * 3) + (1 if hsh(y, 2, 6) < .2 else 0)
def right_edge(y): return W - 19 - int(hsh(y // 2, 3, 7) * 3) - (1 if hsh(y, 4, 8) < .2 else 0)
for y in range(top, bot):
    for x in range(left_edge(y), right_edge(y) + 1):
        d = min(x - left_edge(y), right_edge(y) - x)
        c = PARCH
        u = abs((x - W / 2) / (W / 2)) ** 2 * .35 + abs((y - H / 2) / (H / 2)) ** 2 * .25
        c = mix(PARCH_HI, PARCH_LO, min(1.0, u + .1))
        if d < 12: c = mix(c, PARCH_LO, (12 - d) / 12 * .55)
        h = hsh(x, y, 3)
        if h < .035: c = mix(c, PARCH_LO, .55)
        elif h > .985: c = mix(c, PARCH_HI, .7)
        if y % 9 == 4 and hsh(x // 6, y, 9) < .3: c = mix(c, PARCH_LO, .25)   # fibres
        if d == 0: c = OUTLINE
        elif d == 1: c = BURN
        elif d == 2: c = EDGE
        px[y][x] = c
# burnt, nicked corners
for (cx, cy) in ((18, top), (W - 19, top), (18, bot - 1), (W - 19, bot - 1)):
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            if abs(dx) + abs(dy) <= 2 and hsh(cx + dx, cy + dy, 11) < .5: put(cx + dx + (2 if cx < W // 2 else -2), cy + dy, (0, 0, 0, 0))
# shadows the rolls cast on the sheet
for k in range(7):
    for x in range(20, W - 20):
        for y, s in ((RH + k, .5 - k * .07), (H - RH - 1 - k, .45 - k * .06)):
            if px[y][x][3]: px[y][x] = mix(px[y][x], OUTLINE, max(0, s))

# --- the rolls -----------------------------------------------------------------------------------------------
def roll(y0):
    for r in range(RH):
        for x in range(10, W - 10):
            c = ROLL[r]
            if hsh(x // 3, r, 21) < .12 and 3 < r < 13: c = mix(c, ROLL[min(15, r + 2)], .5)
            if (x - 10) % 41 == 0 and 1 < r < 14: c = mix(c, ROLL[min(15, r + 3)], .6)   # a binding thread
            put(x, y0 + r, c)
    for side in (0, 1):                                              # end caps: a round face with a spiral
        cx = 8 if side == 0 else W - 9
        for yy in range(RH):
            for xx in range(-8, 9):
                if (xx * xx) / 64.0 + ((yy - 7.5) ** 2) / 72.0 <= 1.0:
                    c = CAP
                    dd = (xx * xx) / 64.0 + ((yy - 7.5) ** 2) / 72.0
                    if dd > .72: c = CAP_RING
                    elif .3 < dd < .42 or dd < .05: c = CAP_RING
                    if dd > .93: c = OUTLINE
                    put(cx + xx, y0 + yy, c)
roll(0)
roll(H - RH)

# --- a faint seal-less flourish line under the top roll, so the title has a place to sit ------------------
with open("assets/ui/scroll_panel.png", "wb") as f:
    raw = bytearray()
    for row in px:
        raw.append(0)
        for c in row: raw += bytes(c)
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
print("wrote assets/ui/scroll_panel.png", W, "x", H)
