class_name Guardian
extends Node2D
## A crystal guardian, asleep in its temple until the hero comes close. It strikes the ground (a crystal wave runs along the
## floor: jump it) or calls shards down from the ceiling (a light shows where each lands), then tires. Only while it is tired
## is its heart open: land on the heart from above (a ground pound lands twice as hard) and the hero bounces off, ready again.
## The hero's bamboo stick stuns it for STUN_TIME: whatever it was doing stops and its heart is bare, so the hero can stomp it; it
## cannot be stunned again for STUN_IMMUNE after that, so the stick opens a window but cannot keep it open.
## Defeat all five to open the seal above the Prismatic Lake. Leaving the temple, or falling, resets the fight.
## Position = the middle of its feet on the temple floor.

enum S { SLEEP, WAKE, IDLE, TELL_SLAM, SLAM, TELL_SHARDS, SHARDS, DAZED, STAGGER, DYING, DEAD, STUNNED }

const BODY_HALF := 14.0
const BODY_H := 26.0
const HEART_GAP := 8.0
const WAVE_SPEED := 120.0
const SHARD_FALL := 340.0
const STUN_TIME := 1.5
const STUN_IMMUNE := 2.0

var gid := ""
var region := 0
var hp := 3
var max_hp := 3
var game: Game
var piece_id := 0
var arena_x0 := 0.0   ## world pixels
var arena_x1 := 0.0
var arena_top := 0.0

var _state: S = S.SLEEP
var _t := 0.0
var _clock := 0.0
var _lift := 0.0
var _flash := 0.0
var _attack := 0
var _stomp_lock := 0.0
var _stun_immune := 0.0
var _face := 1
var _waves: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _pending_wave := -1.0


func setup(prop: Dictionary, g: Game, origin: Vector2, id: int) -> void:
	game = g
	piece_id = id
	gid = str(prop["id"])
	region = int(prop["region"])
	max_hp = int(StoryData.GUARDIAN_HP[region])
	hp = max_hp
	position = Vector2(float(prop["x"]), float(prop["y"]))
	arena_x0 = origin.x + float(prop["x0"])
	arena_x1 = origin.x + float(prop["x1"])
	arena_top = origin.y + float(prop["top"])
	z_index = 5
	if bool(g.vitals.guardians.get(gid, false)):
		_state = S.DEAD
	else:
		add_to_group("stunnable")


func is_vulnerable() -> bool:
	return _state == S.DAZED or _state == S.STUNNED


func is_stunned() -> bool:
	return _state == S.STUNNED


## The bamboo stick reached `box`. Returns 0 if it missed, 1 if the guardian is now stunned, 2 if it struck but did nothing
## (asleep: it wakes; already open, or still shaking off the last stun: the stick glances off).
func stick_hit(box: Rect2, _from_x: float) -> int:
	if _state == S.DEAD or _state == S.DYING:
		return 0
	var target := _body_rect().merge(heart_rect())
	if not box.intersects(target):
		return 0
	var at := box.intersection(target).get_center()
	if _state == S.SLEEP:
		_wake()
		_burst(at, 3, 50.0)
		return 2
	if _state == S.WAKE or _state == S.STAGGER or is_vulnerable() or _stun_immune > 0.0:
		_burst(at, 3, 50.0)
		return 2
	stun(STUN_TIME)
	_burst(at, 8, 90.0)
	return 1


func stun(_seconds: float) -> void:
	_set_state(S.STUNNED)
	_pending_wave = -1.0
	for sh in _shards.duplicate():
		if not bool(sh["fall"]):
			_shards.erase(sh)     # the shards it was calling never come
	_flash = 0.6


func fight_name() -> String:
	return "GUARDIAN OF " + StoryData.REGIONS[region]


func _speed() -> float:
	return 1.0 + 0.07 * region + 0.35 * (1.0 - float(hp) / float(max_hp))


func _set_state(s: S) -> void:
	_state = s
	_t = 0.0


func reset() -> void:
	if _state == S.DEAD or _state == S.DYING:
		return
	_state = S.SLEEP
	_t = 0.0
	hp = max_hp
	_lift = 0.0
	_waves.clear()
	_shards.clear()
	_pending_wave = -1.0
	game.boss_bar.hide_boss()


