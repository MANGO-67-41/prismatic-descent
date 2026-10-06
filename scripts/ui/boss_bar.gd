class_name BossBar
extends Control
## The guardian's health at the top of the screen during a fight: its name, and one crystal for each hit it can still take.

var _name := ""
var _hp := 0
var _max := 0
var _colour := UITheme.CREAM
var _hurt := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func show_boss(boss_name: String, hp: int, max_hp: int, colour: Color) -> void:
	_name = boss_name
	_hp = hp
	_max = max_hp
	_colour = colour
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	queue_redraw()


func set_hp(hp: int) -> void:
	_hp = hp
	_hurt = 1.0
	queue_redraw()


func hide_boss() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible and _hurt > 0.0:
		_hurt = maxf(0.0, _hurt - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	var font := UITheme.font(false, 1)
	draw_string_outline(font, Vector2(0, 20), _name, HORIZONTAL_ALIGNMENT_CENTER, 480, 12, 3, UITheme.INK)
	draw_string(font, Vector2(0, 20), _name, HORIZONTAL_ALIGNMENT_CENTER, 480, 12, UITheme.CREAM)
	var pitch := 12.0
	var x0 := 240.0 - (_max - 1) * pitch * 0.5
	for i in _max:
		var c := Vector2(x0 + i * pitch, 31)
		Glyphs.draw_diamond(self, c, 5, UITheme.INK)
		if i < _hp:
			Glyphs.draw_diamond(self, c, 4, _colour)
			Glyphs.draw_diamond(self, c, 1, Color(1, 1, 1, 0.8))
		else:
			Glyphs.draw_diamond(self, c, 4, Color("1c1218"))
			if i == _hp and _hurt > 0.0:
				Glyphs.draw_diamond(self, c, 4, Color(1, 1, 1, _hurt))
