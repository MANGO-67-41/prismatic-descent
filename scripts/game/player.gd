class_name Player
extends CharacterBody2D
## The hero: a small white creature with big dark eyes, long ears, a long tail and a rust scarf.
## Sprite sheet: assets/hero/hero_sheet.png (24x24 frames, made by dev/make_hero.py). Hollow Knight-tight control; every number matches the movement
## model in dev/world_physics.py, which is what proved the rooms can be completed. Tune both together.
## Base kit: run, jump (variable height), wall cling and wall jump, dash. Position is the feet.

signal landed
signal pounded(at: Vector2)  ## ground pound hit the floor (breaks cracked floors)
signal healed_self
signal hit(from_x: float)  ## the hero was hurt (health is already reduced)
signal swung(hitbox: Rect2, dir: int)  ## the bamboo stick reached its strike: world rectangle it covers

const SIZE := Vector2(10, 14)
const RUN := 110.0
const JUMP_V := 288.0
const GRAV_UP := 900.0
const GRAV_DOWN := 1500.0
const FALL_MAX := 400.0
const JUMP_CUT := 0.45
const DASH_V := 280.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.22
const WALL_SLIDE := 60.0
const WALL_JUMP_V := Vector2(120.0, 270.0)
const WALL_LOCK := 0.18
const COYOTE := 0.10
const BUFFER := 0.12
const CLIMB_SPEED := 70.0
const SHEET := preload("res://assets/hero/hero_sheet.png")
const CELL := 24
## name, frames, fps, loops (row order matches dev/make_hero.py)
const ANIMS := [
	["idle", 8, 7.0, true], ["run", 8, 15.0, true], ["jump", 2, 10.0, false], ["apex", 1, 1.0, false],
	["fall", 2, 8.0, true], ["land", 2, 16.0, false], ["wall", 2, 6.0, true], ["climb", 4, 9.0, true], ["dash", 2, 20.0, true],
	["ascend", 4, 5.0, true], ["pound", 2, 14.0, true], ["eat", 3, 6.0, true], ["swing", 4, 26.0, false],
]
const DOUBLE_JUMP_V := 277.0  ## second jump: ~45% higher (and farther) than the first version's 230
const POUND_V := 460.0
const HEAL_TIME := 1.0
const FAST_HEAL_TIME := 0.3
const POUND_COOLDOWN := 4.0
const IFRAME_COOLDOWN := 3.0  ## the dash is invincible at most once every 3 seconds
const LAND_TIME := 0.12
const HURT_STUN := 0.28  ## control is lost for this long after a hit
const HURT_IFRAMES := 1.3
const STOMP_BOUNCE := 230.0
const SWING_TIME := 0.2       ## the slash and its afterglow; the hero can move all the way through it
const SWING_COOLDOWN := 0.3   ## from one slash to the next (Hollow Knight's nail is 0.41, its quick slash 0.25)
const SWING_HIT_AT := 0.0     ## the stick lands on the very first frame: no wind-up
const SWING_RECOIL := 140.0   ## a sideways slash that hits something pushes the hero back a little

var facing := 1
var input_enabled := true
var world: World  ## set by the game; used to find ropes and vines
var vitals: VitalsState  ## set by the game; abilities, health and energy live here
var frozen := false  ## a cutscene (the upgrade ascension) moves the hero instead of physics
var invincible := false  ## true while dashing once INVINCIBLE DASH is learned

var _coyote := 0.0
var _buffer := 0.0
var _dash_left := 0.0
var _dash_cool := 0.0
var _dash_used := false
var _wall_lock := 0.0
var _was_floor := false
var _time := 0.0
var _climbing := false
var _rope: Dictionary = {}
var _sprite: AnimatedSprite2D
var _land_left := 0.0
var _on_wall := false
var _climb_moving := false
var _dj_used := false
var _pounding := false
var _eat_t := 0.0
var _pound_cool := 0.0
var _iframe_cool := 0.0
var _dash_invincible := false
var _streamer: AbilityFx.Streamer
var _hurt_t := 0.0
var _swing_t := -1.0  ## time since the swing began; below 0 when not swinging
var _swing_cool := 0.0
var _swing_hit_done := false
var _swing_up := false        ## this slash goes up (up was held when it began)
var _swing_alt := false       ## sideways slashes alternate: over the top and down, then from below and up
var _last_swing := -9.0
var _stick: BambooStick
var _inv_t := 0.0


