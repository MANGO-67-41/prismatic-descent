class_name AbilityFx
extends RefCounted
## Pixel effects for the region abilities, drawn in code (no textures):
## - Shockwave: ground pound landing. Two crescents race out along the floor, a flash line, dust kicked both ways.
## - Wings: double jump. Pale feathered wings sprout from the hero's back and beat once downward, shedding feathers.
## - Streamer: invincible dash. A prismatic ribbon trails the hero and fades, with a few sparks.

const PALE := Color("f2eefc")
const PALE_SHADE := Color("b9b2d6")
const DUST := Color("b9a888")


static func shockwave(parent: Node, at: Vector2) -> void:
	var fx := Shockwave.new()
	fx.position = at.round()
	parent.add_child(fx)


## Wings are a child of the hero so they follow the jump.
static func wings(hero: Node2D, facing: int) -> void:
	var fx := Wings.new()
	fx.facing = facing
	hero.add_child(fx)


static func streamer(parent: Node) -> Streamer:
	var fx := Streamer.new()
	parent.add_child(fx)
	return fx


class Shockwave extends Node2D:
	const LIFE := 0.45
	var _t := 0.0
	var _dust: Array[Dictionary] = []

	func _ready() -> void:
		z_index = 11
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 14:
			var side := -1.0 if i % 2 == 0 else 1.0
			_dust.append({"p": Vector2(side * rng.randf_range(2, 6), -1), "v": Vector2(side * rng.randf_range(50, 150), rng.randf_range(-70, -15)),
					"s": rng.randf_range(1.0, 2.6)})

	func _process(delta: float) -> void:
		_t += delta
		for d in _dust:
			d["v"] = (d["v"] as Vector2) + Vector2(0, 260) * delta
			d["v"].x *= 0.93
			d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
			if (d["p"] as Vector2).y > 0.0:
				d["p"].y = 0.0
				d["v"].y = 0.0
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / LIFE
		var fade := 1.0 - k
		var ease := 1.0 - pow(1.0 - k, 3.0)
		# flash along the floor
		var flash := roundf(10.0 + 50.0 * ease)
		draw_rect(Rect2(-flash, -1, flash * 2.0, 1), Color(PALE, 0.55 * fade * fade))
		# two crescents racing outward, shrinking as they go
		for side: float in [-1.0, 1.0]:
			var x: float = side * (5.0 + 58.0 * ease)
			var h := roundf(lerpf(11.0, 3.0, k))
			for y in int(h):
				var bend := roundf(sin(float(y) / maxf(h, 1.0) * PI) * 2.0)
				draw_rect(Rect2(x - side * bend, -1 - y, 2, 1), Color(PALE, fade))
				draw_rect(Rect2(x - side * (bend + 2), -1 - y, 1, 1), Color(PALE_SHADE, fade * 0.7))
				draw_rect(Rect2(x - side * (bend + 9), -1 - y * 0.5, 1, 1), Color(PALE, fade * 0.35))
		# impact spark lines straight up, only at the start
		if k < 0.35:
			var a := 1.0 - k / 0.35
			for xo: int in [-4, -1, 2, 5]:
				draw_rect(Rect2(xo, -4 - roundf(10 * k), 1, 3), Color(PALE, a))
		for d in _dust:
			var s := roundf((d["s"] as float) * (1.0 - k * 0.6))
			draw_rect(Rect2((d["p"] as Vector2).round(), Vector2(s, s)), Color(DUST, fade))


