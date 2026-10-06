class_name HoundCreature
extends Creature
## Furnace hound: a starved iron dog of the Rustworks, a cage of ribs with a fire burning inside, a long metal skull.
## It prowls; when it sees the hero it runs flat out and leaps at them from a few lengths away, skids, turns, comes again.

enum M { PROWL, RUN, LEAP, SKID }

var _m: M = M.PROWL
var _mt := 0.0
var _turn := 3.0
var _cool := 0.0


func think(delta: float) -> void:
	_mt += delta
	_cool = maxf(0.0, _cool - delta * aggr)
	var hc := hero_center()
	var sees := hunting() or (hero_near(220.0) and absf(hc.y - global_position.y) < 46.0)
	var route := chase_dir(delta) if hunting() else 0
	var vx := 0.0
	match _m:
		M.PROWL:
			_turn -= delta
			if _turn <= 0.0 or blocked_ahead(22.0):
				facing = -facing
				_turn = randf_range(2.5, 5.0)
			vx = facing * float(spec["speed"])
			if sees:
				_m = M.RUN
		M.RUN:
			if not sees:
				_m = M.PROWL
			else:
				if hunting():
					if route != 0:
						facing = route
				else:
					facing = 1 if hc.x > global_position.x else -1
				vx = facing * float(spec["run"]) if (route != 0 or not hunting()) else 0.0
				if blocked_ahead(22.0) and not hunting():
					vx = 0.0
				if absf(hero_real().x - global_position.x) < 76.0 and level_with_hero(50.0) and _cool <= 0.0 and is_on_floor():
					_m = M.LEAP
					_mt = 0.0
					velocity = Vector2(facing * float(spec["leap"]), -210.0)
		M.LEAP:
			vx = velocity.x
			if _mt > 0.2 and is_on_floor():
				_m = M.SKID
				_mt = 0.0
				_cool = 1.2
		M.SKID:
			vx = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _mt > 0.6:
				_m = M.RUN if sees else M.PROWL
	velocity.x = vx
	ground_move(velocity.x, delta)
	advance_stride(delta, 44.0)


func on_stunned() -> void:
	_m = M.SKID
	_mt = -STUN_TIME


func hit_rects() -> Array[Rect2]:
	var gp := global_position
	return [Rect2(gp + Vector2(-16, -30), Vector2(32, 18)), Rect2(gp + Vector2(facing * 18.0 - 7.0, -34), Vector2(14, 10))]


func stun_anchor() -> Vector2:
	return Vector2(0, -38)


func draw_body() -> void:
	var flip := facing < 0
	if stun_left > 0.0:
		art("stun", by_time("stun", 4.0), Vector2.ZERO, flip)
	elif _m == M.LEAP:
		art("pounce", 1 if velocity.y < -40.0 else 2, Vector2.ZERO, flip)
	elif _m == M.SKID:
		art("pounce", 3, Vector2.ZERO, flip)
	elif absf(velocity.x) > 3.0:
		art("run", by_stride("run"), Vector2.ZERO, flip)
	else:
		art("idle", by_time("idle", 3.0), Vector2.ZERO, flip)
	if stun_left <= 0.0 and int(clock * 12.0) % 5 == 0:     # sparks from the fire in its ribs
		burst(global_position + Vector2(randf_range(-6, 6), -20), 1, 30.0)