func _init() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 3.0
	floor_stop_on_slope = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y / 2.0)
	add_child(shape)
	z_index = 10
	_stick = BambooStick.new()
	_stick.player = self
	add_child(_stick)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.centered = false
	_sprite.position = Vector2(-CELL / 2.0, -22.0)  # feet of the drawing sit on the collision box's bottom centre
	add_child(_sprite)
	_sprite.play("idle")


static func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in ANIMS.size():
		var a: Array = ANIMS[row]
		frames.add_animation(a[0])
		frames.set_animation_speed(a[0], a[2])
		frames.set_animation_loop(a[0], a[3])
		for i in int(a[1]):
			var tex := AtlasTexture.new()
			tex.atlas = SHEET
			tex.region = Rect2(i * CELL, row * CELL, CELL, CELL)
			frames.add_frame(a[0], tex)
	return frames


func is_swinging() -> bool:
	return _swing_t >= 0.0


## 0..1 through the current swing.
func swing_progress() -> float:
	return clampf(_swing_t / SWING_TIME, 0.0, 1.0)


## The stick follows the hero's flicker after a hit.
func stick_modulate() -> Color:
	return Color(1, 1, 1, _sprite.modulate.a)


## The bamboo stick: a short swing in front of the hero, on the ground or in the air. Movement carries on; facing is held.
func _update_swing(delta: float) -> void:
	_swing_cool = maxf(0.0, _swing_cool - delta)
	if is_swinging():
		_swing_t += delta
		if not _swing_hit_done and _swing_t >= SWING_HIT_AT:
			_swing_hit_done = true
			swung.emit(stick_hitbox(), facing)
		if _swing_t >= SWING_TIME:
			_swing_t = -1.0
	elif _ctl() and Input.is_action_just_pressed("attack") and _swing_cool <= 0.0 and _dash_left <= 0.0 and not _pounding and _eat_t <= 0.0:
		_swing_t = 0.0
		_swing_cool = SWING_COOLDOWN
		_swing_hit_done = false
		_swing_up = Input.is_action_pressed("move_up")
		_swing_alt = not _swing_alt if _time - _last_swing < 0.6 else false
		_last_swing = _time
		_sprite.play("swing")
		_sprite.frame = 1                # straight into the lunge: no wind-up


## What the stick covers at its strike, in world pixels: a long box in front of the hero from the feet to above the head, or
## (an up-slash) a box over the head.
func stick_hitbox() -> Rect2:
	if _swing_up:
		return Rect2(global_position.x - 14.0, global_position.y - 50.0, 28.0, 30.0)
	var x0 := global_position.x + (2.0 if facing > 0 else -32.0)
	return Rect2(x0, global_position.y - 26.0, 30.0, 26.0)


func swing_up() -> bool:
	return _swing_up


func swing_alt() -> bool:
	return _swing_alt


## The slash hit something: a sideways one pushes the hero back from it (Hollow Knight's nail recoil).
func recoil() -> void:
	if _swing_up or frozen:
		return
	velocity.x = -facing * SWING_RECOIL
	_wall_lock = maxf(_wall_lock, 0.08)


## Whether the player's keys move the hero: not during a cutscene or the moment after a hit.
func _ctl() -> bool:
	return input_enabled and _hurt_t <= 0.0


func is_pounding() -> bool:
	return _pounding


