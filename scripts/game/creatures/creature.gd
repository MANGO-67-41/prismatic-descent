class_name Creature
extends CharacterBody2D
## Base for the world's creatures, drawn the Rain World way: no sprite frames, a body made of linked segments that trail
## and sag, legs that plant their feet and step, wings that beat, all moved by simple physics every frame, so the motion
## is smooth. Each kind's behaviour lives in a subclass (see CreatureTypes for the roster and their numbers).
## Shared rules: touching one costs the hero a crystal; the bamboo stick stuns any of them for STUN_TIME (harmless and
## still while stunned, then briefly immune); a stomp kills small ones outright ("always"), bigger ones only while stunned
## ("stunned"), and some can never be stomped ("never": landing on them hurts). Killed creatures come back when their
## room is streamed in again, as in Rain World. Position = the middle of the feet (walkers) or of the body (fliers).
## The hunting brain (CreatureBrain) lives here too: see _brain_update, hero_center, hero_near and the chase helpers.

const GRAVITY := 900.0
const STUN_TIME := 1.5
const STUN_IMMUNE := 1.0
const TURN_LOCK := 0.3         ## a creature turns round at most this often (no flicker when the hero is right on top of it)
const CLIMB_MAX := 60.0        ## walkers climb walls up to this high (px); anything taller turns them round
const DROP_MAX := 56.0         ## and walk off drops this deep; deeper holes (the shafts) turn them round

var kind := ""
var spec: Dictionary = {}
var game: Game
var room := Rect2()            ## its room, inside the walls (world pixels)
var hp := 1
var facing := 1
var clock := 0.0
var stun_left := 0.0
var stun_immune := 0.0
var dead := false
var flying := false
var home := Vector2.ZERO        ## where it was placed (world pixels)
var _flash := 0.0
var _death := 0.0
var _touch_lock := 0.0
var _sparks: Array[Dictionary] = []
var wob := Vector2.ZERO        ## the shake while stunned, applied to every sprite
var phase := 0.0               ## how far through its walk cycle (advanced by distance travelled)
var climbing := false          ## on a wall, going up it
var face_s := 1.0              ## facing, eased from one side to the other over a turn (legs and heads follow this, not the flip)
var _turn_lock := 0.0
var _last_x := 0.0
var _stuck_t := 0.0
# --- the hunting brain
var piece_id := -1             ## the room it lives in (-1: none, it then wakes when the hero is inside its rectangle)
var state: CreatureBrain.S = CreatureBrain.S.IDLE
var prof: Dictionary = {}      ## its region's hunting profile
var aggr := 1.0                ## how much more often it attacks (cooldowns count down this much faster)
var _alert_left := 0.0
var _armed := true             ## the hero is out of the room: the next time they come in, it notices
var _known := Vector2.INF      ## where it last saw, heard or smelt the hero
var _lost := 0.0               ## how long it has been hunting without seeing them
var _sight_t := 0.0
var _seen := false
var _calm := 0.0               ## after the hero rests, it takes no notice for a while
var _wp := Vector2.INF
var _wp_t := 0.0
var _wp_dir := 0
var _mark_t := 0.0             ## how long the red "!" over its head still shows (it has noticed the hero / starts the chase)
var _mark_full := 1.0
var _share_t := 0.0
var blind := false             ## no eyes: it only feels the hero right next to it, and hunts by sound
var ears := 1.0                ## how much farther than its region's others it hears


func setup(entry: Dictionary, g: Game, piece_rect: Rect2) -> void:
	kind = str(entry["t"])
	spec = CreatureBrain.scaled_spec(kind)
	prof = CreatureBrain.profile(int(spec["region"]))
	aggr = float(prof["aggr"])
	blind = bool(spec.get("blind", false))
	ears = float(spec.get("ears", 1.0))
	game = g
	room = piece_rect.grow(-40.0)
	position = Vector2(float(entry["x"]), float(entry["y"]))
	hp = int(spec["hp"])
	flying = bool(spec.get("fly", false))
	facing = 1 if (int(entry.get("x", 0)) / 8) % 2 == 0 else -1
	collision_layer = 4
	collision_mask = 0 if flying else 1
	if not flying:
		var box: Vector2 = spec.get("box", Vector2(10, 8))
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = box
		cs.shape = shape
		cs.position = Vector2(0, -box.y / 2.0)
		add_child(cs)
	floor_snap_length = 4.0
	z_index = 6
	add_to_group("stunnable")
	add_to_group("creatures")
	clock = randf() * 10.0


