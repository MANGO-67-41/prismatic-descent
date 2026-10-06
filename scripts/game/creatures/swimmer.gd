class_name SwimmerCreature
extends Creature
## Tide leviathan: a great eyeless eel of the flooded floors of the Drowned Works (between the water's surface and the floor), armoured
## skull, a line of cold lights down its flank, a jaw of long teeth. It cruises in slow curves; when the hero wades into its
## reach it lunges, a burst of bubbles behind, then glides on. It cannot be killed.

var top := 0.0       ## the water's surface (world y)
var bottom := 0.0
var _vel := Vector2.ZERO
var _dart := 0.0
var _cool := 1.0
var _body := PackedVector2Array()
var _bubbles: Array[Dictionary] = []


func setup(entry: Dictionary, g: Game, piece_rect: Rect2) -> void:
	super(entry, g, piece_rect)
	top = piece_rect.position.y + float(entry.get("wy", entry["y"] - 20))
	bottom = piece_rect.position.y + float(entry.get("fy", entry["y"] + 20)) - 4.0


func born() -> void:
	_body = line_of(global_position, Vector2(-facing, 0), 12, 6.0)


func think(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta * aggr)
	var hc := hero_center()
	var in_water := hc != Vector2.INF and hc.y > top - 4.0
	if _dart > 0.0:
		_dart -= delta
		if int(_dart * 30.0) % 3 == 0:
			_bubbles.append({"p": global_position - _vel.normalized() * 8.0, "life": 0.6})
	elif _cool <= 0.0 and in_water and hero_near(150.0):
		_vel = (hc - global_position).normalized() * float(spec["dart"])
		_dart = 0.5
		_cool = 1.8
	else:
		var want := Vector2(home.x + sin(clock * 0.4) * 70.0, lerpf(top + 6.0, bottom, 0.5 + 0.4 * sin(clock * 0.9)))
		_vel = _vel.lerp((want - global_position).normalized() * float(spec["speed"]), minf(1.0, delta * 1.5))
	global_position += _vel * delta
	global_position.y = clampf(global_position.y, top + 8.0, bottom - 4.0)
	global_position.x = clampf(global_position.x, room.position.x, room.end.x)
	if absf(_vel.x) > 3.0:
		facing = 1 if _vel.x > 0.0 else -1


func _physics_process(delta: float) -> void:
	super(delta)
	_body = follow(_body, global_position, 6.0, 0.0, delta)
	for i in range(1, _body.size()):
		_body[i].y += sin(clock * 6.0 - i * 0.8) * 0.25
	for b in _bubbles.duplicate():
		b["life"] = float(b["life"]) - delta
		b["p"] = (b["p"] as Vector2) + Vector2(0, -20.0 * delta)
		if float(b["life"]) <= 0.0 or (b["p"] as Vector2).y < top:
			_bubbles.erase(b)


func hit_rects() -> Array[Rect2]:
	return [Rect2(global_position - Vector2(10, 8), Vector2(20, 15)), Rect2(_body[3] - Vector2(7, 6), Vector2(14, 12)), Rect2(_body[6] - Vector2(5, 5), Vector2(10, 10))]


func stunned_move(delta: float) -> void:
	_dart = 0.0
	_vel *= 0.9
	global_position += _vel * delta


func stun_anchor() -> Vector2:
	return Vector2(0, -8)


func draw_body() -> void:
	var accent: Color = spec["accent"]
	for b in _bubbles:
		draw_rect(Rect2(local(b["p"]).floor(), Vector2(1, 1)), Color(accent, float(b["life"])))
	# a ragged tail fin, then the body from the sheet
	var n := _body.size()
	var tail := local(_body[n - 1])
	var back := (_body[n - 1] - _body[n - 2]).normalized()
	var side := Vector2(-back.y, back.x)
	for s: float in [-1.0, 1.0]:
		CDraw.feather(self, tail + wob, tail + wob + back * 8.0 + side * s * 5.0, Color("16222c"), Color(accent, 0.8))
	draw_chain(_body, ["seg_l", "seg_l", "seg_l", "seg_m", "seg_m", "seg_m", "seg_m", "seg_s", "seg_s", "seg_s", "seg_s"], _dart > 0.0)
