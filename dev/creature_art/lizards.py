"""Lizards, after Rain World's: a big armoured wedge of a head in the lizard's colour, heavy jaws full of teeth, brow spines;
a scaly dark body in three sizes of segment; the legs are drawn by the game (they plant and step). Each kind adds its own
feature to the head: a leaf frill (sprout), a crest of petals (bloom), branching horns (bark), glowing feelers (spark),
gill fronds (drip), a bone mask (pale), no eyes and a mouth of whiskers (crypt).
Head: 16 directions x (shut, open). Segments: 16 directions each. `size` scales the whole lizard (and its cells)."""
import math
from engine import Ell, Tube, Poly, Feather, Rod, Glow, Dot, ramp, hexc, mix, INK, directions

PAL = {
    "sprout_lizard": dict(head="8fcf5a", head2="4f7a2e", body="26331c", spine="f08aa8", tooth="f0ead0", eye="1a1a10", size=.72, feat="leaf"),
    "moss_lizard":   dict(head="6f8a3a", head2="3e5426", body="23301f", spine="9aa860", tooth="e8e2c4", eye="1a1a10"),
    "bloom_lizard":  dict(head="e0508a", head2="7a2048", body="2a1820", spine="ffb0d0", tooth="fff0f4", eye="1a0610", feat="petals"),
    "bark_lizard":   dict(head="8a7458", head2="4a3a28", body="2e2418", spine="c8b48a", tooth="efe4c8", eye="140e08", feat="horns", skull_tex="ridge"),
    "spark_lizard":  dict(head="e8c030", head2="8a6418", body="2a2214", spine="fff0a0", tooth="fff8e0", eye="1a1206", feat="feelers"),
    "slag_lizard":   dict(head="e07a30", head2="8a3a18", body="2a1a16", spine="ffb060", tooth="f2e2bc", eye="1a0e0c"),
    "drip_lizard":   dict(head="3ad0c8", head2="1a6a70", body="102226", spine="a0fff0", tooth="eafcfa", eye="06181a", feat="gills"),
    "mire_lizard":   dict(head="3a8ad0", head2="1e4a7a", body="141e2a", spine="8ad0ff", tooth="e8f0f0", eye="0c1420"),
    "pale_lizard":   dict(head="e8e2d0", head2="9a9482", body="6e6a5e", spine="fff8e8", tooth="ffffff", eye="2a0a0a", feat="mask"),
    "crypt_lizard":  dict(head="2a2430", head2="0e0a12", body="17121c", spine="7a68a8", tooth="f0e8ff", eye=None, feat="whiskers"),
    "cinder_lizard": dict(head="d8302a", head2="6a1414", body="1c0c10", spine="ff8a40", tooth="f8e8d0", eye="1a0606"),
}

def head(p, open_):
    H, H2, B = ramp(p["head"]), ramp(p["head2"]), ramp(p["body"])
    tooth = hexc(p["tooth"]); S = ramp(p["spine"]); feat = p.get("feat", "")
    o = open_ * 4.0
    items = [
        Ell((-6, 1), 5.5, 5.0, B, tex="scale", z=0),                                 # neck
        Poly([(-4, 2), (12, 2 + o), (11, 5 + o), (-3, 6)], H2, z=1),                  # lower jaw
        Ell((-1, -1), 7.5, 5.0, H, tex=p.get("skull_tex", "scale"), z=2),            # skull
        Poly([(2, -5), (13, -1), (14, 1), (12, 2.5), (2, 3)], H, z=3, bulge=.8),      # snout
        Ell((3, -4), 4.0, 1.6, H2, rot=-.15, z=4),                                    # brow ridge
    ]
    n_teeth = 7 if feat in ("whiskers", "mask") else 5
    for k in range(n_teeth if open_ else 3):                                         # teeth along the jaws
        x = 3 + k * (10.0 / n_teeth) * 1.1
        items.append(Dot((x, 2.2), tooth, 3))
        if open_: items.append(Dot((x + .8, 2 + o - .6 + k * .1), tooth, 3))
    if feat not in ("petals", "leaf"):
        for k in range(4):                                                           # brow spines raking back
            items.append(Tube([(-1 - k * 2.6, -4.0 + k * .4), (-4.5 - k * 2.6, -8.5 + k * 1.0)], 1.1, .3, S, z=-1))
    for k in range(3):                                                               # dark bands across the skull
        items.append(Ell((-4 + k * 3.2, -2), .8, 3.6, H2, z=3))
    items.append(Dot((12.5, -.5), INK, 5))                                           # nostril
    if p["eye"]:
        items += [Dot((4, -3), hexc(p["eye"]), 5), Dot((5, -3), hexc(p["eye"]), 5)]
    if open_: items.append(Poly([(2, 2.5), (11, 2.5 + o * .6), (2, 4.5)], [INK] * 5, z=1))   # the dark of the mouth
    sp = hexc(p["spine"]); dark = hexc(p["head2"])
    if feat == "leaf":            # a frill of young leaves behind the jaw, pink at the tips
        for k, a in enumerate((-2.4, -1.9, -1.4, 2.0, 2.5)):
            items.append(Feather((-5, 0), (-5 + math.cos(a) * 9, math.sin(a) * 7), 1.6, hexc("4f7a2e"), sp, z=-2, bend=.8))
    elif feat == "petals":        # a crest of petals fanned over the skull
        for k in range(6):
            a = -2.9 + k * .32
            items.append(Feather((-3, -3), (-3 + math.cos(a) * 11, -3 + math.sin(a) * 10), 2.2, dark, sp, z=-2, bend=1.0))
        items.append(Glow((-2, -6), sp, 1, z=6))
    elif feat == "horns":         # horns like bare branches, forking
        BR = ramp("5a4630")
        items += [Tube([(-2, -4), (-7, -10), (-12, -13)], 1.4, .5, BR, z=-1), Tube([(-7, -10), (-6, -15)], .8, .3, BR, z=-1),
                  Tube([(1, -4), (-2, -11), (-1, -15)], 1.2, .4, BR, z=-1), Tube([(-2, -11), (-6, -13)], .7, .3, BR, z=-1)]
        for k in range(4): items.append(Dot((-6 + k * 3, 1 + (k % 2)), hexc("5a4630"), 4))       # lichen specks
    elif feat == "feelers":       # two long feelers that glow at the tips
        items += [Rod((3, -4), (-6, -14), hexc("6a5420"), z=-1), Rod((-6, -14), (-13, -17), hexc("6a5420"), z=-1), Glow((-13, -17), sp, 1, z=6),
                  Rod((1, -4), (-9, -10), hexc("6a5420"), z=-1), Rod((-9, -10), (-16, -11), hexc("6a5420"), z=-1), Glow((-16, -11), sp, 1, z=6)]
        items.append(Glow((4.5, -3), hexc("ffe060"), 1, z=6))
    elif feat == "gills":         # three gill fronds each side of the neck, like a cave salamander's
        for k in range(3):
            items.append(Feather((-6, -1 + k * 1.5), (-15, -7 + k * 5.5), 1.7, dark, sp, z=-2, bend=1.2))
    elif feat == "mask":          # a bone mask: deep sockets with red points, cracks over the snout
        items += [Ell((4.5, -3), 1.8, 1.5, [INK] * 5, z=5), Dot((5, -3), hexc("ff3a2a"), 6),
                  Rod((7, -4), (10, -1), hexc("9a9482"), z=6), Rod((0, -5), (-3, -1), hexc("9a9482"), z=6)]
    elif feat == "whiskers":      # eyeless: a fringe of pale feelers round the mouth that taste the air
        for k in range(3):
            items.append(Rod((11 - k * 3.0, 4 + o), (9 - k * 3.5, 9 + o + k * 1.5), hexc("9a88c0"), z=-1))
        items += [Rod((12, -1), (17, -4), hexc("b8a8d8"), z=-1), Rod((9, -3), (13, -8), hexc("9a88c0"), z=-1)]
        for k in range(4): items.append(Dot((-2 + k * 3, 2.5), hexc("8a6ad0"), 6))          # pits along the jaw that glow faintly
    return items

