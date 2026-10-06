class_name ShardScreen
extends Control
## When the hero gains a crystal shard (a guardian has fallen). The same family as the death screen, turned the other way: the screen
## dims (not to black: this is a gain) and a half of the HUD crystal hangs in the middle of it, broken along a jagged edge, a glint
## sweeping across it. The first shard of a pair is the LEFT half (light blue, as in the shard circle of the HUD); the second is the RIGHT
## half (violet), which rises beside it, and the two slide together along their break, flash and become a whole crystal. The words
## come up under it (CRYSTAL SHARD / A NEW CRYSTAL), then the shard (or the crystal) shrinks and flies in an arc to where it lives in
## the HUD: the shard circle, or the new crystal's place in the row. `on_arrive` runs as it lands (the game adds the shard then, and the
## HUD answers: the circle fills, or the new crystal regrows), a ring of sparks marks the spot, and the dim lifts. Once the words are up,
## jump, the stick or interact hurries it on.

signal finished

const VEIL := 0.55
const C := Vector2(240, 88)            ## where the shard hangs
const HEAD := UITheme.CREAM
const JAG := [Vector2(0, -40), Vector2(-3, -31), Vector2(2, -23), Vector2(-2, -14), Vector2(3, -5), Vector2(-2, 5), Vector2(2, 15),
		Vector2(-3, 25), Vector2(1, 34), Vector2(0, 40)]        ## the line the crystal broke along, top to bottom (the halves fit exactly)

var _t := -1.0
var _whole := false            ## the second shard of a pair: the halves come together
var _target := Vector2.ZERO    ## where it flies to (screen pixels)
var _on_arrive: Callable
var _arrived := false
var _t_join := 0.0
var _t_head := 0.5
var _t_sub := 0.95
var _t_fly := 2.5
var _t_arrive := 3.05
var _t_end := 3.6
var _at := Vector2.ZERO        ## where the crystal is drawn this frame, and how big (1 = full size)
var _scale := 1.0
var _trail: Array[Vector2] = []
var _sparks: Array[Dictionary] = []
var _glints: Array[Dictionary] = []
var _head: Label
var _sub: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_head = _label("", UITheme.label_settings(28, DeathScreen.BLUE_LIT, false, 3, 2), Rect2(0, C.y + 52, 480, 34))
	_sub = _label("", UITheme.label_settings(12, UITheme.CREAM_DIM, false, 4, 1), Rect2(0, C.y + 88, 480, 16))


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


## Starts it. `second_of_pair`: this shard completes a crystal. `target`: where it ends up in the HUD. `on_arrive` runs when it lands.
func play(second_of_pair: bool, target: Vector2, on_arrive: Callable) -> void:
	_whole = second_of_pair
	_target = target
	_on_arrive = on_arrive
	_arrived = false
	_t = 0.0
	_trail.clear()
	_sparks.clear()
	_glints.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 7:
		_glints.append({"p": Vector2(rng.randf_range(-34, 34), rng.randf_range(-46, 46)), "ph": rng.randf() * TAU, "sp": rng.randf_range(2.0, 4.0)})
	if _whole:
		_t_join = 1.15
		_t_head = 1.3
		_t_sub = 1.75
		_t_fly = 3.0
	else:
		_t_join = 0.0
		_t_head = 0.5
		_t_sub = 0.95
		_t_fly = 2.5
	_t_arrive = _t_fly + 0.55
	_t_end = _t_arrive + 0.55
	_head.text = "A NEW CRYSTAL" if _whole else "CRYSTAL SHARD"
	_sub.text = "THE TWO HALVES BECOME ONE" if _whole else "THE FIRST HALF OF A NEW CRYSTAL"
	for l in [_head, _sub]:
		l.modulate.a = 0.0
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t > _t_sub + 0.3 and _t < _t_fly and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact")):
		_t = _t_fly
	if _t >= _t_fly:
		var k := _fly_k()
		_trail.append(_pos(k))
		if _trail.size() > 9:
			_trail.pop_front()
	if not _arrived and _t >= _t_arrive:
		_arrived = true
		for i in 12:
			var a := TAU * i / 12.0 + 0.2
			_sparks.append({"v": Vector2(cos(a), sin(a)) * randf_range(40.0, 90.0), "p": Vector2.ZERO})
		if _on_arrive.is_valid():
			_on_arrive.call()
	for s in _sparks:
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * delta
		s["v"] = (s["v"] as Vector2) * 0.9 + Vector2(0, 60.0) * delta
	var out := 1.0 - _ease((_t - _t_fly) / 0.35)
	_head.modulate.a = _ease((_t - _t_head) / 0.5) * out
	_head.position.y = C.y + 52 + roundf(4.0 * (1.0 - _ease((_t - _t_head) / 0.5)))
	_sub.modulate.a = _ease((_t - _t_sub) / 0.5) * out
	if _t >= _t_end:
		_t = -1.0
		visible = false
		_trail.clear()
		_sparks.clear()
		finished.emit()
	queue_redraw()


