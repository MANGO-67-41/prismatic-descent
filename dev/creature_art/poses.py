"""Creatures drawn whole, frame by frame, like the hero: each pose is a set of shaded parts placed by a phase.
furnace hound, carrion kite, bone vulture, ember vulture, lure angler, soot wraith."""
import math
from engine import Ell, Tube, Poly, Feather, Rod, Glow, Dot, ramp, hexc, mix, INK, WHITE, render

def leg(hip, knee, foot, r0, r1, mat, z=0, claw=None):
    out = [Tube([hip, knee], r0, (r0 + r1) / 2, mat, z=z), Tube([knee, foot], (r0 + r1) / 2, r1, mat, z=z)]
    if claw: out.append(Rod(foot, (foot[0] + 2, foot[1]), claw, z=z + 1))
    return out

# ------------------------------------------------------------------------------------------------ furnace hound
def hound(mode, i, n):
    """A starved iron dog: a cage of ribs with a fire inside, a long metal skull and a whip of a tail. Runs flat out."""
    B, M, R = ramp("2a1c18"), ramp("6a5a50"), ramp("4a3028")
    fire = hexc("ff8a30")
    ph = i / n * math.tau
    gal = math.sin(ph) if mode == "run" else 0
    crouch = {"pounce": [4, 6, -3, -5][i % 4], "stun": 3}.get(mode, 0)
    by = -20 + crouch + (abs(gal) * -2 if mode == "run" else math.sin(ph) * .5)
    items = []
    legs = [(-11, 0), (-8, math.pi), (8, .4), (11, math.pi + .4)]
    for k, (hxo, off) in enumerate(legs):
        s = math.sin(ph + off) if mode == "run" else (0.3 if mode == "pounce" and i >= 2 else 0)
        hip = (hxo, by + 3)
        foot = (hxo + s * 8, -max(0.0, math.cos(ph + off)) * 4 if mode == "run" else 0)
        if mode == "pounce" and i >= 2: foot = (hxo + (12 if hxo > 0 else -10), -8)
        knee = (hip[0] + (-4 if hxo > 0 else 4), (hip[1] + foot[1]) / 2 + 1)
        items += leg(hip, knee, foot, 1.8, .9, R if k % 2 else B, z=0 if k % 2 else 4, claw=hexc("8a7a70"))
    items.append(Ell((-1, by), 13, 7, B, tex="speck", z=1))
    items.append(Glow((-1, by + .5), fire, 3, 2))
    for k in range(5):   # ribs over the fire
        x = -9 + k * 4
        items.append(Tube([(x, by - 6), (x + 1, by), (x - .5, by + 6)], .9, .8, M, z=3))
    items.append(Tube([(-12, by - 6), (12, by - 7)], 1.6, 1.4, M, tex="ridge", z=3))       # spine
    tail = [(-13, by - 2), (-19, by - 6 + gal * 3), (-25, by - 4 + gal * 5), (-29, by + gal * 6)]
    items.append(Tube(tail, 1.4, .5, B, tex="ridge", z=0))
    jaw = {"pounce": 3, "run": 1}.get(mode, 0)
    hx, hy = 15 + crouch * -.3, by - 6 - (2 if mode == "pounce" and i >= 2 else 0)
    items += [Tube([(10, by - 4), (hx - 3, hy)], 3.0, 2.5, B, z=4),
              Ell((hx + 3, hy), 7, 3.6, M, rot=.15, tex="plate", z=5),
              Poly([(hx, hy + 2), (hx + 10, hy + 3 + jaw), (hx + 9, hy + 5 + jaw), (hx, hy + 5)], R, z=4)]
    for k in range(4): items.append(Dot((hx + 3 + k * 1.8, hy + 3 + jaw * .5), hexc("e8d8c0"), 6))
    items.append(Glow((hx + 4, hy - 1), fire, 0, 7))
    return items

# ------------------------------------------------------------------------------------------------ rib crawler
def wings(sx, lift, span, dark, accent, n_feathers, length, z):
    out = []
    shoulder = (sx * 5, -4)
    elbow = (sx * 16 * span, -4 + lift * 12)
    tip = (sx * 34 * span, -8 + lift * 20)
    for k in range(n_feathers):
        t = k / max(1, n_feathers - 1)
        root = (shoulder[0] + (elbow[0] - shoulder[0]) * t * 2, shoulder[1] + (elbow[1] - shoulder[1]) * t * 2) if t < .5 else \
               (elbow[0] + (tip[0] - elbow[0]) * (t - .5) * 2, elbow[1] + (tip[1] - elbow[1]) * (t - .5) * 2)
        L = length * (.7 + t * .6)
        ang = math.pi / 2 + sx * (-.15 - t * .9) * (1 if lift < .4 else .6)
        out.append(Feather(root, (root[0] + math.cos(ang) * L * .6 * sx * -1 + sx * t * 3, root[1] + math.sin(ang) * L), 1.6 + (1 - t) * .8, dark, accent, z=z, bend=sx * 1.2))
    return out, shoulder, elbow, tip

