class_name BurrowerCreature
extends Creature
## Marrow worm: lives under the floor of the Bone Stacks. Dust and cracks show where it will come up, near the hero; then it
## bursts out in a high arc and dives back into the floor further on, its long dark body following, fronds of blue streaming
## off it and a head of old grey plates and blue lights. It cannot be killed: dodge it, or stun it and it sinks.

enum M { HIDDEN, TELL, ARC, SINK }

var _m: M = M.HIDDEN
var _mt := 0.0
var _wait := 2.0
var _floor := 0.0
var _x0 := 0.0
var _dir := 1
var _body := PackedVector2Array()


func born() -> void:
	_floor = global_position.y
	_body = line_of(Vector2(global_position.x, _floor + 30.0), Vector2(0, 1), 16, 6.5)


func think(delta: float) -> void:
	_mt += delta
	var hc := hero_center()
	match _m:
		M.HIDDEN:
			_wait -= delta * aggr
			if _wait <= 0.0 and hero_near(320.0) and absf(hc.y - _floor) < 60.0:
				_dir = 1 if randf() < 0.5 else -1
				_x0 = clampf(hc.x - _dir * 55.0, room.position.x + 10.0, room.end.x - 10.0)
				if (_dir > 0 and _x0 + 110.0 > room.end.x) or (_dir < 0 and _x0 - 110.0 < room.position.x):
					_dir = -_dir
					_x0 = clampf(hc.x - _dir * 55.0, room.position.x + 10.0, room.end.x - 10.0)
				_m = M.TELL
				_mt = 0.0
		M.TELL:
			if int(_mt * 20.0) % 2 == 0:
				burst(Vector2(_x0 + randf_range(-8, 8), _floor - 1.0), 1, 40.0)
			if _mt > 0.85:
				_m = M.ARC
				_mt = 0.0
				game.cam.shake(1.5) if game != null else null
		M.ARC:
			var t := _mt / 1.15
			global_position = Vector2(_x0 + _dir * 130.0 * t, _floor - sin(t * PI) * 92.0 + 12.0)
			if t >= 1.0:
				_m = M.SINK
				_mt = 0.0
		M.SINK:
			global_position += Vector2(_dir * 30.0, 120.0) * delta
			if _mt > 1.0:
				_m = M.HIDDEN
				_wait = randf_range(1.8, 3.2)
				global_position = Vector2(_x0, _floor + 30.0)


func on_stunned() -> void:
	if _m == M.ARC:
		_m = M.SINK
		_mt = 0.0


func stunned_move(delta: float) -> void:
	global_position += Vector2(0, 90.0) * delta


func _physics_process(delta: float) -> void:
	super(delta)
	_body = follow(_body, global_position, 6.5, 0.0, delta)


func harmful() -> bool:
	return _m == M.ARC or _m == M.SINK


func hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _m == M.HIDDEN or _m == M.TELL:
		return out
	for i in range(0, _body.size(), 2):
		if _body[i].y < _floor - 2.0:
			out.append(Rect2(_body[i] - Vector2(8, 8), Vector2(16, 16)))
	return out


func stun_anchor() -> Vector2:
	return Vector2(0, -12)


func draw_body() -> void:
	var body: Color = spec["body"]
	var accent: Color = spec["accent"]
	var fl := _floor - global_position.y
	if _m == M.TELL:
		var x := _x0 - global_position.x
		for k in 7:
			var dx := (k - 3) * 4.0
			draw_rect(Rect2(Vector2(x + dx, fl - 1 - absf(sin(clock * 20.0 + k)) * 3.0).floor(), Vector2(2, 2)), Color("8a8a7a"))
		return
	if _m == M.HIDDEN:
		return
	var vis := PackedVector2Array()
	for p in _body:
		if p.y <= _floor + 4.0:
			vis.append(p)
		else:
			break
	if vis.size() < 2:
		return
	# fronds: long feather-like streamers off the body, dark to blue, waving (drawn behind it)
	for i in range(2, vis.size(), 2):
		var back := (vis[i] - vis[i - 1]).normalized()
		var side := Vector2(-back.y, back.x)
		var w := sin(clock * 5.0 + i * 0.9) * 4.0
		for s: float in [-1.0, 1.0]:
			var root := local(vis[i]) + side * s * 4.0
			var tip := root + back * (16.0 - i * 0.4) + side * s * (8.0 + w * s)
			var mid := root.lerp(tip, 0.5) + side * s * 2.0
			CDraw.feather(self, root + wob, mid + wob, body, accent.darkened(0.3))
			CDraw.feather(self, mid + wob, tip + wob, accent.darkened(0.3), accent)
	var rows := ["seg_l", "seg_l", "seg_l", "seg_l", "seg_l", "seg_m", "seg_m", "seg_m", "seg_m", "seg_s", "seg_s", "seg_s", "seg_s", "seg_s", "seg_s"]
	draw_chain(vis, rows, _m == M.ARC and _mt > 0.3 and _mt < 0.8)
	for k in 4:   # earth breaking where it leaves or enters the floor
		draw_rect(Rect2(Vector2(_x0 - global_position.x + (k - 1.5) * 5.0, fl - 2.0).floor(), Vector2(2, 2)), Color("6a6a5a"))
