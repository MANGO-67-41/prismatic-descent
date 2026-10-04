"""Player movement simulator used to PROVE that generated rooms can be traversed with the abilities the hero has.
Pixels, 60 ticks/s, tile = 8 px. Numbers match the feel targets in .claude/skills/platformer-feel (tune together).
`skill` (s) scales the hero's jump, run and dash: a room that still works at s=0.7 has a 30% margin for error."""
import math

TILE, DT = 8, 1 / 60
WJ_KEEP_GAP = 0.46   # same-wall climbing is slower in the game than bouncing between two walls (measured: ~190 px in 2.5 s)
BOX_W, BOX_H = 10, 14

class Stats:
    def __init__(self, s=1.0, double_jump=False):
        self.s = s
        self.run = 110 * s
        self.jump_v = 288 * s            # hold: 46 px (5.75 tiles) at s=1
        self.g_up, self.g_down, self.fall_max = 900, 1500, 400
        self.dash_v, self.dash_t = 280 * s, 0.16
        self.wall_slide = 60
        self.wj_vx, self.wj_vy, self.wj_lock = 120 * s, 270 * s, 0.18
        self.double_jump = double_jump
        self.dj_v = 230 * s

class Grid:
    """Tile collision. Out of the room counts as solid except through `openings` (tile rects x0, y0, x1, y1)."""
    def __init__(self, kind, tw, th, openings=()):
        self.tw, self.th, self.open = tw, th, list(openings)
        self.sol = [[1 if kind[y][x] else 0 for x in range(tw)] for y in range(th)]
        self.ropes = []   # (x, top_y, bottom_y) in pixels: the hero can grab these and let go anywhere along them
    def solid(self, tx, ty):
        if 0 <= tx < self.tw and 0 <= ty < self.th: return self.sol[ty][tx]
        for (x0, y0, x1, y1) in self.open:
            if x0 <= tx < x1 and y0 <= ty < y1: return 0
        return 1
    def hit(self, x, y):
        x0 = int((x - BOX_W / 2) // TILE); x1 = int((x + BOX_W / 2 - 0.01) // TILE)
        y0 = int((y - BOX_H) // TILE); y1 = int((y - 0.01) // TILE)
        for ty in range(y0, y1 + 1):
            for tx in range(x0, x1 + 1):
                if self.solid(tx, ty): return True
        return False

def simulate(grid, st, x, y, plan, goals=(), limit=200):
    """One trajectory from a standing (or falling) start. plan: dir, jump, wj, dash_at, dj_at, dash_dir.
    Returns (landing or None, points visited, set of goal indexes reached)."""
    d = plan["dir"]; dash_left = 0.0; dash_used = False; lock = 0.0; dj_used = False
    vx = 0.0; vy = 0.0; t = 0.0; pts = []; reached = set()
    ground = grid.hit(x, y + 1)
    if plan.get("launch"):                         # let go of a rope with a jump
        vy = -st.jump_v * 0.85; ground = False; vx = 0.0
    elif plan["jump"]:
        if not ground: return None, pts, reached
        vy = -st.jump_v; ground = False
    dir_at = plan.get("dir_at"); last_wj = -1.0
    for f in range(limit):
        t += DT
        if dir_at is not None and t >= dir_at and lock <= 0: d = plan["dir2"]
        if lock > 0: lock -= DT
        if dash_left > 0:
            vx = st.dash_v * plan["dash_dir"]; vy = 0.0; dash_left -= DT
        else:
            if lock <= 0: vx = d * st.run
            if plan["dash_at"] is not None and not dash_used and t >= plan["dash_at"] and not ground:
                dash_used = True; dash_left = st.dash_t; continue
            if plan["dj_at"] is not None and st.double_jump and not dj_used and t >= plan["dj_at"] and not ground:
                dj_used = True; vy = -st.dj_v
            vy = min(st.fall_max, vy + (st.g_up if vy < 0 else st.g_down) * DT)
        nx = x + vx * DT; wall = 0
        if grid.hit(nx, y):
            wall = 1 if vx > 0 else -1; nx = x
            if dash_left > 0: dash_left = 0
        x = nx
        ny = y + vy * DT
        if grid.hit(x, ny):
            if vy > 0:
                ty = int(ny // TILE) * TILE
                n = 0
                while grid.hit(x, ty) and n < 24: ty -= 1; n += 1
                if n >= 24: return None, pts, reached
                y = ty; pts.append((x, y))
                for i, (gx0, gy0, gx1, gy1) in enumerate(goals):
                    if gx0 <= x <= gx1 and gy0 <= y <= gy1: reached.add(i)
                return (x, y), pts, reached
            vy = 0.0
        else:
            y = ny
        if wall and vy > 0:
            vy = min(vy, st.wall_slide)
            if plan["wj"] and lock <= 0 and t > 0.1 and (not plan.get("wj_keep") or t - last_wj >= WJ_KEEP_GAP):
                last_wj = t
                vx = -wall * st.wj_vx; vy = -st.wj_vy; lock = st.wj_lock
                d = wall if plan.get("wj_keep") else -wall      # keep pressing into the wall = climb it (as in the game)
                dash_used = False; dj_used = False
        pts.append((x, y))
        for i, (gx0, gy0, gx1, gy1) in enumerate(goals):
            if gx0 <= x <= gx1 and gy0 <= y <= gy1: reached.add(i)
        if y > grid.th * TILE + 60: break
    return None, pts, reached

def plans(st):
    out = []
    for d in (-1, 0, 1):
        for wj in (False, True):
            base = dict(dir=d, jump=True, wj=wj, dash_at=None, dj_at=None, dash_dir=d if d else 1)
            out.append(base)
            if d != 0 and wj:                             # climb one wall by wall-jumping off it repeatedly
                p = dict(base); p["wj_keep"] = True; out.append(p)
            if d == 0 and not wj:                        # rise straight up, then steer onto a higher ledge
                for d2 in (-1, 1):
                    for ta in (0.18, 0.28, 0.38):
                        p = dict(base); p["dir_at"] = ta; p["dir2"] = d2; p["dash_dir"] = d2; out.append(p)
            if d:
                for da in (0.0, 0.25, 0.45):
                    p = dict(base); p["dash_at"] = da; out.append(p)
            if st.double_jump:
                for ja in (0.2, 0.4):
                    p = dict(base); p["dj_at"] = ja; out.append(p)
                    if d:
                        q = dict(p); q["dash_at"] = 0.5; out.append(q)
    return out

def fall_plans(st):
    out = []
    for d in (-1, 0, 1):
        for wj in (False, True):
            base = dict(dir=d, jump=False, wj=wj, dash_at=None, dj_at=None, dash_dir=d if d else 1)
            out.append(base)
            if d:
                for da in (0.0, 0.3):
                    p = dict(base); p["dash_at"] = da; out.append(p)
            if st.double_jump:
                p = dict(base); p["dj_at"] = 0.25; out.append(p)
    return out

def standable(grid, x, y): return grid.hit(x, y + 1) and not grid.hit(x, y)

def walk(grid, x, y, step=2):
    """All standing points reachable by walking from (x, y) along the same ground, plus the two ledge ends."""
    pts = [(x, y)]; ends = []
    for d in (-1, 1):
        cx = x
        while True:
            nx = cx + d * step
            if grid.hit(nx, y): ends.append((cx, y, d)); break          # wall: still a ledge end for jumping
            if not grid.hit(nx, y + 1):                                     # ledge: walking off falls
                ends.append((cx, y, d)); break
            cx = nx; pts.append((cx, y))
    return pts, ends

def reach(grid, st, starts, goals=(), max_states=6000, want=None):
    """Explore standing states from starts [(x, y, airborne)]. Returns (states, points, goals_reached).
    Each walkable ledge is expanded once: jumps from every 16 px and from its ends, plus walking off its ends."""
    J, F = plans(st), fall_plans(st)
    seen = {}; walked = set(); queue = []; pts_all = []; got = set()
    key = lambda x, y: (int(round(x / 4)), int(round(y)))
    def add(x, y):
        k = key(x, y)
        if k not in seen: seen[k] = (x, y); queue.append((x, y))
    for (x, y, air) in starts:
        if air:
            for p in F:
                land, pts, rc = simulate(grid, st, x, y, p, goals)
                pts_all.extend(pts[::3]); got |= rc
                if land: add(*land)
        else: add(x, y)
    active = set()
    def ropes_touched(pts):
        for (px_, py_) in pts[::2]:
            for ri, (rx, rt, rb) in enumerate(grid.ropes):
                if ri not in active and abs(px_ - rx) <= 6 and rt - 4 <= py_ <= rb + 4: active.add(ri); launch_from_rope(ri)
    def launch_from_rope(ri):
        rx, rt, rb = grid.ropes[ri]
        y = rt + 10
        while y <= rb:
            for d in (-1, 0, 1):
                p = dict(dir=d, jump=False, launch=True, wj=False, dash_at=None, dj_at=None, dash_dir=d if d else 1)
                land, pts, rc = simulate(grid, st, rx, y, p, goals)
                pts_all.extend(pts[::3]); got.update(rc)
                if land and standable(grid, *land): add(*land)
            y += 8
        for d in (-1, 0, 1):                       # slide off the bottom end
            p = dict(dir=d, jump=False, wj=False, dash_at=None, dj_at=None, dash_dir=d if d else 1)
            land, pts, rc = simulate(grid, st, rx, rb, p, goals)
            pts_all.extend(pts[::3]); got.update(rc)
            if land and standable(grid, *land): add(*land)
    qi = 0
    while qi < len(queue) and len(seen) < max_states:
        if want is not None and want <= got: break
        x, y = queue[qi]; qi += 1
        if key(x, y) in walked or not standable(grid, x, y): continue
        run, ends = walk(grid, x, y)
        for (rx, ry) in run:
            walked.add(key(rx, ry)); seen.setdefault(key(rx, ry), (rx, ry))
        origins = [(rx, ry) for i, (rx, ry) in enumerate(run) if i % 8 == 0] + [(ex, ey) for (ex, ey, _) in ends]
        for (ox, oy) in origins:
            for p in J:
                land, pts, rc = simulate(grid, st, ox, oy, p, goals)
                pts_all.extend(pts[::3]); got |= rc
                if grid.ropes: ropes_touched(pts)
                if land and standable(grid, *land) and key(*land) not in walked: add(*land)
        for (ex, ey, d) in ends:
            for p in F:
                if p["dir"] != d and p["dir"] != 0: continue
                land, pts, rc = simulate(grid, st, ex + d * 2, ey, p, goals)
                pts_all.extend(pts[::3]); got |= rc
                if grid.ropes: ropes_touched(pts)
                if land and standable(grid, *land) and key(*land) not in walked: add(*land)
    return list(seen.values()), pts_all, got

if __name__ == "__main__":
    tw, th = 60, 40
    flat = [[0] * tw for _ in range(th)]
    for tx in range(tw): flat[30][tx] = 1
    g = Grid(flat, tw, th)
    for dj in (False, True):
        st = Stats(1.0, dj); best_h = 0; far = 0
        for p in plans(st):
            land, pts, _ = simulate(g, st, 100, 30 * TILE, p)
            if pts: best_h = max(best_h, 30 * TILE - min(y for _, y in pts))
            if land: far = max(far, abs(land[0] - 100))
        print("double_jump", dj, "max height tiles", round(best_h / TILE, 1), "max level jump tiles", round(far / TILE, 1))
