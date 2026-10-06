class_name Glyphs
extends RefCounted
## Shared pixel drawing for UI: health pips (round, Rain World style), the energy circle, ornaments, ability badges.
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


## A health pip in the old crystal's 9x11 cell (kept for the inventory and profile rows).
static func draw_crystal(ci: CanvasItem, origin: Vector2, mode: int, t: float = 0.0, glow: float = 1.0) -> void:
	draw_life_pip(ci, origin + Vector2(4.5, 5.5), mode, t, glow, 4.5)


## Round health pip: a pale ring around a soft inner disc (full), a dim hollow ring (empty).
## SHATTER (t 0..1): the ring bursts outward and fades, chips fly. REGROW (t 0..1): the disc swells back with a flash.
static func draw_life_pip(ci: CanvasItem, centre: Vector2, mode: int, t: float = 0.0, glow: float = 1.0, r: float = 5.5) -> void:
	var ring := UITheme.CREAM.lerp(Color.WHITE, 0.15 * glow)
	var disc := Color("d8d2c8").lerp(Color("f6f2ea"), 0.4 * glow)
	var span := int(ceil(r + 4.0))
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var px := Vector2(floorf(centre.x) + dx, floorf(centre.y) + dy)
			var d := (px + Vector2(0.5, 0.5)).distance_to(centre)
			var col := Color(0, 0, 0, 0)
			match mode:
				Crystal.FULL, Crystal.REGROW:
					var inner := r - 2.6
					if mode == Crystal.REGROW:
						inner *= t
					if d <= r + 1.0 and d > r:
						col = UITheme.INK
					elif d <= r and d > r - 1.5:
						col = ring if mode == Crystal.FULL else Color(ring, 0.35 + 0.65 * t)
					elif d <= r - 1.5 and d > r - 2.6:
						col = Color("1c1218")
					elif d <= inner:
						col = disc
						if px.x + 0.5 < centre.x - 0.6 and px.y + 0.5 < centre.y - 0.6:
							col = disc.lerp(Color.WHITE, 0.55)
						if mode == Crystal.REGROW:
							col = col.lerp(Color.WHITE, (1.0 - t) * 0.85)
					elif d <= r - 2.6:
						col = Color("1c1218")
				Crystal.EMPTY:
					if d <= r + 1.0 and d > r:
						col = UITheme.INK
					elif d <= r and d > r - 1.2:
						col = Color("6a5a5e")
					elif d <= r - 1.2:
						col = Color("1c1218")
				Crystal.SHATTER:
					var rr := r + t * 3.0
					if d <= r + 1.0 and d > r - 1.2 and t > 0.6:
						col = Color("6a5a5e")
					if d <= rr and d > rr - 1.4:
						col = Color(ring, 1.0 - t)
					elif d <= (r - 2.6) * (1.0 - t):
						col = Color(Color.WHITE, 1.0 - t)
			if col.a > 0.0:
				ci.draw_rect(Rect2(px, Vector2.ONE), col)
	if mode == Crystal.SHATTER:
		for k in 4:
			var ang := k * TAU / 4.0 + 0.8
			var p := (centre + Vector2(cos(ang), sin(ang)) * (r + t * 9.0) + Vector2(0, t * t * 10.0)).floor()
			ci.draw_rect(Rect2(p, Vector2(2, 1)), Color(ring, 1.0 - t))


