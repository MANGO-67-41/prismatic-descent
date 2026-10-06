class_name WyrmCreature
extends Creature
## Ash wyrm: a flying centipede of the Ash Deep. A long chain of plated segments with small beating wings, it turns through the
## air toward the hero and keeps coming; stunned, it sags and drifts down.

var _body := PackedVector2Array()
var _dir := Vector2.RIGHT
const SEGS := 14


func born() -> void:
	_body = line_of(global_position, Vector2(-facing, 0), SEGS, 6.0)
	_dir = Vector2(facing, 0)


func think(delta: float) -> void:
	var hc := hero_center()
	var target := (hc + Vector2(flank_offset(), -flank_offset() * 0.4)) if hero_near(280.0) else home + Vector2(cos(clock * 0.5) * 60.0, sin(clock * 0.8) * 30.0)
	var want := (target - global_position).normalized()
	var turn := 2.4 * delta
	var ang := _dir.angle_to(want)
	_dir = _dir.rotated(clampf(ang, -turn, turn))
	var sp := float(spec["speed"]) * (1.3 if global_position.distance_to(target) > 150.0 else 1.0)
	global_position += _dir * sp * delta
	if not room.has_point(global_position):
		_dir = (room.get_center() - global_position).normalized()
		clamp_to_room()
	facing = 1 if _dir.x >= 0.0 else -1


func _physics_process(delta: float) -> void:
	super(delta)
	_body = follow(_body, global_position, 6.0, 20.0 if stun_left > 0.0 else 0.0, delta)


func hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in range(0, _body.size(), 2):
		out.append(Rect2(_body[i] - Vector2(6, 6), Vector2(12, 12)))
	return out


func stun_anchor() -> Vector2:
	return Vector2(0, -10)


func draw_body() -> void:
	if _body.size() < 2:
		return
	draw_chain(_body, ["seg"], hero_near(90.0) and stun_left <= 0.0, stun_left <= 0.0)
