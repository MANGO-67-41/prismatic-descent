import colorsys, math, struct, zlib

W = H = 128          # pixel-art grid; scaled x8 to 1024
SCALE = 8
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

def dither(t, x, y):
    return t > (BAYER[y & 3][x & 3] + 0.5) / 16.0

def hexc(s):
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))

def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0, min(1, s)), max(0, min(1, v)))
    return (int(r * 255), int(g * 255), int(b * 255))

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

INK = hexc("120d14")
SKY = [hexc(c) for c in ["c4875a", "a8583f", "7a3a3c", "4a2a40", "2e2238", "1b1d2e", "11202a", "0a1519"]]

img = [[(0, 0, 0, 0) for _ in range(W)] for _ in range(H)]

# --- rounded-square backdrop: the game's dusk-to-depth gradient, dithered ---
M, R = 9, 24
def in_round(x, y):
    if x < M or x > W - 1 - M or y < M or y > H - 1 - M:
        return False
    cx = min(max(x, M + R), W - 1 - M - R)
    cy = min(max(y, M + R), H - 1 - M - R)
    return (x - cx) ** 2 + (y - cy) ** 2 <= R * R

def sky(x, y):
    pos = ((y - M) / (H - 1 - 2 * M)) ** 0.9
    pos += (abs(x - W / 2) / (W / 2)) ** 2 * 0.16
    pos = max(0.0, min(1.0, pos))
    s = pos * (len(SKY) - 1)
    i = min(int(s), len(SKY) - 2)
    return SKY[i + 1] if dither(s - i, x, y) else SKY[i]

for y in range(H):
    for x in range(W):
        if in_round(x, y):
            img[y][x] = sky(x, y) + (255,)

# --- crystal polygon (elongated gem) ---
P = [(64, 15), (87, 40), (87, 65), (64, 112), (41, 65), (41, 40)]

def inside_poly(x, y):
    sign = 0
    for i in range(len(P)):
        x1, y1 = P[i]; x2, y2 = P[(i + 1) % len(P)]
        c = (x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)
        if c == 0:
            continue
        s = 1 if c > 0 else -1
        if sign == 0:
            sign = s
        elif s != sign:
            return False
    return True

def dist_to_poly(x, y):
    best = 1e9
    for i in range(len(P)):
        x1, y1 = P[i]; x2, y2 = P[(i + 1) % len(P)]
        dx, dy = x2 - x1, y2 - y1
        t = max(0, min(1, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(x - (x1 + t * dx), y - (y1 + t * dy)))
    return best

# soft cyan-violet glow around the gem (dithered, stays inside the backdrop)
for y in range(H):
    for x in range(W):
        if not in_round(x, y) or inside_poly(x, y):
            continue
        d = dist_to_poly(x, y)
        if d < 13 and dither((1 - d / 13) * 0.55, x, y):
            hue = 0.52 + 0.22 * (y / H)
            img[y][x] = lerp(img[y][x][:3], hsv(hue, 0.5, 0.9), 0.55) + (255,)

# --- facets: each is (colour at start, colour at end, axis) blended with ordered dither ---
def facet_colour(x, y):
    left = x < 64
    if y < 40:                                   # upper cap
        t = (y - 15) / 25.0
        if left:
            a, b = hsv(0.50, 0.28, 1.0), hsv(0.52, 0.50, 0.95)
        else:
            a, b = hsv(0.60, 0.30, 0.98), hsv(0.64, 0.50, 0.88)
    elif y < 65:                                 # middle band
        t = (y - 40) / 25.0
        if left:
            a, b = hsv(0.53, 0.55, 1.0), hsv(0.58, 0.65, 0.88)
        else:
            a, b = hsv(0.66, 0.55, 0.86), hsv(0.72, 0.62, 0.72)
    else:                                        # lower point
        t = (y - 65) / 47.0
        if left:
            a, b = hsv(0.60, 0.62, 0.84), hsv(0.74, 0.70, 0.58)
        else:
            a, b = hsv(0.76, 0.60, 0.66), hsv(0.86, 0.70, 0.44)
    return b if dither(t, x, y) else a

for y in range(H):
    for x in range(W):
        if inside_poly(x, y):
            img[y][x] = facet_colour(x, y) + (255,)

# facet edges: lighter lines where the cut planes meet
def put(x, y, c):
    if 0 <= x < W and 0 <= y < H and img[y][x][3] > 0:
        img[y][x] = c + (255,)

for y in range(15, 113):
    put(64, y, hsv(0.55, 0.15, 1.0))                       # centre ridge
for x in range(41, 88):
    put(x, 40, hsv(0.55, 0.25, 1.0))                       # shoulder line
    put(x, 65, hsv(0.6, 0.3, 0.95))                        # belt line
for t in range(0, 24):                                      # cap ridges toward the shoulders
    put(64 - t, 15 + t * 25 // 24, hsv(0.52, 0.2, 1.0))
    put(64 + t, 15 + t * 25 // 24, hsv(0.6, 0.2, 1.0))

# --- dark outline around the gem ---
for y in range(H):
    for x in range(W):
        if img[y][x][3] and not inside_poly(x, y):
            continue
for y in range(H):
    for x in range(W):
        if inside_poly(x, y) or not in_round(x, y):
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            if inside_poly(x + dx, y + dy):
                img[y][x] = INK + (255,)
                break

# --- prism dispersion: a fan of spectral rays leaving the right side of the gem ---
def line(x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n); y = round(y0 + (y1 - y0) * i / n)
        if in_round(x, y) and not inside_poly(x, y):
            img[y][x] = c + (255,)
rays = 7
for k in range(rays):
    hue = (k / (rays - 1)) * 0.80                            # red -> violet
    c = hsv(hue, 0.85, 1.0)
    line(88, 53, 114, 62 + k * 3, c)
    line(88, 54, 114, 63 + k * 3, lerp(c, INK, 0.35))

# --- sparkles ---
def star(cx, cy, c):
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        put(cx + dx, cy + dy, c)
    for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
        if in_round(cx + dx, cy + dy):
            img[cy + dy][cx + dx] = lerp(img[cy + dy][cx + dx][:3], c, 0.8) + (255,)
star(52, 33, (255, 255, 255))
star(98, 33, hsv(0.55, 0.15, 1.0))
star(30, 86, hsv(0.6, 0.2, 1.0))
for y in range(46, 60):                                      # specular streak on the left facet
    put(51, y, (255, 255, 255))
    if y % 3:
        put(52, y, hsv(0.5, 0.15, 1.0))

# --- rim of the rounded square ---
for y in range(H):
    for x in range(W):
        if not in_round(x, y):
            continue
        edge = any(not in_round(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            img[y][x] = lerp(img[y][x][:3], INK, 0.75) + (255,)

# --- write PNG at 1024x1024 (nearest-neighbour scale, keeps the pixel look) ---
raw = bytearray()
for y in range(H):
    row = bytearray()
    for x in range(W):
        row += bytes(img[y][x]) * SCALE
    for _ in range(SCALE):
        raw += b"\x00" + row
def chunk(tag, data):
    c = struct.pack(">I", len(data)) + tag + data
    return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W * SCALE, H * SCALE, 8, 6, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
open("icon.png", "wb").write(png)
print("wrote", len(png), "bytes")
