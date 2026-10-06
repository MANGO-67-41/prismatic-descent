class_name Toast
extends Control
## A short message near the top of the screen (a key found, a guardian fallen, a door that will not open): the words in the
## accent colour with a line drawing out beneath, and an optional smaller line under that.

const HOLD := 2.6

var _text := ""
var _sub := ""
var _colour := UITheme.CREAM
var _alpha := 0.0
var _line := 0.0
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func show_message(text: String, colour: Color = UITheme.CREAM, sub: String = "") -> void:
	_text = text
	_sub = sub
	_colour = colour
	if _tween:
		_tween.kill()
	_alpha = 0.0
	_line = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "_alpha", 1.0, 0.25)
	_tween.parallel().tween_property(self, "_line", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "_alpha", 0.0, 0.6)
	_tween.tween_callback(func() -> void: visible = false)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if _text == "":
		return
	var font := UITheme.font(false, 2)
	var small := UITheme.font(false, 1)
	var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var y := 62.0
	draw_string_outline(font, Vector2(0, y), _text, HORIZONTAL_ALIGNMENT_CENTER, 480, 16, 4, Color(UITheme.INK, _alpha))
	draw_string(font, Vector2(0, y), _text, HORIZONTAL_ALIGNMENT_CENTER, 480, 16, Color(_colour, _alpha))
	var half := roundf((w * 0.5 + 8.0) * _line)
	draw_rect(Rect2(240 - half, y + 6, half * 2, 1), Color(_colour, _alpha))
	draw_rect(Rect2(240 - half, y + 7, half * 2, 1), Color(UITheme.INK, _alpha))
	Glyphs.draw_diamond(self, Vector2(240, y + 6), 2, Color(UITheme.CREAM, _alpha * _line))
	if _sub != "":
		draw_string_outline(small, Vector2(0, y + 22), _sub, HORIZONTAL_ALIGNMENT_CENTER, 480, 12, 3, Color(UITheme.INK, _alpha))
		draw_string(small, Vector2(0, y + 22), _sub, HORIZONTAL_ALIGNMENT_CENTER, 480, 12, Color(UITheme.CREAM_DIM, _alpha))
