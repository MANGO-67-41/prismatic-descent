"""Authors THE PRISMATIC LAKE: one massive, calm room (3x2 screens) at the bottom of the world, reached by a shaft from the
LAKE GATE. A stair cut into the cliff and a rope lead down from the entrance; a torii gate, a long wooden bridge over the
rainbow lake, and a three-tier pagoda on a stepped plinth with a rest point at its door. Nothing hostile, nothing hard.
Writes data/world/51_prismatic_lake.json and data/world/shaft_50.json. Run: python3 dev/make_lake.py"""
import json

T = 8; TW, TH = 180, 68; FT = TH - 8; XIN = 14
k = [[0] * TW for _ in range(TH)]
def fill(x0, y0, x1, y1, v):
    for y in range(max(0, y0), min(TH, y1)):
        for x in range(max(0, x0), min(TW, x1)): k[y][x] = v
fill(0, 0, 5, TH, 1); fill(TW - 5, 0, TW, TH, 1)          # walls
fill(5, 0, TW - 5, 5, 1); fill(XIN - 3, 0, XIN + 3, 5, 0)  # ceiling with the entrance
fill(5, FT, TW - 5, TH, 1)                                 # floor
fill(60, FT, 132, TH - 1, 0)                               # the lake basin (water is drawn in the art)
fill(60, FT, 132, FT + 1, 2)                               # bridge walkway, level with the floor
for i in range(12):                                        # stair cut into the cliff: 4 rows down, 3 tiles out each step
    top = 12 + 4 * i; fill(5, top, 16 + 3 * i, FT, 1)
fill(133, FT - 2, 137, FT, 1); fill(137, FT - 4, 141, FT, 1); fill(141, FT - 6, TW - 5, FT, 1)   # temple plinth steps

temple_x, plinth = 158 * T, (FT - 6) * T
room = dict(kind="room", index=51, name="PRISMATIC LAKE", theme="lake", tile=T, tw=TW, th=TH, sw=3, sh=2, depth=0.5, seed=51,
            tiles=["".join(str(v) for v in row) for row in k], poles=[],
            marks=[["entry", XIN * T, 7 * T], ["rest", temple_x, plinth]], enemies=[], food=[], pound_food=[], cracks=[],
            margin=0.5, threat=0, foodcount=0, entry_tile=XIN, exit_tile=55, first=False, final=True,
            ropes=[[XIN * T, 0, 12 * T, "rope"], [96 * T + 4, 5 * T, (FT - 5) * T, "rope"]],
            lake=dict(water=[60 * T, 132 * T, (FT + 1) * T, (TH - 1) * T], bridge=[60 * T, 132 * T, FT * T], torii=[54 * T, FT * T],
                      temple=[temple_x, plinth], lanterns=[temple_x - 104, temple_x + 104],
                      crystals=[[7 * T, 12 * T, 12], [44 * T, FT * T, 14], [57 * T, FT * T, 10], [135 * T, (FT - 2) * T, 12], [172 * T, plinth, 16]]))
json.dump(room, open("data/world/51_prismatic_lake.json", "w"))
shaft = json.load(open("data/world/shaft_49.json"))
shaft.update(index=50, name="SHAFT 50", seed=251, theme="ash")
json.dump(shaft, open("data/world/shaft_50.json", "w"))
print("lake room and shaft written")
