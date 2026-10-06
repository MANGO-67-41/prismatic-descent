class_name DiverCreature
extends Creature
## Bone vulture and ember vulture: big winged hunters. They soar high above the hero on slow wingbeats, fold their wings
## and dive at where the hero was (a flash of the eye and raised wings warn first), then climb away. The ember vulture also
## spits embers while it circles. Skull mask, long neck, feathers that go from dark to the region's colour at the tips.

enum M { SOAR, TELL, DIVE, RISE }

var _m: M = M.SOAR
var _mt := 0.0
var _vel := Vector2.ZERO
var _target := Vector2.ZERO
var _shot := 1.5


func born() -> void:
	pass


func think(delta: float) -> void:
	_mt += delta * (aggr if _m == M.SOAR else 1.0)
	var hc := hero_center()
	var near := hero_near(260.0)
	var want := home + Vector2(sin(clock * 0.5) * 60.0, sin(clock * 0.9) * 10.0)
	var sp := float(spec["speed"])
	match _m:
		M.SOAR:
			if near:
				want = Vector2(hc.x + sin(clock * 0.6) * 80.0 + flank_offset(), maxf(room.position.y + 24.0, hc.y - 90.0))
				if _mt > 2.2:
					_m = M.TELL
					_mt = 0.0
				if bool(spec["shots"]):
					_shot -= delta
					if _shot <= 0.0:
						_shot = 2.4
						_spit(hc)
		M.TELL:
			want = global_position
			sp = 0.0
			_vel *= 0.9
			if _mt > 0.55:
				_target = hc
				_m = M.DIVE
				_mt = 0.0
		M.DIVE:
			_vel = (_target - global_position).normalized() * float(spec["dive"])
			global_position += _vel * delta
			if global_position.distance_to(_target) < 8.0 or _mt > 0.9:
				_m = M.RISE
				_mt = 0.0
			clamp_to_room()
			return
		M.RISE:
			want = global_position + Vector2(-facing * 40.0, -80.0)
			if _mt > 1.0:
				_m = M.SOAR
				_mt = 0.0
	var to := want - global_position
	_vel = _vel.lerp(to.normalized() * sp if to.length() > 3.0 else Vector2.ZERO, minf(1.0, delta * 2.0))
	global_position += _vel * delta
	clamp_to_room()
	if absf(_vel.x) > 5.0:
		facing = 1 if _vel.x > 0.0 else -1


func _spit(at: Vector2) -> void:
	for k in 3:
		var dir := (at - global_position).normalized().rotated((k - 1) * 0.22)
		var p := Projectile.new()
		p.setup("ember", global_position + Vector2(facing * 14.0, 10), dir * 140.0, game, spec["accent"])
		get_parent().add_child(p)


func on_stunned() -> void:
	_m = M.RISE
	_mt = 0.0


func hit_rects() -> Array[Rect2]:
	var skull := global_position + Vector2(facing * 13.0, 9.0)
	return [Rect2(global_position - Vector2(10, 8), Vector2(20, 16)), Rect2(skull - Vector2(6, 5), Vector2(12, 10))]


func stun_anchor() -> Vector2:
	return Vector2(0, -16)


func draw_body() -> void:
	var flip := facing < 0
	if stun_left > 0.0:
		art("stun", by_time("stun", 4.0), Vector2.ZERO, flip)
	elif _m == M.TELL:
		art("tell", by_time("tell", 10.0), Vector2.ZERO, flip)
	elif _m == M.DIVE:
		art("dive", by_time("dive", 8.0), Vector2.ZERO, flip)
	else:
		art("soar", by_time("soar", 5.0 if _m == M.SOAR else 9.0), Vector2.ZERO, flip)