func _wake() -> void:
	_set_state(S.WAKE)
	game.boss_bar.show_boss(fight_name(), hp, max_hp, StoryData.COLOURS[region])
	game.cam.shake(2.0)


func heart_rect() -> Rect2:
	var gp := global_position
	var body_top := gp.y - BODY_H - _lift
	return Rect2(gp.x - 9.0, body_top - HEART_GAP - 10.0, 18.0, 10.0)


func _body_rect() -> Rect2:
	var gp := global_position
	return Rect2(gp.x - BODY_HALF, gp.y - BODY_H - _lift, BODY_HALF * 2.0, BODY_H)


func _hero_rect() -> Rect2:
	var p := game.player.global_position
	return Rect2(p.x - 5.0, p.y - 14.0, 10.0, 14.0)


func _physics_process(delta: float) -> void:
	if game == null or game.player == null:
		return
	_clock += delta
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	_stomp_lock = maxf(0.0, _stomp_lock - delta)
	_stun_immune = maxf(0.0, _stun_immune - delta)
	_update_sparks(delta)
	if _state == S.DEAD:
		queue_redraw()
		return
	var hero := game.player
	if _state != S.SLEEP and _state != S.DYING and (game.piece != piece_id or game.dying):
		reset()
	match _state:
		S.SLEEP:
			if game.piece == piece_id and not game.dying and absf(hero.global_position.x - global_position.x) < 165.0:
				_wake()
		S.WAKE:
			_lift = lerpf(_lift, 10.0, minf(1.0, delta * 5.0))
			if _t > 1.3:
				_lift = 0.0
				_set_state(S.IDLE)
		S.IDLE:
			_face = 1 if hero.global_position.x >= global_position.x else -1
			if _t > 0.75 / _speed():
				_next_attack()
		S.TELL_SLAM:
			_lift = lerpf(_lift, 16.0, minf(1.0, delta * 8.0))
			if _t > 0.85 / _speed():
				_slam()
		S.SLAM:
			_lift = lerpf(_lift, 0.0, minf(1.0, delta * 20.0))
			if _pending_wave > 0.0:
				_pending_wave -= delta
				if _pending_wave <= 0.0:
					_spawn_waves()
					_pending_wave = -1.0
			if _t > 0.7 and _waves.is_empty():
				_set_state(S.DAZED)
		S.TELL_SHARDS:
			_lift = lerpf(_lift, 12.0, minf(1.0, delta * 8.0))
			if _t > 1.05 / _speed():
				for s in _shards:
					s["fall"] = true
				_set_state(S.SHARDS)
		S.SHARDS:
			_lift = lerpf(_lift, 0.0, minf(1.0, delta * 12.0))
			if _shards.is_empty() and _t > 0.5:
				_set_state(S.DAZED)
		S.DAZED:
			_lift = lerpf(_lift, -2.0, minf(1.0, delta * 10.0))
			if _t > 2.7:
				_lift = 0.0
				_set_state(S.IDLE)
		S.STUNNED:
			_lift = lerpf(_lift, -3.0, minf(1.0, delta * 10.0))
			if _t > STUN_TIME:
				_lift = 0.0
				_stun_immune = STUN_IMMUNE
				_set_state(S.IDLE)
		S.STAGGER:
			_lift = lerpf(_lift, 0.0, minf(1.0, delta * 10.0))
			if _t > 0.7:
				_set_state(S.IDLE)
		S.DYING:
			if int(_t * 30.0) % 3 == 0:
				_burst(heart_rect().get_center(), 1, 90.0)
			if _t > 1.8:
				_finish()
	if _state != S.SLEEP and _state != S.DYING:
		_run_hazards(delta)
		_check_stomp()
	queue_redraw()


func _next_attack() -> void:
	var pattern := _attack % 4
	_attack += 1
	if pattern == 1 or pattern == 3:
		_start_shards()
	else:
		_set_state(S.TELL_SLAM)


func _slam() -> void:
	_set_state(S.SLAM)
	_spawn_waves()
	if float(hp) / float(max_hp) <= 0.5:
		_pending_wave = 0.5
	game.cam.shake(3.0)
	_burst(global_position + Vector2(0, -2), 10, 110.0)


func _spawn_waves() -> void:
	for dir: int in [-1, 1]:
		_waves.append({"x": global_position.x + dir * 16.0, "dir": dir})


