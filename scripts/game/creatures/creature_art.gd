class_name CreatureArt
extends RefCounted
## The creatures' sprite sheets (assets/creatures/<kind>.png with a .json atlas, made by dev/creature_art/build_all.py).
## Each sheet is rows of frames; a row has its own cell size and an origin (the feet, or the middle of the body).
## Whole-body creatures play rows as animations; long-bodied ones use rows of 16 directions for the head and body segments.

static var _cache: Dictionary = {}


static func sheet(kind: String) -> Dictionary:
	if not _cache.has(kind):
		var tex: Texture2D = load("res://assets/creatures/%s.png" % kind)
		var f := FileAccess.open("res://assets/creatures/%s.json" % kind, FileAccess.READ)
		var atlas: Dictionary = JSON.parse_string(f.get_as_text()) if f != null else {"rows": {}}
		_cache[kind] = {"tex": tex, "rows": atlas["rows"]}
	return _cache[kind]


static func count(kind: String, row: String) -> int:
	var rows: Dictionary = sheet(kind)["rows"]
	return int(rows[row]["n"]) if rows.has(row) else 1


## Draws frame `i` of `row` with its origin at `at` (local to `ci`), mirrored when `flip`.
static func draw(ci: CanvasItem, kind: String, row: String, i: int, at: Vector2, flip: bool = false, offset: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE, rot: float = 0.0) -> void:
	var s := sheet(kind)
	var rows: Dictionary = s["rows"]
	if not rows.has(row) or s["tex"] == null:
		return
	var r: Dictionary = rows[row]
	var w := float(r["w"])
	var h := float(r["h"])
	var src := Rect2(posmod(i, int(r["n"])) * w, float(r["y"]), w, h)
	ci.draw_set_transform((at + offset).floor(), rot, Vector2(-1.0 if flip else 1.0, 1.0))
	ci.draw_texture_rect_region(s["tex"], Rect2(-float(r["ox"]), -float(r["oy"]), w, h), src, tint)
	ci.draw_set_transform(Vector2.ZERO)


## Which of 16 directions a vector points in (0 = right, turning clockwise as on screen).
static func dir(v: Vector2) -> int:
	return posmod(int(round(v.angle() / (TAU / 16.0))), 16)