## The energy circle: a ring whose inside fills from the bottom with prismatic light as `fill` goes 0..1.
## When full it breathes and its crystal glyph lights. `heal` 0..1 draws a bright arc around it while a heal is channelled.
static func draw_energy(ci: CanvasItem, centre: Vector2, r: float, fill: float, time: float, heal: float = 0.0) -> void:
	var full := fill >= 1.0
	var level := centre.y + (r - 2.0) - (r - 2.0) * 2.0 * fill
	var span := int(ceil(r + 3.0))
	var pulse := 0.5 + 0.5 * sin(time * 3.0) if full and not SettingsStore.reduce_flashing else 1.0
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var px := Vector2(floorf(centre.x) + dx, floorf(centre.y) + dy)
			var pc := px + Vector2(0.5, 0.5)
			var d := pc.distance_to(centre)
			var col := Color(0, 0, 0, 0)
			if d <= r + 1.0 and d > r:
				col = UITheme.INK
			elif d <= r and d > r - 2.0:
				col = UITheme.CREAM.lerp(Color.WHITE, 0.3 * pulse) if full else UITheme.CREAM_DIM
			elif d <= r - 2.0:
				col = Color("1c1218")
				if pc.y >= level:
					var hue := fmod(0.5 + (pc.x - centre.x) / (r * 6.0) + time * 0.05, 1.0)
					col = Color.from_hsv(hue, 0.35, 0.95)
					if pc.y < level + 1.0:
						col = Color.WHITE
			if col.a > 0.0:
				ci.draw_rect(Rect2(px, Vector2.ONE), col)
	# the glyph: a small crystal in the middle, dark until the circle is full
	var g := Color.WHITE if full else Color(UITheme.INK, 0.55)
	draw_diamond(ci, centre.floor(), 3, g)
	ci.draw_rect(Rect2(centre.floor() + Vector2(0, -5), Vector2(1, 2)), g)
	ci.draw_rect(Rect2(centre.floor() + Vector2(0, 4), Vector2(1, 2)), g)
	if heal > 0.0:
		var steps := int(48 * heal)
		for k in steps:
			var ang := -PI / 2.0 + k * TAU / 48.0
			ci.draw_rect(Rect2((centre + Vector2(cos(ang), sin(ang)) * (r + 2.5)).floor(), Vector2.ONE), Color.from_hsv(fmod(0.5 + k / 48.0 * 0.3, 1.0), 0.4, 1.0))


static func draw_outline_pixel(ci: CanvasItem, p: Vector2, alpha: float = 1.0) -> void:
	ci.draw_rect(Rect2(p - Vector2.ONE, Vector2(3, 3)), Color(UITheme.INK, alpha))


# --- Ornaments ----------------------------------------------------------------------------


## A pixel key standing upright: a round bow with a hole, a shaft and two teeth. `centre` is the middle of the whole key.
static func draw_key(ci: CanvasItem, centre: Vector2, colour: Color, scale: int = 1, glow: float = 0.0) -> void:
	var o := centre.floor() - Vector2(3, 7) * scale
	var dark := colour.darkened(0.55)
	var light := colour.lightened(0.45)
	if glow > 0.0:
		draw_diamond(ci, o + Vector2(3, 4) * scale, 9 * scale, Color(colour, 0.14 * glow))
		draw_diamond(ci, o + Vector2(3, 4) * scale, 6 * scale, Color(colour, 0.2 * glow))
	for y in range(-1, 15):
		var inked := Rect2(o + Vector2(-1, y) * scale, Vector2(8, 1) * scale)
		if y < 8:
			ci.draw_rect(inked, UITheme.INK)
	ci.draw_rect(Rect2(o + Vector2(1, 0) * scale, Vector2(4, 1) * scale), colour)
	ci.draw_rect(Rect2(o + Vector2(0, 1) * scale, Vector2(6, 5) * scale), colour)
	ci.draw_rect(Rect2(o + Vector2(1, 6) * scale, Vector2(4, 1) * scale), dark)
	ci.draw_rect(Rect2(o + Vector2(2, 2) * scale, Vector2(2, 3) * scale), UITheme.INK)
	ci.draw_rect(Rect2(o + Vector2(1, 1) * scale, Vector2(2, 1) * scale), light)
	ci.draw_rect(Rect2(o + Vector2(2, 7) * scale, Vector2(2, 7) * scale), colour)
	ci.draw_rect(Rect2(o + Vector2(3, 7) * scale, Vector2(1, 7) * scale), dark)
	ci.draw_rect(Rect2(o + Vector2(4, 9) * scale, Vector2(2, 1) * scale), colour)
	ci.draw_rect(Rect2(o + Vector2(4, 12) * scale, Vector2(3, 1) * scale), colour)


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


