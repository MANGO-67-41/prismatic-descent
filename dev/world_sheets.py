"""Rebuilds the region sheets from the saved room and shaft PNGs (no re-rendering). python3 dev/world_sheets.py"""
import glob, json, os, struct, sys, zlib
sys.path.insert(0, os.path.dirname(__file__))
from world_render import write_rows_png
import world_gen as wg

def read_png(path, down):
    d = open(path, "rb").read(); w, h = struct.unpack(">II", d[16:24]); i = 8; idat = b""
    while i < len(d):
        n = struct.unpack(">I", d[i:i + 4])[0]
        if d[i + 4:i + 8] == b"IDAT": idat += d[i + 8:i + 8 + n]
        i += 12 + n
    raw = zlib.decompress(idat); stride = 1 + w * 3; rows = []
    for y in range(0, h, down):
        row = raw[y * stride + 1:(y + 1) * stride]
        if down == 1: rows.append(bytes(row))
        else: rows.append(b"".join(row[x * 3:x * 3 + 3] for x in range(0, w, down)))
    return rows, w // down, len(rows)

def main():
    BG = bytes((12, 9, 16))
    for ri, (rname, theme, specs) in enumerate(wg.REGIONS):
        folder = "dev/world/%d_%s" % (ri + 1, theme); gi0 = sum(len(r[2]) for r in wg.REGIONS[:ri]); parts = []
        for li in range(len(specs)):
            gi = gi0 + li
            for f in glob.glob("data/world/%02d_*.json" % (gi + 1)):
                data = json.load(open(f)); T = data["tile"]
                name = os.path.basename(f)[:-5]
                png = [p for p in glob.glob("%s/room_%s.png" % (folder, name))][0]
                rows, w, h = read_png(png, 2)
                parts.append((rows, w, h, data["entry_tile"] * T if data["entry_tile"] is not None else 0, data["exit_tile"] * T))
            sh = "data/world/shaft_%02d.json" % (gi + 1)
            if os.path.exists(sh):
                rows, w, h = read_png("%s/shaft_%02d.png" % (folder, gi + 1), 3)
                parts.append((rows, w, h, 56, 56))
        xs = []; prev_out = 0
        for i, p in enumerate(parts):
            x0 = 0 if i == 0 else prev_out - p[3]
            xs.append(x0); prev_out = x0 + p[4]
        minx = min(xs); W = max(x + p[1] for x, p in zip(xs, parts)) - minx + 16; H = sum(p[2] for p in parts)
        def stream():
            for (rows, w, h, xi, xo), x0 in zip(parts, xs):
                left = x0 - minx + 8; right = W - left - w
                for row in rows: yield BG * left + row + BG * right
        write_rows_png("dev/world/region_%d_%s_sheet.png" % (ri + 1, theme), W, H, stream())
        print("sheet", ri + 1, W, H, flush=True)

if __name__ == "__main__":
    main()
