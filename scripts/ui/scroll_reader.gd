class_name ScrollReader
extends Control
## A parchment scroll that unrolls in the middle of the screen, 80% of it (384 x 216 of 480 x 270), to be read: a title, a rule,
## the words. Interact, Jump or Esc closes it; Left and Right turn the page when a scroll has more than one.

signal opened
signal closed

const PANEL := preload("res://assets/ui/scroll_panel.png")
const SIZE := Vector2(384, 216)
const POS := Vector2(48, 27)
const ROLL_H := 16.0
const INK_BROWN := Color("3e2214")
const TEXT_BROWN := Color("4a2a18")
const DIM_BROWN := Color("7a4a2c")
const RUST_BROWN := Color("9a4a26")
const TEXT_X := 84.0
const TEXT_W := 312.0

var is_open := false

var _title := ""
var _pages: Array = []
var _page := 0
var _unroll := 0.0
var _tween: Tween
var _title_label: Label
var _body: Label
var _hint: Label
var _count: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	_title_label = _label(UITheme.label_settings(20, INK_BROWN, false, 2, 0), Rect2(TEXT_X, POS.y + 30, TEXT_W, 24), HORIZONTAL_ALIGNMENT_CENTER)
	_body = _label(UITheme.label_settings(16, TEXT_BROWN, false, 1, 0), Rect2(TEXT_X, POS.y + 68, TEXT_W, 104), HORIZONTAL_ALIGNMENT_LEFT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER   # short texts sit in the middle of the sheet
	_hint = _label(UITheme.label_settings(12, DIM_BROWN, false, 1, 0), Rect2(TEXT_X, POS.y + 176, 160, 14), HORIZONTAL_ALIGNMENT_LEFT)
	_count = _label(UITheme.label_settings(12, DIM_BROWN, false, 1, 0), Rect2(TEXT_X + TEXT_W - 120, POS.y + 176, 120, 14), HORIZONTAL_ALIGNMENT_RIGHT)


func _label(settings: LabelSettings, rect: Rect2, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.label_settings = settings
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func open(title: String, pages: Array) -> void:
	_title = StoryData.format(title)
	_pages = pages
	_page = 0
	is_open = true
	visible = true
	_apply_page()
	_unroll = 0.0
	_set_text_alpha(0.0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_unroll", 1.0, 0.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_text_alpha, 0.0, 1.0, 0.18)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if _tween:
		_tween.kill()
	closed.emit()


func _set_text_alpha(a: float) -> void:
	for node in [_title_label, _body, _hint, _count]:
		(node as Label).modulate.a = a
	queue_redraw()


func _apply_page() -> void:
	_title_label.text = _title
	_body.text = StoryData.format(str(_pages[_page]))
	_hint.text = "%s  CLOSE" % KeyBindings.key_name("interact")
	_count.text = "%d / %d    %s  %s" % [_page + 1, _pages.size(), KeyBindings.key_name("move_left"), KeyBindings.key_name("move_right")] if _pages.size() > 1 else ""
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("jump") or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		if _unroll > 0.5:
			close()
	elif event.is_action_pressed("ui_right") and _page < _pages.size() - 1:
		_page += 1
		_apply_page()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") and _page > 0:
		_page -= 1
		_apply_page()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not is_open:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color(0.03, 0.02, 0.05, 0.62 * minf(1.0, _unroll * 3.0)))
	# the scroll unrolls: the two rolls part and the sheet is uncovered from the middle outwards
	var total := roundf(lerpf(ROLL_H * 2.0 + 2.0, SIZE.y, _unroll))
	var top := roundf(POS.y + (SIZE.y - total) * 0.5)
	var sheet_h := total - ROLL_H * 2.0
	draw_texture_rect_region(PANEL, Rect2(POS.x, top, SIZE.x, ROLL_H), Rect2(0, 0, SIZE.x, ROLL_H))
	if sheet_h > 0.0:
		var src_y := ROLL_H + (SIZE.y - ROLL_H * 2.0 - sheet_h) * 0.5
		draw_texture_rect_region(PANEL, Rect2(POS.x, top + ROLL_H, SIZE.x, sheet_h), Rect2(0, src_y, SIZE.x, sheet_h))
	draw_texture_rect_region(PANEL, Rect2(POS.x, top + total - ROLL_H, SIZE.x, ROLL_H), Rect2(0, SIZE.y - ROLL_H, SIZE.x, ROLL_H))
	if _unroll >= 0.98:
		# a rust rule with a diamond under the title, and a lighter one above the footer
		var cx := TEXT_X + TEXT_W * 0.5
		var ry := POS.y + 56.0
		draw_rect(Rect2(TEXT_X + 28, ry, TEXT_W * 0.5 - 38, 1), RUST_BROWN)
		draw_rect(Rect2(cx + 10, ry, TEXT_W * 0.5 - 38, 1), RUST_BROWN)
		Glyphs.draw_diamond(self, Vector2(cx, ry), 3, RUST_BROWN)
		Glyphs.draw_diamond(self, Vector2(cx, ry), 1, Color("e6bd84"))
		draw_rect(Rect2(TEXT_X, POS.y + 172, TEXT_W, 1), Color(DIM_BROWN, 0.45))