func _ready() -> void:
	home = global_position
	face_s = float(facing)
	born()


# --- for subclasses ---------------------------------------------------------------------------------------------

func born() -> void:
	pass

func think(_delta: float) -> void:
	pass

## While stunned: walkers drop and stop, fliers sink a little.
func stunned_move(delta: float) -> void:
	if flying:
		global_position.y = minf(global_position.y + 18.0 * delta, room.end.y)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		velocity.y = minf(400.0, velocity.y + GRAVITY * delta)
		move_and_slide()

func on_stunned() -> void:
	pass

## World rectangles that touch the hero (and that the stick can hit).
func hit_rects() -> Array[Rect2]:
	return [Rect2(global_position - Vector2(6, 10), Vector2(12, 10))]

func can_be_stomped() -> bool:
	match str(spec["stomp"]):
		"always":
			return true
		"stunned":
			return stun_left > 0.0
	return false

func harmful() -> bool:
	return true

## Where the stun stars circle (local).
func stun_anchor() -> Vector2:
	return Vector2(0, -14)

func draw_body() -> void:
	pass


# --- the shared loop ----------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	clock += delta
	_flash = maxf(0.0, _flash - delta * 4.0)
	stun_immune = maxf(0.0, stun_immune - delta)
	_touch_lock = maxf(0.0, _touch_lock - delta)
	_update_sparks(delta)
	if dead:
		_death += delta
		modulate.a = clampf(1.0 - _death / 0.6, 0.0, 1.0)
		if _death > 0.7:
			queue_free()
		queue_redraw()
		return
	_brain_update(delta)
	_turn_lock = maxf(0.0, _turn_lock - delta)
	var before := facing
	if stun_left > 0.0:
		stun_left -= delta
		if stun_left <= 0.0:
			stun_immune = STUN_IMMUNE
		stunned_move(delta)
	elif _alert_left > 0.0:
		_alert_left -= delta
		alert_idle(delta)
		if _alert_left <= 0.0:
			state = CreatureBrain.S.HUNT
			_lost = 0.0
	else:
		think(delta)
	if facing != before:
		if _turn_lock > 0.0:
			facing = before                  # it turned round a moment ago: hold this way a little longer
		else:
			_turn_lock = TURN_LOCK
	face_s = move_toward(face_s, float(facing), delta * 10.0)     # a full turn takes 0.2 s
	_check_hero()
	queue_redraw()


func hero() -> Player:
	if game == null or game.player == null or game.dying:
		return null
	return game.player


## The hero's real middle, or Vector2.INF when there is no hero to care about.
func hero_real() -> Vector2:
	var h := hero()
	return h.global_position - Vector2(0, 7) if h != null else Vector2.INF


## Where this creature believes the hero is: the real spot while it is hunting and can see (or smell) them, the last spot it
## saw them when it cannot, the real spot otherwise.
func hero_center() -> Vector2:
	if state == CreatureBrain.S.HUNT and _known != Vector2.INF:
		return _known
	return hero_real()


func hunting() -> bool:
	return state == CreatureBrain.S.HUNT


## The hero is in this creature's room and (while it is not hunting, or for a short reach) within `reach` of it. A hunting
## creature knows where the hero is anywhere in the room, so every long-range question is yes.
func hero_near(reach: float) -> bool:
	var h := hero()
	if h == null or not room.grow(24.0).has_point(h.global_position):
		return false
	if hunting() and reach >= 100.0:
		return true
	return global_position.distance_to(h.global_position - Vector2(0, 7)) < reach


