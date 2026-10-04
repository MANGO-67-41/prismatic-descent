class_name WorldData
extends RefCounted
## The fixed world, baked by dev/world_bake.py into data/world_runtime.json: five regions, 50 rooms and the 49 shafts between
## them, stitched into one tall world (x and y in pixels, 8 px tiles). Rooms are never generated at runtime.

const PATH := "res://data/world_runtime.json"
const TILE := 8
const MAP_SCALE := 16  ## one pixel of the map picture covers 2x2 tiles

static var loaded := false
static var pieces: Array = []
static var regions: Array = []
static var size := Vector2.ZERO


static func ensure_loaded() -> void:
	if loaded:
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("World data missing: " + PATH)
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	pieces = data["pieces"]
	regions = data["regions"]
	size = Vector2(float(data["width"]), float(data["height"]))
	loaded = true


static func rect(i: int) -> Rect2:
	var p: Dictionary = pieces[i]
	return Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"]))


## Index of the piece holding `pos`, searching outward from `hint` (the last known piece). -1 when outside the world.
static func piece_at(pos: Vector2, hint: int = 0) -> int:
	if pieces.is_empty():
		return -1
	hint = clampi(hint, 0, pieces.size() - 1)
	for d in pieces.size():
		for i in [hint - d, hint + d]:
			if i >= 0 and i < pieces.size() and rect(i).has_point(pos):
				return i
	return -1


static func region_name(i: int) -> String:
	return str(regions[clampi(i, 0, regions.size() - 1)]["name"])
