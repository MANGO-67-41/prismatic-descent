class_name KeyAltar
extends Node2D
## A small altar with a region's key floating over it. Walk into the key to take it.

var game: Game
var region := 0
var key_id := ""
var _t := 0.0
var _taken := false


func setup(prop: Dictionary, g: Game) -> void:
	game = g
	region = int(prop["region"])
	key_id = str(prop["id"])
	position = Vector2(float(prop["x"]), float(prop["y"]))
	z_index = 4
	_taken = bool(g.vitals.items.get(key_id, false))


func _process(delta: float) -> void:
	_t += delta
	if not _taken and game != null and game.player != null:
		var d := game.player.global_position + Vector2(0, -7) - (global_position + Vector2(0, -20))
		if absf(d.x) < 12.0 and absf(d.y) < 16.0 and not game.in_ceremony:
			_taken = true
			game.collect_key(region)
	queue_redraw()


func _draw() -> void:
	var colour: Color = StoryData.COLOURS[region]
	var stone := Color("6e5e56")
	draw_rect(Rect2(-9, -3, 18, 3), Color("3c302e"))
	draw_rect(Rect2(-7, -9, 14, 6), stone)
	draw_rect(Rect2(-7, -9, 14, 1), Color("a8957c"))
	draw_rect(Rect2(-9, -11, 18, 2), Color("8c7a68"))
	# a pillar of faint light rising from the altar
	for i in 5:
		draw_rect(Rect2(-2 - i, -11 - i * 5, 4 + i * 2, 1), Color(colour, 0.22 - i * 0.04))
	if not _taken:
		var bob := roundf(sin(_t * 2.2) * 2.0)
		Glyphs.draw_key(self, Vector2(0, -21 + bob), colour, 1, 0.6 + 0.4 * sin(_t * 3.0))
	else:
		Glyphs.draw_diamond(self, Vector2(0, -15), 2, Color(UITheme.CREAM_DIM, 0.4))