def seg(p, r, spined):
    B = ramp(p["body"])
    items = [Ell((0, 0), r * 1.25, r, B, tex="scale")]
    if spined:
        if p.get("feat") == "leaf": items.append(Feather((0, -r + 1), (-3, -r - 4), 1.2, hexc("4f7a2e"), hexc(p["spine"]), z=-1))
        elif p.get("feat") == "petals": items.append(Feather((0, -r + 1), (-3.5, -r - 4), 1.4, hexc(p["head2"]), hexc(p["spine"]), z=-1))
        else: items.append(Tube([(.5, -r + 1), (-2.5, -r - 3)], 1.2, .3, ramp(p["spine"]), z=-1))
    if p.get("feat") == "spark" or p.get("feat") == "feelers": items.append(Dot((0, 0), hexc(p["spine"]), 4))  # a faint glow down the back
    if p.get("feat") == "mask": items.append(Ell((0, -r * .3), r * .9, r * .35, ramp(p["head"]), z=1))    # bone plates on the back
    return items

def scaled(items, s):
    """The same model `s` times the size."""
    if s == 1: return items
    out = []
    for it in items:
        if isinstance(it, Ell): out.append(Ell((it.c[0] * s, it.c[1] * s), it.rx * s, it.ry * s, it.mat, it.rot, it.tex, it.z))
        elif isinstance(it, Tube): out.append(Tube([(x * s, y * s) for x, y in it.pts], it.r0 * s, it.r1 * s, it.mat, it.tex, it.z))
        elif isinstance(it, Poly): out.append(Poly([(x * s, y * s) for x, y in it.pts], it.mat, it.z, it.tex, it.bulge))
        elif isinstance(it, Feather): out.append(Feather((it.root[0] * s, it.root[1] * s), (it.tip[0] * s, it.tip[1] * s), max(1.0, it.w * s), it.dark, it.accent, it.z, it.bend * s))
        elif isinstance(it, Rod): out.append(Rod((it.a[0] * s, it.a[1] * s), (it.b[0] * s, it.b[1] * s), it.col, it.z, it.w, it.cap))
        elif isinstance(it, Glow): out.append(Glow((it.p[0] * s, it.p[1] * s), it.col, it.r, it.z))
        elif isinstance(it, Dot): out.append(Dot((it.p[0] * s, it.p[1] * s), it.col, it.z))
    return out

def build(kind, sheet):
    p = PAL[kind]; s = p.get("size", 1.0)
    def cell(n): return int(math.ceil(n * s / 2.0)) * 2
    hc = cell(40) if p.get("feat") else cell(32)
    sheet.row("head", directions(scaled(head(p, 0), s), hc, hc) + directions(scaled(head(p, 1), s), hc, hc), hc, hc, hc // 2, hc // 2)
    for name, r, spined, c in (("seg_l", 5.0, True, 18), ("seg_m", 4.0, True, 16), ("seg_s", 2.4, False, 12)):
        cc = cell(c)
        sheet.row(name, directions(scaled(seg(p, r, spined), s), cc, cc), cc, cc, cc // 2, cc // 2)
