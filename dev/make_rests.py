"""NO LONGER USED: every lantern in the main rooms was removed again (dev/world_remove_main_rests.py); only the old halls, the lantern shrines
and the lake have lanterns now. Do not run this.
Adds resting lanterns to the main rooms: every region already had one (the sixth room) and one in its ruin hall; this adds
more, in the third, eighth and last room of each region (the last is the one before the gate), so a lantern is never more than
two or three rooms away. Each goes on a flat stretch of floor away from the holes, ropes, cracks, scrolls and the entrance.
Safe to run again (rooms that already have one are left alone). Run: python3 dev/make_rests.py
then python3 dev/make_creatures.py && python3 dev/world_bake.py"""
import glob, json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from world_bake import load_room
from world_thin import meta_for
T = 8
WHICH = (3, 8, 10)          # position within the region (1 to 10)

def spot(d, r):
    m = meta_for(d, r); tw, th = d["tw"], d["th"]
    avoid = [int(m_[1]) // T for m_ in d["marks"]] + [int(p["x"]) // T for p in d.get("props", [])] + [m["x_out"], m["x_in"]]
    for span, gap in ((8, 9), (6, 7), (5, 5), (4, 4)):        # small rooms get a smaller stretch and tighter spacing
        best = None
        for x in range(7, tw - 7 - span):
            tops = m["top"][x:x + span]
            if len(set(tops)) != 1 or tops[0] < th - 14: continue
            cx = x + span // 2
            if any(abs(cx - a) < gap for a in avoid): continue
            if any(abs(int(rp[0]) // T - cx) < 3 for rp in d.get("ropes", [])): continue
            if any(x - 2 <= int(c[0]) // T <= x + span + 2 for c in d.get("cracks", [])): continue
            score = abs(cx - tw // 2)
            if best is None or score < best[0]: best = (score, cx, tops[0])
        if best: return best
    return None

def main():
    added = []
    for i in range(1, 51):
        if (i - 1) % 10 + 1 not in WHICH: continue
        f = glob.glob("data/world/%02d_*.json" % i)[0]
        d = json.load(open(f)); r, _ = load_room(f)
        if any(m[0] == "rest" for m in d["marks"]): continue
        s = spot(d, r)
        if s is None: print("no flat spot in room", i, d["name"]); continue
        _, cx, top = s
        d["marks"].append(["rest", cx * T + 4, top * T])
        json.dump(d, open(f, "w")); added.append((i, d["name"], cx))
    print("added", len(added), "resting lanterns:", added)

if __name__ == "__main__":
    main()
