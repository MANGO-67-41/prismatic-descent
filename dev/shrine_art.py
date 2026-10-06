"""Temple halls, ruins and door arches for the wing rooms (and the shrine at the lake's door). Drawn into a room's art by
overgrowth_art.render from the room's "deco" list: [{"t": "temple", "x": px, "y": base_px}, ...].
Every structure takes its colours from a per-region palette, so the same pagoda reads as mossy wood in the Overgrowth, rusted
copper in the Rustworks, jade in the Drowned Works, bone in the Bone Stacks and charred lacquer in the Ash Deep."""
import math, random
import overgrowth_art as oa
from overgrowth_art import hexc, lerp, hsh, hsv, dith, INK

def _pal(**kw): return {k: hexc(v) for k, v in kw.items()}

PAL = {
 "overgrowth": _pal(wall="b4b48c", wall_d="868a66", wood="3a2a1c", red="8a4a2a", red_d="52301e", tile="2e4a3a", tile_hi="64946a", gold="c0b058",
                    stone="7a7a62", stone_d="52523e", moss="6b7a3c", moss_hi="9aa860", glow="b8f090"),
 "rustworks": _pal(wall="a67e5c", wall_d="6c4c3a", wood="2a1a14", red="b8501e", red_d="6a2a14", tile="3e2c2a", tile_hi="80604c", gold="e09a3a",
                   stone="7a5a48", stone_d="4a3226", moss="8a5a2a", moss_hi="c4803a", glow="ffb868"),
 "drowned": _pal(wall="8ab4aa", wall_d="5a8884", wood="1e3036", red="2a8a86", red_d="175a5c", tile="1e4a52", tile_hi="5aa4ac", gold="cfe6b4",
                 stone="5a8484", stone_d="34585a", moss="3a7a70", moss_hi="6ab0a0", glow="8af0e4"),
 "bone": _pal(wall="e2dac2", wall_d="b2aa8a", wood="4a443a", red="aa9e82", red_d="6c624e", tile="5c564a", tile_hi="9c927a", gold="eadfa8",
              stone="a8a080", stone_d="6c6652", moss="a8a080", moss_hi="d8d0b0", glow="f4ecd0"),
 "ash": _pal(wall="5e4c5a", wall_d="3a2c3a", wood="1a1218", red="8e2c2c", red_d="4c1a1a", tile="2c2232", tile_hi="5c4c62", gold="e48c4c",
             stone="4e3e4c", stone_d="2e2230", moss="6a4a58", moss_hi="9a6a70", glow="ff8a58"),
 "lake": _pal(wall="d8d0c0", wall_d="a8a090", wood="4a2a22", red="a8402e", red_d="6e2a20", tile="2e3a4a", tile_hi="5a6e86", gold="c8a24a",
              stone="8a8478", stone_d="5a5650", moss="6aa8b8", moss_hi="a8e0e8", glow="ffd9a0"),
}

def pal_of(r): return PAL.get(r.theme, PAL["overgrowth"])

def _hang(cv, x0, x1, y, pal, rng, amt=.5, depth=6):
    """Moss threads hanging from an edge."""
    for x in range(x0, x1):
        if rng.random() < amt:
            for m in range(rng.randint(1, depth)):
                cv.px(x, y + m, pal["moss_hi"] if m == 0 else (pal["moss"] if m % 2 else lerp(pal["moss"], INK, .45)))

def steps(cv, cx, base, half, n, pal, rise=4, inset=10):
    for i in range(n):
        w = half - i * inset
        cv.rect(cx - w, base - rise * (i + 1), w * 2, rise, pal["stone"])
        cv.rect(cx - w, base - rise * (i + 1), w * 2, 1, lerp(pal["stone"], oa.CREAM, .25))
        cv.rect(cx - w, base - rise * i - 1, w * 2, 1, pal["stone_d"])