func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(2.0, -10.0 * k) if k < 1.0 else 1.0


func _veil() -> float:
	if _t < _t_fly:
		return VEIL * _ease(_t / 0.35)
	return VEIL * (1.0 - _ease((_t - _t_fly) / (_t_arrive - _t_fly + 0.3)))


## How far along its flight (0 at the hang, 1 at the HUD): it sets off slowly and speeds up.
func _fly_k() -> float:
	return pow(clampf((_t - _t_fly) / (_t_arrive - _t_fly), 0.0, 1.0), 2.2)


func _pos(k: float) -> Vector2:
	var from := C
	var ctrl := Vector2(_target.x + 90.0, C.y - 40.0)
	return from.lerp(ctrl, k).lerp(ctrl.lerp(_target, k), k)


func _draw() -> void:
	if _t < 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color(UITheme.INK, _veil()))
	if _whole and _t >= _t_join and _t < _t_join + 0.4:                 # the halves meet: a ring and a short flash
		var jk := (_t - _t_join) / 0.4
		draw_arc(C, 8.0 + 52.0 * _ease(jk), 0.0, TAU, 48, Color(UITheme.CREAM, (1.0 - jk) * 0.9), 1.0)
		if jk < 0.25 and not SettingsStore.reduce_flashing:
			draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color(1, 1, 1, 0.22 * (1.0 - jk / 0.25)))
	if _arrived:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var ak := clampf((_t - _t_arrive) / 0.4, 0.0, 1.0)
		draw_arc(_target, 3.0 + 14.0 * _ease(ak), 0.0, TAU, 24, Color(UITheme.CREAM, 1.0 - ak), 1.0)
		for s in _sparks:
			draw_rect(Rect2((_target + (s["p"] as Vector2)).floor(), Vector2(1, 1)), Color(DeathScreen.BLUE_LIT, 1.0 - ak))
	if _t < _t_arrive:
		var flying := _t >= _t_fly
		var k := _fly_k() if flying else 0.0
		var at := _pos(k) if flying else C + Vector2(0, roundf(10.0 * (1.0 - _ease(_t / 0.35))))
		var s := lerpf(1.0, 0.15, k) if _whole else lerpf(1.0, 0.2, k)
		var a := _ease(_t / 0.3)
		if flying:
			for i in _trail.size():
				draw_rect(Rect2(_trail[i].floor(), Vector2(2, 2)), Color(DeathScreen.BLUE_LIT, 0.5 * float(i) / _trail.size() * (1.0 - k * 0.5)))
		_at = at.floor()
		_scale = s
		draw_set_transform(_at, 0.0, Vector2(s, s))
		_draw_crystal(a, not flying)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not flying:
			_draw_glints(a)


