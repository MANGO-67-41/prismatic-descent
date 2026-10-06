"""Pixel-art engine for the creature sprite sheets (the same approach as the hero's sheet, dev/make_hero.py, grown up).
A creature frame is a list of shaded body parts (ellipses, tubes, polygons) plus overlays (feathers, rods, glowing lights,
teeth). Parts are rasterised in their own model space (facing right, y down), so the same model renders at any angle and
stays crisp: every pixel is shaded from the part's surface normal against one light (top left) into a 4-tone ramp, textured
(scales, ridges, specks), given a rim of light along its top edge and an ink outline, exactly like the hero.
"""
import math, struct, zlib

INK = (18, 13, 20)
LIGHT = (-0.55, -0.83)
WHITE = (255, 255, 255)

def hexc(s): return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
def mix(a, b, t): t = max(0.0, min(1.0, t)); return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
def hsh(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0

def ramp(base, warm=None):
    """Four tones and a rim from one colour: deep shadow, shadow, base, light, and the rim light."""
    b = hexc(base) if isinstance(base, str) else base
    lit = mix(b, hexc(warm) if warm else WHITE, .3)
    return [mix(b, INK, .55), mix(b, INK, .28), b, lit, mix(b, WHITE, .5)]

# --------------------------------------------------------------------------------------------- parts
class Ell:
    def __init__(s, c, rx, ry, mat, rot=0.0, tex="", z=0): s.c, s.rx, s.ry, s.mat, s.rot, s.tex, s.z = c, rx, ry, mat, rot, tex, z
    def bbox(s): r = max(s.rx, s.ry) + 1; return (s.c[0] - r, s.c[1] - r, s.c[0] + r, s.c[1] + r)
    def hit(s, x, y):
        dx, dy = x - s.c[0], y - s.c[1]
        cr, sr = math.cos(-s.rot), math.sin(-s.rot)
        u, v = dx * cr - dy * sr, dx * sr + dy * cr
        q = (u / s.rx) ** 2 + (v / s.ry) ** 2
        if q > 1.0: return None
        nu, nv = u / s.rx, v / s.ry
        cr2, sr2 = math.cos(s.rot), math.sin(s.rot)
        return (nu * cr2 - nv * sr2, nu * sr2 + nv * cr2, u)

class Tube:
    """A thick line through points, radius from r0 to r1; `t` along it drives ridges."""
    def __init__(s, pts, r0, r1, mat, tex="", z=0): s.pts, s.r0, s.r1, s.mat, s.tex, s.z = pts, r0, r1, mat, tex, z
    def bbox(s):
        r = max(s.r0, s.r1) + 1
        return (min(p[0] for p in s.pts) - r, min(p[1] for p in s.pts) - r, max(p[0] for p in s.pts) + r, max(p[1] for p in s.pts) + r)
    def hit(s, x, y):
        best = None; total = 0.0; lens = []
        for i in range(len(s.pts) - 1):
            a, b = s.pts[i], s.pts[i + 1]; lens.append(math.hypot(b[0] - a[0], b[1] - a[1]))
        L = sum(lens) or 1.0
        for i in range(len(s.pts) - 1):
            a, b = s.pts[i], s.pts[i + 1]; ab = (b[0] - a[0], b[1] - a[1]); l2 = ab[0] ** 2 + ab[1] ** 2 or 1e-6
            t = max(0.0, min(1.0, ((x - a[0]) * ab[0] + (y - a[1]) * ab[1]) / l2))
            q = (a[0] + ab[0] * t, a[1] + ab[1] * t); d = math.hypot(x - q[0], y - q[1])
            along = (total + lens[i] * t) / L; r = s.r0 + (s.r1 - s.r0) * along
            if d <= r and (best is None or d / max(r, .01) < best[0]): best = (d / max(r, .01), (x - q[0]) / max(r, .01), (y - q[1]) / max(r, .01), total + lens[i] * t)
            total += lens[i]
        return None if best is None else (best[1], best[2], best[3])

class Poly:
    def __init__(s, pts, mat, z=0, tex="", bulge=0.6): s.pts, s.mat, s.z, s.tex, s.bulge = pts, mat, z, tex, bulge
    def bbox(s): return (min(p[0] for p in s.pts) - 1, min(p[1] for p in s.pts) - 1, max(p[0] for p in s.pts) + 1, max(p[1] for p in s.pts) + 1)
    def hit(s, x, y):
        inside = False; n = len(s.pts); j = n - 1
        for i in range(n):
            xi, yi = s.pts[i]; xj, yj = s.pts[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi: inside = not inside
            j = i
        if not inside: return None
        x0, y0, x1, y1 = s.bbox(); cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        return ((x - cx) / max(1, (x1 - x0) / 2) * s.bulge, (y - cy) / max(1, (y1 - y0) / 2) * s.bulge, 0.0)

# overlays (drawn on top of / behind the shaded body, no shading of their own)
class Feather:
    def __init__(s, root, tip, w, dark, accent, z=1, bend=0.0): s.root, s.tip, s.w, s.dark, s.accent, s.z, s.bend = root, tip, w, dark, accent, z, bend
class Rod:
    def __init__(s, a, b, col, z=1, w=1, cap=None): s.a, s.b, s.col, s.z, s.w, s.cap = a, b, col, z, w, cap
class Glow:
    def __init__(s, p, col, r=1, z=2): s.p, s.col, s.r, s.z = p, col, r, z
class Dot:
    def __init__(s, p, col, z=2): s.p, s.col, s.z = p, col, z

# --------------------------------------------------------------------------------------------- rendering
def render(items, w, h, ox, oy, ang=0.0, upright=False):
    """Rasterise one frame. Model origin goes to (ox, oy) on the cell, the model turned by `ang`. With `upright`, a model
    turned past vertical is mirrored top to bottom first, so a head facing left keeps its jaw underneath."""
    ca, sa = math.cos(ang), math.sin(ang)
    my_sign = -1.0 if (upright and ca < -1e-6) else 1.0
    def to_screen(p): mx, my = p[0], p[1] * my_sign; return (ox + mx * ca - my * sa, oy + mx * sa + my * ca)
    def to_model(X, Y): dx, dy = X - ox, Y - oy; return (dx * ca + dy * sa, (-dx * sa + dy * ca) * my_sign)
    def n_to_screen(nx, ny): ny *= my_sign; return (nx * ca - ny * sa, nx * sa + ny * ca)
    img = [[None] * w for _ in range(h)]
    body = [[None] * w for _ in range(h)]       # (z, level, rim allowed)
    parts = [i for i in items if isinstance(i, (Ell, Tube, Poly))]
    overlays = [i for i in items if not isinstance(i, (Ell, Tube, Poly))]
    for o in sorted([o for o in overlays if o.z < 0], key=lambda o: o.z): draw_overlay(img, o, to_screen, w, h)
    for p in sorted(parts, key=lambda p: p.z):
        x0, y0, x1, y1 = p.bbox()
        corners = [to_screen((x0, y0)), to_screen((x1, y0)), to_screen((x0, y1)), to_screen((x1, y1))]
        X0 = max(0, int(min(c[0] for c in corners)) - 1); X1 = min(w - 1, int(max(c[0] for c in corners)) + 1)
        Y0 = max(0, int(min(c[1] for c in corners)) - 1); Y1 = min(h - 1, int(max(c[1] for c in corners)) + 1)
        for Y in range(Y0, Y1 + 1):
            for X in range(X0, X1 + 1):
                mx, my = to_model(X + .5, Y + .5)
                r = p.hit(mx, my)
                if r is None: continue
                nx, ny = n_to_screen(r[0], r[1]); d = nx * LIGHT[0] + ny * LIGHT[1]
                lvl = 3 if d > .42 else 2 if d > -.18 else 1 if d > -.6 else 0
                if p.tex == "scale" and lvl >= 2 and (X * 2 + Y * 3) % 5 == 0: lvl -= 1
                elif p.tex == "ridge" and lvl >= 1 and int(r[2]) % 3 == 0: lvl -= 1
                elif p.tex == "speck" and hsh(X, Y, 3) < .1: lvl = max(0, lvl - 1)
                elif p.tex == "plate" and lvl >= 1 and int(abs(r[2]) + 0.5) % 4 == 0: lvl -= 1
                body[Y][X] = (p.z, lvl, p.mat)
    for Y in range(h):
        for X in range(w):
            b = body[Y][X]
            if b is None: continue
            lvl = b[1]; col = b[2][lvl]
            if (Y == 0 or body[Y - 1][X] is None) and lvl >= 2: col = b[2][4]     # rim light along the top
            img[Y][X] = col
    for Y in range(h):
        for X in range(w):
            if body[Y][X] is None and any(0 <= X + a < w and 0 <= Y + c < h and body[Y + c][X + a] is not None for a, c in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                img[Y][X] = INK
    for o in sorted([o for o in overlays if o.z >= 0], key=lambda o: o.z): draw_overlay(img, o, to_screen, w, h)
    return [[(c + (255,)) if c is not None and len(c) == 3 else (c if c is not None else (0, 0, 0, 0)) for c in row] for row in img]

def put(img, x, y, c, w, h):
    x, y = int(math.floor(x)), int(math.floor(y))
    if 0 <= x < w and 0 <= y < h: img[y][x] = c

def draw_overlay(img, o, to_screen, w, h):
    if isinstance(o, Feather):
        a, b = to_screen(o.root), to_screen(o.tip)
        L = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) * 1.4))
        nx, ny = -(b[1] - a[1]), b[0] - a[0]; nl = math.hypot(nx, ny) or 1; nx, ny = nx / nl, ny / nl
        for k in range(L + 1):
            t = k / L
            cx = a[0] + (b[0] - a[0]) * t + nx * o.bend * math.sin(t * math.pi)
            cy = a[1] + (b[1] - a[1]) * t + ny * o.bend * math.sin(t * math.pi)
            half = o.w * (math.sin(t * math.pi) ** .6) * (1 - .35 * t)
            col = mix(o.dark, o.accent, max(0.0, (t - .25) / .75) ** 1.1)
            steps = max(1, int(half * 2 + 1))
            for s in range(steps + 1):
                u = -half + 2 * half * s / max(1, steps)
                edge = abs(u) > half - .7 and half > 1.2
                put(img, cx + nx * u, cy + ny * u, mix(col, INK, .45) if edge else col, w, h)
    elif isinstance(o, Rod):
        a, b = to_screen(o.a), to_screen(o.b)
        L = max(1, int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))))
        for k in range(L + 1):
            t = k / L; x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            for q in range(o.w): put(img, x + (q if abs(b[1] - a[1]) > abs(b[0] - a[0]) else 0), y + (0 if abs(b[1] - a[1]) > abs(b[0] - a[0]) else q), o.col, w, h)
        if o.cap: put(img, b[0], b[1], o.cap, w, h)
    elif isinstance(o, Glow):
        p = to_screen(o.p)
        for dy in range(-o.r - 1, o.r + 2):
            for dx in range(-o.r - 1, o.r + 2):
                d = math.hypot(dx, dy)
                x, y = int(p[0]) + dx, int(p[1]) + dy
                if not (0 <= x < w and 0 <= y < h): continue
                if d <= o.r * .6: img[y][x] = mix(o.col, WHITE, .55)
                elif d <= o.r: img[y][x] = o.col
                elif d <= o.r + 1.2 and img[y][x] is not None and len(img[y][x]) == 3: img[y][x] = mix(img[y][x], o.col, .45)
    elif isinstance(o, Dot):
        p = to_screen(o.p); put(img, p[0], p[1], o.col, w, h)