def temple(cv, cx, base, pal, rng):
    """A two-tier temple hall with a glowing doorway: the guardian's home."""
    steps(cv, cx, base, 112, 3, pal)
    y = base - 12
    tiers = [(88, 46, 126, 24), (60, 34, 94, 20)]
    for i, (bw, bh, rw, rh) in enumerate(tiers):
        cv.rect(cx - bw - 3, y - 3, bw * 2 + 6, 3, pal["wood"])
        cv.rect(cx - bw, y - bh, bw * 2, bh - 3, pal["wall"])
        cv.rect(cx - bw, y - bh, bw * 2, 2, pal["wall_d"])
        for yy in range(y - bh + 2, y - 3):                                   # soft age on the wall
            for xx in range(cx - bw, cx + bw):
                if hsh(xx, yy, 77) < .05: cv.px(xx, yy, lerp(pal["wall"], pal["wall_d"], .6))
        for px_ in range(cx - bw, cx + bw + 1, max(12, bw // 3)):              # lacquered pillars
            cv.rect(px_ - 2, y - bh, 4, bh - 3, pal["red"]); cv.rect(px_ + 1, y - bh, 1, bh - 3, pal["red_d"])
        if i == 0:                                                              # the doorway: the crystal's light spills out
            dw, dh = 20, 40
            cv.rect(cx - dw - 3, y - dh - 3, dw * 2 + 6, dh, pal["wood"])
            for yy in range(y - dh, y - 3):
                for xx in range(cx - dw, cx + dw):
                    t = (yy - (y - dh)) / dh
                    c = lerp(pal["glow"], INK, .15 + .5 * (1 - t) ** 1.5)
                    if abs(xx - cx) > dw - 3: c = lerp(c, INK, .45)
                    cv.px(xx, yy, c)
        else:
            for wx in (cx - bw // 2, cx + bw // 2):
                cv.rect(wx - 7, y - bh + 8, 14, bh - 18, pal["wood"])
                for k in range(3): cv.rect(wx - 6 + k * 5, y - bh + 9, 1, bh - 20, lerp(pal["glow"], pal["gold"], .4))
        y -= bh
        oa.roof(cv, cx, y + 2, rw, rh, pal["tile"], pal["tile_hi"], pal["gold"])
        _hang(cv, cx - rw, cx + rw, y + 5, pal, rng, .18, 7)
        y -= rh - 2
    cv.rect(cx - 1, y - 24, 3, 24, pal["gold"])
    for k in range(4): cv.rect(cx - 3, y - 7 - k * 5, 7, 2, pal["gold"])
    for dy in range(-4, 5):
        for dx in range(-(4 - abs(dy)), 5 - abs(dy)): cv.px(cx + dx, y - 30 + dy, lerp(pal["glow"], oa.CREAM, max(0.0, min(1.0, .45 + .08 * dy))))

def broken_pillar(cv, x, base, h, pal, rng):
    w = 8
    cv.rect(x - w // 2 - 2, base - 5, w + 4, 5, pal["stone_d"])
    for xx in range(x - w // 2, x + w // 2 + 1):
        top = base - h + rng.randint(0, 7)
        for yy in range(top, base - 5):
            c = pal["stone"] if xx < x + 1 else pal["stone_d"]
            if (yy // 5) % 2 == 0 and hsh(xx, yy, 5) < .3: c = lerp(c, pal["stone_d"], .5)
            cv.px(xx, yy, c)
        cv.px(xx, top, pal["moss_hi"]); cv.px(xx, top + 1, pal["moss"])
    _hang(cv, x - w // 2, x + w // 2 + 1, base - h + 8, pal, rng, .25, 5)
    for k in range(rng.randint(2, 4)):                                         # rubble at the foot
        rx = x + rng.randint(-14, 14); cv.rect(rx, base - 3, rng.randint(2, 4), 3, pal["stone_d"]); cv.px(rx, base - 3, pal["stone"])

def ruin_arch(cv, cx, base, w, h, pal, rng):
    """A stone gate: one post stands whole, the other is broken, the lintel has lost an end."""
    for side, hh in ((-1, h), (1, h - rng.randint(14, 24))):
        px_ = cx + side * w // 2
        cv.rect(px_ - 4, base - hh, 8, hh, pal["stone"]); cv.rect(px_ + 1, base - hh, 3, hh, pal["stone_d"])
        cv.rect(px_ - 6, base - 5, 12, 5, pal["stone_d"])
        for xx in range(px_ - 4, px_ + 4): cv.px(xx, base - hh, pal["moss_hi"])
    left = cx - w // 2 - 7; right = cx + w // 2 + 7 - rng.randint(10, 16)
    cv.rect(left, base - h - 6, right - left, 6, pal["stone"]); cv.rect(left, base - h - 1, right - left, 1, pal["stone_d"])
    cv.rect(left - 2, base - h - 8, (right - left) + 4, 2, pal["red"])
    for xx in range(left, right):
        if hsh(xx, 3, 9) < .5: cv.px(xx, base - h - 7, pal["moss_hi"])
    _hang(cv, left, right, base - h, pal, rng, .35, 9)

def ruin_hall(cv, cx, base, pal, rng):
    """What is left of a smaller hall: a wall with a hole, a few pillars, the roof tiles fallen in the dust."""
    bw, bh = 62, 40
    cv.rect(cx - bw - 3, base - 3, bw * 2 + 6, 3, pal["wood"])
    for xx in range(cx - bw, cx + bw):
        top = base - bh + (0 if abs(xx - cx) > 30 else rng.randint(10, 24)) + rng.randint(0, 3)
        for yy in range(top, base - 3):
            c = pal["wall"] if (xx // 3 + yy // 7) % 5 else lerp(pal["wall"], pal["wall_d"], .5)
            if xx > cx + 10 and xx < cx + 34 and yy < base - 16: continue         # a hole you can see through
            cv.px(xx, yy, lerp(c, INK, .18))
        cv.px(xx, top, pal["moss_hi"])
    for px_ in range(cx - bw, cx + bw + 1, 21):
        keep = rng.random() < .65
        hgt = bh if keep else rng.randint(12, 24)
        cv.rect(px_ - 2, base - 3 - hgt, 4, hgt, pal["red"]); cv.rect(px_ + 1, base - 3 - hgt, 1, hgt, pal["red_d"])
    for k in range(7):                                                           # fallen tiles
        tx = cx + rng.randint(-bw - 14, bw + 14); cv.rect(tx, base - 4, rng.randint(3, 6), 2, pal["tile_hi"]); cv.rect(tx, base - 2, 5, 2, pal["tile"])
    _hang(cv, cx - bw, cx + bw, base - bh + 12, pal, rng, .12, 8)

def lantern(cv, x, base, pal):
    cv.rect(x - 4, base - 4, 9, 4, pal["stone_d"]); cv.rect(x - 1, base - 14, 3, 10, pal["stone"])
    cv.rect(x - 4, base - 20, 9, 6, pal["stone"]); cv.rect(x - 2, base - 19, 5, 4, pal["glow"])
    cv.rect(x - 6, base - 23, 13, 3, pal["stone_d"]); cv.px(x, base - 25, pal["stone"])

def door_arch(cv, x, base, side, pal):
    """The frame of a wing's doorway at the mouth of the tunnel. `x` is the inner face of the wall and `side` which wall it
    is (-1 left, 1 right): one post hugging the wall, a lintel reaching out over the room, a little gold roof and a lamp."""
    h = 44; out = -side
    def span(a, w): return (a, w) if out > 0 else (a - w, w)
    px_, pw = span(x + out * 2, 4); cv.rect(px_, base - h, pw, h, pal["red"]); cv.rect(px_ + (pw - 1 if out > 0 else 0), base - h, 1, h, pal["red_d"])
    lx, lw = span(x, 26); cv.rect(lx, base - h - 5, lw, 4, pal["wood"]); cv.rect(lx, base - h - 6, lw, 1, pal["gold"])
    rx, rw = span(x + out * 3, 20); cv.rect(rx, base - h - 9, rw, 3, pal["tile"]); cv.rect(rx, base - h - 10, rw, 1, pal["tile_hi"])
    tip = x + out * 25; cv.px(tip, base - h - 11, pal["gold"]); cv.px(tip, base - h - 7, pal["gold"])
    lamp = x + out * 18; cv.rect(lamp, base - h - 1, 2, 3, pal["gold"]); cv.rect(lamp - 1, base - h + 2, 4, 5, lerp(pal["glow"], INK, .15))

# ------------------------------------------------------------------------------------------------ the lantern shrines
# A shrine wing is a quiet room: a forest of tall trunks, stone stairs climbing into mist, red gates, stone lanterns and, where the
# hero rests, a halo of light. Every piece below takes the region's palette (PAL for stone and tile, SPAL for trees, mist and gates).
SPAL = {
 "overgrowth": _pal(trunk="5e3c2a", trunk_d="3a2318", trunk_hi="93613f", leaf="2e4a2e", leaf_d="17281c", sky_top="08140f", sky_bot="2c4a3c",
                    mist="9ab89a", light="d8f0b0", torii="c24a2a", torii_d="7c2a1c", fire="ffcf80"),
 "rustworks": _pal(trunk="6e3c24", trunk_d="3c2018", trunk_hi="a9663a", leaf="5e3a22", leaf_d="2e1c14", sky_top="180c0a", sky_bot="5e3424",
                   mist="d89a68", light="ffc888", torii="dc5a2a", torii_d="8c3218", fire="ffc070"),
 "drowned": _pal(trunk="2e4c4e", trunk_d="16282c", trunk_hi="4e8486", leaf="1e5a52", leaf_d="0e2e2c", sky_top="051317", sky_bot="1e5a62",
                 mist="8ad8d0", light="b8fff0", torii="3cbaa8", torii_d="1c7c74", fire="c8fff0"),
 "bone": _pal(trunk="b6ac8e", trunk_d="6e664f", trunk_hi="e6dec2", leaf="7e7862", leaf_d="48422f", sky_top="1c1812", sky_bot="6e6652",
              mist="e6dec2", light="fff4d0", torii="a8503a", torii_d="5e261c", fire="fff0c0"),
 "ash": _pal(trunk="2c222a", trunk_d="120c14", trunk_hi="5e4454", leaf="3c2c3a", leaf_d="1a1220", sky_top="09050b", sky_bot="3c1e26",
             mist="a87074", light="ff9a60", torii="a42c32", torii_d="5c1418", fire="ff9a58"),
}
CRE = oa.CREAM

def sp_of(r): return SPAL.get(r.theme, SPAL["overgrowth"])

def _fog(c, sp, t): return lerp(c, sp["mist"], max(0.0, min(1.0, t)))

def shrine_back(cv, r, base, sp):
    """The whole backdrop: dusk in the trees, dithered from the dark top to the misty floor."""
    W, H = cv.W, cv.H
    for y in range(H):
        t = min(1.0, y / max(1, base)) ** 1.3 * 7.0
        i = int(t); f = t - i
        ca = lerp(sp["sky_top"], sp["sky_bot"], min(1.0, i / 7.0)); cb = lerp(sp["sky_top"], sp["sky_bot"], min(1.0, (i + 1) / 7.0))
        for x in range(W): cv.p[y][x] = cb if dith(f, x, y) else ca

def shafts(cv, r, base, sp, xs):
    """Slanting shafts of light through the branches."""
    for x0 in xs:
        for y in range(40, base):
            cx = x0 + (y - 40) * 0.55; hw = 7 + (y - 40) * 0.07; fall = 1.0 - (y - 40) / max(1, base - 40)
            for x in range(int(cx - hw), int(cx + hw) + 1):
                k = (1.0 - abs(x - cx) / hw) * fall * 0.62
                if k > 0 and dith(k * 0.7, x, y): cv.px(x, y, lerp(cv.get(x, y), sp["light"], .3))

def cedar(cv, x, w, top, base, sp, rng, fog=0.3):
    """A great trunk with grooved bark, a flare at its foot and a few stubs of branches; thicker towards the ground; hazed by distance."""
    seed = rng.randint(1, 999)
    for yy in range(top, base):
        k = (yy - top) / max(1, base - top)
        ww = w * (1.0 + 0.28 * k ** 3)
        for xx in range(int(x - ww / 2), int(x + ww / 2) + 1):
            u = (xx - (x - ww / 2)) / max(1.0, ww)
            c = sp["trunk_hi"] if u < .2 else (sp["trunk"] if u < .62 else (lerp(sp["trunk"], sp["trunk_d"], .55) if u < .86 else sp["trunk_d"]))
            g = hsh(xx, 7, seed)
            if g < .34 and (yy + int(g * 60)) % 19 < 14: c = lerp(c, sp["trunk_d"], .45)
            elif g > .93 and (yy // 3) % 5 != 0: c = lerp(c, sp["trunk_hi"], .35)
            if hsh(xx, yy, seed) < .018: c = lerp(c, sp["trunk_d"], .6)
            cv.px(xx, yy, _fog(c, sp, fog + .26 * k))
    for j in range(3):                                                                # branch stubs
        by = top + int((base - top) * (.2 + .22 * j) + rng.randint(-6, 6)); side = rng.choice((-1, 1)); bx = x + side * int(w / 2)
        for t in range(rng.randint(4, 8)):
            cv.px(bx + side * t, by - t // 3, _fog(sp["trunk_d"], sp, fog)); cv.px(bx + side * t, by - t // 3 + 1, _fog(sp["trunk"], sp, fog))

def canopy(cv, r, sp, rng, y0=36, depth=48):
    """Needles hanging from the ceiling in ragged clumps, with loose strands; the tops of the trunks vanish into it."""
    ph = rng.random() * 6.0
    for x in range(36, cv.W - 36):
        n = 0.5 + 0.5 * math.sin(x * .07 + ph) * math.sin(x * .031 + ph * 1.7)
        hgt = int(depth * (.3 + .7 * (.55 * n + .45 * hsh(x // 3, 5, 3))))
        for y in range(y0, y0 + hgt):
            k = (y - y0) / max(1, hgt)
            c = sp["leaf_d"] if (k < .55 or dith(.5, x, y)) else sp["leaf"]
            if k > .8 and not dith(1.0 - k + .15, x, y): continue
            if hsh(x, y, 11) < .06: c = lerp(c, sp["light"], .2)
            cv.px(x, y, c)
        if hsh(x, 1, 21) < .07:
            for y in range(y0 + hgt, y0 + hgt + rng.randint(5, 14)): cv.px(x, y, sp["leaf_d"] if y % 2 else sp["leaf"])

def stairs(cv, cx, base, top, w0, w1, pal, sp, rng):
    """Stone stairs climbing away between the trunks: each step narrower and lower than the one under it, hazed into the mist, with
    low cheek walls and a lamp on a post every few steps."""
    y = base; i = 0; n = max(8, (base - top) // 5)
    while y > top and i < n * 2:
        t = min(1.0, i / n); h = max(2, int(round(7 * (1 - .66 * t)))); w = int(w0 + (w1 - w0) * t ** .9)
        tread = _fog(lerp(pal["stone"], CRE, .22), sp, .1 + .62 * t); riser = _fog(pal["stone_d"], sp, .14 + .62 * t)
        cv.rect(cx - w // 2, y - h, w, h, riser); cv.rect(cx - w // 2, y - h, w, 1 if h < 5 else 2, tread)
        for sx in range(cx - w // 2 + 2, cx + w // 2 - 2):
            if hsh(sx, i, 9) < .05: cv.px(sx, y - h, _fog(pal["moss"], sp, .15 + .5 * t))
        cw = max(2, int(5 - 3 * t))                                                  # the cheek walls
        for sdx in (-1, 1):
            xx = cx + sdx * (w // 2) + (0 if sdx > 0 else -cw)
            cv.rect(xx, y - h - 3, cw, h + 3, _fog(pal["stone_d"], sp, .1 + .6 * t)); cv.rect(xx, y - h - 3, cw, 1, _fog(pal["stone"], sp, .1 + .6 * t))
        if i % 5 == 3 and t < .85:                                                   # a lamp on a post
            for sdx in (-1, 1):
                xx = cx + sdx * (w // 2 + 2) - 1
                cv.rect(xx, y - h - 9, 2, 6, _fog(pal["stone_d"], sp, .3 + .5 * t)); cv.rect(xx - 1, y - h - 12, 4, 3, lerp(sp["fire"], sp["mist"], .2 + .4 * t))
        y -= h; i += 1

def torii_gate(cv, cx, base, w_in, h, pal, sp, rng, fog=0.0):
    """A red gate: two tapering pillars on white stone feet, the lower tie beam (nuki), a short strut, and the great top beam (kasagi,
    dark, lifting at its ends) over a red layer (shimaki). Paint flakes and moss on the feet, as on a weathered one."""
    F = lambda c: _fog(c, sp, fog)
    red, red_d, black = sp["torii"], sp["torii_d"], pal["wood"]
    pw = max(5, w_in // 9); seed = rng.randint(1, 999)
    for sx in (cx - w_in // 2, cx + w_in // 2):
        for yy in range(base - h + 6, base - 7):
            wid = pw + (1 if yy > base - h * .5 else 0)
            for xx in range(sx - wid // 2, sx - wid // 2 + wid):
                u = (xx - (sx - wid // 2)) / wid
                c = lerp(red, CRE, .2) if u < .25 else (red if u < .68 else red_d)
                if hsh(xx, yy, seed) < .03: c = lerp(c, pal["wall"], .5)                 # flaked paint
                elif hsh(xx, 3, seed) < .2 and (yy + xx) % 23 < 4: c = lerp(c, red_d, .5)   # rain streaks
                cv.px(xx, yy, F(c))
        fx = sx - pw // 2 - 2; fw = pw + 5                                              # the white stone foot
        cv.rect(fx, base - 7, fw, 7, F(pal["wall"])); cv.rect(fx + fw - 2, base - 7, 2, 7, F(pal["wall_d"])); cv.rect(fx, base - 7, fw, 1, F(lerp(pal["wall"], CRE, .4)))
        for k in range(fw):
            if hsh(fx + k, 1, seed) < .35: cv.px(fx + k, base - 1, F(pal["moss"])); 
            if hsh(fx + k, 2, seed) < .15: cv.px(fx + k, base - 2, F(pal["moss_hi"]))
    yn = base - int(h * .68)
    nx0 = cx - w_in // 2 - pw // 2 - 4; nw = w_in + pw + 8
    cv.rect(nx0, yn, nw, 5, F(red)); cv.rect(nx0, yn, nw, 1, F(lerp(red, CRE, .25))); cv.rect(nx0, yn + 4, nw, 1, F(red_d))
    cv.rect(cx - 3, yn - int(h * .2), 6, int(h * .2), F(red)); cv.rect(cx + 1, yn - int(h * .2), 2, int(h * .2), F(red_d))   # the strut
    top = base - h; half = w_in // 2 + pw // 2 + max(10, w_in // 7)
    for xx in range(-half, half + 1):
        lift = int(round(max(5, h // 18) * (abs(xx) / half) ** 2.4)); y0 = top - lift
        cv.rect(cx + xx, y0, 1, 4, F(black)); cv.px(cx + xx, y0, F(lerp(black, sp["trunk_hi"], .35)))
        if abs(xx) < half - 5: cv.rect(cx + xx, y0 + 4, 1, 3, F(red if hsh(xx, 8, seed) > .06 else red_d))

def toro(cv, x, base, pal, sp, h=44, fog=0.0, lit=True):
    """A stone lantern: foot, post, a platform, the fire box with its lit windows, a broad roof and a finial. Moss on the roof."""
    F = lambda c: _fog(c, sp, fog)
    st, sd, hi = pal["stone"], pal["stone_d"], lerp(pal["stone"], CRE, .35)
    k = h / 44.0
    def R(dx, dy, w, hh, c): cv.rect(int(x + dx * k), int(base - dy * k), max(1, int(w * k)), max(1, int(hh * k)), F(c))
    R(-7, 4, 14, 4, sd); R(-7, 4, 14, 1, st)                                         # foot
    R(-3, 18, 6, 14, st); R(0, 18, 3, 14, sd); R(-3, 18, 1, 14, hi)                    # post
    R(-6, 21, 13, 3, st); R(-6, 21, 13, 1, hi)                                        # platform
    R(-5, 33, 11, 12, sd); R(-4, 32, 9, 10, st)                                       # the fire box
    glow = lerp(sp["fire"], CRE, .2) if lit else lerp(sd, sp["mist"], .2)
    R(-2, 30, 5, 6, glow); R(-2, 30, 5, 1, lerp(glow, CRE, .5))                          # its window
    for i in range(7):                                                                # the roof: wide at its eaves, narrowing up
        w = 20 - i * 2
        R(-w // 2, 39 + i, w, 1, st if i % 2 else hi if i == 6 else st); 
    R(-10, 39, 20, 1, sd)
    R(-1, 48, 3, 5, st)
    for j in range(5):
        if hsh(int(x) + j, 4, 3) < .6: cv.px(int(x - 6 * k + j * 2 * k), int(base - 45 * k), F(pal["moss_hi"]))
    if lit:
        cx_, cy_ = int(x), int(base - 33 * k); rad = int(22 * k + 6)
        for dy in range(-rad, rad + 1):
            for dx in range(-rad, rad + 1):
                d = math.hypot(dx, dy)
                if d < rad:
                    kk = (1 - d / rad) ** 2 * .6
                    if dith(kk, cx_ + dx, cy_ + dy): cv.px(cx_ + dx, cy_ + dy, lerp(cv.get(cx_ + dx, cy_ + dy), sp["fire"], .32))

def hall(cv, cx, base, pal, sp, rng):
    """A small shrine hall on two steps: lacquered pillars, a lit doorway with a rope across it, a hipped roof with upturned eaves."""
    steps(cv, cx, base, 50, 2, pal, rise=3, inset=7)
    y = base - 6
    cv.rect(cx - 36, y - 30, 72, 30, pal["wall"]); cv.rect(cx - 36, y - 30, 72, 2, pal["wall_d"])
    for xx in range(cx - 36, cx + 36):
        for yy in range(y - 28, y):
            if hsh(xx, yy, 41) < .04: cv.px(xx, yy, lerp(pal["wall"], pal["wall_d"], .6))
    for px_ in (cx - 34, cx - 12, cx + 10, cx + 32):
        cv.rect(px_, y - 30, 4, 30, sp["torii"]); cv.rect(px_ + 3, y - 30, 1, 30, sp["torii_d"])
    for yy in range(y - 24, y):                                                       # the doorway, lit from within
        t = (yy - (y - 24)) / 24.0
        for xx in range(cx - 8, cx + 8): cv.px(xx, yy, lerp(sp["fire"], INK, .15 + .5 * (1 - t) ** 1.4 + (.3 if abs(xx - cx) > 5 else 0)))
    for k in range(-8, 9): cv.px(cx + k, y - 24 + int(2 * math.sin(k * .4)) + 2, pal["gold"])   # the rope
    for k in (-5, 0, 5): cv.rect(cx + k, y - 21, 1, 4, CRE)                              # paper streamers
    oa.roof(cv, cx, y - 28, 46, 20, pal["tile"], pal["tile_hi"], pal["gold"])
    _hang(cv, cx - 46, cx + 46, y - 26, pal, rng, .1, 6)

def halo(cv, x, y, sp, rad=30):
    """The soft light round the resting lantern."""
    for dy in range(-rad, rad + 1):
        for dx in range(-rad, rad + 1):
            d = math.hypot(dx, dy)
            if d < rad:
                k = (1 - d / rad) ** 1.5 * 1.0
                if dith(k, x + dx, y + dy): cv.px(x + dx, y + dy, lerp(cv.get(x + dx, y + dy), sp["light"], .5))

def fireflies(cv, sp, rng, n, x0, x1, y0, y1):
    for _ in range(n):
        x = rng.randint(x0, x1); y = rng.randint(y0, y1); c = lerp(sp["light"], CRE, .4)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if dith(.4, x + dx, y + dy): cv.px(x + dx, y + dy, lerp(cv.get(x + dx, y + dy), sp["light"], .5))
        cv.px(x, y, c)

def ground_mist(cv, base, sp, rng, height=34, strength=.7, tone=.4):
    """Mist lying on the ground: thickest at the floor, thinning upward, in a few drifting banks."""
    ph = rng.random() * 6.0
    for y in range(base - height, base):
        t = (y - (base - height)) / height
        for x in range(cv.W):
            bank = .55 + .45 * math.sin(x * .021 + ph + y * .07) * math.sin(x * .047 - ph)
            k = strength * (t ** 1.6) * bank
            if dith(k, x, y): cv.px(x, y, lerp(cv.get(x, y), sp["mist"], tone))

def draw(cv, r, rng):
    deco = getattr(r, "deco", None)
    if not deco: return
    pal = pal_of(r)
    sp_ = None
    for d in deco:
        t = d["t"]; x = int(d["x"]); y = int(d["y"]); g = random.Random(int(d.get("s", x * 7 + y)))
        if t == "temple": temple(cv, x, y, pal, g)
        elif t == "pillar": broken_pillar(cv, x, y, int(d.get("h", 40)), pal, g)
        elif t == "ruin_arch": ruin_arch(cv, x, y, int(d.get("w", 40)), int(d.get("h", 56)), pal, g)
        elif t == "ruin_hall": ruin_hall(cv, x, y, pal, g)
        elif t == "lantern": lantern(cv, x, y, pal)
        elif t == "door_arch": door_arch(cv, x, y, int(d.get("side", 1)), pal)
        elif t == "shrine_back": spp = sp_of(r); shrine_back(cv, r, y, spp); shafts(cv, r, y, spp, d.get("shafts", [90, 210, 330]))
        elif t == "cedar": cedar(cv, x, int(d["w"]), int(d.get("top", 30)), y, sp_of(r), g, float(d.get("fog", .3)))
        elif t == "canopy": canopy(cv, r, sp_of(r), g)
        elif t == "stairs": stairs(cv, x, y, int(d["top"]), int(d["w0"]), int(d["w1"]), pal, sp_of(r), g)
        elif t == "torii": torii_gate(cv, x, y, int(d["w"]), int(d["h"]), pal, sp_of(r), g, float(d.get("fog", 0)))
        elif t == "toro": toro(cv, x, y, pal, sp_of(r), int(d.get("h", 44)), float(d.get("fog", 0)))
        elif t == "hall": hall(cv, x, y, pal, sp_of(r), g)
        elif t == "halo": halo(cv, x, y, sp_of(r), int(d.get("r", 30)))
        elif t == "fireflies": fireflies(cv, sp_of(r), g, int(d.get("n", 10)), int(d.get("x0", 50)), int(d.get("x1", 430)), int(d.get("y0", 90)), int(d.get("y1", 200)))
        elif t == "ground_mist": ground_mist(cv, y, sp_of(r), g, int(d.get("h", 34)), float(d.get("k", .7)))