## Something hurt the hero from the side of `from_x`: one crystal, a short knock back, then a moment of safety.
## Returns false when nothing happened (the invincible dash, the moment after a hit, a cutscene).
func take_hit(from_x: float) -> bool:
	if vitals == null or frozen or invincible or _inv_t > 0.0 or vitals.health <= 0:
		return false
	vitals.hurt(1)
	_inv_t = HURT_IFRAMES
	_hurt_t = HURT_STUN
	_wall_lock = HURT_STUN
	var away := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(away * 130.0, -170.0)
	_climbing = false
	_pounding = false
	_dash_left = 0.0
	_swing_t = -1.0
	hit.emit(from_x)
	return true


## Springs off something stepped on: a hop upward, and the air moves are given back.
func bounce() -> void:
	velocity.y = -STOMP_BOUNCE
	_pounding = false
	_dj_used = false
	_dash_used = false
	_coyote = 0.0
	_sprite.play("jump")


## A lizard's tongue caught the hero: pulled toward `to_x` for a moment, out of control (no crystal lost; the bite does that).
func yank(to_x: float, speed: float) -> bool:
	if frozen or invincible or _inv_t > 0.0 or _hurt_t > 0.0 or vitals == null or vitals.health <= 0:
		return false
	velocity = Vector2((1.0 if to_x > global_position.x else -1.0) * speed, -110.0)
	_hurt_t = 0.3
	_wall_lock = 0.3
	_climbing = false
	_pounding = false
	_dash_left = 0.0
	_swing_t = -1.0
	return true


func grant_invincibility(seconds: float) -> void:
	_inv_t = maxf(_inv_t, seconds)


func _has(ability: String) -> bool:
	return vitals != null and bool(vitals.unlocked.get(ability, false))


