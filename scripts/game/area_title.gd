class_name AreaTitle
extends Control
## The area name that appears in the bottom right corner when the hero crosses into another region (or wakes at a lantern, or walks
## into a lantern shrine: then it reads LANTERN ROOM, in the region's colour):
## a small "NOW ENTERING" line, the name in the region's colour, and a line that draws out underneath. Fades after a few seconds.

const HOLD := 3.2

var shown_name := ""
var _alpha := 0.0
var _line := 0.0
var _colour := UITheme.CREAM
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func show_area(region_name: String, colour: Color) -> void:
	shown_name = region_name
	_colour = colour
	if _tween:
		_tween.kill()
	_alpha = 0.0
	_line = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "_alpha", 1.0, 0.5)
	_tween.parallel().tween_property(self, "_line", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "_alpha", 0.0, 0.9)
	_tween.tween_callback(func() -> void: visible = false)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if shown_name == "":
		return
	var small := UITheme.font(false, 1)
	var big := UITheme.font(false, 2)
	var right := 466.0
	var name_w := big.get_string_size(shown_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var line_w := roundf(maxf(name_w, 90.0) * _line)
	draw_string_outline(small, Vector2(right - 200, 233), "NOW ENTERING", HORIZONTAL_ALIGNMENT_RIGHT, 200, 12, 3, Color(UITheme.INK, _alpha))
	draw_string(small, Vector2(right - 200, 233), "NOW ENTERING", HORIZONTAL_ALIGNMENT_RIGHT, 200, 12, Color(UITheme.CREAM_DIM, _alpha))
	draw_string_outline(big, Vector2(right - 300, 252), shown_name, HORIZONTAL_ALIGNMENT_RIGHT, 300, 16, 4, Color(UITheme.INK, _alpha))
	draw_string(big, Vector2(right - 300, 252), shown_name, HORIZONTAL_ALIGNMENT_RIGHT, 300, 16, Color(_colour, _alpha))
	draw_rect(Rect2(right - line_w, 258, line_w, 1), Color(_colour, _alpha))
	draw_rect(Rect2(right - line_w, 259, line_w, 1), Color(UITheme.INK, _alpha))
	Glyphs.draw_diamond(self, Vector2(right - line_w - 4, 258), 2, Color(UITheme.CREAM, _alpha * _line))
