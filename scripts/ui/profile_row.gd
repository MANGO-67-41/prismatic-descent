class_name ProfileRow
extends Control
## One save slot on the profile screen: ornate top line, numeral, portrait, health pips,
## currency, location, completion and play time. An empty slot reads NEW GAME.

const WIDTH := 360
const HEIGHT := 38

var slot := 1
var data: Dictionary = {}
var active := false

var _num_label: Label
var _clear_label: Label
var _confirming := false
var _num_dim: LabelSettings
var _num_lit: LabelSettings
var _clear_rust: LabelSettings
var _clear_lit: LabelSettings


func setup(slot_number: int, summary: Dictionary) -> void:
	slot = slot_number
	data = summary
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, HEIGHT)
	for child in get_children():
		child.queue_free()
	_num_dim = UITheme.label_settings(20, UITheme.CREAM_DIM, false, 0, 2)
	_num_lit = UITheme.label_settings(20, UITheme.CREAM, false, 0, 2)
	_clear_rust = UITheme.label_settings(12, UITheme.RUST, false, 1)
	_clear_lit = UITheme.label_settings(12, UITheme.CREAM, false, 1)
	var text_dim := UITheme.label_settings(16, UITheme.CREAM_DIM)
	var small := UITheme.label_settings(12, UITheme.CREAM_DIM, false, 1)
	_num_label = _text("%d." % slot, _num_dim, Rect2(8, 6, 30, 26), HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_num_label)
	if data.is_empty():
		add_child(_text("NEW GAME", text_dim, Rect2(60, 10, 200, 20), HORIZONTAL_ALIGNMENT_LEFT))
		_clear_label = null
	else:
		add_child(_text(str(data["location"]), UITheme.label_settings(16, UITheme.CREAM), Rect2(WIDTH - 204, 3, 200, 18), HORIZONTAL_ALIGNMENT_RIGHT))
		var stats := "%d%%     %s" % [int(data["percent"]), SaveSlots.format_time(int(data["playtime"]))]
		add_child(_text(stats, small, Rect2(WIDTH - 204, 21, 200, 14), HORIZONTAL_ALIGNMENT_RIGHT))
		add_child(_text(str(int(data["currency"])), small, Rect2(88, 20, 70, 14), HORIZONTAL_ALIGNMENT_LEFT))
		_clear_label = _text("CLEAR SAVE", small, Rect2(150, 21, 110, 14), HORIZONTAL_ALIGNMENT_LEFT)
		add_child(_clear_label)
	_apply_state()


func set_active(value: bool) -> void:
	active = value
	_apply_state()


func set_confirming(value: bool) -> void:
	_confirming = value
	_apply_state()


## Where the CLEAR SAVE text sits in screen space; empty unless it is currently shown.
func clear_rect() -> Rect2:
	if _clear_label == null or not _clear_label.visible:
		return Rect2()
	return Rect2(position + Vector2(150, 19), Vector2(110, 16))


func _apply_state() -> void:
	if _num_label == null:
		return
	_num_label.label_settings = _num_lit if active else _num_dim
	if _clear_label:
		_clear_label.visible = active
		_clear_label.text = "CONFIRM ERASE" if _confirming else "CLEAR SAVE"
		_clear_label.label_settings = _clear_lit if _confirming else _clear_rust
	queue_redraw()


