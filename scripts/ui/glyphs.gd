class_name Glyphs
extends RefCounted
## Shared pixel drawing for UI: health crystals, food pips, ornaments, ability badges, item icons.
## Every function draws onto a CanvasItem (call from its _draw) in whole pixels.

enum Crystal { FULL, EMPTY, SHATTER, REGROW }

const CRYSTAL_PITCH := 11
const CRYSTAL_SHAPE: Array[String] = [
	"....#....",
	"...###...",
	"..#####..",
	".#######.",
	"#########",
	"#########",
	"#########",
	".#######.",
	"..#####..",
	"...###...",
	"....#....",
]
const FOOD_SHAPE: Array[String] = [
	"..###..",
	".#####.",
	"#######",
	"#######",
	"#######",
	".#####.",
	"..###..",
]
const FOOD_PITCH := 9

const SHATTER_DIRS: Array[Vector2] = [
	Vector2(-1.0, -0.6), Vector2(1.0, -0.6),
	Vector2(-1.0, 0.0), Vector2(1.0, 0.0),
	Vector2(-0.7, 0.6), Vector2(0.7, 0.6),
]


# --- Crystals -----------------------------------------------------------------------------


static func _filled(shape: Array[String], r: int, c: int) -> bool:
	return r >= 0 and r < shape.size() and c >= 0 and c < shape[r].length() and shape[r][c] == "#"


static func _crystal_colour(c: int, r: int, glow: float) -> Color:
	var value := clampf(0.74 + 0.26 * glow, 0.0, 1.0)
	var hue := 0.50
	var sat := 0.45
	if c == 4:
		hue = 0.55
	elif c > 4:
		hue = 0.64
		sat = 0.5
		value *= 0.82
	var colour := Color.from_hsv(hue, sat, value)
	if (c == 3 and (r == 3 or r == 4)) or (c == 2 and r == 4):
		colour = colour.lerp(Color.WHITE, 0.7)
	return colour


## mode: Crystal.FULL / EMPTY / SHATTER (t 0..1, pieces fly apart) / REGROW (t 0..1, rebuilds with a flash).
## glow 0..1 dims or brightens a full crystal (used for the low-health pulse).
static func draw_crystal(ci: CanvasItem, origin: Vector2, mode: int, t: float = 0.0, glow: float = 1.0) -> void:
	var rows := CRYSTAL_SHAPE.size()
	for pass_index in 2:
		for r in rows:
			for c in CRYSTAL_SHAPE[r].length():
				if not _filled(CRYSTAL_SHAPE, r, c):
					continue
				var offset := Vector2.ZERO
				var alpha := 1.0
				var colour := _crystal_colour(c, r, glow)
				match mode:
					Crystal.EMPTY:
						var edge := not (_filled(CRYSTAL_SHAPE, r, c - 1) and _filled(CRYSTAL_SHAPE, r, c + 1) and _filled(CRYSTAL_SHAPE, r - 1, c) and _filled(CRYSTAL_SHAPE, r + 1, c))
						colour = UITheme.RUST_DARK if edge else Color("1c1218")
					Crystal.SHATTER:
						var chunk := (0 if c < 4 else 1) + 2 * (0 if r < 4 else (1 if r < 7 else 2))
						var dir := SHATTER_DIRS[chunk]
						offset = Vector2(roundf(dir.x * t * 9.0), roundf(dir.y * t * 6.0 + t * t * 18.0))
						alpha = 1.0 - t
					Crystal.REGROW:
						if r < rows - ceili(t * rows):
							continue
						colour = colour.lerp(Color.WHITE, (1.0 - t) * 0.8)
				var p := origin + offset + Vector2(c, r)
				if pass_index == 0:
					draw_outline_pixel(ci, p, alpha)
				else:
					ci.draw_rect(Rect2(p, Vector2.ONE), Color(colour, alpha))


static func draw_outline_pixel(ci: CanvasItem, p: Vector2, alpha: float = 1.0) -> void:
	ci.draw_rect(Rect2(p - Vector2.ONE, Vector2(3, 3)), Color(UITheme.INK, alpha))


# --- Food ---------------------------------------------------------------------------------


## Rain World-style round pip. `alarm` 0..1 pulses an empty ring toward rust (starving).
static func draw_food_pip(ci: CanvasItem, origin: Vector2, filled: bool, alarm: float = 0.0) -> void:
	for pass_index in 2:
		for r in FOOD_SHAPE.size():
			for c in FOOD_SHAPE[r].length():
				if not _filled(FOOD_SHAPE, r, c):
					continue
				var p := origin + Vector2(c, r)
				if pass_index == 0:
					draw_outline_pixel(ci, p)
					continue
				var edge := not (_filled(FOOD_SHAPE, r, c - 1) and _filled(FOOD_SHAPE, r, c + 1) and _filled(FOOD_SHAPE, r - 1, c) and _filled(FOOD_SHAPE, r + 1, c))
				var colour := UITheme.CREAM
				if not filled:
					colour = UITheme.RUST_DARK.lerp(UITheme.RUST, alarm) if edge else Color("1c1218")
				ci.draw_rect(Rect2(p, Vector2.ONE), colour)


# --- Ornaments ----------------------------------------------------------------------------


static func draw_diamond(ci: CanvasItem, centre: Vector2, radius: int, colour: Color) -> void:
	for dy in range(-radius, radius + 1):
		var half := radius - absi(dy)
		ci.draw_rect(Rect2(centre.x - half, centre.y + dy, half * 2 + 1, 1), colour)


