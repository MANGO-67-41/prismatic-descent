class_name Pedestal
extends Node2D
## A stone pedestal with a scroll on it. Stand beside it and press interact to read. The scroll glows until it has been read.

const REACH_X := 22.0
const REACH_Y := 20.0

var scroll_id := ""
var game: Game
var _t := 0.0
var _near := false


func setup(prop: Dictionary, g: Game) -> void:
	scroll_id = str(prop["id"])
	game = g
	position = Vector2(float(prop["x"]), float(prop["y"]))
	z_index = 4
	add_to_group("interactable")


func can_interact(pos: Vector2) -> bool:
	return absf(pos.x - global_position.x) <= REACH_X and pos.y <= global_position.y + 3.0 and pos.y >= global_position.y - REACH_Y


func interact(g: Game) -> void:
	g.read_scroll(scroll_id)


func _process(delta: float) -> void:
	_t += delta
	if game != null and game.player != null:
		_near = can_interact(game.player.global_position)
	queue_redraw()


func _draw() -> void:
	var read: bool = game != null and bool(game.vitals.read_scrolls.get(scroll_id, false))
	var stone := Color("6e5e56")
	var stone_hi := Color("a8957c")
	var stone_lo := Color("3c302e")
	draw_rect(Rect2(-8, -4, 16, 4), stone_lo)
	draw_rect(Rect2(-8, -4, 16, 1), stone)
	draw_rect(Rect2(-5, -12, 10, 8), stone)
	draw_rect(Rect2(-5, -12, 1, 8), stone_hi)
	draw_rect(Rect2(3, -12, 2, 8), stone_lo)
	draw_rect(Rect2(-8, -15, 16, 3), stone_hi)
	draw_rect(Rect2(-8, -13, 16, 1), stone_lo)
	# the scroll: a cream roll with rust bands lying across the slab
	draw_rect(Rect2(-6, -19, 12, 4), UITheme.INK)
	draw_rect(Rect2(-5, -18, 10, 2), Color("f2dcae"))
	draw_rect(Rect2(-5, -17, 10, 1), Color("d9b27a"))
	draw_rect(Rect2(-6, -19, 2, 4), Color("a8512d"))
	draw_rect(Rect2(4, -19, 2, 4), Color("a8512d"))
	if not read:
		var bob := roundf(sin(_t * 2.6) * 1.5)
		var glow := 0.55 + 0.45 * sin(_t * 3.0)
		Glyphs.draw_diamond(self, Vector2(0, -27 + bob), 3, Color(UITheme.CREAM, 0.35 + 0.3 * glow))
		Glyphs.draw_diamond(self, Vector2(0, -27 + bob), 1, Color(1, 1, 1, glow))
	if _near:
		Prompt.draw(self, Vector2(0, -34), "READ")
