class_name Projectile
extends Node2D
## Something thrown or spat at the hero: a bone spear (arcs) or an ember (straight). Breaks on the world or on the hero.

var kind := "spear"
var vel := Vector2.ZERO
var gravity := 0.0
var game: Game
var colour := Color.WHITE
var _life := 3.0
var _trail: Array[Vector2] = []


func setup(k: String, at: Vector2, v: Vector2, g: Game, c: Color) -> void:
	kind = k
	vel = v
	game = g
	colour = c
	top_level = true
	global_position = at
	z_index = 7


func _physics_process(delta: float) -> void:
	_life -= delta
	var from := global_position
	vel.y += gravity * delta
	var to := from + vel * delta
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() or _life <= 0.0:
		queue_free()
		return
	global_position = to
	_trail.push_front(to)
	if _trail.size() > 5:
		_trail.pop_back()
	if game != null and game.player != null and not game.dying:
		var h := game.player
		if Rect2(h.global_position - Vector2(5, 14), Vector2(10, 14)).has_point(to):
			h.take_hit(from.x)
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	if kind == "spear":
		var d := vel.normalized()
		CDraw.line(self, -d * 8.0, d * 4.0, UITheme.INK, 2.0)
		CDraw.line(self, -d * 8.0, d * 4.0, colour)
		draw_rect(Rect2((d * 4.0).floor(), Vector2(2, 1)), Color.WHITE)
	else:
		for i in _trail.size():
			draw_rect(Rect2((_trail[i] - global_position).floor(), Vector2(2, 2)), Color(colour, 0.5 - i * 0.1))
		CDraw.glow(self, Vector2.ZERO, 3.5, colour, 0.8)
		draw_rect(Rect2(-1, -1, 2, 2), Color("fff0c0"))