static func draw_divider(ci: CanvasItem, cx: float, y: float, half: int, ornate: bool = true) -> void:
	for side in [-1, 1]:
		var x0: float = cx + 6 if side == 1 else cx - half
		ci.draw_rect(Rect2(x0, y + 3, half - 6, 1), UITheme.RUST)
		ci.draw_rect(Rect2(x0, y + 4, half - 6, 1), UITheme.INK)
		var tick_x: float = cx + half - 1 if side == 1 else cx - half
		ci.draw_rect(Rect2(tick_x, y + 1, 1, 5), UITheme.RUST)
	draw_diamond(ci, Vector2(cx, y + 3), 2, UITheme.CREAM_DIM)
	if ornate:
		for side in [-1, 1]:
			for step in [16, 28]:
				draw_diamond(ci, Vector2(cx + side * step, y + 3), 1, UITheme.CREAM_DIM)


## Curling corner flourish. fx / fy are -1 or 1 and mirror it into each corner of the screen.
static func draw_corner(ci: CanvasItem, origin: Vector2, fx: int, fy: int) -> void:
	var line := UITheme.CREAM_DIM
	for i in 30:
		_px(ci, origin, fx, fy, i, 0, line)
		_px(ci, origin, fx, fy, 0, i, line)
		_px(ci, origin, fx, fy, i, 1, UITheme.INK)
		_px(ci, origin, fx, fy, 1, i, UITheme.INK)
	for step in [34]:
		for dy in range(-2, 3):
			var half := 2 - absi(dy)
			for dx in range(-half, half + 1):
				_px(ci, origin, fx, fy, step + dx, dy, UITheme.CREAM)
				_px(ci, origin, fx, fy, dy, step + dx, UITheme.CREAM)
	# a small inner curl: a hollow square one step in from the corner
	for i in 5:
		_px(ci, origin, fx, fy, 4 + i, 4, UITheme.RUST)
		_px(ci, origin, fx, fy, 4, 4 + i, UITheme.RUST)


static func _px(ci: CanvasItem, origin: Vector2, fx: int, fy: int, x: int, y: int, colour: Color) -> void:
	ci.draw_rect(Rect2(origin + Vector2(x * fx, y * fy), Vector2.ONE), colour)


static func draw_ring(ci: CanvasItem, centre: Vector2, radius: float, colour: Color) -> void:
	var steps := int(radius * 8.0)
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		ci.draw_rect(Rect2(centre + Vector2(roundf(cos(angle) * radius), roundf(sin(angle) * radius)), Vector2.ONE), colour)


# --- Abilities ----------------------------------------------------------------------------


## Round badge with a pictogram. lit = unlocked. id: pound, double_jump, dash_iframes, fast_heal.
static func draw_ability(ci: CanvasItem, id: String, centre: Vector2, lit: bool, selected: bool = false) -> void:
	var tone := UITheme.CREAM if lit else UITheme.RUST_DARK
	for dy in range(-11, 12):
		var half := int(sqrt(maxf(0.0, 121.0 - dy * dy)))
		ci.draw_rect(Rect2(centre.x - half, centre.y + dy, half * 2 + 1, 1), Color("17101a"))
	draw_ring(ci, centre, 11.0, tone if lit else UITheme.RUST_DARK)
	if selected:
		draw_ring(ci, centre, 13.0, UITheme.CREAM_DIM)
	var c := centre
	match id:
		"pound":
			ci.draw_rect(Rect2(c.x - 1, c.y - 6, 2, 8), tone)
			for i in 4:
				ci.draw_rect(Rect2(c.x - 3 + i, c.y + 1 + i, 7 - i * 2, 1), tone)
			ci.draw_rect(Rect2(c.x - 6, c.y + 7, 13, 1), tone)
		"double_jump":
			for k in 2:
				var y := c.y - 5 + k * 6
				for i in 5:
					ci.draw_rect(Rect2(c.x - 4 + i, y + 4 - i, 1, 1), tone)
					ci.draw_rect(Rect2(c.x + 4 - i, y + 4 - i, 1, 1), tone)
					ci.draw_rect(Rect2(c.x - 4 + i, y + 5 - i, 1, 1), tone)
					ci.draw_rect(Rect2(c.x + 4 - i, y + 5 - i, 1, 1), tone)
		"dash_iframes":
			for i in 3:
				ci.draw_rect(Rect2(c.x - 7 + i * 2, c.y - 4 + i * 4, 8 - i * 2, 1), tone)
			for i in 4:
				ci.draw_rect(Rect2(c.x + 1 + i, c.y - 3 + i, 1, 7 - i * 2), tone)
			draw_diamond(ci, Vector2(c.x + 6, c.y - 5), 1, tone)
		"fast_heal":
			for r in 7:
				var half := mini(r, 3) if r < 5 else 6 - r
				ci.draw_rect(Rect2(c.x - half, c.y - 5 + r + 1, half * 2 + 1, 1), tone)
			ci.draw_rect(Rect2(c.x, c.y - 6, 1, 2), tone)
			ci.draw_rect(Rect2(c.x - 1, c.y - 1, 3, 1), Color("17101a"))
			ci.draw_rect(Rect2(c.x, c.y - 2, 1, 3), Color("17101a"))