## The hero is in the room this creature lives in.
func hero_in_room() -> bool:
	var h := hero()
	if h == null:
		return false
	if piece_id >= 0:
		return game.piece == piece_id
	return room.grow(24.0).has_point(h.global_position)


## A walker's eye: can it see the hero from here (no rock between, within `range`)?
func sees_hero(range_px: float) -> bool:
	if blind:
		range_px = minf(range_px, 52.0)      # what it feels brushing past, not sight
	var hc := hero_real()
	if hc == Vector2.INF or global_position.distance_to(hc) > range_px:
		return false
	var box: Vector2 = spec.get("box", Vector2(10, 12))
	var eye := global_position + Vector2(0, -float(spec.get("eye", maxf(10.0, box.y))) if not flying else 0.0)
	return ray(eye, hc).is_empty() or ray(eye, hc + Vector2(0, -6)).is_empty()      # over a low step is still a clear line


func _brain_update(delta: float) -> void:
	_calm = maxf(0.0, _calm - delta)
	_mark_t = maxf(0.0, _mark_t - delta)
	_share_t -= delta
	var inside := hero_in_room() and _calm <= 0.0
	if not hero_in_room():
		_armed = true
		if state != CreatureBrain.S.IDLE:
			state = CreatureBrain.S.IDLE
			_alert_left = 0.0
			_known = Vector2.INF
		return
	_sight_t -= delta
	if _sight_t <= 0.0:
		_sight_t = 0.12
		_seen = sees_hero(1100.0 if state == CreatureBrain.S.HUNT else float(prof["sight"]))     # once hunting, a clear line across the room is enough
	match state:
		CreatureBrain.S.IDLE:
			if inside and ((_armed and not blind and not ambusher()) or _seen):
				_notice(hero_real(), float(prof["reaction"]) * (1.0 if _armed else 0.7))
		CreatureBrain.S.HUNT:
			if _seen or (bool(prof["smell"]) and not blind):
				if _lost > 1.5:
					_mark_t = 0.8        # there you are: the "!" again as it picks the chase back up
					_mark_full = 0.8
				_known = hero_real()
				_lost = 0.0
				if _seen and bool(prof["share"]) and _share_t <= 0.0:
					_share_t = 0.5
					_tell_mates(_known)
			else:
				_lost += delta
				if _known == Vector2.INF or _lost > float(prof["memory"]):
					state = CreatureBrain.S.IDLE        # it has looked where it last saw them, and around it, and found nothing: back to its rounds
					_armed = false
					_known = Vector2.INF


func _notice(at: Vector2, reaction: float) -> void:
	state = CreatureBrain.S.ALERT
	_armed = false
	_known = at
	_alert_left = reaction
	_mark_t = reaction + 1.0
	_mark_full = _mark_t
	if at != Vector2.INF and absf(at.x - global_position.x) > 2.0:
		facing = 1 if at.x > global_position.x else -1
	if bool(spec.get("caller", false)):
		on_call()
		for c in mates():
			if c.state == CreatureBrain.S.IDLE and c._calm <= 0.0:
				c._notice(at, 0.15)       # the call wakes the whole room at once


## The other living creatures in this one's room.
func mates() -> Array[Creature]:
	var out: Array[Creature] = []
	if piece_id < 0 or not is_inside_tree():
		return out
	for c in get_tree().get_nodes_in_group("creatures"):
		if c != self and c is Creature and (c as Creature).piece_id == piece_id and not (c as Creature).dead:
			out.append(c)
	return out


## It sees the hero: hunters in the room that have lost them learn where they are (from the Rustworks on).
func _tell_mates(at: Vector2) -> void:
	for c in mates():
		if c.hunting() and not c._seen:
			c._known = at
			c._lost = 0.0


## Waits hidden and only notices the hero when it sees them (not the moment they come into the room).
func ambusher() -> bool:
	return false


## A caller's cry (the spark lizard flashes its feelers).
func on_call() -> void:
	pass


## Hunting but it has lost the hero for a while: looking for them (a "?" shows).
func searching() -> bool:
	return hunting() and not _seen and _lost > 1.2 and not bool(prof["smell"])


