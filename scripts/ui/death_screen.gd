class_name DeathScreen
extends Control
## When the hero's last crystal breaks. The screen sinks into ink and the last crystal hangs in the middle of it, the HUD's crystal
## grown large (blue on its lit side, violet on its dark side, a white glint). Cracks run through it from the top right, it shivers,
## and it bursts: a ring, a flash (none with Reduce Flashing), shards that tumble away under their own weight and a few glints of
## prism dust that drift down. Where it hung come the words NOT HERE (the hero wants an end, but not this one) and under them THE
## LAKE IS STILL BELOW; then, at the foot of the screen, where the hero will wake. The ink closes, `on_dark` puts the hero back at
## the last lantern, and the ink lifts. Once the words are up, jump, the stick or interact hurries it on.

signal finished

const T_RISE := 0.25      ## the crystal has risen into place
const T_CRACK := 0.45     ## the cracks begin
const T_BURST := 1.0      ## it bursts
const T_HEAD := 1.2       ## NOT HERE
const T_SUB := 1.65       ## THE LAKE IS STILL BELOW
const T_HINT := 2.1       ## where the hero wakes
const T_CLOSE := 3.1      ## the ink starts to close
const T_DARK := 3.5       ## fully dark: the hero is moved to the lantern
const T_LIFT := 3.9       ## the ink starts to lift
const T_END := 4.6
const VEIL := 0.82
const C := Vector2(240, 108)     ## where the crystal hangs, and the words come up
const BLUE := Color(0.62, 0.88, 0.9)
const BLUE_LIT := Color(0.82, 0.97, 0.98)
const VIOLET := Color(0.56, 0.5, 0.86)
const VIOLET_DARK := Color(0.4, 0.34, 0.68)
## the crystal's outline (pixels from its middle): a long gem, its girdle a little above the middle
const RIM := [Vector2(0, -40), Vector2(26, -14), Vector2(18, 26), Vector2(0, 40), Vector2(-18, 26), Vector2(-26, -14)]
## the cracks: paths from the point where it gives (top right), each with the moment (0..1 of the cracking) it starts
const CRACKS := [
	[0.0, [Vector2(9, -20), Vector2(3, -8), Vector2(6, 4), Vector2(-2, 16), Vector2(2, 30)]],
	[0.15, [Vector2(9, -20), Vector2(16, -12), Vector2(20, 2)]],
	[0.35, [Vector2(3, -8), Vector2(-9, -4), Vector2(-16, 4)]],
	[0.55, [Vector2(6, 4), Vector2(12, 14)]],
	[0.65, [Vector2(-2, 16), Vector2(-9, 21)]],
]

var _t := -1.0
var _on_dark: Callable
var _on_burst: Callable
var _darked := false
var _burst_done := false
var _shards: Array[Dictionary] = []
var _dust: Array[Dictionary] = []
var _head: Label
var _sub: Label
var _hint: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_head = _label("NOT HERE", UITheme.label_settings(40, UITheme.CREAM, false, 3, 2), Rect2(0, C.y - 22, 480, 44))
	_sub = _label("THE LAKE IS STILL BELOW", UITheme.label_settings(12, UITheme.CREAM_DIM, false, 4, 1), Rect2(0, C.y + 26, 480, 16))
	_hint = _label("YOU WAKE BY THE LAST LANTERN", UITheme.label_settings(12, UITheme.CREAM_DIM, false, 1, 1), Rect2(0, 232, 480, 16))


func _label(text: String, settings: LabelSettings, rect: Rect2) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = settings
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	return l


func is_playing() -> bool:
	return _t >= 0.0


