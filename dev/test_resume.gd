extends SceneTree
## Dev test: coming back to a profile puts the hero at the last lantern they rested at (not where they stood), healed, and the corner
## says LANTERN ROOM; and the old debug keys (R unlocked abilities, H hurt, ...) do nothing in the game. Uses profile slot 4.
## Run: Godot --headless --path . --script res://dev/test_resume.gd

var _failures := 0

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures += 1

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await physics_frame

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		print("slot 4 in use; skipping")
		quit()
		return
	WorldData.ensure_loaded()
	SaveSlots.create_new(4)
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(game)
	await _frames(30)
	# the old debug keys do nothing
	var before := game.vitals.unlocked.duplicate()
	var hp := game.vitals.health
	for code in [KEY_R, KEY_R, KEY_R, KEY_R, KEY_H, KEY_K, KEY_G, KEY_T, KEY_C, KEY_U]:
		await _key(code)
	_check("R does not hand out abilities (and H, K, G, T, C do nothing either)", game.vitals.unlocked == before and game.vitals.health == hp and game.vitals.currency == 0)
	# rest at a lantern in some later room, then walk away and leave
	var lantern := Vector2.ZERO
	var id := -1
	for i in WorldData.pieces.size():
		var p: Dictionary = WorldData.pieces[i]
		if (p["rest"] as Array).size() > 0 and i > 8:
			var r: Array = p["rest"][0]
			lantern = Vector2(float(p["x"]) + float(r[0]), float(p["y"]) + float(r[1]))
			id = i
			break
	game.rest_pos = lantern
	game.player.respawn_at(Vector2(float(WorldData.pieces[0]["x"]) + 120.0, float(WorldData.pieces[0]["y"]) + 200.0))
	game.vitals.health = 2
	game._save()
	game.queue_free()
	await process_frame
	await _frames(3)
	var again: Game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(again)
	await _frames(30)
	_check("coming back, the hero is at the last lantern they rested at", again.player.position.distance_to(lantern) < 4.0 and again.piece == id)
	_check("healed: a lantern mends every crystal", again.vitals.health == again.vitals.max_health)
	_check("the bottom right corner says LANTERN ROOM", again.area_title.shown_name == "LANTERN ROOM")
	again.queue_free()
	await process_frame
	SaveSlots.erase(4)
	print("RESULT: %d failure(s)" % _failures)
	quit()