## A noise at `pos` that carries `radius` px (landings, ground pounds, stick swings).
func hear(pos: Vector2, radius: float) -> void:
	if dead or stun_left > 0.0 or _calm > 0.0 or not hero_in_room():
		return
	if global_position.distance_to(pos) > radius * float(prof["hearing"]) * ears:
		return
	match state:
		CreatureBrain.S.IDLE:
			_notice(pos, float(prof["reaction"]) * 0.5)
		CreatureBrain.S.HUNT:
			if not _seen:
				_known = pos
				_lost = 0.0


## The hero rested at a lantern: it loses them and takes no notice for `seconds`.
func forget(seconds: float) -> void:
	state = CreatureBrain.S.IDLE
	_alert_left = 0.0
	_known = Vector2.INF
	_calm = seconds
	_armed = false


## While it reacts: walkers stop where they are and face the hero, fliers hold still.
func alert_idle(delta: float) -> void:
	if not flying:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		velocity.y = minf(400.0, velocity.y + GRAVITY * delta)
		move_and_slide()
	var hc := hero_real()
	if hc != Vector2.INF and absf(hc.x - global_position.x) > 4.0:
		facing = 1 if hc.x > global_position.x else -1


# --- chasing on foot ---------------------------------------------------------------------------------------------

func clearance() -> int:
	return maxi(2, int(ceil((spec.get("box", Vector2(10, 12)) as Vector2).y / 8.0)))


## Packs of hunters come from different sides in the deeper regions: an offset (px, along x) for this one.
func flank_offset() -> float:
	if not bool(prof.get("flank", false)) or piece_id < 0:
		return 0.0
	var mates: Array = []
	for c in get_tree().get_nodes_in_group("creatures"):
		if c is Creature and (c as Creature).piece_id == piece_id and (c as Creature).hunting() and not (c as Creature).dead and (c as Creature).flying == flying:
			mates.append(c)
	if mates.size() < 2:
		return 0.0
	mates.sort_custom(func(a: Object, b: Object) -> bool: return a.get_instance_id() < b.get_instance_id())
	return (mates.find(self) - (mates.size() - 1) / 2.0) * 46.0


## The next point on the way to the hero across the room's floors and ledges (recomputed a few times a second).
func chase_point(delta: float) -> Vector2:
	_wp_t -= delta
	if _wp_t <= 0.0 or _wp == Vector2.INF:
		_wp_t = randf_range(0.25, 0.4)
		var target := hero_center()
		if target == Vector2.INF:
			_wp = Vector2.INF
		else:
			target.x += flank_offset()
			if piece_id >= 0:
				var nav := RoomNav.for_piece(piece_id)
				_wp = nav.waypoint(global_position, target, clearance(), 3, mini(int(climb_max() / 8.0), 40))
				_wp_dir = nav.last_dir
			else:
				_wp = Vector2(target.x, global_position.y)
				_wp_dir = 0
			if _wp == Vector2.INF:
				_wp = Vector2(target.x, global_position.y)
	return _wp


## -1, 0 or 1: which way to walk to follow the route to the hero (0 when it is there).
func chase_dir(delta: float) -> int:
	var wp := chase_point(delta)
	if wp == Vector2.INF:
		return 0
	var dx := wp.x - global_position.x
	if absf(dx) < 3.0 and wp.y < global_position.y - 4.0 and _wp_dir != 0:
		return _wp_dir           # the way on is up the wall beside it: push against that wall to climb it
	if absf(dx) < 6.0 or (absf(dx) < 12.0 and signi(int(dx)) != facing):
		return 0                 # close enough, or only just past it: stop rather than spin round
	return 1 if dx > 0.0 else -1


## The hero is about level with this walker (so a lunge, pounce or throw can reach them).
func level_with_hero(tolerance: float = 44.0) -> bool:
	var hc := hero_real()
	return hc != Vector2.INF and absf(hc.y - (global_position.y - 8.0)) < tolerance