## The shard (the left half, centred) or the pair: two halves that slide together along their break, then a whole crystal.
func _draw_crystal(a: float, sparkle: bool) -> void:
	if not _whole:
		_half(Vector2(13, 0), true, a, true)
		if sparkle:
			_shine(Vector2(13, 0), true, (_t - 0.4) / 0.45)
		return
	var d := 30.0 * (1.0 - _ease_io((_t - 0.45) / (_t_join - 0.45)))          # how far each half is from the axis (they meet at 0)
	var joined := _t - _t_join
	if d > 0.5:
		_half(Vector2(-d, 0), true, a, true)
		_half(Vector2(d, 0), false, a, true)
		return
	var pulse := 1.0 + 0.07 * sin(clampf(joined / 0.4, 0.0, 1.0) * PI)
	draw_set_transform(_at, 0.0, Vector2(_scale * pulse, _scale * pulse))
	_half(Vector2.ZERO, true, a, false)
	_half(Vector2.ZERO, false, a, false)
	var outline := PackedVector2Array()
	for p: Vector2 in DeathScreen.RIM:
		outline.append(p)
	outline.append(DeathScreen.RIM[0])
	draw_polyline(outline, Color(UITheme.INK, a), 1.0)
	var seam_a := clampf(1.0 - joined / 0.4, 0.0, 1.0)                           # the break, a bright seam that heals
	if seam_a > 0.0:
		var pts := PackedVector2Array()
		for p: Vector2 in JAG:
			pts.append(p)
		draw_polyline(pts, Color(1, 1, 1, seam_a), 1.0)
	if joined >= 0.2:
		_shine(Vector2.ZERO, true, (joined - 0.2) / 0.5, true)


func _ease_io(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## One half of the crystal with its axis at `o`: left (blue) or right (violet), outlined when `outline`.
func _half(o: Vector2, left: bool, a: float, outline: bool) -> void:
	var poly := _poly(left)
	var shifted := PackedVector2Array()
	for p in poly:
		shifted.append(p + o)
	draw_colored_polygon(shifted, Color(DeathScreen.BLUE if left else DeathScreen.VIOLET_DARK, a))
	var lit: Array = [DeathScreen.RIM[0], DeathScreen.RIM[5], JAG[3], JAG[2], JAG[1]] if left else [DeathScreen.RIM[0], JAG[1], JAG[2], JAG[3], DeathScreen.RIM[1]]
	var lit_pts := PackedVector2Array()
	for p: Vector2 in lit:
		lit_pts.append(p + o)
	draw_colored_polygon(lit_pts, Color(DeathScreen.BLUE_LIT if left else DeathScreen.VIOLET, a))
	if outline:
		var closed := shifted.duplicate()
		closed.append(shifted[0])
		draw_polyline(closed, Color(UITheme.INK, a), 1.0)
		var edge := PackedVector2Array()                                           # the fresh break: pale
		for p: Vector2 in JAG:
			edge.append(p + o)
		draw_polyline(edge, Color(1, 1, 1, 0.55 * a), 1.0)


func _poly(left: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if left:
		pts.append(JAG[0])
		pts.append(DeathScreen.RIM[5])
		pts.append(DeathScreen.RIM[4])
		pts.append(JAG[9])
		for i in range(8, 0, -1):
			pts.append(JAG[i])
	else:
		pts.append(JAG[0])
		for i in range(1, 9):
			pts.append(JAG[i])
		pts.append(JAG[9])
		pts.append(DeathScreen.RIM[2])
		pts.append(DeathScreen.RIM[1])
	return pts


## A diagonal bar of light sweeping across the shard (or the whole crystal), clipped to its outline. `k` runs 0..1 over the sweep.
func _shine(o: Vector2, left: bool, k: float, whole: bool = false) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	var x := lerpf(-60.0, 60.0, k)
	var bar := PackedVector2Array([Vector2(x - 5, -50), Vector2(x + 5, -50), Vector2(x - 15, 50), Vector2(x - 25, 50)])
	for q in bar.size():
		bar[q] += o
	var shape := PackedVector2Array()
	if whole:
		for p: Vector2 in DeathScreen.RIM:
			shape.append(p)
	else:
		for p in _poly(left):
			shape.append(p + o)
	for part in Geometry2D.intersect_polygons(bar, shape):
		if part.size() >= 3:
			draw_colored_polygon(part, Color(1, 1, 1, 0.55 * sin(k * PI)))


func _draw_glints(a: float) -> void:
	for g in _glints:
		var tw := 0.5 + 0.5 * sin(_t * float(g["sp"]) + float(g["ph"]))
		if tw < 0.55:
			continue
		var p: Vector2 = C + (g["p"] as Vector2)
		var col := Color(1, 1, 1, (tw - 0.55) / 0.45 * a)
		draw_rect(Rect2((p - Vector2(0, 2)).floor(), Vector2(1, 5)), col)
		draw_rect(Rect2((p - Vector2(2, 0)).floor(), Vector2(5, 1)), col)
