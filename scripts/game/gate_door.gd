class_name GateDoor
extends Node2D
## A stone door sealed across a shaft. The four gates between regions open with that region's key; the seal above the Prismatic Lake
## opens once all five guardians have fallen. Press interact standing above it. Opened doors stay open (saved).

const REACH_X := 34.0

var door_id := ""
var need_key := -1          ## region index of the key it wants, or -1
var need_guardians := false
var width := 64.0
var game: Game
var _body: StaticBody2D
var _open := 0.0            ## 0 shut .. 1 open
var _t := 0.0
var _near := false
var _flash := 0.0


func setup(prop: Dictionary, g: Game) -> void:
	game = g
	door_id = str(prop["id"])
	need_key = int(prop.get("key", -1))
	need_guardians = str(prop.get("need", "")) == "guardians"
	width = float(prop.get("w", 64))
	position = Vector2(float(prop["x"]), float(prop["y"]))
	z_index = 3
	if bool(g.vitals.doors.get(door_id, false)):
		_open = 1.0
	else:
		_body = StaticBody2D.new()
		_body.collision_layer = 1
		_body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(width, 8)
		cs.shape = shape
		cs.position = Vector2(0, 4)
		_body.add_child(cs)
		add_child(_body)
		add_to_group("interactable")


func is_open() -> bool:
	return _open >= 1.0


func can_interact(pos: Vector2) -> bool:
	return _body != null and absf(pos.x - global_position.x) <= REACH_X and pos.y <= global_position.y + 2.0 and pos.y >= global_position.y - 48.0


func accent() -> Color:
	if need_key >= 0:
		return StoryData.COLOURS[need_key]
	return Color("a8e0f0")


func openable() -> bool:
	if need_key >= 0:
		return bool(game.vitals.items.get("key_%d" % need_key, false))
	return game.vitals.guardians.size() >= 5


func interact(g: Game) -> void:
	if not openable():
		if need_key >= 0:
			g.toast.show_message("THE GATE WANTS THE " + StoryData.key_name(need_key), StoryData.COLOURS[need_key])
		else:
			g.toast.show_message("THE SEAL HOLDS", Color("a8e0f0"), "%d OF 5 GUARDIANS STILL STAND" % (5 - g.vitals.guardians.size()))
		_flash = 0.4
		return
	g.open_door(door_id)
	remove_from_group("interactable")
	_near = false
	_flash = 1.0
	if _body != null:
		_body.queue_free()
		_body = null
	var tw := create_tween()
	tw.tween_property(self, "_open", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 1.5)
	if game != null and game.player != null and _body != null:
		_near = can_interact(game.player.global_position)
	queue_redraw()


func _draw() -> void:
	var col := accent()
	var half := width / 2.0
	var slide := _open * (half - 3.0)
	var stone := Color("4a3c44")
	var stone_hi := Color("7a6670")
	var stone_lo := Color("231a22")
	for side: int in [-1, 1]:
		var x0: float = (0.0 if side == 1 else -half) + side * slide
		var w := half
		draw_rect(Rect2(x0, 0, w, 8), stone)
		draw_rect(Rect2(x0, 0, w, 1), stone_hi)
		draw_rect(Rect2(x0, 7, w, 1), stone_lo)
		draw_rect(Rect2(x0, 0, 1, 8), stone_lo)
		draw_rect(Rect2(x0 + w - 1, 0, 1, 8), stone_lo)
		for k in range(6, int(w) - 4, 10):    # carved lozenges
			Glyphs.draw_diamond(self, Vector2(x0 + k, 4), 1, Color(col, 0.7))
	# two lamp posts at the ends of the door, lit in the gate's colour
	for side: int in [-1, 1]:
		var px: float = side * (half - 4.0) - 3.0
		draw_rect(Rect2(px, -14, 6, 14), stone)
		draw_rect(Rect2(px, -14, 1, 14), stone_hi)
		draw_rect(Rect2(px - 1, -16, 8, 3), stone_hi)
		draw_rect(Rect2(px + 1, -11, 4, 4), UITheme.INK)
		draw_rect(Rect2(px + 2, -10, 2, 2), Color(col, 0.7 + 0.3 * sin(_t * 3.0 + side)))
	# the lock: a crystal pendant hanging under the door, which wakes up when the way is open to the hero
	var wake := 0.5 + 0.5 * sin(_t * 3.0) if (game != null and openable() and _open < 1.0) else 0.0
	if _open < 0.9:
		var fade := 1.0 - _open
		draw_rect(Rect2(-1, 8, 2, 5), Color(stone_lo, fade))
		var c := Vector2(0, 20)
		Glyphs.draw_diamond(self, c, 12, Color(col, (0.06 + 0.1 * wake + _flash * 0.2) * fade))
		Glyphs.draw_diamond(self, c, 8, Color(UITheme.INK, fade))
		Glyphs.draw_diamond(self, c, 7, Color(col, (0.55 + 0.35 * wake + _flash * 0.4) * fade))
		Glyphs.draw_diamond(self, c, 4, Color(col.lightened(0.4), fade))
		Glyphs.draw_diamond(self, c, 1, Color(1, 1, 1, (0.6 + 0.4 * wake) * fade))
		draw_rect(Rect2(-5, 4, 10, 1), Color(col, 0.5 * fade))
	if _flash > 0.0:
		draw_rect(Rect2(-half, -2, width, 12), Color(col, 0.25 * _flash))
	if _near:
		Prompt.draw(self, Vector2(0, -30), "OPEN" if openable() else "LOCKED")