func _start_shards() -> void:
	_set_state(S.TELL_SHARDS)
	_shards.clear()
	var hero_x := game.player.global_position.x
	var count := mini(4 + region, 8)
	for i in count:
		var off := (i - (count - 1) / 2.0) * 34.0 + randf_range(-6.0, 6.0)
		var x := clampf(hero_x + off, arena_x0 + 12.0, arena_x1 - 12.0)
		_shards.append({"x": x, "y": arena_top, "fall": false})


func _run_hazards(delta: float) -> void:
	var hero := game.player
	var floor_y := global_position.y
	var hr := _hero_rect()
	# crystal waves along the floor
	for w in _waves.duplicate():
		w["x"] = float(w["x"]) + float(w["dir"]) * WAVE_SPEED * _speed() * delta
		if float(w["x"]) < arena_x0 or float(w["x"]) > arena_x1:
			_waves.erase(w)
			continue
		if Rect2(float(w["x"]) - 6.0, floor_y - 12.0, 12.0, 12.0).intersects(hr):
			hero.take_hit(float(w["x"]))
	# falling shards
	for s in _shards.duplicate():
		if not bool(s["fall"]):
			continue
		s["y"] = float(s["y"]) + SHARD_FALL * delta
		if Rect2(float(s["x"]) - 3.0, float(s["y"]) - 16.0, 6.0, 16.0).intersects(hr):
			hero.take_hit(float(s["x"]))
		if float(s["y"]) >= floor_y:
			_burst(Vector2(float(s["x"]), floor_y - 2.0), 5, 70.0)
			_shards.erase(s)
	# touching its body hurts, except while it is tired
	if not is_vulnerable() and _state != S.STAGGER and _state != S.WAKE and _body_rect().intersects(hr):
		hero.take_hit(global_position.x)


func _check_stomp() -> void:
	var hero := game.player
	if _stomp_lock > 0.0 or hero.velocity.y < 20.0:
		return
	var hr := heart_rect()
	var feet := hero.global_position
	if feet.x > hr.position.x - 4.0 and feet.x < hr.end.x + 4.0 and feet.y > hr.position.y - 5.0 and feet.y < hr.position.y + 12.0:
		_stomp_lock = 0.3
		var pounding := hero.is_pounding()
		hero.bounce()
		if is_vulnerable():
			_hit(2 if pounding else 1)
		else:
			_burst(hr.get_center(), 4, 60.0)   # the casing rings: not now


func _hit(amount: int) -> void:
	hp = maxi(0, hp - amount)
	_flash = 1.0
	game.cam.shake(3.5)
	_burst(heart_rect().get_center(), 12, 120.0)
	game.boss_bar.set_hp(hp)
	if hp <= 0:
		_waves.clear()
		_shards.clear()
		_set_state(S.DYING)
		game.cam.shake(5.0)
	else:
		_set_state(S.STAGGER)


func _finish() -> void:
	_state = S.DEAD
	remove_from_group("stunnable")
	game.boss_bar.hide_boss()
	game.cam.shake(6.0)
	_burst(global_position + Vector2(0, -14), 30, 160.0)
	game.guardian_defeated(gid, region)


# --- Sparks -------------------------------------------------------------------------------


func _burst(at_global: Vector2, n: int, speed: float) -> void:
	var c: Array = StoryData.CRYSTAL[region]
	for i in n:
		var a := randf() * TAU
		_sparks.append({"p": at_global - global_position, "v": Vector2(cos(a), sin(a) - 0.6) * speed * randf_range(0.4, 1.0),
				"life": randf_range(0.5, 1.1), "c": c[randi() % 3 + 1] if randf() < 0.8 else Color.WHITE})


func _update_sparks(delta: float) -> void:
	for s in _sparks.duplicate():
		s["life"] = float(s["life"]) - delta
		s["v"] = (s["v"] as Vector2) + Vector2(0, 340.0) * delta
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * delta
		if float(s["life"]) <= 0.0:
			_sparks.erase(s)


# --- Drawing ------------------------------------------------------------------------------


