"""Adds climbing notches inside every hole between rooms and shafts so the way back up always works:
ceiling holes (5 rows) get stubs at row 4 (left) and row 1 (right); floor holes (8 rows) get stubs at the bottom row (left),
3 rows up (right) and 6 rows up (left). Stubs are 2 tiles of the 6-tile hole, alternating sides, so falling still goes straight
through the middle. Edits data/world/*.json once. Run: python3 dev/world_notches.py"""
import glob, json
for f in sorted(glob.glob("data/world/[0-9]*.json")):
    d = json.load(open(f)); k = [list(row) for row in d["tiles"]]; th = d["th"]
    def stub(row, x0):
        for x in (x0, x0 + 1):
            if k[row][x] == "0": k[row][x] = "1"
    xi, xo = d["entry_tile"], d["exit_tile"]
    if not d.get("first"):
        stub(4, xi - 3); stub(1, xi + 1)
    stub(th - 1, xo - 3); stub(th - 4, xo + 1); stub(th - 7, xo - 3)
    d["tiles"] = ["".join(row) for row in k]
    json.dump(d, open(f, "w"))
print("notches added")