func _check_hero() -> void:
	var h := hero()
	if h == null:
		return
	var hr := Rect2(h.global_position - Vector2(5, 14), Vector2(10, 14))
	for r in hit_rects():
		if not r.intersects(hr):
			continue
		if h.velocity.y > 30.0 and h.global_position.y <= r.position.y + 7.0 and _touch_lock <= 0.0 and can_be_stomped():
			_touch_lock = 0.25
			h.bounce()
			take_damage(2 if h.is_pounding() else 1, h.global_position)
			return
		if stun_left <= 0.0 and harmful():
			h.take_hit(global_position.x)
		return


func take_damage(amount: int, at: Vector2) -> void:
	hp -= amount
	_flash = 1.0
	burst(at, 6, 80.0)
	if game != null:
		game.cam.shake(1.5)
	if hp <= 0:
		die()


func die() -> void:
	dead = true
	remove_from_group("stunnable")
	collision_layer = 0
	collision_mask = 0
	burst(global_position + Vector2(0, -6), 16, 120.0)
	if game != null:
		game.cam.shake(2.0)


## The bamboo stick reached `box`: 0 missed, 1 stunned, 2 struck but already stunned or still shaking it off.
func stick_hit(box: Rect2, _from_x: float) -> int:
	if dead:
		return 0
	for r in hit_rects():
		if r.intersects(box):
			if stun_left > 0.0 or stun_immune > 0.0:
				burst(box.intersection(r).get_center(), 3, 50.0)
				return 2
			stun_left = STUN_TIME
			_flash = 0.6
			burst(box.intersection(r).get_center(), 8, 90.0)
			on_stunned()
			return 1
	return 0


# --- the world -----------------------------------------------------------------------------------------------------

func ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(q)


## y of the ground under `p` within `depth`, or INF.
func ground_below(p: Vector2, depth: float = 40.0) -> float:
	var hit := ray(p, p + Vector2(0, depth))
	return float((hit["position"] as Vector2).y) if not hit.is_empty() else INF


## A wall too high to climb, a drop too deep to go down, or the edge of the room: time to turn round.
## (Low walls and short drops are not in the way: walkers climb them, like Rain World's creatures.)
func blocked_ahead(dist: float = 8.0) -> bool:
	var gp := global_position
	if gp.x + facing * dist < room.position.x or gp.x + facing * dist > room.end.x:
		return true
	if not ray(gp + Vector2(0, -4), gp + Vector2(facing * dist, -4)).is_empty():
		return wall_height(dist) > climb_max()
	return ray(gp + Vector2(facing * dist, -2), gp + Vector2(facing * dist, DROP_MAX)).is_empty()


## How high this walker can climb (px): CLIMB_MAX, or any wall for the climbing kinds.
func climb_max() -> float:
	return float(spec.get("climb_max", CLIMB_MAX))


## How high the wall in front goes (px above the feet), up to a little past CLIMB_MAX (climbers: any wall will do).
func wall_height(dist: float = 8.0) -> float:
	if climb_max() >= 999.0:
		return 8.0
	var gp := global_position
	var h := 8.0
	while h <= CLIMB_MAX + 8.0:
		if ray(gp + Vector2(0, -h), gp + Vector2(facing * (dist + 2.0), -h)).is_empty():
			return h
		h += 8.0
	return 999.0


func walk(vx: float, delta: float) -> void:
	ground_move(vx, delta)


## Moves a walker: gravity, or straight up the wall it is pushing against (then over the top). A walker that has not
## got anywhere for a while turns round; one that has fallen out of its room is put back where it started.
func ground_move(vx: float, delta: float) -> void:
	velocity.x = vx
	var against := vx != 0.0 and is_on_wall() and signf(get_wall_normal().x) == -signf(vx)
	climbing = against and wall_height(4.0) <= climb_max() and not is_on_ceiling()
	if climbing:
		velocity.y = -float(spec.get("climb", 60.0))
	else:
		velocity.y = minf(400.0, velocity.y + GRAVITY * delta)
	move_and_slide()
	if absf(global_position.x - _last_x) > 3.0 or climbing or vx == 0.0:
		_last_x = global_position.x
		_stuck_t = 0.0
	else:
		_stuck_t += delta
		if _stuck_t > 2.0:
			facing = -facing
			_stuck_t = 0.0
	if not room.grow(48.0).has_point(global_position):
		global_position = home
		velocity = Vector2.ZERO