func _draw() -> void:
	var pal: Array = StoryData.CRYSTAL[region]
	var body: Color = pal[0]
	var light: Color = pal[1]
	var dark: Color = pal[2]
	var glow: Color = pal[3]
	_draw_telegraphs(glow)
	if _state == S.DEAD:
		_draw_remains(pal)
	else:
		_draw_body(body, light, dark, glow)
	_draw_hazards(light, glow)
	for s in _sparks:
		var p: Vector2 = (s["p"] as Vector2).floor()
		var a := clampf(float(s["life"]) * 2.0, 0.0, 1.0)
		draw_rect(Rect2(p, Vector2(2, 2)), Color(s["c"], a))


func _draw_telegraphs(glow: Color) -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 18.0)
	if _state == S.TELL_SLAM:
		for dir: int in [-1, 1]:
			var x := 18.0
			while x < 150.0:
				draw_rect(Rect2(x * dir - (0 if dir > 0 else 5), -2, 5, 2), Color(glow, 0.25 + 0.45 * pulse))
				x += 12.0
	if _state == S.TELL_SHARDS:
		for s in _shards:
			var lx := float(s["x"]) - global_position.x
			var h := global_position.y - arena_top
			for y in range(0, int(h), 6):
				draw_rect(Rect2(lx, -h + y, 1, 3), Color(glow, 0.12 + 0.2 * pulse))
			Glyphs.draw_diamond(self, Vector2(lx, -2), 3, Color(glow, 0.45 + 0.45 * pulse))


func _draw_body(body: Color, light: Color, dark: Color, glow: Color) -> void:
	var asleep := _state == S.SLEEP
	var stunned := _state == S.STUNNED
	var lift := -_lift
	if stunned:   # it reels: a quick side to side wobble
		draw_set_transform(Vector2(roundf(sin(_clock * 28.0) * 1.5), 0))
	draw_rect(Rect2(-18, -1, 36, 2), Color(0, 0, 0, 0.35))   # shadow on the floor
	var tell := _state == S.TELL_SLAM or _state == S.TELL_SHARDS
	var pulse := 0.5 + 0.5 * sin(_clock * 16.0)
	var b := body.lerp(glow, 0.35 * pulse) if tell else body
	var l := light.lerp(Color.WHITE, 0.6 * _flash)
	var d := dark
	if asleep:
		b = b.darkened(0.35)
		l = l.darkened(0.3)
		d = d.darkened(0.3)
	# orbiting crystals
	if not asleep:
		for k in 3 + region / 2:
			var a := _clock * (1.2 + 0.1 * region) + k * TAU / float(3 + region / 2)
			var c := Vector2(cos(a) * 24.0, -BODY_H * 0.55 + lift + sin(a) * 6.0)
			Glyphs.draw_diamond(self, c.floor(), 2, l)
			draw_rect(Rect2(c.floor() - Vector2(0, 0), Vector2(1, 1)), Color.WHITE)
	# the crystal body: two facets, a bevelled top
	var left := PackedVector2Array([Vector2(-14, lift), Vector2(-14, -16 + lift), Vector2(-8, -26 + lift), Vector2(0, -26 + lift), Vector2(0, lift)])
	var right := PackedVector2Array([Vector2(0, lift), Vector2(0, -26 + lift), Vector2(8, -26 + lift), Vector2(14, -16 + lift), Vector2(14, lift)])
	draw_colored_polygon(left, b)
	draw_colored_polygon(right, d)
	draw_rect(Rect2(-11, -22 + lift, 2, 14), l)
	draw_rect(Rect2(-11, -22 + lift, 2, 2), Color.WHITE if _flash > 0.2 else l)
	var outline := PackedVector2Array([Vector2(-14, lift), Vector2(-14, -16 + lift), Vector2(-8, -26 + lift), Vector2(8, -26 + lift), Vector2(14, -16 + lift), Vector2(14, lift), Vector2(-14, lift)])
	draw_polyline(outline, UITheme.INK, 1.0)
	# eyes: shut while asleep, narrow and bright otherwise (they follow the hero)
	var ey := -14 + lift
	if asleep:
		draw_rect(Rect2(-7, ey + 1, 4, 1), UITheme.INK)
		draw_rect(Rect2(3, ey + 1, 4, 1), UITheme.INK)
	elif stunned:     # crossed-out eyes
		for ex in [-6, 4]:
			for k in 3:
				draw_rect(Rect2(ex - 1 + k, ey - 1 + k, 1, 1), glow)
				draw_rect(Rect2(ex + 1 - k, ey - 1 + k, 1, 1), glow)
	else:
		var shift := 1 if _face > 0 else -1
		draw_rect(Rect2(-7 + shift, ey, 4, 2), glow)
		draw_rect(Rect2(3 + shift, ey, 4, 2), glow)
	# the heart: caged in a dark casing until the guardian tires, then bare and bright
	var hc := Vector2(0, -BODY_H - HEART_GAP - 5 + lift)
	var vuln := is_vulnerable()
	var hp_pulse := 0.5 + 0.5 * sin(_clock * 9.0)
	if vuln:
		Glyphs.draw_diamond(self, hc, 9, Color(glow, 0.18 + 0.18 * hp_pulse))
		Glyphs.draw_diamond(self, hc, 6, UITheme.INK)
		Glyphs.draw_diamond(self, hc, 5, glow.lerp(Color.WHITE, 0.5 * hp_pulse))
		Glyphs.draw_diamond(self, hc, 2, Color.WHITE)
		# a downward arrow of light: step on it
		for i in 3:
			draw_rect(Rect2(hc.x - 2 + i, hc.y - 14 - i + roundf(sin(_clock * 8.0) * 1.5), 5 - i * 2, 1), Color(glow, 0.9))
	else:
		Glyphs.draw_diamond(self, hc, 7, UITheme.INK)
		Glyphs.draw_diamond(self, hc, 6, d.lerp(b, 0.3))
		Glyphs.draw_diamond(self, hc, 3, b.lerp(glow, 0.15 if asleep else 0.35))
		draw_rect(Rect2(hc.x - 1, hc.y - 1, 2, 2), Color(glow, 0.45))
	if stunned:
		# little stars circling its head, and a ring showing how long the stun has left
		for k in 3:
			var a := _clock * 5.0 + k * TAU / 3.0
			var sp := (hc + Vector2(cos(a) * 13.0, sin(a) * 4.0 - 4.0)).floor()
			var star := Color("ffe08a")
			draw_rect(Rect2(sp - Vector2(1, 0), Vector2(3, 1)), star)
			draw_rect(Rect2(sp - Vector2(0, 1), Vector2(1, 3)), star)
		var remain := 1.0 - clampf(_t / STUN_TIME, 0.0, 1.0)
		for k in int(24 * remain):
			var a := -PI / 2.0 + k * TAU / 24.0
			draw_rect(Rect2((hc + Vector2(cos(a), sin(a)) * 11.0).floor(), Vector2(1, 1)), Color(1, 1, 1, 0.75))
		draw_set_transform(Vector2.ZERO)