func _physics_process(delta: float) -> void:
	_time += delta
	_hurt_t = maxf(0.0, _hurt_t - delta)
	_inv_t = maxf(0.0, _inv_t - delta)
	if frozen:
		_sprite.flip_h = facing < 0
		return
	var dir := Input.get_axis("move_left", "move_right") if _ctl() else 0.0
	var jump_pressed := _ctl() and Input.is_action_just_pressed("jump")
	var jump_held := _ctl() and Input.is_action_pressed("jump")
	var dash_pressed := _ctl() and Input.is_action_just_pressed("dash")
	if dir != 0.0 and not is_swinging():
		facing = 1 if dir > 0.0 else -1
	var up := _ctl() and Input.is_action_pressed("move_up")
	var down := _ctl() and Input.is_action_pressed("pound")
	if _climbing:
		_climb(delta, dir, up, down, jump_pressed, dash_pressed)
		return
	_pound_cool = maxf(0.0, _pound_cool - delta)
	_iframe_cool = maxf(0.0, _iframe_cool - delta)
	_update_swing(delta)
	# Heal (hold, with a full energy circle): restores one crystal; FAST HEAL makes it nearly instant.
	if _try_eat(delta, dir):
		return
	# Ground pound: straight down, fast, breaks cracked floors.
	if _pounding:
		velocity = Vector2(0.0, POUND_V)
		move_and_slide()
		if is_on_floor():
			_pounding = false
			pounded.emit(global_position)
		_after_move()
		return
	if (up or down) and _dash_left <= 0.0 and world != null:
		var rope := world.rope_at(global_position + Vector2(0, -SIZE.y / 2.0))
		if not rope.is_empty() and ((up and global_position.y > float(rope["top"]) + 12.0) or (down and global_position.y < float(rope["bottom"]) - 2.0)):
			_grab(rope)
			return
	if _ctl() and Input.is_action_just_pressed("pound") and _has("pound") and not is_on_floor() and _dash_left <= 0.0 and _pound_cool <= 0.0:
		_pounding = true
		_pound_cool = POUND_COOLDOWN
		return

	if is_on_floor():
		_coyote = COYOTE
		_dash_used = false
		_dj_used = false
	else:
		_coyote = maxf(0.0, _coyote - delta)
	_buffer = BUFFER if jump_pressed else maxf(0.0, _buffer - delta)
	_dash_cool = maxf(0.0, _dash_cool - delta)
	_wall_lock = maxf(0.0, _wall_lock - delta)

	# Dash: a fixed burst with gravity suspended, once per time in the air.
	if dash_pressed and _dash_left <= 0.0 and _dash_cool <= 0.0 and not _dash_used:
		_dash_left = DASH_TIME
		_dash_cool = DASH_COOLDOWN + DASH_TIME
		_dash_invincible = _has("dash_iframes") and _iframe_cool <= 0.0
		if _dash_invincible:
			_iframe_cool = IFRAME_COOLDOWN
		_dash_used = not is_on_floor()
	invincible = _dash_left > 0.0 and _dash_invincible
	if _dash_left <= 0.0 and _streamer != null and is_instance_valid(_streamer):
		_streamer.finish()
		_streamer = null
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = Vector2(facing * DASH_V, 0.0)
		if invincible and get_parent() != null:
			if _streamer == null or not is_instance_valid(_streamer):
				_streamer = AbilityFx.streamer(get_parent())
			_streamer.add_point(global_position)
		move_and_slide()
		if is_on_wall():
			_dash_left = 0.0
		_after_move()
		return

	# Horizontal: instant, with a short lockout after a wall jump so it cannot be spammed up one wall.
	if _wall_lock <= 0.0:
		velocity.x = dir * RUN
	# Vertical
	var gravity := GRAV_UP if velocity.y < 0.0 else GRAV_DOWN
	velocity.y = minf(FALL_MAX, velocity.y + gravity * delta)
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -JUMP_V
		_buffer = 0.0
		_coyote = 0.0
	elif _buffer > 0.0 and is_on_wall_only() and _wall_lock <= 0.0:
		var away := get_wall_normal().x
		velocity = Vector2(away * WALL_JUMP_V.x, -WALL_JUMP_V.y)
		facing = 1 if away > 0.0 else -1
		_wall_lock = WALL_LOCK
		_dash_used = false
		_dj_used = false
		_buffer = 0.0
	elif jump_pressed and _has("double_jump") and not _dj_used and not is_on_floor():
		velocity.y = -DOUBLE_JUMP_V
		_dj_used = true
		_buffer = 0.0
		AbilityFx.wings(self, facing)
		_sprite.play("jump")
		_sprite.frame = 0
	if velocity.y < 0.0 and not jump_held and _wall_lock <= 0.0:
		velocity.y *= JUMP_CUT if velocity.y < -60.0 else 1.0
	_on_wall = false
	if is_on_wall_only() and velocity.y > 0.0:
		velocity.y = minf(velocity.y, WALL_SLIDE)
		_dash_used = false
		_on_wall = true
		facing = -1 if get_wall_normal().x > 0.0 else 1
	move_and_slide()
	_after_move()


func _after_move() -> void:
	var delta := get_physics_process_delta_time()
	if is_on_floor() and not _was_floor and not _climbing:
		_land_left = LAND_TIME
		landed.emit()
	_was_floor = is_on_floor()
	_land_left = maxf(0.0, _land_left - delta)
	_animate()


## Picks the animation for the current state. Facing flips the drawing.
func _animate() -> void:
	var anim := "idle"
	_sprite.speed_scale = 1.0
	if _climbing:
		anim = "climb"
		_sprite.speed_scale = 1.0 if _climb_moving else 0.0
	elif _eat_t > 0.0:
		anim = "eat"
	elif _pounding:
		anim = "pound"
	elif _dash_left > 0.0:
		anim = "dash"
	elif is_swinging():
		anim = "swing"
	elif is_on_floor():
		if _land_left > 0.0:
			anim = "land"
		elif absf(velocity.x) > 5.0:
			anim = "run"
	elif _on_wall:
		anim = "wall"
	elif velocity.y < -70.0:
		anim = "jump"
	elif velocity.y < 70.0:
		anim = "apex"
	else:
		anim = "fall"
	if _sprite.animation != anim and not (anim == "jump" and _sprite.animation == "jump"):
		_sprite.play(anim)
	_sprite.flip_h = facing < 0
	_sprite.modulate = Color(0.75, 1.0, 1.0) if invincible else Color.WHITE
	if _inv_t > 0.0 and int(_time * 24.0) % 2 == 0:
		_sprite.modulate.a = 0.35   # flicker while safe after a hit


