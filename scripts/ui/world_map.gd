class_name WorldMap
extends Control
## The map of the descent, drawn from the baked picture of the real world (assets/world/map.png, 1 px = 2x2 tiles).
## Quick map (Tab): a corner panel centred on the hero, a few seconds. Full map (M): the whole world as far as explored,
## scrollable, with region names on their boundaries. Only rooms the hero has entered are drawn.
## Region names other than THE OVERGROWTH are placeholders.

signal opened  ## the full map opened
signal closed  ## the full map closed

enum Mode { CLOSED, QUICK, FULL }

const MAP_ART := preload("res://assets/world/map.png")
const S := WorldData.MAP_SCALE
const QUICK_SECONDS := 3.0
const FULL_TOP := 40.0
const FULL_HEIGHT := 214.0
const FULL_LEFT := 40.0
const ZOOM := 2.0
const SCROLL_SPEED := 160.0
const QUICK_RECT := Rect2(284, 8, 188, 82)
const QUICK_VIEW := Vector2(176, 58)
const REGIONS := [
	{"name": "THE OVERGROWTH", "colour": Color("8f9d5e")},
	{"name": "THE RUSTWORKS", "colour": Color("d0743a")},
	{"name": "THE DROWNED WORKS", "colour": Color("56a3a6")},
	{"name": "THE BONE STACKS", "colour": Color("d8c9a0")},
	{"name": "THE ASH DEEP", "colour": Color("a98bb0")},
]

var mode := Mode.CLOSED
var current_region := 0
var current_piece := 0
var player_pos := Vector2.ZERO
var discovered: Dictionary = {}  ## piece id -> true; while empty and unbound every room shows (preview scenes)
var bound := false

var _scroll := 0.0
var _quick_tween: Tween
var _fade: Tween
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	WorldData.ensure_loaded()


## Hand the map the set of explored rooms (shared with the game, which adds to it).
func bind_discovered(set_of_rooms: Dictionary) -> void:
	discovered = set_of_rooms
	bound = true


## Where the hero is now: world position and the piece (room or shaft) they stand in.
func set_player(pos: Vector2, piece_id: int) -> void:
	player_pos = pos
	if piece_id >= 0:
		current_piece = piece_id
		current_region = int(WorldData.pieces[piece_id]["region"])
	if visible:
		queue_redraw()


func set_region(region_name: String) -> void:
	current_region = 0
	for i in REGIONS.size():
		if REGIONS[i]["name"] == region_name:
			current_region = i
	queue_redraw()


func is_full() -> bool:
	return mode == Mode.FULL


func press_quick() -> void:
	if mode == Mode.CLOSED:
		_open_quick()
	else:
		close()


func press_full() -> void:
	if mode == Mode.FULL:
		close()
	else:
		_open_full()


func close() -> void:
	if mode == Mode.CLOSED:
		return
	var was_full := mode == Mode.FULL
	mode = Mode.CLOSED
	visible = false
	if _quick_tween:
		_quick_tween.kill()
	if was_full:
		closed.emit()


func _open_quick() -> void:
	mode = Mode.QUICK
	visible = true
	_fade_in()
	if _quick_tween:
		_quick_tween.kill()
	_quick_tween = create_tween()
	_quick_tween.tween_interval(QUICK_SECONDS)
	_quick_tween.tween_callback(func() -> void:
		if mode == Mode.QUICK:
			close()
	)
	queue_redraw()


func _open_full() -> void:
	if _quick_tween:
		_quick_tween.kill()
	mode = Mode.FULL
	visible = true
	_scroll = clampf(roundf(player_pos.y / S * ZOOM - FULL_HEIGHT * 0.5), 0.0, _max_scroll())
	_fade_in()
	opened.emit()
	queue_redraw()


func _fade_in() -> void:
	if _fade:
		_fade.kill()
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.12)


func _max_scroll() -> float:
	return maxf(0.0, MAP_ART.get_height() * ZOOM - FULL_HEIGHT)


func _known(i: int) -> bool:
	return not bound or discovered.has(i)


# --- Input --------------------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if mode != Mode.FULL:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventMouseButton and event.pressed:
		var wheel := (event as InputEventMouseButton).button_index
		if wheel == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-20.0)
		elif wheel == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(20.0)


func _process(delta: float) -> void:
	if mode == Mode.CLOSED:
		return
	_t += delta
	queue_redraw()  # the hero's marker blinks
	if mode == Mode.FULL:
		var dir := Input.get_axis("ui_up", "ui_down")
		if dir != 0.0:
			_scroll_by(dir * SCROLL_SPEED * delta)


func _scroll_by(amount: float) -> void:
	_scroll = clampf(_scroll + amount, 0.0, _max_scroll())


# --- Drawing ------------------------------------------------------------------------------


func _draw() -> void:
	match mode:
		Mode.QUICK:
			_draw_quick()
		Mode.FULL:
			_draw_full()


## Blits the part of the map picture belonging to `src` (map pixels) to the screen, clipped to `clip`.
func _blit(src: Rect2, to: Vector2, zoom: float, clip: Rect2) -> void:
	var dest := Rect2(to, src.size * zoom)
	var vis := dest.intersection(clip)
	if vis.size.x <= 0.0 or vis.size.y <= 0.0:
		return
	var s := Rect2(src.position + (vis.position - dest.position) / zoom, vis.size / zoom)
	draw_texture_rect_region(MAP_ART, vis, s)


func _piece_src(i: int) -> Rect2:
	var r := WorldData.rect(i)
	return Rect2(floorf(r.position.x / S), floorf(r.position.y / S), ceilf(r.size.x / S) + 1.0, ceilf(r.size.y / S) + 1.0)


