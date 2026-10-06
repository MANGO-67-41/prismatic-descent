"""Long-bodied creatures drawn as a head and body segments in 16 directions (the game chains them along the body):
ash wyrm, tide leviathan, marrow worm."""
import math
from engine import Ell, Tube, Poly, Feather, Rod, Glow, Dot, ramp, hexc, mix, INK, WHITE, directions

# ------------------------------------------------------------------------------------------------ ash wyrm
def wyrm_head(open_):
    B, E = ramp("1e1018"), ramp("5a2a30")
    o = open_ * 3.0
    items = [Ell((-1, 0), 7.0, 5.0, B, tex="speck", z=1), Ell((-2, -2.5), 5.0, 2.0, E, z=2)]
    for s in (-1, 1):
        items.append(Tube([(4, 1 + s), (9, 1.5 + s * (2 + o)), (11, s * (1 + o))], 1.5, .4, ramp("3a1a20"), z=3 if s > 0 else 0))
    items += [Glow((3, -1.5), hexc("ffb040"), 1, 4), Glow((0, -2.5), hexc("ff7a3a"), 0, 4)]
    for k in range(3): items.append(Tube([(-3 - k * 2.5, -4), (-6 - k * 2.5, -8)], 1.0, .2, ramp("ff7a3a"), z=0))
    return items

def wyrm_seg(phase):
    B, E = ramp("1e1018"), ramp("4a2028")
    up = -1 if phase else 1
    items = [Ell((0, 0), 5.0, 4.4, B, tex="plate", z=1), Ell((0, -2.6), 4.0, 1.3, E, z=2)]
    for s in (-1, 1):
        tip = (-4, s * (8 + (3 if (s == up) else -1)))
        items.append(Feather((0, s * 2), tip, 2.2, hexc("1e1018"), hexc("ff7a3a"), z=-1 if s > 0 else 0))
        items.append(Feather((2, s * 2), (tip[0] + 3, tip[1] * .8), 1.6, hexc("1e1018"), hexc("ffb040"), z=-1 if s > 0 else 0))
    return items

# ------------------------------------------------------------------------------------------------ tide leviathan
def lev_head(open_):
    B, A, J = ramp("16222c"), ramp("3a5466"), ramp("101820")
    o = open_ * 6.0
    items = [Ell((-6, 0), 8.0, 7.0, B, tex="speck", z=0),
             Poly([(-4, 3), (16, 4 + o), (15, 7 + o), (-4, 7)], J, z=1),                 # the long lower jaw
             Ell((2, -1), 11.0, 6.0, B, tex="speck", z=2),
             Poly([(-6, -6), (8, -7), (15, -3), (4, -3), (-6, -2)], A, z=3, bulge=.8),     # bony armour over the skull
             Poly([(6, -1), (17, 1.5), (16, 3.5), (6, 3)], B, z=3)]
    for k in range(6):   # long teeth
        x = 5 + k * 2
        items.append(Rod((x, 3), (x + .5, 5 + (o * .4 if open_ else 0)), hexc("d8e8e8"), z=4))
        if open_: items.append(Rod((x + 1, 4 + o + 2), (x + 1.3, 4 + o - .5), hexc("b8c8c8"), z=4))
    for k in range(5): items.append(Glow((-6 + k * 3.5, 1.5 - k * .3), hexc("7af0e8"), 0, 5))   # a line of cold lights
    items.append(Glow((9, -2.5), hexc("c8fff6"), 1, 5))
    if open_: items.append(Poly([(5, 3.5), (15, 4 + o * .7), (5, 6)], [INK] * 5, z=2))
    return items

def lev_seg(r):
    B, F = ramp("16222c"), ramp("2a4456")
    items = [Ell((0, 0), r * 1.3, r, B, tex="speck", z=1),
             Tube([(1, -r + .5), (-2, -r - r * .7)], r * .3, .3, F, z=0)]
    if r > 3: items += [Glow((0, r * .25), hexc("7af0e8"), 0, 3), Glow((-r * .8, r * .2), hexc("4aa8c0"), 0, 3)]
    return items

# ------------------------------------------------------------------------------------------------ marrow worm (old machine head)
def worm_head(open_):
    B, M, M2 = ramp("1e2a24"), ramp("767880"), ramp("4a4c54")
    blue = hexc("6a8aff")
    o = open_ * 4.0
    items = [Ell((-7, 0), 8.5, 7.5, B, tex="ridge", z=0),
             Poly([(-2, -7), (10, -6), (14, -2), (14, 2), (10, 6 + o * .3), (-2, 7)], M, z=2, bulge=.7),     # the casing
             Poly([(8, -5), (16, -4 - o * .4), (17, -1), (9, -1)], M2, z=3),
             Poly([(8, 1), (17, 1 + o), (16, 4 + o), (9, 5)], M2, z=3),
             Ell((2, -3), 3.0, 1.5, M2, z=3), Ell((2, 3), 3.0, 1.5, M2, z=3)]
    for (x, y) in ((4, -2), (6, -3.5), (6, -.5), (8, -2)): items.append(Glow((x, y), blue, 0, 5))
    for (a, b) in (((3, -6), (8, -15)), ((0, -7), (-3, -16)), ((6, 5), (13, 12)), ((-2, 7), (-6, 14)), ((10, -5), (18, -12))):
        items.append(Rod(a, b, hexc("3a3c44"), z=-1, cap=blue))
    if open_: items.append(Poly([(10, -1), (17, -1 - o * .2), (17, 1 + o * .6), (10, 1)], [INK] * 5, z=2))
    return items

def worm_seg(r):
    B = ramp("1e2a24"); P = ramp("3a4aa0")
    items = [Ell((0, 0), r * 1.25, r, B, tex="ridge", z=1)]
    if r > 4: items.append(Ell((0, 0), r * .22, r * 1.02, P, rot=.12, z=2))           # a strap of blue pipe around the body
    return items

def build(kind, sheet):
    if kind == "ash_wyrm":
        sheet.row("head", directions(wyrm_head(0), 30, 30) + directions(wyrm_head(1), 30, 30), 30, 30, 15, 15)
        sheet.row("seg", directions(wyrm_seg(0), 26, 26) + directions(wyrm_seg(1), 26, 26), 26, 26, 13, 13)
    elif kind == "tide_leviathan":
        sheet.row("head", directions(lev_head(0), 44, 44) + directions(lev_head(1), 44, 44), 44, 44, 22, 22)
        sheet.row("seg_l", directions(lev_seg(7.0), 26, 26), 26, 26, 13, 13)
        sheet.row("seg_m", directions(lev_seg(5.0), 20, 20), 20, 20, 10, 10)
        sheet.row("seg_s", directions(lev_seg(3.0), 14, 14), 14, 14, 7, 7)
    elif kind == "marrow_worm":
        sheet.row("head", directions(worm_head(0), 44, 44) + directions(worm_head(1), 44, 44), 44, 44, 22, 22)
        sheet.row("seg_l", directions(worm_seg(7.5), 28, 28), 28, 28, 14, 14)
        sheet.row("seg_m", directions(worm_seg(5.5), 22, 22), 22, 22, 11, 11)
        sheet.row("seg_s", directions(worm_seg(3.5), 16, 16), 16, 16, 8, 8)
