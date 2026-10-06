class_name LizardCreature
extends Creature
## The lizards, after Rain World's: a heavy armoured head in the lizard's colour, a scaly body and tail that trail behind,
## carried on four legs that plant their feet and step. It wanders; when it hunts it runs at the hero and lunges with its
## jaws wide. Each kind adds a trick from its spec (see CreatureTypes): the sprout lizard is small and bites and backs off;
## the bloom and drip lizards climb any wall, and the drip lizard drops on the hero from above; the bark and pale lizards fade
## into the room while they wait and shoot a sticky tongue that yanks the hero in; the spark lizard's cry wakes the whole
## room; the crypt lizard is blind and hunts by sound; the pale, crypt, mire and cinder lizards leap up to a ledge the hero
## is on; the cinder lizard lunges twice. From the Drowned Works down they hop back from a swing of the stick now and then.

enum M { WANDER, CHASE, LUNGE, REST, BACKOFF, TONGUE, LEAP }

var _m: M = M.WANDER
var _mt := 0.0
var _turn := 3.0
var _body := PackedVector2Array()
var _legs: Array = []
var _lunges := 0
var _head_x := 12.0
var sz := 1.0
var _tongue_cd := 1.0
var _tongue_aim := Vector2.ZERO
var _tongue_len := 0.0
var _tongue_caught := false
var _leap_cd := 0.0
var _dodge_cd := 0.0
var _call_t := 0.0
const SEG := 4.8
const ROWS := ["seg_l", "seg_l", "seg_l", "seg_l", "seg_m", "seg_m", "seg_m", "seg_s", "seg_s", "seg_s", "seg_s", "seg_s"]
const TONGUE_WIND := 0.28     ## the tell: it stops, opens its mouth and shakes its head
const TONGUE_OUT := 0.16
const TONGUE_HOLD := 0.08
const TONGUE_BACK := 0.2


func born() -> void:
	sz = float(spec.get("size", 1.0))
	_head_x = facing * 12.0 * sz
	_body = line_of(global_position + Vector2(_head_x, -9 * sz), Vector2(-facing, 0), 13, SEG * sz)
	for i in 4:
		_legs.append(Creature.Leg.new(7.0 * sz, 7.0 * sz, -1.0 if i < 2 else 1.0, global_position))


## The camouflaged kinds wait unseen in ambush: they notice the hero when they see them, not the moment they come in.
func ambusher() -> bool:
	return bool(spec.get("camo", false))


func think(delta: float) -> void:
	_mt += delta
	_tongue_cd -= delta * aggr
	_leap_cd -= delta * aggr
	_dodge_cd -= delta
	var hc := hero_center()
	var hr := hero_real()
	var sees := hunting() or (hero_near(180.0) and absf(hc.y - global_position.y) < 40.0 and not blind)
	var dx := hc.x - global_position.x if sees else 0.0
	var route := chase_dir(delta) if hunting() else 0
	var vx := 0.0
	match _m:
		M.WANDER:
			_turn -= delta
			if _turn <= 0.0 or blocked_ahead(14.0):
				facing = -facing
				_turn = randf_range(3.0, 6.0)
			vx = 0.0 if ambusher() else facing * float(spec["speed"])     # an ambusher sits still where it waits
			if sees:
				_m = M.CHASE
		M.CHASE:
			if not sees:
				_m = M.WANDER
			else:
				if hunting():
					if route != 0:
						facing = route
				elif absf(dx) > 10.0:
					facing = 1 if dx > 0.0 else -1
				vx = facing * float(spec["run"]) if (route != 0 or not hunting()) else 0.0
				if searching() and route == 0:          # where it last saw them and they are not there: pace up and down, looking
					_turn -= delta
					if _turn <= 0.0 or blocked_ahead(14.0):
						facing = -facing
						_turn = randf_range(0.7, 1.2)
					vx = facing * float(spec["speed"]) * 1.3
				var close_x := absf(hr.x - global_position.x) if hr != Vector2.INF else INF
				if _try_dodge(close_x):
					pass
				elif close_x < 44.0 * maxf(sz, 0.8) and level_with_hero() and is_on_floor():
					_lunge()
				elif _try_tongue(hr):
					pass
				elif _try_leap(hr):
					pass
				elif blocked_ahead(12.0) and not hunting():
					vx = 0.0
		M.LUNGE:
			vx = velocity.x
			if _mt > 0.35 and is_on_floor():
				if bool(spec["double"]) and _lunges < 2 and sees:
					_lunge()
				elif bool(spec.get("skittish", false)):
					_m = M.BACKOFF                   # bite and run
					_mt = 0.0
				else:
					_m = M.REST
					_mt = 0.0
		M.REST:
			vx = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _mt > 0.7 / aggr:
				_m = M.CHASE if sees else M.WANDER
				_lunges = 0
		M.BACKOFF:
			if hr != Vector2.INF:
				facing = -1 if hr.x > global_position.x else 1
			vx = facing * float(spec["run"])
			if _mt > 0.8 or blocked_ahead(12.0):
				_m = M.CHASE if sees else M.WANDER
				_lunges = 0
		M.TONGUE:
			vx = 0.0
			_update_tongue()
		M.LEAP:
			vx = velocity.x
			if _mt > 0.15 and is_on_floor():
				_m = M.REST
				_mt = 0.3 / aggr
	velocity.x = vx
	ground_move(velocity.x, delta)