func clamp_to_room() -> void:
	global_position = global_position.clamp(room.position, room.end)


func local(p: Vector2) -> Vector2:
	return p - global_position


# --- sparks and drawing ----------------------------------------------------------------------------------------------

func burst(at_global: Vector2, n: int, speed: float) -> void:
	var cols := [spec.get("accent", Color.WHITE), spec.get("hi", Color.WHITE), Color.WHITE]
	for i in n:
		var a := randf() * TAU
		_sparks.append({"p": at_global - global_position, "v": Vector2(cos(a), sin(a) - 0.5) * speed * randf_range(0.3, 1.0),
				"life": randf_range(0.3, 0.7), "c": cols[randi() % cols.size()]})


func _update_sparks(delta: float) -> void:
	for s in _sparks.duplicate():
		s["life"] = float(s["life"]) - delta
		s["v"] = (s["v"] as Vector2) + Vector2(0, 300.0) * delta
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * delta
		if float(s["life"]) <= 0.0:
			_sparks.erase(s)


func _draw() -> void:
	wob = Vector2(roundf(sin(clock * 30.0)), 0) if stun_left > 0.0 else Vector2.ZERO
	draw_body()
	if stun_left <= 0.0:
		if _mark_t > 0.0:            # it has seen you and is coming: a red "!" over its head, popping up
			var pop := -roundf(sin(clampf((_mark_full - _mark_t) / 0.18, 0.0, 1.0) * PI) * 3.0)
			_draw_glyph(MARK_BANG, stun_anchor() + Vector2(0, -8 + pop), Color("ff3a2a"), Color("ffb09a"), clampf(_mark_t * 4.0, 0.0, 1.0))
		elif searching():            # it has lost you and is looking: a yellow "?"
			_draw_glyph(MARK_ASK, stun_anchor() + Vector2(0, -8 + roundf(sin(clock * 4.0))), Color("ffd04a"), Color("fff0b0"), 0.85)
	if stun_left > 0.0:
		var c := stun_anchor()
		for k in 3:
			var a := clock * 5.0 + k * TAU / 3.0
			var sp := (c + Vector2(cos(a) * 9.0, sin(a) * 3.0)).floor()
			draw_rect(Rect2(sp - Vector2(1, 0), Vector2(3, 1)), Color("ffe08a"))
			draw_rect(Rect2(sp - Vector2(0, 1), Vector2(1, 3)), Color("ffe08a"))
	for s in _sparks:
		draw_rect(Rect2((s["p"] as Vector2).floor(), Vector2(1, 1)), Color(s["c"], clampf(float(s["life"]) * 2.5, 0.0, 1.0)))


const MARK_BANG := ["XX", "XX", "XX", "XX", "XX", "..", "XX"]
const MARK_ASK := [".XX.", "X..X", "...X", "..X.", "....", "..X."]


## A tiny pixel glyph (bottom centre at `at`), outlined in ink, its top row lit.
func _draw_glyph(rows: Array, at: Vector2, col: Color, lit: Color, a: float) -> void:
	var w := (rows[0] as String).length()
	var o := (at - Vector2(w / 2.0, rows.size())).floor()
	for pass_ in 2:
		for y in rows.size():
			var r: String = rows[y]
			for x in w:
				if r[x] != "X":
					continue
				if pass_ == 0:
					draw_rect(Rect2(o + Vector2(x - 1, y - 1), Vector2(3, 3)), Color(UITheme.INK, a))
				else:
					draw_rect(Rect2(o + Vector2(x, y), Vector2(1, 1)), Color(lit if y == 0 else col, a))


# --- sprites -------------------------------------------------------------------------------------------------------------

## A hit flashes the creature white; stunned ones go a little grey.
func tint() -> Color:
	if _flash > 0.0:
		return Color(1, 1, 1).lerp(Color(3, 3, 3), _flash)
	return Color(0.8, 0.8, 0.9) if stun_left > 0.0 else Color.WHITE


