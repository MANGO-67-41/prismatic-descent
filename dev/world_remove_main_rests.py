"""One-time pass: takes the resting lanterns out of every MAIN room (20 of them: the ones the world generator and dev/make_rests.py put
there), so the only lanterns left are the five in the old halls (ruin hall wings), the fifteen in the lantern shrines and the one at the
Prismatic Lake's temple. dev/make_rests.py must not be run again. Backup of the rooms before: data/world_before_unrest/.
Run: python3 dev/world_remove_main_rests.py   then python3 dev/make_creatures.py && python3 dev/world_bake.py && python3 dev/world_verify.py"""
import glob, json, os, shutil
if not os.path.isdir("data/world_before_unrest"): shutil.copytree("data/world", "data/world_before_unrest")
n = 0
for f in sorted(glob.glob("data/world/[0-9]*.json")):
    d = json.load(open(f))
    if d.get("final"): continue
    keep = [m for m in d["marks"] if m[0] != "rest"]
    if len(keep) != len(d["marks"]):
        n += len(d["marks"]) - len(keep); d["marks"] = keep; json.dump(d, open(f, "w"))
print("removed", n, "resting lanterns from the main rooms")