func _text(text: String, settings: LabelSettings, rect: Rect2, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _diamond(center: Vector2, radius: int, colour: Color) -> void:
	for dy in range(-radius, radius + 1):
		var half := radius - absi(dy)
		draw_rect(Rect2(center.x - half, center.y + dy, half * 2 + 1, 1), colour)


func _draw() -> void:
	var line := UITheme.CREAM_DIM if active else UITheme.RUST
	draw_rect(Rect2(0, 0, WIDTH, 1), line)
	draw_rect(Rect2(0, 1, WIDTH, 1), UITheme.INK)
	draw_rect(Rect2(0, 0, 1, 8), line)
	draw_rect(Rect2(1, 7, 3, 1), line)
	_diamond(Vector2(16, 0), 2, UITheme.CREAM if active else UITheme.CREAM_DIM)
	_diamond(Vector2(WIDTH - 1, 0), 2, line)
	if data.is_empty():
		return
	_draw_portrait(Vector2(42, 6))
	var health := int(data["health"])
	for i in int(data["max_health"]):
		var mode: int = Glyphs.Crystal.FULL if i < health else Glyphs.Crystal.EMPTY
		Glyphs.draw_crystal(self, Vector2(80 + i * Glyphs.CRYSTAL_PITCH, 7), mode, 0.0, 1.0 if active else 0.75)
	_diamond(Vector2(82, 27), 3, UITheme.CREAM_DIM)


## Slot portrait: an emblem of the region the profile is currently in (the five region names are final).
## Unknown regions fall back to a placeholder creature head (replace with the real hero art).
func _draw_portrait(origin: Vector2) -> void:
	var region := str(data.get("location", ""))
	var backdrop := UITheme.RUST_DARK
	match region:
		"THE OVERGROWTH":
			backdrop = Color("222a1b")
		"THE RUSTWORKS":
			backdrop = Color("2a1a18")
		"THE DROWNED WORKS":
			backdrop = Color("0f1f24")
		"THE BONE STACKS":
			backdrop = Color("2a2620")
		"THE ASH DEEP":
			backdrop = Color("1c1420")
		"THE PRISMATIC LAKE":
			backdrop = Color("0f1b24")
	draw_rect(Rect2(origin.x - 1, origin.y - 1, 28, 28), UITheme.INK)
	draw_rect(Rect2(origin.x, origin.y, 26, 26), backdrop)
	match region:
		"THE OVERGROWTH":
			_emblem_vines(origin)
		"THE RUSTWORKS":
			_emblem_gear(origin)
		"THE DROWNED WORKS":
			_emblem_water(origin)
		"THE BONE STACKS":
			_emblem_ribs(origin)
		"THE ASH DEEP":
			_emblem_ash(origin)
		"THE PRISMATIC LAKE":
			_emblem_prism(origin)
		_:
			_emblem_creature(origin)


## Muted moss greens: the one place a non-dusk hue is allowed, scoped to this region's emblem.
func _emblem_vines(origin: Vector2) -> void:
	var stem := Color("7d9250") if active else Color("56653b")
	var leaf := Color("a9bd6a") if active else Color("737f4a")
	var dark := Color("3e4b2b") if active else Color("2f3822")
	# ground ledge
	draw_rect(Rect2(origin.x + 2, origin.y + 24, 22, 2), dark)
	# back vine: darker, thinner, different phase
	for y in 22:
		var bx := 8 + roundi(sin(y * 0.28 + 2.4) * 3.0)
		draw_rect(Rect2(origin.x + bx, origin.y + 23 - y, 1, 1), dark)
	for tuft in [Vector2(6, 17), Vector2(5, 11)]:
		draw_rect(Rect2(origin.x + tuft.x - 1, origin.y + tuft.y, 3, 1), dark)
		draw_rect(Rect2(origin.x + tuft.x, origin.y + tuft.y - 1, 1, 3), dark)
	# main vine: a gentle S-curve, two pixels wide
	var stem_x: Array[int] = []
	for y in 24:
		var x := 14 + roundi(sin(y * 0.33 + 0.4) * 3.0)
		stem_x.append(x)
		draw_rect(Rect2(origin.x + x, origin.y + 23 - y, 2, 1), stem)
	# leaves on alternating sides, five pixels wide
	var side := 1
	for ly: int in [19, 14, 9, 5]:
		var lx: float = origin.x + stem_x[23 - ly]
		var y: float = origin.y + ly
		if side == 1:
			draw_rect(Rect2(lx + 3, y - 1, 3, 1), leaf)
			draw_rect(Rect2(lx + 2, y, 5, 1), leaf)
			draw_rect(Rect2(lx + 3, y + 1, 3, 1), dark)
		else:
			draw_rect(Rect2(lx - 4, y - 1, 3, 1), leaf)
			draw_rect(Rect2(lx - 5, y, 5, 1), leaf)
			draw_rect(Rect2(lx - 4, y + 1, 3, 1), dark)
		side = -side
	# curled tip
	var tip: int = stem_x[23]
	draw_rect(Rect2(origin.x + tip + 2, origin.y + 1, 3, 1), stem)
	draw_rect(Rect2(origin.x + tip + 4, origin.y + 2, 1, 3), stem)
	draw_rect(Rect2(origin.x + tip + 2, origin.y + 4, 3, 1), stem)
	draw_rect(Rect2(origin.x + tip + 2, origin.y + 3, 1, 1), stem)
	# drifting spores
	for spore: Vector2 in [Vector2(3, 6), Vector2(22, 13), Vector2(21, 20), Vector2(5, 3)]:
		draw_rect(Rect2(origin.x + spore.x, origin.y + spore.y, 1, 1), leaf)


## THE RUSTWORKS: two meshing gears in rust orange.
func _emblem_gear(origin: Vector2) -> void:
	var metal := Color("d0743a") if active else Color("8a5230")
	var dark := Color("7a3a28") if active else Color("5a2c20")
	_gear(origin + Vector2(10, 11), 5.2, 3.2, 8, metal, dark)
	_gear(origin + Vector2(20, 19), 3.6, 2.0, 6, metal, dark)
	draw_rect(Rect2(origin.x + 2, origin.y + 24, 22, 2), dark)  # floor plate


func _gear(centre: Vector2, outer: float, inner: float, teeth: int, colour: Color, hole: Color) -> void:
	for dy in range(-int(outer) - 3, int(outer) + 4):
		for dx in range(-int(outer) - 3, int(outer) + 4):
			var dist := sqrt(dx * dx + dy * dy)
			if dist >= inner and dist <= outer:
				draw_rect(Rect2(centre.x + dx, centre.y + dy, 1, 1), colour)
	for tooth in teeth:
		var angle := tooth * TAU / teeth
		var tx := centre.x + roundi(cos(angle) * (outer + 1.2))
		var ty := centre.y + roundi(sin(angle) * (outer + 1.2))
		draw_rect(Rect2(tx - 1, ty - 1, 2, 2), colour)
	draw_rect(Rect2(centre.x - 1, centre.y - 1, 2, 2), hole)
	for spoke in 4:
		var a := spoke * TAU / 4.0 + 0.4
		draw_rect(Rect2(centre.x + roundi(cos(a) * inner * 0.7), centre.y + roundi(sin(a) * inner * 0.7), 1, 1), hole)


## THE DROWNED WORKS: a dripping pipe over still water.
func _emblem_water(origin: Vector2) -> void:
	var teal := Color("56a3a6") if active else Color("3a7274")
	var pale := Color("9ad8cc") if active else Color("6a9a92")
	var deep := Color("2a6a6c") if active else Color("1f4a4c")
	draw_rect(Rect2(origin.x + 2, origin.y + 3, 14, 3), teal)        # pipe
	draw_rect(Rect2(origin.x + 13, origin.y + 3, 3, 8), teal)         # elbow down
	draw_rect(Rect2(origin.x + 12, origin.y + 10, 5, 2), deep)        # spout
	draw_rect(Rect2(origin.x + 2, origin.y + 3, 14, 1), pale)
	draw_rect(Rect2(origin.x + 14, origin.y + 13, 1, 2), pale)        # drips
	draw_rect(Rect2(origin.x + 14, origin.y + 17, 1, 1), pale)
	for x in 26:                                                       # water
		var wave := roundi(sin(x * 0.75) * 0.9)
		draw_rect(Rect2(origin.x + x, origin.y + 19 + wave, 1, 1), pale)
		for y in range(20, 26):
			if (x + y) % 2 == 0 or y > 22:
				draw_rect(Rect2(origin.x + x, origin.y + y + (1 if y == 20 else 0), 1, 1), teal if y < 24 else deep)
	draw_rect(Rect2(origin.x + 11, origin.y + 21, 7, 1), pale)          # ripple under the drip


## THE BONE STACKS: a spine with rib arches.
func _emblem_ribs(origin: Vector2) -> void:
	var bone := Color("d8c9a0") if active else Color("9a9078")
	var dark := Color("6a6050") if active else Color("4e4638")
	for k in 6:                                                          # vertebrae
		draw_rect(Rect2(origin.x + 11, origin.y + 2 + k * 4, 4, 2), bone)
		draw_rect(Rect2(origin.x + 12, origin.y + 4 + k * 4, 2, 2), dark)
	for k in 4:                                                          # ribs: arcs sweeping out and down
		var y0 := 5 + k * 4
		var reach := 9 - k
		for i in range(1, reach):
			var drop := roundi(float(i * i) / (reach * 1.4))
			draw_rect(Rect2(origin.x + 11 - i, origin.y + y0 + drop, 1, 1), bone if k % 2 == 0 else dark)
			draw_rect(Rect2(origin.x + 14 + i, origin.y + y0 + drop, 1, 1), bone if k % 2 == 0 else dark)
	draw_rect(Rect2(origin.x + 3, origin.y + 24, 20, 2), dark)


## THE ASH DEEP: ash dunes with a glowing cinder and drifting embers.
func _emblem_ash(origin: Vector2) -> void:
	var ash := Color("a98bb0") if active else Color("75607a")
	var dark := Color("46354f") if active else Color("33283a")
	var ember := Color("e08a4a") if active else Color("a8602a")
	var glow := Color("ffd9a0") if active else Color("c4986a")
	for x in 26:                                                       # dunes
		var h := 6 + roundi(sin(x * 0.42) * 2.0 + sin(x * 0.17) * 1.5)
		draw_rect(Rect2(origin.x + x, origin.y + 26 - h, 1, h), dark)
		draw_rect(Rect2(origin.x + x, origin.y + 26 - h, 1, 1), ash)
	for row in [[1, 0], [1, 1], [3, 2], [3, 3], [5, 4], [7, 5], [7, 6], [5, 7], [3, 8]]:   # cinder: a teardrop flame
		var half: int = row[0] / 2
		draw_rect(Rect2(origin.x + 13 - half, origin.y + 4 + row[1], row[0], 1), ember)
	draw_rect(Rect2(origin.x + 12, origin.y + 9, 3, 3), glow)
	draw_rect(Rect2(origin.x + 13, origin.y + 8, 1, 1), Color.WHITE if active else glow)
	for e: Vector2 in [Vector2(5, 11), Vector2(20, 9), Vector2(8, 5), Vector2(18, 3), Vector2(22, 14), Vector2(4, 17), Vector2(15, 1)]:
		draw_rect(Rect2(origin.x + e.x, origin.y + e.y, 1, 1), ember)


func _emblem_prism(origin: Vector2) -> void:
	var centre := origin + Vector2(13, 13)
	var bright := 1.0 if active else 0.7
	for dy in range(-10, 11):
		var half := 10 - absi(dy)
		var left := Color.from_hsv(0.50, 0.45, bright)
		var right := Color.from_hsv(0.66, 0.45, bright)
		draw_rect(Rect2(centre.x - half, centre.y + dy, half, 1), left)
		draw_rect(Rect2(centre.x, centre.y + dy, half + 1, 1), right)
	draw_rect(Rect2(centre.x - 1, centre.y - 6, 2, 12), Color(1, 1, 1, 0.35))


func _emblem_creature(origin: Vector2) -> void:
	var tone := UITheme.CREAM if active else UITheme.CREAM_DIM
	var cx := origin.x + 13
	var cy := origin.y + 15
	for dy in range(-8, 9):
		var half := int(sqrt(maxf(0.0, 64.0 - dy * dy)) * 1.1)
		draw_rect(Rect2(cx - half, cy + dy, half * 2 + 1, 1), tone)
	draw_rect(Rect2(cx - 7, cy - 11, 3, 4), tone)
	draw_rect(Rect2(cx + 5, cy - 11, 3, 4), tone)
	draw_rect(Rect2(cx - 5, cy - 2, 3, 4), UITheme.INK)
	draw_rect(Rect2(cx + 3, cy - 2, 3, 4), UITheme.INK)