## Starts it. `on_dark` runs once the screen is fully dark (move the hero there); `on_burst` when the crystal bursts (shake).
func play(on_dark: Callable, on_burst: Callable = Callable()) -> void:
	_on_dark = on_dark
	_on_burst = on_burst
	_t = 0.0
	_darked = false
	_burst_done = false
	_shards.clear()
	_dust.clear()
	for l in [_head, _sub, _hint]:
		l.modulate.a = 0.0
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t > T_SUB and _t < T_CLOSE and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact")):
		_t = T_CLOSE           # hurry on: straight to the closing ink
	if not _burst_done and _t >= T_BURST:
		_burst_done = true
		_burst()
		if _on_burst.is_valid():
			_on_burst.call()
	if not _darked and _t >= T_DARK:
		_darked = true
		if _on_dark.is_valid():
			_on_dark.call()
	for s in _shards:
		s["v"] = (s["v"] as Vector2) + Vector2(0, 340.0) * delta
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * delta
		s["r"] = float(s["r"]) + float(s["w"]) * delta
	for d in _dust:
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
	# the words: each rises 4 px into place as it fades in; all of it goes as the ink lifts
	var out := 1.0 - _ease((_t - T_LIFT) / (T_END - T_LIFT))
	_head.modulate.a = _ease((_t - T_HEAD) / 0.5) * out
	_head.position.y = C.y - 22 + roundf(4.0 * (1.0 - _ease((_t - T_HEAD) / 0.5)))
	_sub.modulate.a = _ease((_t - T_SUB) / 0.5) * out
	_hint.modulate.a = 0.75 * _ease((_t - T_HINT) / 0.6) * out
	if _t >= T_END:
		_t = -1.0
		visible = false
		finished.emit()
	queue_redraw()


## Exponential ease-out of a 0..1 progress (clamped).
func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(2.0, -10.0 * k) if k < 1.0 else 1.0


func _veil() -> float:
	if _t < T_CLOSE:
		return VEIL * _ease(_t / 0.45)
	if _t < T_DARK:
		return lerpf(VEIL, 1.0, _ease((_t - T_CLOSE) / (T_DARK - T_CLOSE)))
	if _t < T_LIFT:
		return 1.0
	return 1.0 - _ease((_t - T_LIFT) / (T_END - T_LIFT))


func _draw() -> void:
	if _t < 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color(UITheme.INK, _veil()))
	var fade := clampf(1.0 - (_t - T_LIFT) / (T_END - T_LIFT), 0.0, 1.0) if _t > T_LIFT else 1.0
	if _t < T_BURST:
		var rise := _ease(_t / T_RISE)
		var shiver := Vector2.ZERO
		if _t > T_CRACK:
			var k := (_t - T_CRACK) / (T_BURST - T_CRACK)
			shiver = Vector2(roundf(sin(_t * 90.0) * k * 1.2), 0)
		var at := (C + Vector2(0, roundf(8.0 * (1.0 - rise))) + shiver).floor()
		_gem(at, rise)
		if _t > T_CRACK:
			_cracks(at, (_t - T_CRACK) / (T_BURST - T_CRACK))
	else:
		var since := _t - T_BURST
		if since < 0.32:                               # the ring the burst throws out
			var k := since / 0.32
			draw_arc(C, 8.0 + 60.0 * _ease(k), 0.0, TAU, 48, Color(UITheme.CREAM, (1.0 - k) * 0.9), 1.0)
		if since < 0.1 and not SettingsStore.reduce_flashing:
			draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color(1, 1, 1, 0.45 * (1.0 - since / 0.1)))
		var life := clampf(1.0 - since / 1.3, 0.0, 1.0)
		for s in _shards:
			var pts := PackedVector2Array()
			var ca := cos(float(s["r"]))
			var sa := sin(float(s["r"]))
			for v: Vector2 in s["pts"]:
				pts.append((C + (s["p"] as Vector2) + Vector2(v.x * ca - v.y * sa, v.x * sa + v.y * ca)).floor())
			draw_colored_polygon(pts, Color(s["c"], life))
		for d in _dust:
			var tw := 0.5 + 0.5 * sin(_t * 9.0 + float(d["ph"]))
			var a := clampf((T_DARK - _t) / 1.2, 0.0, 1.0) * tw * fade
			draw_rect(Rect2((C + (d["p"] as Vector2)).floor(), Vector2(1, 1)), Color(d["c"], a))