# --------------------------------------------------------------------------------------------- sheets
class Sheet:
    """Rows of frames; each row its own cell size. Writes a PNG and a JSON atlas the game reads."""
    def __init__(s): s.rows = []
    def row(s, name, frames, w, h, ox, oy): s.rows.append((name, frames, w, h, ox, oy))
    def save(s, png, js):
        W = max(len(f) * w for _, f, w, h, _, _ in s.rows); H = sum(h for _, _, _, h, _, _ in s.rows)
        sheet = [[(0, 0, 0, 0)] * W for _ in range(H)]; atlas = {}; y = 0
        for name, frames, w, h, ox, oy in s.rows:
            for i, fr in enumerate(frames):
                for yy in range(h):
                    for xx in range(w): sheet[y + yy][i * w + xx] = fr[yy][xx]
            atlas[name] = dict(y=y, w=w, h=h, n=len(frames), ox=ox, oy=oy); y += h
        raw = bytearray()
        for r in sheet:
            raw.append(0)
            for p in r: raw += bytes(p)
        def chunk(t, d): c = struct.pack(">I", len(d)) + t + d; return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
        open(png, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
        import json; json.dump(dict(width=W, height=H, rows=atlas), open(js, "w"), indent=0)
        return W, H

def directions(model, w, h, n=16, upright=True):
    """The same model at n angles (0 = facing right, clockwise)."""
    return [render(model, w, h, w / 2, h / 2, ang=i * math.tau / n, upright=upright) for i in range(n)]

def preview(sheet_png_rows, path, scale=6, bg=(40, 34, 46)):
    """Blow a list of frames up for a look (contact sheet)."""
    frames = sheet_png_rows
    cw = max(len(f[0]) for f in frames); ch = max(len(f) for f in frames)
    W, H = cw * len(frames) * scale, ch * scale
    out = [[bg + (255,)] * W for _ in range(H)]
    for i, fr in enumerate(frames):
        for y in range(len(fr)):
            for x in range(len(fr[0])):
                p = fr[y][x]
                if p[3]:
                    for a in range(scale):
                        for b in range(scale): out[y * scale + a][(i * cw + x) * scale + b] = p
    raw = bytearray()
    for r in out:
        raw.append(0)
        for p in r: raw += bytes(p)
    def chunk(t, d): c = struct.pack(">I", len(d)) + t + d; return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