class Wings extends Node2D:
	const LIFE := 0.36
	var facing := 1
	var _t := 0.0
	var _feathers: Array[Dictionary] = []

	func _ready() -> void:
		z_index = -1      # behind the hero's drawing
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 4:
			_feathers.append({"p": Vector2(rng.randf_range(-12, 12), rng.randf_range(-14, -6)), "ph": rng.randf() * TAU})

	func _process(delta: float) -> void:
		_t += delta
		for f in _feathers:
			f["p"] = (f["p"] as Vector2) + Vector2(sin(_t * 9.0 + (f["ph"] as float)) * 14.0, 26.0) * delta
		if _t >= LIFE + 0.25:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / LIFE, 0.0, 1.0)
		var fade := 1.0 if k < 0.65 else 1.0 - (k - 0.65) / 0.35
		if _t < LIFE:
			# one downward beat: raised and spread, then swept down
			var sweep := lerpf(-0.95, 0.6, 1.0 - pow(1.0 - k, 2.0))
			var shoulder := Vector2(-3.0 * facing, -11.0)
			_wing(shoulder, -1.0, sweep, fade, PALE_SHADE)       # far wing, a touch darker and shorter
			_wing(shoulder, 1.0, sweep, fade, PALE)
		var ff := clampf(1.0 - (_t - 0.1) / 0.5, 0.0, 1.0)
		for f in _feathers:
			draw_rect(Rect2((f["p"] as Vector2).round(), Vector2(2, 1)), Color(PALE, ff))

	## A solid wing: leading edge curving up and out, a scalloped trailing edge of feathers, outlined.
	## side: -1 = the far wing (behind the body, smaller, shaded), +1 = the near wing. sweep: rotation in radians.
	func _wing(shoulder: Vector2, side: float, sweep: float, alpha: float, colour: Color) -> void:
		var outline := PackedVector2Array([Vector2(0, 0), Vector2(3, -5), Vector2(8, -9), Vector2(14, -11), Vector2(19, -10),
			Vector2(21, -7), Vector2(18, -6), Vector2(19, -3), Vector2(15, -3), Vector2(15, 0), Vector2(11, -1), Vector2(10, 2),
			Vector2(6, 1), Vector2(4, 3)])
		var veins := [Vector2(18, -6), Vector2(15, -3), Vector2(11, -1), Vector2(6, 1)]
		var scale := 1.0 if side > 0.0 else 0.82
		var outward: float = -float(facing) if side < 0.0 else float(facing)
		var rot := Transform2D(sweep * outward, Vector2.ZERO)
		var pts := PackedVector2Array()
		for p in outline:
			pts.append((shoulder + rot * Vector2(p.x * outward, p.y) * scale).round())
		draw_colored_polygon(pts, Color(colour, alpha))
		for v: Vector2 in veins:
			draw_line(shoulder.round(), (shoulder + rot * Vector2(v.x * outward, v.y) * scale).round(), Color(PALE_SHADE.darkened(0.15), alpha * 0.8), 1.0)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(UITheme.INK, alpha * 0.85), 1.0)


class Streamer extends Node2D:
	const AGE := 0.32
	var _points: Array[Vector3] = []   # x, y, birth time
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		z_index = 9

	func add_point(p: Vector2) -> void:
		_points.append(Vector3(p.x, p.y, _t))

	## Stop growing; the ribbon fades out and frees itself.
	func finish() -> void:
		_done = true

	func _process(delta: float) -> void:
		_t += delta
		while not _points.is_empty() and _t - _points[0].z > AGE:
			_points.pop_front()
		if _done and _points.is_empty():
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var n := _points.size()
		for i in range(1, n):
			var a := _points[i - 1]
			var b := _points[i]
			var life := 1.0 - (_t - b.z) / AGE
			var hue := fmod(0.48 + 0.32 * float(i) / maxf(n, 1.0) + _t * 0.4, 1.0)
			var col := Color.from_hsv(hue, 0.5, 1.0, life)
			var pa := Vector2(a.x, a.y - 7.0).round()
			var pb := Vector2(b.x, b.y - 7.0).round()
			draw_line(pa, pb, Color(col, life * 0.35), roundf(3.0 + 5.0 * life))
			draw_line(pa + Vector2(0, -1), pb + Vector2(0, -1), Color.from_hsv(fmod(hue + 0.12, 1.0), 0.55, 1.0, life), roundf(1.0 + 2.0 * life))
			draw_line(pa + Vector2(0, 1), pb + Vector2(0, 1), Color.from_hsv(fmod(hue - 0.12, 1.0), 0.55, 1.0, life), roundf(1.0 + 2.0 * life))
			draw_line(pa, pb, Color(1, 1, 1, life * 0.9), 1.0)
			if i % 3 == 0 and life > 0.3:
				draw_rect(Rect2(Vector2(b.x + sin(b.z * 90.0) * 5.0, b.y - 7.0 + cos(b.z * 70.0) * 5.0).round(), Vector2(1, 1)), Color.from_hsv(hue, 0.3, 1.0, life))
