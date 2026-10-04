"""Tops up the ropes and vines to 2-3 per room (relaxed spacing). Edits data/world/*.json. Run after dev/world_thin.py."""
import glob, json, random
TILE = 8
files = sorted(glob.glob("data/world/[0-9]*.json")); counts = []
for f in files:
    d = json.load(open(f)); k = [[int(c) for c in row] for row in d["tiles"]]; tw, th = d["tw"], d["th"]
    want = 2 + (1 if d["sw"] * d["sh"] >= 2 else 0); ct = 0 if d.get("first") else 5
    kind = "vine" if d["theme"] == "overgrowth" else "rope"; rng = random.Random(d["index"] * 31 + 7)
    ropes = [list(r) for r in d.get("ropes", [])][:want]
    def col(x): return int((x - 4) // TILE)
    cands = []
    for x in range(7, tw - 7):
        for y in range(max(ct, 1), th - 9):
            if k[y][x] != 0 and k[y + 1][x] == 0:
                L = 0
                while y + 1 + L < th - 8 and all(k[y + 1 + L][xx] == 0 for xx in (x - 1, x, x + 1)) and L < 18: L += 1
                if L >= 5 and abs(x - d["entry_tile"]) > 5 and abs(x - d["exit_tile"]) > 5: cands.append((x, y + 1, L))
    rng.shuffle(cands); cands.sort(key=lambda c: -min(c[2], 14) + rng.random() * 2)
    if len(ropes) < want:     # tight rooms: allow shorter ropes and ropes beside a ledge edge (hero is 10 px wide, a tile is 8)
        for x in range(7, tw - 7):
            for y in range(max(ct, 1), th - 9):
                if k[y][x] != 0 and k[y + 1][x] == 0:
                    L = 0
                    while y + 1 + L < th - 8 and k[y + 1 + L][x] == 0 and L < 18: L += 1
                    if L >= 4 and abs(x - d["entry_tile"]) > 4 and abs(x - d["exit_tile"]) > 4 and (x, y + 1, L) not in cands: cands.append((x, y + 1, L))
        rng.shuffle(cands); cands.sort(key=lambda c: -min(c[2], 14) + rng.random() * 2)
    for spacing in (14, 10, 7, 5):
        for (x, y, L) in cands:
            if len(ropes) >= want: break
            if all(abs(x - col(r[0])) > spacing for r in ropes): ropes.append([x * TILE + 4, y * TILE, L * TILE, kind])
    d["ropes"] = ropes; counts.append(len(ropes))
    json.dump(d, open(f, "w"))
print("ropes per room:", sorted(set(counts)), "rooms with fewer than wanted:", sum(1 for c, f in zip(counts, files) if c < 2))
