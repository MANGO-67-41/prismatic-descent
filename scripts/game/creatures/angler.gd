class_name AnglerCreature
extends Creature
## Lure angler: a swollen black fish waiting in the flooded floors of the Drowned Works, a light dangling on a stalk in front of
## a jaw of crooked needles. It hangs still, the lure swaying; when the hero comes within reach of the water it lunges with
## its jaw wide, then drifts back to its spot.

var top := 0.0
var bottom := 0.0
var _vel := Vector2.ZERO
var _lunge := 0.0
var _cool := 0.5


func setup(entry: Dictionary, g: Game, piece_rect: Rect2) -> void:
	super(entry, g, piece_rect)
	top = piece_rect.position.y + float(entry.get("wy", entry["y"] - 20))
	bottom = piece_rect.position.y + float(entry.get("fy", entry["y"] + 20)) - 6.0


func think(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta * aggr)
	var hc := hero_center()
	if _lunge > 0.0:
		_lunge -= delta
	elif _cool <= 0.0 and hero_near(90.0) and hc.y > top - 10.0:
		_vel = (hc - global_position).normalized() * float(spec["lunge"])
		_lunge = 0.4
		_cool = 1.8
		facing = 1 if hc.x > global_position.x else -1
	else:
		var want := home + Vector2(sin(clock * 0.3) * 10.0, sin(clock * 0.7) * 3.0)
		_vel = _vel.lerp((want - global_position) * 1.2, minf(1.0, delta * 2.0))
		if hc != Vector2.INF and hero_near(200.0):
			facing = 1 if hc.x > global_position.x else -1
	global_position += _vel * delta
	global_position.y = clampf(global_position.y, top + 10.0, bottom)
	global_position.x = clampf(global_position.x, room.position.x, room.end.x)


func stunned_move(delta: float) -> void:
	_lunge = 0.0
	_vel *= 0.9
	global_position += _vel * delta


func hit_rects() -> Array[Rect2]:
	return [Rect2(global_position - Vector2(14, 10), Vector2(28, 20))]


func stun_anchor() -> Vector2:
	return Vector2(0, -20)


func draw_body() -> void:
	var flip := facing < 0
	var lure := global_position + Vector2(facing * 17.0, -7.0)
	CDraw.glow(self, local(lure) + wob, 9.0, spec["accent"], 0.25 + 0.1 * sin(clock * 3.0))
	if stun_left > 0.0:
		art("stun", by_time("stun", 4.0), Vector2.ZERO, flip)
	elif _lunge > 0.0:
		art("lunge", 1 if _lunge > 0.25 else 2, Vector2.ZERO, flip)
	else:
		art("idle", by_time("idle", 5.0), Vector2.ZERO, flip)
