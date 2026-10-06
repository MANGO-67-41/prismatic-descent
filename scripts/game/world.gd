class_name World
extends Node2D
## Streams the world in around a focus point: only pieces near the hero exist as nodes (art + collision), the rest are freed.
## Pieces are baked art (one PNG per room or shaft) plus rectangles of solid tiles for collision.

const KEEP_X := 640.0
const KEEP_Y := 520.0
const BEAM_H := 4  ## thickness in pixels of beam platforms (BEAM_H in dev/overgrowth_art.py)

var game: Game  ## set by the game: the props (scrolls, keys, gates, guardians) talk to it
var _nodes: Dictionary = {}  ## piece id -> Node2D
var _ropes: Dictionary = {}  ## piece id -> Array of {x, top, bottom} in world pixels
var _shapes: Dictionary = {}  ## "wxh" -> RectangleShape2D, shared
var _last_focus := Vector2(-99999, -99999)
var broken: Dictionary = {}  ## "piece:x:y" -> true for cracked floor tiles already smashed (saved with the profile)
var _crack_bodies: Dictionary = {}  ## piece id -> {"x:y": CollisionShape2D}


func update_focus(focus: Vector2, force: bool = false) -> void:
	if not force and focus.distance_squared_to(_last_focus) < 64.0 * 64.0:
		return
	_last_focus = focus
	var view := Rect2(focus - Vector2(KEEP_X, KEEP_Y), Vector2(KEEP_X, KEEP_Y) * 2.0)
	for i in WorldData.pieces.size():
		var near := WorldData.rect(i).intersects(view)
		if near and not _nodes.has(i):
			_build(i)
		elif not near and _nodes.has(i):
			(_nodes[i] as Node2D).queue_free()
			_nodes.erase(i)
			_ropes.erase(i)
			_crack_bodies.erase(i)


func _shape(w: int, h: int) -> RectangleShape2D:
	var key := "%dx%d" % [w, h]
	if not _shapes.has(key):
		var shape := RectangleShape2D.new()
		shape.size = Vector2(w, h)
		_shapes[key] = shape
	return _shapes[key]


## A ground pound landed at `feet`: smash every cracked tile under it (and the rest of that crack). Returns how many broke.
func break_cracks_at(feet: Vector2) -> int:
	var count := 0
	for i in _crack_bodies.keys():
		var p: Dictionary = WorldData.pieces[i]
		var local := feet - Vector2(float(p["x"]), float(p["y"]))
		var tx := int(floor(local.x / WorldData.TILE))
		var ty := int(floor((local.y + 2.0) / WorldData.TILE))
		var entry: Dictionary = _crack_bodies[i]
		var shapes: Dictionary = entry["shapes"]
		var hit := false
		for dx in [-1, 0, 1]:
			if shapes.has("%d:%d" % [tx + dx, ty]):
				hit = true
		if not hit:
			continue
		for key in shapes.keys():       # the whole crack goes at once
			var parts: PackedStringArray = (key as String).split(":")
			if absi(int(parts[1]) - ty) <= 1:
				(shapes[key] as CollisionShape2D).queue_free()
				shapes.erase(key)
				broken["%d:%s" % [i, key]] = true
				(entry["holes"] as HoleMask).cells.append(Vector2i(int(parts[0]), int(parts[1])))
				count += 1
		(entry["holes"] as HoleMask).queue_redraw()
	return count


## The rope or vine within reach of `point` (world pixels), or {} when there is none: {x, top, bottom}.
func rope_at(point: Vector2) -> Dictionary:
	for list in _ropes.values():
		for r in list:
			if absf(point.x - float(r["x"])) <= 6.0 and point.y >= float(r["top"]) - 4.0 and point.y <= float(r["bottom"]) + 4.0:
				return r
	return {}


func loaded_count() -> int:
	return _nodes.size()


