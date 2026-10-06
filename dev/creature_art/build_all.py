"""Builds every creature's sprite sheet: assets/creatures/<kind>.png and a <kind>.json atlas (rows of frames, each row's
cell size and origin), which scripts/game/creatures/creature_art.gd reads. Also writes a big preview of each into
dev/creature_art/preview/. Run: python3 dev/creature_art/build_all.py [kind ...]"""
import os, sys, json
sys.path.insert(0, os.path.dirname(__file__))
from multiprocessing import Pool
import engine, lizards, chains, poses

KINDS = {k: lizards for k in lizards.PAL}
for k in ("ash_wyrm", "tide_leviathan", "marrow_worm"): KINDS[k] = chains
for k in poses.SPECS: KINDS[k] = poses

def build(kind):
    sheet = engine.Sheet()
    KINDS[kind].build(kind, sheet)
    W, H = sheet.save("assets/creatures/%s.png" % kind, "assets/creatures/%s.json" % kind)
    # preview: the first few frames of every row, 5x
    frames = []
    for name, fr, w, h, ox, oy in sheet.rows:
        step = max(1, len(fr) // 4)
        frames += fr[::step][:4]
    big_w = max(len(f[0]) for f in frames)
    os.makedirs("dev/creature_art/preview", exist_ok=True)
    rows = [frames[i:i + 8] for i in range(0, len(frames), 8)]
    for k, r in enumerate(rows):
        engine.preview(r, "dev/creature_art/preview/%s_%d.png" % (kind, k), 4)
    return kind, W, H

if __name__ == "__main__":
    kinds = sys.argv[1:] or list(KINDS)
    with Pool(8) as pool:
        for k, W, H in pool.imap_unordered(build, kinds): print(k, W, "x", H)