func _draw_remains(pal: Array) -> void:
	var b: Color = pal[0]
	var l: Color = pal[1]
	var d: Color = pal[2]
	var glow: Color = pal[3]
	var t := 0.5 + 0.5 * sin(_clock * 2.0)
	for k in 5:
		var x := -16 + k * 8
		var h := 3 + (k * 7) % 5
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 0), Vector2(x, -h), Vector2(x + 3, 0)]), b if k % 2 == 0 else d)
		draw_rect(Rect2(x - 1, -h + 1, 1, 2), l)
	Glyphs.draw_diamond(self, Vector2(0, -12), 3, Color(glow, 0.25 + 0.2 * t))
	Glyphs.draw_diamond(self, Vector2(0, -12), 1, Color(1, 1, 1, 0.8))


func _draw_hazards(light: Color, glow: Color) -> void:
	var gx := global_position.x
	for w in _waves:
		var dir := int(w["dir"])
		var lx := float(w["x"]) - gx
		for k in 5:
			var x := lx - dir * k * 7.0
			var h := 13.0 - k * 2.0
			var c := glow if k == 0 else light.darkened(0.12 * k)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 0), Vector2(x, -h), Vector2(x + 4, 0)]), c)
			draw_rect(Rect2(x - 1, -h + 2, 1, 3), Color(1, 1, 1, 0.8 - k * 0.15))
	for s in _shards:
		if not bool(s["fall"]):
			continue
		var x := float(s["x"]) - gx
		var y := float(s["y"]) - global_position.y
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, y - 16), Vector2(x + 3, y - 16), Vector2(x, y)]), light)
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 16), Vector2(x + 3, y - 16), Vector2(x, y)]), light.darkened(0.3))
		draw_rect(Rect2(x - 1, y - 14, 1, 5), Color.WHITE)
