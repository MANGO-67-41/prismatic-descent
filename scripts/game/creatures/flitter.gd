class_name FlitterCreature
extends Creature
## Carrion kite: a hooked skull on torn leather wings. It hangs over the hero, then folds its wings and swoops straight
## through them (its wings flare and its beak opens first), and climbs back up to wait.

var _vel := Vector2.ZERO
var _swoop := 0.0
var _tell := 0.0
var _next := 2.0
var _target := Vector2.ZERO
func think(delta: float) -> void:
	var sp := float(spec["speed"])
	var hc := hero_center()
	var near := hero_near(float(spec["reach"]))
	var want := home + Vector2(sin(clock * 0.7) * 30.0, sin(clock * 1.3) * 12.0)
	_next -= delta * aggr
	if _swoop > 0.0:
		_swoop -= delta
		want = _target
		sp = 200.0
	elif _tell > 0.0:
		_tell -= delta
		sp = 8.0
		if _tell <= 0.0:
			_swoop = 0.7
			_target = hc + (hc - global_position).normalized() * 50.0
	elif near:
		want = hc + Vector2(sin(clock * 0.8) * 50.0 + flank_offset(), -70.0)
		if _next <= 0.0:
			_next = 2.4
			_tell = 0.5
	var to := want - global_position
	var dir := to.normalized() if to.length() > 2.0 else Vector2.ZERO
	_vel = _vel.lerp(dir * sp, minf(1.0, delta * 3.0))
	global_position += _vel * delta
	clamp_to_room()
	if absf(_vel.x) > 4.0:
		facing = 1 if _vel.x > 0.0 else -1


func hit_rects() -> Array[Rect2]:
	return [Rect2(global_position - Vector2(8, 6), Vector2(16, 14)), Rect2(global_position + Vector2(facing * 8.0 - 6.0, -2), Vector2(12, 9))]


func stunned_move(delta: float) -> void:
	_swoop = 0.0
	_tell = 0.0
	super(delta)


func stun_anchor() -> Vector2:
	return Vector2(0, -10)


func draw_body() -> void:
	var flip := facing < 0
	if stun_left > 0.0:
		art("stun", by_time("stun", 4.0), Vector2.ZERO, flip)
	elif _swoop > 0.0:
		art("swoop", by_time("swoop", 10.0), Vector2.ZERO, flip)
	elif _tell > 0.0:
		art("tell", by_time("tell", 12.0), Vector2.ZERO, flip)
	else:
		art("flap", by_time("flap", 10.0), Vector2.ZERO, flip)