def vulture(mode, i, n, ember=False):
    B = ramp("1c1424" if not ember else "1a0c14")
    Bn = ramp("e8e4f0" if not ember else "f0e0d0")
    dark = hexc("1c1424" if not ember else "1a0c14"); accent = hexc("4a5ad0" if not ember else "ff7a3a")
    ph = i / n * math.tau
    if mode == "soar": lift, span = math.sin(ph) * .9, 1.0
    elif mode == "tell": lift, span = -1.1, 1.05
    elif mode == "dive": lift, span = -.7, .45
    else: lift, span = .7, .8
    items = []
    for sx, z in ((-1, -3), (1, -2)):
        fe, sh, el, tp = wings(sx, lift, span, dark, accent, 9, 16, z)
        items += fe
        items += [Tube([sh, el], 2.6, 1.8, B, z=0 if sx < 0 else 3), Tube([el, tp], 1.8, .6, B, z=0 if sx < 0 else 3)]
    items.append(Ell((0, 0), 10, 8, B, tex="speck", z=1))
    items.append(Ell((-2, -3), 6, 3, ramp("3a2e48" if not ember else "3a1a26"), z=2))
    for k in range(4): items.append(Feather((-5, 5), (-12 - k * 2, 16 + k * 2), 1.8, dark, accent, z=0))
    for s in (-1, 1): items.append(Tube([(s * 3, 7), (s * 4, 13), (s * 5 + 2, 15)], 1.2, .6, ramp("6a6070"), z=2))   # talons
    neck_dx = 6 if mode != "dive" else 9
    head = (neck_dx + 5, 9 if mode != "dive" else 12)
    items += [Tube([(4, 3), (neck_dx + 2, 7), head], 2.2, 1.8, B, tex="ridge", z=3),
              Ell(head, 5.2, 4.4, Bn, tex="speck", z=4),
              Poly([(head[0] + 3, head[1] - 1), (head[0] + 11, head[1] + 2), (head[0] + 8, head[1] + 4), (head[0] + 3, head[1] + 3)], Bn, z=5),
              Dot((head[0] + 1, head[1] - .5), INK, 6), Dot((head[0] + 2, head[1] - .5), INK, 6),
              Glow((head[0] + 1.5, head[1] - .5), hexc("2a3ad0" if not ember else "ff4a2a"), 0 if mode != "tell" else 1, 7)]
    if ember:
        for (x, y) in ((-6, -2), (3, -4), (-2, 3)): items.append(Glow((x, y), hexc("ff7a3a"), 0, 6))
    return items

def kite(mode, i, n):
    """Carrion kite: a hooked skull on a scrap of a body, wings of torn leather and rusted wire, trailing streamers."""
    B, Bn, W = ramp("2a1c18"), ramp("d8c8b0"), ramp("4a3028")
    dark, accent = hexc("2a1c18"), hexc("e09a4a")
    ph = i / n * math.tau
    lift = math.sin(ph) * .8 if mode == "flap" else {"swoop": -.5, "tell": -1.0, "stun": .6}[mode]
    span = .55 if mode == "swoop" else .8
    items = []
    for sx, z in ((-1, -2), (1, -1)):
        sh = (sx * 3, -2); el = (sx * 13 * span, -3 + lift * 10); tp = (sx * 26 * span, -6 + lift * 16)
        mem = [sh, el, tp, (tp[0] - sx * 4, tp[1] + 7), (el[0] - sx * 2, el[1] + 9), (sx * 2, 6)]
        items.append(Poly(mem, W, z=0 if sx < 0 else 2, tex="speck", bulge=.3))
        for k in range(3):   # torn holes
            hx = el[0] + (tp[0] - el[0]) * (.3 + k * .2); hy = el[1] + (tp[1] - el[1]) * (.3 + k * .2) + 4
            items.append(Dot((hx, hy), (0, 0, 0, 0) if False else INK, 3))
        items += [Tube([sh, el], 1.6, 1.2, B, z=1 if sx < 0 else 3), Tube([el, tp], 1.2, .5, B, z=1 if sx < 0 else 3)]
        items.append(Rod(el, (el[0] + sx * 3, el[1] + 12), accent, z=3))
    items.append(Ell((0, 0), 6, 5, B, tex="speck", z=2))
    for k in range(2): items.append(Feather((-3, 3), (-14 - k * 4, 14 + k * 5), 1.4, dark, accent, z=1, bend=2))
    head = (7, 3)
    open_ = 2 if mode == "tell" else 0
    items += [Ell(head, 4, 3.4, Bn, tex="speck", z=4),
              Poly([(head[0] + 2, head[1] - 1), (head[0] + 10, head[1] + 1), (head[0] + 9, head[1] + 4 + open_), (head[0] + 7, head[1] + 2), (head[0] + 2, head[1] + 2)], Bn, z=5),
              Dot((head[0], head[1] - .5), INK, 6), Glow((head[0] + .5, head[1] - .5), hexc("ffd080"), 0, 7)]
    for s in (-1, 1): items.append(Tube([(s * 2, 4), (s * 2 + 1, 9), (s * 2 + 3, 10)], 1.0, .5, ramp("6a6070"), z=3))
    return items

