class_name UpgradeCeremony
extends Control
## The banner shown when the hero is given a region's ability: the ability's badge, NEW ABILITY, its name, what it does
## and which key uses it. The game drives `banner` (0..1) with a tween while the hero ascends in a beam of light.

const HINTS := {
	"pound": "IN THE AIR, PRESS %s",
	"double_jump": "IN THE AIR, PRESS %s AGAIN",
	"dash_iframes": "PRESS %s: NOTHING CAN TOUCH YOU MID-DASH",
	"fast_heal": "HOLD %s WITH A FULL CIRCLE TO HEAL IN A HEARTBEAT",
}
const HINT_KEYS := {"pound": "pound", "double_jump": "jump", "dash_iframes": "dash", "fast_heal": "eat"}

var banner := 0.0:
	set(v):
		banner = v
		visible = v > 0.001
		queue_redraw()
var ability := ""
var _hint := ""
var y_shift := 0.0  ## moves the banner down when the hero is in the top half of the screen
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func show_for(id: String, hero_screen_y: float = 200.0) -> void:
	ability = id
	y_shift = 118.0 if hero_screen_y < 150.0 else 0.0
	_hint = (HINTS[id] as String) % KeyBindings.key_name(HINT_KEYS[id])
	banner = 0.0


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if ability == "":
		return
	var a := banner
	draw_set_transform(Vector2(0, y_shift), 0.0, Vector2.ONE)
	# a dark band behind the text, fading at its edges
	for i in 40:
		var edge := minf(i, 39 - i) / 8.0
		draw_rect(Rect2(0, 22 + i * 3, 480, 3), Color(0.03, 0.02, 0.05, 0.78 * a * clampf(edge, 0.0, 1.0)))
	# badge, twice size, with a slowly turning prismatic ring
	var centre := Vector2(240, 46)
	for k in 24:
		var ang := k * TAU / 24.0 + _t * 0.6
		var col := Color.from_hsv(fmod(0.48 + k / 24.0 * 0.3, 1.0), 0.45, 1.0, a * (0.4 + 0.6 * float(k % 2)))
		draw_rect(Rect2(centre + Vector2(cos(ang), sin(ang)) * 20.0 - Vector2(1, 1), Vector2(2, 2)), col)
	draw_set_transform(centre + Vector2(0, y_shift), 0.0, Vector2(2, 2))
	Glyphs.draw_ability(self, ability, Vector2.ZERO, true, false)
	draw_set_transform(Vector2(0, y_shift), 0.0, Vector2.ONE)
	var text: Array = InventoryScreen.ABILITY_TEXT[ability]
	var small := UITheme.font(false, 1)
	var big := UITheme.font(false, 3)
	_centered(small, "NEW ABILITY", 80, 12, Color(UITheme.CREAM_DIM, a))
	_centered(big, str(text[0]), 100, 20, Color(UITheme.CREAM, a), 2)
	Glyphs.draw_divider(self, 240, 106, 70, false)
	_centered(small, str(text[1]), 122, 12, Color(UITheme.CREAM, a))
	_centered(small, _hint, 140, 12, Color(UITheme.RUST.lightened(0.25), a))


func _centered(font: Font, text: String, y: float, size: int, colour: Color, outline: int = 1) -> void:
	draw_string_outline(font, Vector2(20, y), text, HORIZONTAL_ALIGNMENT_CENTER, 440, size, outline * 2, Color(UITheme.INK, colour.a))
	draw_string(font, Vector2(20, y), text, HORIZONTAL_ALIGNMENT_CENTER, 440, size, colour)