func _lunge() -> void:
	_m = M.LUNGE
	_mt = 0.0
	_lunges += 1
	velocity = Vector2(facing * float(spec["lunge"]), -140.0 * sqrt(sz))


## The tongue kinds: the hero in plain sight, in reach but not right on top of it.
func _try_tongue(hr: Vector2) -> bool:
	var reach := float(spec.get("tongue", 0.0))
	if reach <= 0.0 or _tongue_cd > 0.0 or hr == Vector2.INF or not _seen or not is_on_floor():
		return false
	var mouth := _mouth()
	var d := mouth.distance_to(hr)
	if d < 40.0 or d > reach or absf(hr.y - mouth.y) > reach * 0.6:
		return false
	facing = 1 if hr.x > global_position.x else -1
	_m = M.TONGUE
	_mt = 0.0
	_tongue_aim = hr
	_tongue_len = 0.0
	_tongue_caught = false
	return true


func _update_tongue() -> void:
	var mouth := _mouth()
	var full := mouth.distance_to(_tongue_aim) + 8.0
	var dir := (_tongue_aim - mouth).normalized()
	if _mt < TONGUE_WIND:
		_tongue_len = 0.0
	elif _mt < TONGUE_WIND + TONGUE_OUT:
		_tongue_len = full * (_mt - TONGUE_WIND) / TONGUE_OUT
	elif _mt < TONGUE_WIND + TONGUE_OUT + TONGUE_HOLD:
		_tongue_len = full
	elif _mt < TONGUE_WIND + TONGUE_OUT + TONGUE_HOLD + TONGUE_BACK:
		_tongue_len = full * (1.0 - (_mt - TONGUE_WIND - TONGUE_OUT - TONGUE_HOLD) / TONGUE_BACK)
	else:
		_tongue_len = 0.0
		_tongue_cd = 3.0
		_m = M.CHASE
		if _tongue_caught:
			_lunge()                 # reel them in and bite
		return
	var h := hero()
	if h != null and not _tongue_caught and _tongue_len > 0.0:
		var tip := mouth + dir * _tongue_len
		var hb := Rect2(h.global_position - Vector2(6, 15), Vector2(12, 16))
		if hb.has_point(tip) or hb.has_point(mouth + dir * _tongue_len * 0.7):
			_tongue_caught = h.yank(global_position.x, 250.0)
			if _tongue_caught:
				burst(tip, 5, 60.0)
				if game != null:
					game.cam.shake(1.0)


func _mouth() -> Vector2:
	return (_body[0] if not _body.is_empty() else global_position) + Vector2(facing * 7.0 * sz, 1.0)


## The jumping kinds leap up to the hero's ledge; the drip lizard drops on the hero from above.
func _try_leap(hr: Vector2) -> bool:
	if hr == Vector2.INF or _leap_cd > 0.0 or not is_on_floor() or not hunting():
		return false
	var dx := hr.x - global_position.x
	var dy := hr.y - (global_position.y - 6.0)
	if bool(spec.get("jump", false)) and dy < -18.0 and dy > -84.0 and absf(dx) < 80.0 and _seen:
		var vy := -sqrt(2.0 * GRAVITY * (-dy + 14.0))
		velocity = Vector2(clampf(dx * 2.2, -float(spec["run"]), float(spec["run"])), maxf(vy, -400.0))
	elif bool(spec.get("drop", false)) and dy > 24.0 and dy < 170.0 and absf(dx) < 64.0 and _seen:
		velocity = Vector2(clampf(dx * 2.5, -140.0, 140.0), -70.0)
	else:
		return false
	facing = 1 if dx > 0.0 else -1
	_m = M.LEAP
	_mt = 0.0
	_leap_cd = 1.6
	return true


## From the Drowned Works down a lizard sometimes hops back out of reach of a swing of the stick.
func _try_dodge(close_x: float) -> bool:
	var h := hero()
	var chance := float(prof.get("dodge", 0.0))
	if h == null or chance <= 0.0 or _dodge_cd > 0.0 or close_x > 40.0 or not h.is_swinging() or not is_on_floor():
		return false
	_dodge_cd = 1.5
	if randf() > chance:
		return false
	facing = 1 if h.global_position.x > global_position.x else -1
	velocity = Vector2(-facing * 130.0, -160.0)
	_m = M.LEAP
	_mt = 0.0
	return true


func on_stunned() -> void:
	_m = M.REST
	_mt = -STUN_TIME
	_tongue_len = 0.0


func on_call() -> void:
	_call_t = 0.9
	if not _body.is_empty():
		burst(_body[0] + Vector2(0, -10), 10, 70.0)


