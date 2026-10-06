class_name RoomNav
extends RefCounted
## A walking map of one room, built from its baked solid rectangles: every tile where a creature could stand (solid under it, head
## room above), and which of those it can get between by walking, by climbing a wall up to CLIMB_MAX, or by stepping off a ledge
## up to DROP_MAX. Hunting walkers ask it for the next point on the way to the hero, so they go round pits, up ledges and over
## walls instead of pushing at the nearest one. Fliers do not use it.

const TILE := 8
const MAX_UP := 7      ## tiles a walker can climb (CLIMB_MAX / 8, rounded down)
const MAX_DOWN := 12   ## tiles a hunter will drop to get at the hero (falling does them no harm)

static var _cache: Dictionary = {}

var tw := 0
var th := 0
var ox := 0.0
var oy := 0.0
var _solid := PackedByteArray()
var last_dir := 0      ## which way the first step of the last route went (-1, 1), or 0


static func for_piece(id: int) -> RoomNav:
	if not _cache.has(id):
		_cache[id] = RoomNav.new(id)
	return _cache[id]


func _init(id: int) -> void:
	var p: Dictionary = WorldData.pieces[id]
	tw = int(p["w"]) / TILE
	th = int(p["h"]) / TILE
	ox = float(p["x"])
	oy = float(p["y"])
	_solid.resize(tw * th)
	for r in p["rects"]:
		for yy in range(int(r[1]), int(r[1]) + int(r[3])):
			for xx in range(int(r[0]), int(r[0]) + int(r[2])):
				_solid[yy * tw + xx] = 1
	for c in p.get("cracks", []):          # cracked floor holds a creature up (only a ground pound breaks it)
		_solid[int(c[1]) * tw + int(c[0])] = 1
	for b in p.get("beams", []):           # beams are thin but they are floor to a walker
		for xx in range(int(b[0]), int(b[0]) + int(b[2])):
			_solid[int(b[1]) * tw + xx] = 1


func solid(x: int, y: int) -> bool:
	if x < 0 or x >= tw or y < 0:
		return true
	if y >= th:
		return false       # below the room is a hole out of it (the exit): never somewhere to stand
	return _solid[y * tw + x] == 1


func can_stand(x: int, y: int, c: int) -> bool:
	if not solid(x, y + 1):
		return false
	for i in c:
		if solid(x, y - i):
			return false
	return true


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - ox) / TILE), floori((p.y - oy - 1.0) / TILE))


func point_of(cell: Vector2i) -> Vector2:
	return Vector2(ox + (cell.x + 0.5) * TILE, oy + (cell.y + 1) * TILE)


## The standing cell at or just under `cell` (up to `depth` tiles down), or (-1, -1).
func ground_under(cell: Vector2i, c: int, depth: int) -> Vector2i:
	for d in range(0, depth + 1):
		if can_stand(cell.x, cell.y + d, c):
			return Vector2i(cell.x, cell.y + d)
	return Vector2i(-1, -1)


func _neighbours(cell: Vector2i, c: int, up: int = MAX_UP) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in [-1, 1]:
		var nx: int = cell.x + dx
		for ny in range(cell.y - up, cell.y + MAX_DOWN + 1):
			if not can_stand(nx, ny, c):
				continue
			if ny < cell.y:                                       # climbing: a wall to grip beside it, and the column it is in clear up to the top
				var grip := true
				for yy in range(ny + 1, cell.y + 1):
					if not solid(nx, yy):
						grip = false
						break
				if not grip:
					continue
				var clear := true
				for yy in range(ny - c + 1, cell.y + 1):
					if solid(cell.x, yy):
						clear = false
						break
				if not clear:
					continue
			elif ny > cell.y:                                     # dropping: the column it falls through must be clear
				var clear2 := true
				for yy in range(cell.y - c + 1, ny + 1):
					if solid(nx, yy):
						clear2 = false
						break
				if not clear2:
					continue
			out.append(Vector2i(nx, ny))
	return out


## The next point (world pixels) on the way from `from` to `to`, `lead` steps ahead on the route. When the hero cannot be
## reached on foot, the route ends at the reachable spot nearest to them. Returns Vector2.INF when `from` is not on the floor.
## `up`: how many tiles of wall it can climb (the climbing lizards go up any wall).
func waypoint(from: Vector2, to: Vector2, c: int, lead: int = 3, up: int = MAX_UP) -> Vector2:
	last_dir = 0
	var start := ground_under(cell_of(from), c, 6)
	if start.x < 0:
		return Vector2.INF
	var goal_cell := cell_of(to)
	var goal := ground_under(goal_cell, c, 14)
	if goal.x < 0:
		goal = goal_cell
	var parent := {start: start}
	var queue: Array[Vector2i] = [start]
	var best := start
	var best_score := _score(start, goal)
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == goal:
			best = cur
			break
		for n in _neighbours(cur, c, up):
			if parent.has(n):
				continue
			parent[n] = cur
			queue.append(n)
			var s := _score(n, goal)
			if s < best_score:
				best_score = s
				best = n
		if queue.size() > 6000:
			break
	if best == start:
		return Vector2(to.x, from.y)
	var path: Array[Vector2i] = [best]
	while path[-1] != start:
		path.append(parent[path[-1]])
	path.reverse()                       # start ... best
	if path.size() > 1:
		last_dir = signi(path[1].x - path[0].x)
	return point_of(path[mini(lead, path.size() - 1)])


func _score(a: Vector2i, b: Vector2i) -> float:
	return absf(a.x - b.x) + absf(a.y - b.y) * 1.5


## Whether a walker could get from `from` to within a couple of tiles of `to` on foot.
func reachable(from: Vector2, to: Vector2, c: int, up: int = MAX_UP) -> bool:
	var wp := waypoint(from, to, c, 9999, up)
	if wp == Vector2.INF:
		return false
	var goal := ground_under(cell_of(to), c, 14)
	return goal.x >= 0 and absf(wp.x - point_of(goal).x) < 20.0 and absf(wp.y - point_of(goal).y) < 20.0