func art(row: String, i: int, at: Vector2 = Vector2.ZERO, flip: bool = false) -> void:
	if climbing and not flying:   # on the wall: turned so its feet are on the wall and its head points up
		var box: Vector2 = spec.get("box", Vector2(10, 8))
		CreatureArt.draw(self, kind, row, i, at + Vector2(facing * box.x * 0.5, -box.y * 0.5), flip, wob, tint(), -PI / 2.0 * facing)
		return
	CreatureArt.draw(self, kind, row, i, at, flip, wob, tint())


## Frame of a looping row by time.
func by_time(row: String, fps: float) -> int:
	return int(clock * fps) % CreatureArt.count(kind, row)


## Frame of a walk / run row by distance travelled, so the feet do not slide.
func by_stride(row: String) -> int:
	var n := CreatureArt.count(kind, row)
	return int(phase * n) % n


func advance_stride(delta: float, stride: float) -> void:
	phase = fmod(phase + absf(velocity.x) * delta / stride, 1.0)


## A long body drawn from sprites: tail first, the head last on top. `rows` names the segment row for each point (index 1..),
## `alt` uses the second half of a segment row (its legs or wings in the other position) on every other segment over time.
func draw_chain(pts: PackedVector2Array, rows: Array, head_open: bool, alt: bool = false) -> void:
	for i in range(pts.size() - 1, 0, -1):
		var d := CreatureArt.dir(pts[i - 1] - pts[i])
		var row: String = rows[mini(i - 1, rows.size() - 1)]
		var a := 16 if alt and (i + int(clock * 8.0)) % 2 == 0 else 0
		CreatureArt.draw(self, kind, row, d + a, local(pts[i]), false, wob, tint())
	var hd := CreatureArt.dir(pts[0] - pts[1])
	CreatureArt.draw(self, kind, "head", hd + (16 if head_open else 0), local(pts[0]), false, wob, tint())


# --- body helpers -----------------------------------------------------------------------------------------------------

## Pulls a chain of points after its first one: each keeps `seg` from the one before; `sag` drags them down a little.
static func follow(pts: PackedVector2Array, head: Vector2, seg: float, sag: float = 0.0, delta: float = 0.0) -> PackedVector2Array:
	pts[0] = head
	for i in range(1, pts.size()):
		var p := pts[i] + Vector2(0, sag * delta)
		var d := p - pts[i - 1]
		var l := d.length()
		if l > 0.001 and (l > seg or l < seg * 0.7):
			p = pts[i - 1] + d / l * (seg if l > seg else seg * 0.7)
		pts[i] = p
	return pts


static func line_of(from: Vector2, dir: Vector2, n: int, seg: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(from + dir * seg * i)
	return out


## A leg that keeps its foot planted and steps when the body has moved too far from it: Rain World walking.
class Leg:
	var foot := Vector2.ZERO
	var _from := Vector2.ZERO
	var _to := Vector2.ZERO
	var _t := 1.0
	var a := 6.0
	var b := 6.0
	var bend := 1.0

	func _init(upper: float, lower: float, knee_dir: float, at: Vector2) -> void:
		a = upper
		b = lower
		bend = knee_dir
		foot = at
		_to = at

	func stepping() -> bool:
		return _t < 1.0

	func update(want: Vector2, step: float, delta: float, speed: float = 8.0, lift: float = 3.0) -> void:
		if _t < 1.0:
			_t = minf(1.0, _t + delta * speed)
			foot = _from.lerp(_to, _t) + Vector2(0, -sin(_t * PI) * lift)
		elif foot.distance_to(want) > step:
			_from = foot
			_to = want
			_t = 0.0

	## Two-bone reach from `hip` to the foot.
	func knee(hip: Vector2) -> Vector2:
		var d := foot - hip
		var l := clampf(d.length(), 0.5, a + b - 0.01)
		var c := clampf((a * a + l * l - b * b) / (2.0 * a * l), -1.0, 1.0)
		var ang := d.angle() - bend * acos(c)
		return hip + Vector2(cos(ang), sin(ang)) * a
