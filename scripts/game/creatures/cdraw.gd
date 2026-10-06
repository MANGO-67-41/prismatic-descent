class_name CDraw
extends RefCounted
## Pixel drawing for the creatures: filled discs row by row, chains of discs with an ink outline, one-pixel lines,
## feathers, eyes. Everything is snapped to whole pixels so the procedural bodies stay crisp.


static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r < 0.5:
		ci.draw_rect(Rect2(c.floor(), Vector2.ONE), col)
		return
	var cc := c.floor()
	var ri := int(ceil(r))
	for dy in range(-ri, ri + 1):
		var s := r * r - dy * dy
		if s < 0.0:
			continue
		var half := int(floor(sqrt(s) + 0.3))
		ci.draw_rect(Rect2(cc.x - half, cc.y + dy, half * 2 + 1, 1), col)


## A body of discs: ink outline under everything, then the fill, then a small highlight on the upper side.
static func chain(ci: CanvasItem, pts: PackedVector2Array, radii: Array, col: Color, hi: Color) -> void:
	for i in pts.size():
		disc(ci, pts[i], float(radii[i]) + 1.0, UITheme.INK)
	for i in pts.size():   # a rim of light along the top edge, so dark bodies read on dark ground
		disc(ci, pts[i] + Vector2(0, -1), float(radii[i]), hi)
	for i in pts.size():
		disc(ci, pts[i] + Vector2(0, 0.5), float(radii[i]) - 0.3, col)
	for i in pts.size():
		var r := float(radii[i])
		if r >= 3.0:
			disc(ci, pts[i] + Vector2(-0.3, -0.45) * r, r * 0.22, hi.lightened(0.15))


static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float = 1.0) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	if n <= 0:
		ci.draw_rect(Rect2(a.floor(), Vector2(w, w)), col)
		return
	for k in n + 1:
		ci.draw_rect(Rect2(a.lerp(b, float(k) / n).floor(), Vector2(w, w)), col)


## A line with an ink edge under it, for limbs.
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float = 2.0) -> void:
	line(ci, a - Vector2(0.5, 0.5), b - Vector2(0.5, 0.5), UITheme.INK, w + 1.0)
	line(ci, a, b, col, w)


## A feather: dark at the root, the accent colour toward the tip.
static func feather(ci: CanvasItem, root: Vector2, tip: Vector2, dark: Color, accent: Color) -> void:
	var n := int(maxf(absf(tip.x - root.x), absf(tip.y - root.y)))
	for k in n + 1:
		var t := float(k) / maxf(1.0, n)
		ci.draw_rect(Rect2(root.lerp(tip, t).floor(), Vector2.ONE), dark if t < 0.45 else dark.lerp(accent, (t - 0.45) / 0.55))


static func eye(ci: CanvasItem, p: Vector2, col: Color, big: bool = false) -> void:
	var s := 3.0 if big else 2.0
	ci.draw_rect(Rect2(p.floor() - Vector2.ONE, Vector2(s + 1, s + 1)), UITheme.INK)
	ci.draw_rect(Rect2(p.floor(), Vector2(s - 1, s - 1)), col)
	ci.draw_rect(Rect2(p.floor(), Vector2.ONE), Color.WHITE)


static func glow(ci: CanvasItem, p: Vector2, r: float, col: Color, a: float) -> void:
	disc(ci, p, r, Color(col, a * 0.35))
	disc(ci, p, r * 0.55, Color(col, a * 0.5))
