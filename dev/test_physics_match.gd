extends SceneTree
## Dev test: the real in-game hero against the numbers the room checker (dev/world_physics.py) assumes.
## Jump height, jump distance, jump+dash distance and wall-jump height must be at least what the checker assumes (and not wildly more), otherwise rooms
## that were proved completable might not be completable in the game. Run: Godot --headless --path . --script dev/test_physics_match.gd

var _failures := 0

func _check(name: String, ok: bool, detail: String = "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("   " + detail if detail != "" else ""))
	if not ok:
		_failures += 1

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame

func _measure(game: Game, at: Vector2, left: bool, right: bool, dash_frame: int, wall_spam: bool) -> Dictionary:
	var p := game.player
	p.respawn_at(at)
	await _frames(25)
	var start := p.position
	var top := p.position.y
	if right: Input.action_press("move_right")
	if left: Input.action_press("move_left")
	Input.action_press("jump")
	var left_ground := false
	for f in 150:
		if f == dash_frame:
			Input.action_press("dash")
		elif f == dash_frame + 1:
			Input.action_release("dash")
		if wall_spam and f > 2 and f % 2 == 0:
			Input.action_release("jump")
		elif wall_spam and f > 2:
			Input.action_press("jump")
		await physics_frame
		top = minf(top, p.position.y)
		if not p.is_on_floor():
			left_ground = true
		elif left_ground and not wall_spam:
			break
	Input.action_release("jump"); Input.action_release("move_left"); Input.action_release("move_right"); Input.action_release("dash")
	return {"apex": start.y - top, "dx": p.position.x - start.x}

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		quit()
		return
	WorldData.ensure_loaded()
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(game)
	await _frames(30)
	var piece: Dictionary = WorldData.pieces[0]
	var floor_at := game.player.position
	var a := await _measure(game, floor_at, false, true, -1, false)
	_check("jump is at least as high as the checker assumes (43.7 px) and not much higher", a["apex"] >= 43.7 - 2.0 and a["apex"] < 43.7 + 10.0, "engine %.1f" % a["apex"])
	_check("jump distance is at least the checker's (62.3 px)", a["dx"] >= 62.3 - 3.0 and a["dx"] < 62.3 + 15.0, "engine %.1f" % a["dx"])
	var b := await _measure(game, floor_at, false, true, 15, false)
	_check("jump + dash distance is at least the checker's (99.8 px)", b["dx"] >= 99.8 - 4.0 and b["dx"] < 99.8 + 20.0, "engine %.1f" % b["dx"])
	var wall := Vector2(float(piece["x"]) + 5.0 * 8.0 + 5.5, floor_at.y)
	var c := await _measure(game, wall, true, false, -1, true)
	_check("wall jump climbs about as high as the checker says (81.8 px)", c["apex"] > 70.0, "engine %.1f" % c["apex"])
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	print("RESULT: %d failure(s)" % _failures)
	quit()
