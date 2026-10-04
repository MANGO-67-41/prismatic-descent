class_name Player
extends CharacterBody2D
## The hero: a small white creature with big dark eyes, long ears, a long tail and a rust scarf.
## Sprite sheet: assets/hero/hero_sheet.png (24x24 frames, made by dev/make_hero.py). Hollow Knight-tight control; every number matches the movement
## model in dev/world_physics.py, which is what proved the rooms can be completed. Tune both together.
## Base kit: run, jump (variable height), wall cling and wall jump, dash. Position is the feet.

signal landed
signal pounded(at: Vector2)  ## ground pound hit the floor (breaks cracked floors)
signal ate

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
	["ascend", 4, 5.0, true], ["pound", 2, 14.0, true], ["eat", 3, 6.0, true],
]
const DOUBLE_JUMP_V := 230.0
const POUND_V := 460.0
const EAT_TIME := 1.0
const FAST_EAT_TIME := 0.3
const LAND_TIME := 0.12

var facing := 1
var input_enabled := true
var world: World  ## set by the game; used to find ropes and vines
var vitals: VitalsState  ## set by the game; abilities and food live here
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
var _ghost_t := 0.0


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


func _has(ability: String) -> bool:
	return vitals != null and bool(vitals.unlocked.get(ability, false))


func _physics_process(delta: float) -> void:
	_time += delta
	if frozen:
		_sprite.flip_h = facing < 0
		return
	var dir := Input.get_axis("move_left", "move_right") if input_enabled else 0.0
	var jump_pressed := input_enabled and Input.is_action_just_pressed("jump")
	var jump_held := input_enabled and Input.is_action_pressed("jump")
	var dash_pressed := input_enabled and Input.is_action_just_pressed("dash")
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	var up := input_enabled and Input.is_action_pressed("move_up")
	var down := input_enabled and Input.is_action_pressed("pound")
	if _climbing:
		_climb(delta, dir, up, down, jump_pressed, dash_pressed)
		return
	# Eat (hold): turns one food pip into one crystal; FAST HEAL makes it nearly instant.
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
	if input_enabled and Input.is_action_just_pressed("pound") and _has("pound") and not is_on_floor() and _dash_left <= 0.0:
		_pounding = true
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
		_dash_used = not is_on_floor()
	invincible = _dash_left > 0.0 and _has("dash_iframes")
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = Vector2(facing * DASH_V, 0.0)
		if invincible:
			_ghost_t -= delta
			if _ghost_t <= 0.0:
				_ghost_t = 0.03
				_spawn_ghost()
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


## The upgrade ascension: the game moves the hero and shows the floating pose.
func set_frozen(value: bool) -> void:
	frozen = value
	velocity = Vector2.ZERO
	_climbing = false
	_pounding = false
	_dash_left = 0.0
	_sprite.speed_scale = 1.0
	_sprite.play("ascend" if value else "idle")


## A fading copy of the current frame, tinted prismatic: the invincible dash's trail.
func _spawn_ghost() -> void:
	if get_parent() == null:
		return
	var g := Sprite2D.new()
	g.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	g.centered = false
	g.flip_h = _sprite.flip_h
	g.global_position = global_position + _sprite.position
	g.modulate = Color.from_hsv(fmod(_time * 1.5, 1.0) * 0.25 + 0.48, 0.55, 1.0, 0.7)
	g.z_index = z_index - 1
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_callback(g.queue_free)


func _try_eat(delta: float, dir: float) -> bool:
	var wants := input_enabled and Input.is_action_pressed("eat") and is_on_floor() and dir == 0.0 and vitals != null \
			and vitals.food > 0 and vitals.health < vitals.max_health
	if not wants:
		_eat_t = 0.0
		return false
	_eat_t += delta
	velocity = Vector2.ZERO
	if _eat_t >= (FAST_EAT_TIME if _has("fast_heal") else EAT_TIME):
		_eat_t = 0.0
		vitals.eat(-1)
		vitals.heal(1)
		ate.emit()
	move_and_slide()
	_after_move()
	return true


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
	_climbing = false
	_pounding = false
	position = pos
	velocity = Vector2.ZERO
	_dash_left = 0.0