# --- Pause menu ornaments -----------------------------------------------------------------


## Ten discrete pips (volume), cream when filled, dark when empty.
static func draw_pips(ci: CanvasItem, origin: Vector2, value: int, active: bool) -> void:
	for i in 10:
		var colour := UITheme.RUST_DARK
		if i < value:
			colour = UITheme.CREAM if active else UITheme.CREAM_DIM
		ci.draw_rect(Rect2(origin.x + i * 7 - 1, origin.y - 1, 6, 9), UITheme.INK)
		ci.draw_rect(Rect2(origin.x + i * 7, origin.y, 4, 7), colour)


## Ornate line with curled ends, a centre diamond and small diamonds either side, like the
## flourishes on Hollow Knight's pause menu. `emblem` adds a crystal rising above the centre.
static func draw_flourish(ci: CanvasItem, cx: float, y: float, half: int, emblem: bool = false) -> void:
	var line := UITheme.CREAM
	for side in [-1, 1]:
		var x0: float = cx + 7 if side == 1 else cx - half
		ci.draw_rect(Rect2(x0, y, half - 7, 1), line)
		ci.draw_rect(Rect2(x0, y + 1, half - 7, 1), UITheme.INK)
		# curled end: rises, then hooks back toward the centre
		var bx: float = cx + side * half - (1 if side == 1 else 0)
		for k in 5:
			ci.draw_rect(Rect2(bx, y - k, 1, 1), line)
		for hook in [Vector2(1, -5), Vector2(2, -5), Vector2(3, -4), Vector2(3, -3)]:
			ci.draw_rect(Rect2(bx - side * hook.x, y + hook.y, 1, 1), line)
		for step in [14, 24]:
			draw_diamond(ci, Vector2(cx + side * step, y), 1, line)
	draw_diamond(ci, Vector2(cx, y), 3, line)
	draw_diamond(ci, Vector2(cx, y), 1, UITheme.INK)
	if emblem:
		draw_crystal(ci, Vector2(cx - 4, y - 20), Crystal.FULL, 0.0, 1.0)
		ci.draw_rect(Rect2(cx, y - 9, 1, 6), line)
		for side in [-1, 1]:
			for k in 7:
				ci.draw_rect(Rect2(cx + side * (5 + k) - (1 if side == 1 else 0), y - 2 - k / 2, 1, 1), line)


const DROP_SHAPE: Array[String] = ["00100", "01110", "01110", "11111", "11111", "11111", "01110"]


## The menu selector: the same raindrop used on the title screen. `origin` is its top-left pixel.
static func draw_drop(ci: CanvasItem, origin: Vector2, tint: Color) -> void:
	for pass_index in 2:
		for r in DROP_SHAPE.size():
			for c in DROP_SHAPE[r].length():
				if DROP_SHAPE[r][c] != "1":
					continue
				if pass_index == 0:
					ci.draw_rect(Rect2(origin + Vector2(c - 1, r - 1), Vector2(3, 3)), UITheme.INK)
				else:
					ci.draw_rect(Rect2(origin + Vector2(c, r), Vector2.ONE), tint)


## The hover line: 1px rust with an ink shadow, drawn `width` pixels wide from `origin`.
static func draw_underline(ci: CanvasItem, origin: Vector2, width: float) -> void:
	var w := int(width)
	ci.draw_rect(Rect2(origin, Vector2(w, 1)), UITheme.RUST)
	ci.draw_rect(Rect2(origin + Vector2(0, 1), Vector2(w, 1)), UITheme.INK)