func _draw_pieces(origin_map: Vector2, to: Vector2, zoom: float, clip: Rect2) -> void:
	var view_map := Rect2(origin_map, clip.size / zoom).grow(2.0)
	for i in WorldData.pieces.size():
		if not _known(i):
			continue
		var src := _piece_src(i)
		if src.intersects(view_map):
			_blit(src, to + (src.position - origin_map) * zoom, zoom, clip)


func _draw_marks(origin_map: Vector2, to: Vector2, zoom: float, clip: Rect2) -> void:
	for i in WorldData.pieces.size():
		if not _known(i):
			continue
		var p: Dictionary = WorldData.pieces[i]
		for rest in p["rest"]:
			var at := to + ((Vector2(float(p["x"]) + float(rest[0]), float(p["y"]) + float(rest[1])) / S) - origin_map) * zoom
			if clip.has_point(at):
				Glyphs.draw_diamond(self, at, 2, UITheme.CREAM)
	var me := to + ((player_pos / S) - origin_map) * zoom
	if clip.has_point(me) and int(_t * 2.5) % 2 == 0:
		draw_rect(Rect2(me - Vector2(1, 1) * zoom, Vector2(2, 2) * zoom), Color("ffffff"))
		draw_rect(Rect2(me - Vector2(2, 2) * zoom, Vector2(4, 4) * zoom), Color(UITheme.CREAM, 0.35))


func _draw_quick() -> void:
	var colour: Color = REGIONS[current_region]["colour"]
	draw_rect(QUICK_RECT.grow(2), UITheme.INK)
	draw_rect(QUICK_RECT, Color(0.03, 0.02, 0.05, 0.96))
	var inner := Rect2(QUICK_RECT.position + Vector2(6, 6), QUICK_VIEW)
	var zoom := 2.0
	var origin := (player_pos / S - QUICK_VIEW * 0.5 / zoom).floor()
	_draw_pieces(origin, inner.position, zoom, inner)
	_draw_marks(origin, inner.position, zoom, inner)
	_frame(QUICK_RECT, colour)
	var font := UITheme.font(false, 1)
	draw_string(font, QUICK_RECT.position + Vector2(0, 76), REGIONS[current_region]["name"], HORIZONTAL_ALIGNMENT_CENTER, QUICK_RECT.size.x, 12, UITheme.CREAM)


func _draw_full() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color(0.03, 0.02, 0.05, 0.96))
	Glyphs.draw_corner(self, Vector2(8, 8), 1, 1)
	Glyphs.draw_corner(self, Vector2(471, 8), -1, 1)
	Glyphs.draw_corner(self, Vector2(8, 261), 1, -1)
	Glyphs.draw_corner(self, Vector2(471, 261), -1, -1)
	var font := UITheme.font(false, 3)
	draw_string_outline(font, Vector2(0, 26), "MAP", HORIZONTAL_ALIGNMENT_CENTER, 480, 20, 2, UITheme.INK)
	draw_string(font, Vector2(0, 26), "MAP", HORIZONTAL_ALIGNMENT_CENTER, 480, 20, UITheme.CREAM)
	Glyphs.draw_divider(self, 240, 31, 96, true)
	var width := MAP_ART.get_width() * ZOOM
	var view := Rect2(FULL_LEFT, FULL_TOP, width, FULL_HEIGHT)
	var origin := Vector2(0.0, roundf(_scroll) / ZOOM)
	_draw_pieces(origin, view.position, ZOOM, view)
	var small := UITheme.font(false, 1)
	for i in WorldData.regions.size():
		var region: Dictionary = WorldData.regions[i]
		var seen := false
		for id in range(int(region["first"]), int(region["last"]) + 1):
			if _known(id):
				seen = true
				break
		if not seen:
			continue
		var y := FULL_TOP + float(region["y0"]) / S * ZOOM - roundf(_scroll)
		var colour: Color = REGIONS[i]["colour"]
		if y > FULL_TOP and y < FULL_TOP + FULL_HEIGHT - 4.0:
			for x in range(int(FULL_LEFT), int(FULL_LEFT + width), 3):
				draw_rect(Rect2(x, y - 1, 1, 1), colour.darkened(0.2))
		var ty := y + 11.0
		if ty > FULL_TOP + 6.0 and ty < FULL_TOP + FULL_HEIGHT:
			draw_string_outline(small, Vector2(FULL_LEFT + 4, ty), REGIONS[i]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, UITheme.INK)
			draw_string(small, Vector2(FULL_LEFT + 4, ty), REGIONS[i]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.CREAM if i == current_region else colour)
	_draw_marks(origin, view.position, ZOOM, view)
	_frame(view.grow(1), UITheme.RUST_DARK)
	if _scroll > 0.5:
		_chevron(Vector2(view.get_center().x, FULL_TOP - 6), -1)
	if _scroll < _max_scroll() - 0.5:
		_chevron(Vector2(view.get_center().x, FULL_TOP + FULL_HEIGHT + 6), 1)


func _frame(rect: Rect2, colour: Color) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1)), colour)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 1), Vector2(rect.size.x, 1)), colour)
	draw_rect(Rect2(rect.position, Vector2(1, rect.size.y)), colour)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 1, 0), Vector2(1, rect.size.y)), colour)


func _chevron(centre: Vector2, dir: int) -> void:
	for i in 3:
		draw_rect(Rect2(centre.x - (3 - i), centre.y + dir * (i - 1), (3 - i) * 2 + 1, 1), UITheme.CREAM_DIM)
