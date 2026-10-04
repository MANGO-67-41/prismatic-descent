"""Renders the generated world: every room and shaft as PNG, one stitched sheet per region, a difficulty chart and the report.
Run after dev/world_gen.py:  python3 dev/world_render.py"""
import os, pickle, struct, sys, zlib
sys.path.insert(0, os.path.dirname(__file__))
import overgrowth_art as oa
from overgrowth_art import Canvas, TILE, hexc, hsv, lerp, label, write_png
import world_gen as wg

BG = hexc("0c0910")

def rows_of(cv):
    return [b"".join(bytes(c) for c in row) for row in cv.p]

def write_rows_png(path, width, height, row_iter):
    raw = bytearray()
    for row in row_iter: raw += b"\x00" + row
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))

def main():
    rooms, cors = pickle.load(open("dev/world/_world.pkl", "rb"))
    by_idx = {x["idx"]: x for x in rooms}; cor_idx = {x["idx"]: x for x in cors}
    report = []; os.makedirs("dev/world", exist_ok=True)
    for ri, (rname, theme, specs) in enumerate(wg.REGIONS):
        oa.set_theme(theme)
        folder = "dev/world/%d_%s" % (ri + 1, theme); os.makedirs(folder, exist_ok=True)
        gi0 = sum(len(r[2]) for r in wg.REGIONS[:ri]); parts = []   # (rows, width, height, hole_x_in, hole_x_out)
        for li, spec in enumerate(specs):
            gi = gi0 + li
            res = by_idx.get(gi)
            if res is None or "room" not in res: continue
            r = res["room"]
            cv = oa.render(r); lay = oa.render(r, overlay=True)
            label(cv, 6, 6, "%02d %s" % (gi + 1, r.name), oa.CREAM)
            write_png("%s/room_%02d_%s.png" % (folder, gi + 1, r.name.lower().replace(" ", "_")), cv, 2)
            write_png("%s/room_%02d_%s_layout.png" % (folder, gi + 1, r.name.lower().replace(" ", "_")), lay, 2)
            m = r.meta
            parts.append(("room", rows_of(cv), r.W, r.H, m["x_in"] * TILE, m["x_out"] * TILE))
            report.append(dict(gi=gi, region=rname, name=r.name, sw=r.sw, sh=r.sh, margin=res["margin"], threat=r.threat,
                               enemies=len(r.enemies), food=len(r.food_pos or []) , pound=len(r.pound_food) // 2,
                               rest=any(k == "rest" for k, _, _ in r.marks), d=0.04 + 0.9 * gi / (wg.N_ROOMS - 1)))
            c = cor_idx.get(gi)
            if c and "room" in c and not (ri == len(wg.REGIONS) - 1 and li == len(specs) - 1):
                ccv = oa.render(c["room"]); write_png("%s/shaft_%02d.png" % (folder, gi + 1), ccv, 3)
                parts.append(("shaft", rows_of(ccv), c["room"].W, c["room"].H, 56, 56))
                report[-1]["shaft_margin"] = c["margin"]
        # stitch: align each hole with the next piece's hole
        xs = []; cx = 0
        for i, p in enumerate(parts):
            if i == 0: x0 = 0
            else: x0 = prev_out - p[4]
            xs.append(x0); prev_out = x0 + p[5]
        minx = min(xs); W = max(x + p[2] for x, p in zip(xs, parts)) - minx + 16
        H = sum(p[3] for p in parts)
        def stream():
            bgrow = bytes(BG) * W
            for (kind, rows, w, h, xi, xo), x0 in zip(parts, xs):
                left = (x0 - minx + 8) * 3; right = (W - (x0 - minx + 8) - w) * 3
                for row in rows: yield bytes(BG) * (left // 3) + row + bytes(BG) * (right // 3)
        write_rows_png("dev/world/region_%d_%s_sheet.png" % (ri + 1, theme), W, H, stream())
        print("region", ri + 1, rname, "sheet", W, "x", H, flush=True)
    pickle.dump(report, open("dev/world/_report.pkl", "wb"))
    chart(report)
    markdown(report)

def chart(report):
    n = len(report); cw = 10; W = n * cw + 60; H = 158
    cv = Canvas(W, H, hexc("120d14"))
    label(cv, 6, 5, "THE DESCENT - DIFFICULTY ACROSS ALL %d ROOMS" % n, oa.CREAM)
    rows = [("MARGIN FOR ERROR (LESS IS HARDER)", lambda r: r["margin"], hexc("8f9d5e"), 1.0),
            ("THREAT (ENEMIES)", lambda r: r["threat"] / 8, hexc("e0483a"), 1.0),
            ("FOOD (BULBS)", lambda r: r["food"] / 6, hsv(.52, .45, 1.0), 1.0)]
    y0 = 22
    for title, fn, col, mx in rows:
        label(cv, 6, y0, title, oa.DIM)
        for i, r in enumerate(report):
            h = int(fn(r) / mx * 28)
            cv.rect(8 + i * cw, y0 + 38 - h, cw - 2, h, col)
        cv.rect(8, y0 + 38, n * cw, 1, oa.DIM)
        y0 += 44
    for ri in range(1, len(wg.REGIONS)):
        x = 8 + ri * 10 * cw - 1
        for y in range(18, H - 6, 3): cv.px(x, y, oa.DIM)
    for ri, (rname, *_r) in enumerate(wg.REGIONS):
        label(cv, 10 + ri * 10 * cw, 14, rname.replace("THE ", ""), oa.CREAM)
    write_png("dev/world/difficulty_chart.png", cv, 3)

def markdown(report):
    L = ["# The Descent: all rooms, verified", "",
         "Every room was checked with a movement simulator (dev/world_physics.py): a hero with the abilities of that region can walk from the entrance to the exit AND climb back up. Region 1 hero: run, jump, wall cling and wall jump, dash. Region 2 adds ground pound (cracked floors, optional stashes). Region 3 adds double jump. Region 4 adds invincible dash. Region 5 adds fast heal.",
         "", "**Margin** = how much weaker the hero can be (shorter jumps, slower run and dash) before the room becomes impossible. 50% means very forgiving, 0% means it needs full-strength, well-timed play.", ""]
    cur = None
    for r in report:
        if r["region"] != cur:
            cur = r["region"]; L += ["", "## " + cur, "", "| # | Room | Screens | Margin | Enemies | Food | Rest | Pound stash | Shaft margin |", "|---|---|---|---|---|---|---|---|---|"]
        L.append("| %d | %s | %dx%d | %d%% | %d | %d | %s | %s | %s |" % (r["gi"] + 1, r["name"].title(), r["sw"], r["sh"], r["margin"] * 100, r["enemies"], r["food"],
                 "yes" if r["rest"] else "", "yes" if r["pound"] else "", ("%d%%" % (r["shaft_margin"] * 100)) if "shaft_margin" in r else "-"))
    open("dev/world/REPORT.md", "w").write("\n".join(L) + "\n")

if __name__ == "__main__":
    main()