## The upgrade ascension: the game moves the hero and shows the floating pose.
func set_frozen(value: bool) -> void:
	frozen = value
	_swing_t = -1.0
	velocity = Vector2.ZERO
	_climbing = false
	_pounding = false
	_dash_left = 0.0
	_sprite.speed_scale = 1.0
	_sprite.play("ascend" if value else "idle")


func _try_eat(delta: float, dir: float) -> bool:
	var wants := _ctl() and Input.is_action_pressed("eat") and is_on_floor() and dir == 0.0 and vitals != null \
			and vitals.energy_full() and vitals.health < vitals.max_health
	if not wants:
		_eat_t = 0.0
		if vitals != null:
			vitals.heal_progress = 0.0
		return false
	_eat_t += delta
	var need := FAST_HEAL_TIME if _has("fast_heal") else HEAL_TIME
	vitals.heal_progress = clampf(_eat_t / need, 0.0, 1.0)
	velocity = Vector2.ZERO
	if _eat_t >= need:
		_eat_t = 0.0
		vitals.heal_progress = 0.0
		vitals.spend_energy_heal()
		healed_self.emit()
	move_and_slide()
	_after_move()
	return true


## 0..1: how recharged an ability is (1 = ready). "pound" or "dash_iframes".
func cooldown_fraction(ability: String) -> float:
	if ability == "pound":
		return 1.0 - _pound_cool / POUND_COOLDOWN
	return 1.0 - _iframe_cool / IFRAME_COOLDOWN


func _grab(rope: Dictionary) -> void:
	_climbing = true
	_rope = rope
	velocity = Vector2.ZERO
	position.x = float(rope["x"])
	_dash_used = false
	_dash_left = 0.0
	_animate()


func _release() -> void:
	_climbing = false
	_rope = {}


## On a rope or vine: up/down climb, jump leaps off (with a push if a direction is held), the ground or the end lets go.
func _climb(delta: float, dir: float, up: bool, down: bool, jump_pressed: bool, dash_pressed: bool) -> void:
	if jump_pressed:
		_release()
		velocity = Vector2(dir * RUN, -JUMP_V * 0.85)
		_coyote = 0.0
		_buffer = 0.0
		move_and_slide()
		_after_move()
		return
	if dash_pressed:
		_release()
		return
	var vy := (CLIMB_SPEED if down else 0.0) - (CLIMB_SPEED if up else 0.0)
	_climb_moving = vy != 0.0
	if world != null and ((up and position.y <= float(_rope["top"]) + 11.0) or (down and position.y >= float(_rope["bottom"]) - 1.0)):
		var next := world.rope_at(global_position + Vector2(0, -22.0 if up else 8.0))
		if not next.is_empty() and next != _rope and absf(float(next["x"]) - float(_rope["x"])) < 4.0:
			_rope = next
	var top := float(_rope["top"]) + 10.0
	var bottom := float(_rope["bottom"])
	var step := clampf(position.y + vy * delta, top, bottom) - position.y
	var hit := move_and_collide(Vector2(0, step))
	position.x = float(_rope["x"])
	velocity = Vector2.ZERO
	if (hit != null and vy > 0.0) or (position.y >= bottom - 0.5 and vy > 0.0):
		_release()      # stepped onto the floor, or climbed off the end
	elif dir != 0.0 and is_on_floor():
		_release()
	_was_floor = true
	_after_move()


func respawn_at(pos: Vector2) -> void:
	_hurt_t = 0.0
	_swing_t = -1.0
	_climbing = false
	_pounding = false
	position = pos
	velocity = Vector2.ZERO
	_dash_left = 0.0
