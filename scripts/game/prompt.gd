class_name Prompt
extends RefCounted
## The small "[E] READ" tag that floats above something the hero can use.


static func draw(ci: CanvasItem, at: Vector2, label: String, action: String = "interact") -> void:
	var font := UITheme.font(false, 1)
	var key := KeyBindings.key_name(action) if KeyBindings.keys.has(action) else "E"
	var key_w := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var w := key_w + (label_w + 6.0 if label != "" else 0.0)
	var rect := Rect2((at - Vector2(w / 2.0 + 4.0, 0.0)).floor(), Vector2(w + 8.0, 14.0))
	ci.draw_rect(rect.grow(1.0), UITheme.INK)
	ci.draw_rect(rect, Color(0.08, 0.05, 0.1, 0.94))
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), UITheme.RUST)
	ci.draw_string(font, rect.position + Vector2(4.0, 11.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.CREAM)
	if label != "":
		ci.draw_string(font, rect.position + Vector2(4.0 + key_w + 6.0, 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.CREAM_DIM)