func _physics_process(delta: float) -> void:
	super(delta)
	if dead:
		return
	_call_t = maxf(0.0, _call_t - delta)
	if ambusher():                # the camouflaged kinds fade into the room while they wait
		var hidden := state == CreatureBrain.S.IDLE and stun_left <= 0.0 and _flash <= 0.0
		modulate.a = move_toward(modulate.a, 0.16 if hidden else 1.0, delta * (0.8 if hidden else 5.0))
	var tongue_shake := sin(clock * 50.0) * 1.5 if _m == M.TONGUE and _mt < TONGUE_WIND else 0.0
	_head_x = face_s * (4.0 if climbing else 12.0) * sz      # turning round is a swing of the head, not a jump
	var head := global_position + Vector2(_head_x + tongue_shake, (-18.0 if climbing else -9.0) * sz + sin(clock * 9.0) * (0.6 if _m == M.CHASE else 0.2))
	_body = follow(_body, head, SEG * sz, 30.0, delta)
	var floor_y := global_position.y
	if is_on_floor() and not climbing:     # on the ground the body rests on it; on a wall it hangs off the head
		for i in range(1, _body.size()):
			_body[i].y = minf(_body[i].y, floor_y - (8.0 if i < 6 else 4.0 - i * 0.15) * sz)
	for i in 4:
		var hip := _body[2] if i < 2 else _body[5]
		var reach := (8.0 if i % 2 == 0 else 2.0) * sz
		var g := ground_below(hip + Vector2(face_s * reach, 0), 30.0)        # the feet reach the way it is turning, not the way it flipped to
		var want := Vector2(hip.x + face_s * reach, g if g != INF else hip.y + 10.0 * sz)
		var leg: Creature.Leg = _legs[i]
		var partner: Creature.Leg = _legs[i ^ 1]
		if not partner.stepping() or leg.stepping():
			leg.update(want, 10.0 * sz, delta, 9.0 if _m == M.WANDER else 16.0, 4.0 * sz)


func hit_rects() -> Array[Rect2]:
	if _body.is_empty():
		return []
	return [Rect2(_body[0] - Vector2(9, 7) * sz, Vector2(18, 13) * sz), Rect2(_body[3] - Vector2(8, 6) * sz, Vector2(16, 12) * sz),
			Rect2(_body[7] - Vector2(5, 4) * sz, Vector2(10, 8) * sz)]


func stun_anchor() -> Vector2:
	return local(_body[0]) + Vector2(0, -14 * sz) if not _body.is_empty() else Vector2(0, -20)


func _draw_leg(i: int, col: Color, hi: Color, w: float) -> void:
	var hip_g := _body[2] if i < 2 else _body[5]
	var leg: Creature.Leg = _legs[i]
	var hip := local(hip_g)
	var knee := local(leg.knee(hip_g))
	var foot := local(leg.foot)
	CDraw.limb(self, hip + wob, knee + wob, col, w + 1.0)
	CDraw.limb(self, knee + wob, foot + wob, col, w)
	CDraw.line(self, knee + wob + Vector2(0, -1), knee + wob + (hip - knee) * 0.5 + Vector2(0, -1), hi)
	for t in 3:   # claws
		CDraw.line(self, foot + wob, foot + wob + Vector2(facing * (1 + t), 1 - t * 0.5), col.darkened(0.3))


func draw_body() -> void:
	if _body.size() < 2:
		return
	var body: Color = spec["body"]
	var hi: Color = spec["hi"]
	var lw := 1.0 if sz < 0.9 else 2.0
	_draw_leg(1, body.darkened(0.4), hi.darkened(0.4), 1.0)
	_draw_leg(3, body.darkened(0.4), hi.darkened(0.4), 1.0)
	draw_chain(_body, ROWS, _m == M.LUNGE or _m == M.TONGUE or (_m == M.CHASE and int(clock * 4.0) % 3 == 0))
	_draw_leg(0, body, hi, lw)
	_draw_leg(2, body, hi, lw)
	if _tongue_len > 0.0:          # the tongue: a fat sticky strap with a blob on the end
		var tc: Color = spec.get("tongue_col", Color("c86a7a"))
		var m := local(_mouth()) + wob
		var tip := m + (_tongue_aim - _mouth()).normalized() * _tongue_len
		CDraw.limb(self, m, tip, tc.darkened(0.35), 3.0)
		CDraw.limb(self, m, tip, tc, 2.0)
		draw_rect(Rect2(tip.floor() - Vector2(2, 2), Vector2(4, 4)), tc.darkened(0.45))
		draw_rect(Rect2(tip.floor() - Vector2(1, 1), Vector2(2, 2)), tc.lightened(0.3))
	if _call_t > 0.0:              # the spark lizard's cry: rings of light off its feelers
		var c := local(_body[0]) + Vector2(-facing * 6.0, -14.0)
		var acc: Color = spec["accent"]
		for k in 2:
			var t := fmod(0.9 - _call_t + k * 0.3, 0.9) / 0.9
			draw_arc(c, 4.0 + t * 34.0, 0.0, TAU, 24, Color(acc, (1.0 - t) * 0.8), 1.0)