# ------------------------------------------------------------------------------------------------ lure angler
def angler(mode, i, n):
    """A swollen black fish of the flooded floors: a lure on a stalk glowing in front of a jaw of needles."""
    B, J = ramp("161e28", "4a6a80"), ramp("101820")
    ph = i / n * math.tau
    open_ = {"lunge": [3, 7, 8, 4][i % 4], "stun": 1}.get(mode, 1 + math.sin(ph) * .5)
    sway = math.sin(ph) * 2 if mode == "idle" else 0
    items = [Ell((-2, 0), 13, 9.5, B, tex="speck", z=1),
             Poly([(-4, 2), (14, 3 + open_), (13, 8 + open_), (-4, 9)], J, z=2, bulge=.5),
             Poly([(2, 2), (14, 2.5 + open_ * .7), (2, 6)], [INK] * 5, z=3)]
    for k, (up, dn) in enumerate(((3, 2), (5, 3), (2, 5), (4, 2), (6, 4), (2, 3), (4, 5))):   # needles, crooked and uneven
        x = 3 + k * 1.6
        items.append(Rod((x, 1.5), (x + .6, 1.5 + up), hexc("e8f0f0"), z=4))
        items.append(Rod((x + .8, 4 + open_ + 3.5), (x + .3, 4 + open_ + 3.5 - dn), hexc("c8d8d8"), z=4))
    items += [Dot((6, -4), WHITE, 5), Dot((5, -4), INK, 5)]
    stalk = [(2, -8), (8 + sway * .5, -15), (15 + sway, -13), (17 + sway, -7)]
    items.append(Tube(stalk, 1.0, .5, ramp("2a3a4a"), z=0))
    items.append(Glow(stalk[-1], hexc("8affee"), 2, 6))
    for s in (-1, 1): items.append(Feather((-6, s * 6), (-12, s * 12 + sway * s), 2.4, hexc("161e28"), hexc("4a8aa0"), z=0))
    items.append(Feather((-14, 0), (-24, -4 - sway), 3.0, hexc("161e28"), hexc("4a8aa0"), z=0))
    items.append(Feather((-14, 1), (-24, 6 + sway), 3.0, hexc("161e28"), hexc("4a8aa0"), z=0))
    return items

# ------------------------------------------------------------------------------------------------ soot wraith body
def wraith(mode, i, n):
    B = ramp("120a10", "ff6a2a")
    ph = i / n * math.tau
    pulse = math.sin(ph) * 1.2 if mode == "idle" else -1
    items = []
    for k in range(7):
        a = k * 2.1
        items.append(Ell((math.cos(a) * 5, math.sin(a * 1.3) * 3.5 + 1), 7 + (k % 3) + pulse * .3, 6 + (k % 2) + pulse * .3, B, tex="speck", z=k))
    for k in range(7):   # eyes like coals, blinking out of step
        if (i + k) % 5 == 0 and mode == "idle": continue
        a = k * .9
        items.append(Glow((math.cos(a) * 6, math.sin(a) * 3 - 2), hexc("ffb040" if k % 2 else "ff6a2a"), 0, 9))
    for k in range(4): items.append(Tube([(-6 + k * 4, 6), (-6 + k * 4 + (k - 1.5), 12 + (k % 2) * 2)], 1.6, .4, B, z=0))   # soot dripping
    return items

# ------------------------------------------------------------------------------------------------ sheets
SPECS = {
    "furnace_hound": (hound, 72, 48, 36, 46, [("idle", 4), ("run", 8), ("pounce", 4), ("stun", 2)]),
    "carrion_kite": (kite, 72, 56, 36, 24, [("flap", 6), ("swoop", 2), ("tell", 2), ("stun", 2)]),
    "bone_vulture": (lambda m, i, n: vulture(m, i, n, False), 100, 80, 50, 34, [("soar", 8), ("tell", 2), ("dive", 2), ("stun", 2)]),
    "ember_vulture": (lambda m, i, n: vulture(m, i, n, True), 100, 80, 50, 34, [("soar", 8), ("tell", 2), ("dive", 2), ("stun", 2)]),
    "lure_angler": (angler, 64, 48, 34, 26, [("idle", 6), ("lunge", 4), ("stun", 2)]),
    "soot_wraith": (wraith, 40, 36, 20, 20, [("idle", 6), ("stun", 2)]),
}

def build(kind, sheet):
    fn, w, h, ox, oy, anims = SPECS[kind]
    for name, n in anims:
        sheet.row(name, [render(fn(name, i, n), w, h, ox, oy) for i in range(n)], w, h, ox, oy)