## The crystal at `at` (its middle), `a` opaque: four facets lit from the top left, an ink outline, a white glint.
func _gem(at: Vector2, a: float) -> void:
	var top: Vector2 = RIM[0]
	var r_g: Vector2 = RIM[1]
	var r_l: Vector2 = RIM[2]
	var bot: Vector2 = RIM[3]
	var l_l: Vector2 = RIM[4]
	var l_g: Vector2 = RIM[5]
	var mid := Vector2(0, -14)
	_facet(at, [top, l_g, mid], BLUE_LIT, a)
	_facet(at, [top, mid, r_g], VIOLET, a)
	_facet(at, [l_g, l_l, bot, mid], BLUE, a)
	_facet(at, [mid, bot, r_l, r_g], VIOLET_DARK, a)
	var outline := PackedVector2Array()
	for p: Vector2 in RIM:
		outline.append(at + p)
	outline.append(at + RIM[0])
	draw_polyline(outline, Color(UITheme.INK, a), 1.0)
	draw_line(at + l_g, at + r_g, Color(1, 1, 1, 0.35 * a), 1.0)                      # the girdle
	draw_line(at + mid, at + bot, Color(UITheme.INK, 0.35 * a), 1.0)                   # the keel
	for g: Vector2 in [Vector2(-11, -21), Vector2(-12, -21), Vector2(-13, -21), Vector2(-10, -21), Vector2(-9, -21), Vector2(-11, -22), Vector2(-11, -23), Vector2(-11, -20), Vector2(-11, -19), Vector2(-12, -22), Vector2(-10, -20)]:
		draw_rect(Rect2(at + g, Vector2(1, 1)), Color(1, 1, 1, a))                     # the glint


func _facet(at: Vector2, corners: Array, colour: Color, a: float) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in corners:
		pts.append(at + p)
	draw_colored_polygon(pts, Color(colour, a))


## White cracks running out from where it gives, `k` (0..1) of the way through the cracking.
func _cracks(at: Vector2, k: float) -> void:
	draw_rect(Rect2(at + Vector2(8, -21), Vector2(3, 3)), Color.WHITE)
	for crack in CRACKS:
		var start: float = crack[0]
		var g := clampf((k - start) / (1.0 - start) * 1.6, 0.0, 1.0)
		if g <= 0.0:
			continue
		var path: Array = crack[1]
		var total := 0.0
		for i in path.size() - 1:
			total += (path[i] as Vector2).distance_to(path[i + 1])
		var left := total * g
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var seg := a.distance_to(b)
			var n := int(minf(seg, left))
			for s in n + 1:
				var px := (at + a + (b - a) * (s / seg)).floor()
				draw_rect(Rect2(px + Vector2(1, 1), Vector2(1, 1)), Color(UITheme.INK, 0.7))     # the crack's shadow
				draw_rect(Rect2(px, Vector2(1, 1)), Color.WHITE)
			left -= seg
			if left <= 0.0:
				break


## Breaks the crystal into shards (triangles from its middle to its rim, each the colour of the facet it came from) and dust.
func _burst() -> void:
	var rim: Array[Vector2] = []
	for i in RIM.size():
		var a: Vector2 = RIM[i]
		var b: Vector2 = RIM[(i + 1) % RIM.size()]
		rim.append(a)
		rim.append(a.lerp(b, 0.5) + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)))
	for i in rim.size():
		var c0 := Vector2(randf_range(-2, 2), randf_range(-6, 2))
		var tri: Array[Vector2] = [c0, rim[i], rim[(i + 1) % rim.size()]]
		var cen: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
		var pts: Array[Vector2] = []
		for v: Vector2 in tri:
			pts.append(v - cen)
		var lit: bool = cen.y < -14.0
		var colour := (BLUE_LIT if lit else BLUE) if cen.x < 0.0 else (VIOLET if lit else VIOLET_DARK)
		var out: Vector2 = cen.normalized() if cen.length() > 0.1 else Vector2.UP
		_shards.append({"pts": pts, "p": cen, "v": out * randf_range(80.0, 160.0) + Vector2(0, -70.0), "r": 0.0,
				"w": randf_range(-9.0, 9.0), "c": colour})
	for i in 22:
		var a := randf() * TAU
		_dust.append({"p": Vector2(cos(a), sin(a)) * randf_range(4.0, 26.0), "v": Vector2(randf_range(-6, 6), randf_range(6, 16)),
				"ph": randf() * TAU, "c": [BLUE_LIT, VIOLET, Color.WHITE][i % 3]})