func _build(i: int) -> void:
	var p: Dictionary = WorldData.pieces[i]
	var node := Node2D.new()
	node.name = "Piece%03d" % i
	node.position = Vector2(float(p["x"]), float(p["y"]))
	var sprite := Sprite2D.new()
	sprite.texture = load(str(p["art"]))
	sprite.centered = false
	node.add_child(sprite)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for r in p["rects"]:
		var w := int(r[2]) * WorldData.TILE
		var h := int(r[3]) * WorldData.TILE
		var key := "%dx%d" % [w, h]
		if not _shapes.has(key):
			var shape := RectangleShape2D.new()
			shape.size = Vector2(w, h)
			_shapes[key] = shape
		var cs := CollisionShape2D.new()
		cs.shape = _shapes[key]
		cs.position = Vector2(int(r[0]) * WorldData.TILE + w / 2.0, int(r[1]) * WorldData.TILE + h / 2.0)
		body.add_child(cs)
	for b in p.get("beams", []):  # thin bars sprouting from walls: only the top BEAM_H pixels of the tile are solid
		var bw := int(b[2]) * WorldData.TILE
		var bkey := "%dx%d" % [bw, BEAM_H]
		if not _shapes.has(bkey):
			var bshape := RectangleShape2D.new()
			bshape.size = Vector2(bw, BEAM_H)
			_shapes[bkey] = bshape
		var bcs := CollisionShape2D.new()
		bcs.shape = _shapes[bkey]
		bcs.position = Vector2(int(b[0]) * WorldData.TILE + bw / 2.0, int(b[1]) * WorldData.TILE + BEAM_H / 2.0)
		body.add_child(bcs)
	if bool(p["first"]):  # the very first room is open to the sky: keep the hero from leaving through the top
		var lid := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = Vector2(float(p["w"]), 16)
		lid.shape = s
		lid.position = Vector2(float(p["w"]) / 2.0, -8)
		body.add_child(lid)
	node.add_child(body)
	# cracked floor: solid until a ground pound lands on it
	var cracks: Dictionary = {}
	var crack_body := StaticBody2D.new()
	crack_body.collision_layer = 1
	crack_body.collision_mask = 0
	var holes := HoleMask.new()
	for c in p.get("cracks", []):
		var key := "%d:%d" % [int(c[0]), int(c[1])]
		if broken.has("%d:%s" % [i, key]):
			holes.cells.append(Vector2i(int(c[0]), int(c[1])))
			continue
		var cs2 := CollisionShape2D.new()
		cs2.shape = _shape(WorldData.TILE, WorldData.TILE)
		cs2.position = Vector2(int(c[0]) * WorldData.TILE + 4, int(c[1]) * WorldData.TILE + 4)
		crack_body.add_child(cs2)
		cracks[key] = cs2
	node.add_child(crack_body)
	node.add_child(holes)
	_crack_bodies[i] = {"shapes": cracks, "holes": holes}
	var list: Array = []
	for rp in p.get("ropes", []):
		var rope := Rope.new()
		rope.setup(float(rp[0]), float(rp[1]), float(rp[2]), str(rp[3]), str(p["theme"]) if p.has("theme") else "")
		node.add_child(rope)
		list.append({"x": node.position.x + float(rp[0]), "top": node.position.y + float(rp[1]), "bottom": node.position.y + float(rp[1]) + float(rp[2])})
	_ropes[i] = list
	for rest in p["rest"]:
		var mark := RestMark.new()
		mark.position = Vector2(float(rest[0]), float(rest[1]))
		node.add_child(mark)
	if game != null:
		for prop in p.get("props", []):
			var made := _make_prop(prop, i, node.position)
			if made != null:
				node.add_child(made)
		for c in p.get("creatures", []):     # rebuilt with the room: killed creatures are back next time
			var cr := CreatureTypes.make(str(c["t"]))
			cr.piece_id = i
			cr.setup(c, game, WorldData.rect(i))
			node.add_child(cr)
	add_child(node)
	_nodes[i] = node


func _make_prop(prop: Dictionary, id: int, origin: Vector2) -> Node2D:
	match str(prop["t"]):
		"scroll":
			var ped := Pedestal.new()
			ped.setup(prop, game)
			return ped
		"key":
			var altar := KeyAltar.new()
			altar.setup(prop, game)
			return altar
		"door":
			var door := GateDoor.new()
			door.setup(prop, game)
			return door
		"guardian":
			var guardian := Guardian.new()
			guardian.setup(prop, game, origin, id)
			return guardian
	return null


## Paints over smashed cracked tiles so the hole shows (the baked art still has the floor there).
class HoleMask extends Node2D:
	var cells: Array[Vector2i] = []

	func _draw() -> void:
		for c in cells:
			draw_rect(Rect2(c.x * 8, c.y * 8, 8, 8), Color("0c0910"))
			draw_rect(Rect2(c.x * 8, c.y * 8, 8, 1), Color("2a1a18"))


## A bench-like glow where the hero can rest (E): a cream diamond that breathes.
class RestMark extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var glow := 0.55 + 0.45 * sin(_t * 2.4)
		draw_rect(Rect2(-9, -3, 18, 3), Color("5a2a22"))
		draw_rect(Rect2(-9, -4, 18, 1), Color("a8512d"))
		Glyphs.draw_diamond(self, Vector2(0, -12), 4, Color(UITheme.CREAM, 0.55 + 0.45 * glow))
		Glyphs.draw_diamond(self, Vector2(0, -12), 2, Color(1, 1, 1, glow))


## A climbable rope (or vine in the Overgrowth) hanging from a ceiling or platform. It sways a little; logic ignores the sway.
class Rope extends Node2D:
	var _x := 0.0
	var _top := 0.0
	var _len := 0.0
	var _vine := false
	var _t := 0.0
	var _phase := 0.0

	func setup(x: float, top: float, length: float, kind: String, _theme: String) -> void:
		_x = x
		_top = top
		_len = length
		_vine = kind == "vine"
		_phase = x * 0.13
		z_index = 5

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var core := Color("2a3a20") if _vine else Color("7a5a3a")
		var hi := Color("6b7a3c") if _vine else Color("c4a070")
		var steps := int(_len / 2.0)
		for i in steps:
			var y := _top + i * 2.0
			var sway := roundf(sin(_t * 1.1 + _phase + i * 0.05) * 1.2 * (float(i) / maxf(steps, 1.0)))
			draw_rect(Rect2(_x + sway - 1, y, 2, 2), core)
			draw_rect(Rect2(_x + sway - 1, y, 1, 2), hi if (i % 6) < 3 else core)
			if _vine and i % 7 == 3:
				draw_rect(Rect2(_x + sway + (2 if i % 14 == 3 else -3), y, 2, 1), hi)
			elif not _vine and i % 8 == 0:
				draw_rect(Rect2(_x + sway - 2, y, 4, 1), Color("3a2418"))
		draw_rect(Rect2(_x - 2, _top - 1, 4, 3), Color("120d14"))
		draw_rect(Rect2(_x - 1, _top, 2, 1), hi)
