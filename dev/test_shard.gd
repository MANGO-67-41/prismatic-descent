extends SceneTree
## Dev test: the crystal shard moment (profile slot 4). A guardian's fall plays it: the first shard of a pair is a half crystal that flies
## to the shard circle, the second joins it into a whole crystal that flies to the new crystal's place in the HUD row; the shard is only
## added as it lands, the hero cannot move during it, and the toast follows. Run: Godot --headless --path . --script res://dev/test_shard.gd

var _failures := 0

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures += 1

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		print("slot 4 in use; skipping")
		quit()
		return
	WorldData.ensure_loaded()
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(game)
	await _frames(30)
	_check("starting point: no shards, six crystals", game.vitals.shards == 0 and game.vitals.max_health == 6)
	game.guardian_defeated("t1", 0)
	await _frames(10)
	_check("the first shard plays the shard moment (a half crystal)", game.shard_screen.is_playing() and not game.shard_screen._whole)
	_check("it flies to the shard circle", game.shard_screen._target == game.hud.circle_center())
	_check("the shard is not added until it lands", game.vitals.shards == 0)
	_check("the hero cannot move during it", not game.player.input_enabled)
	await _frames(200)
	_check("it lands: one shard, still six crystals", game.vitals.shards == 1 and game.vitals.max_health == 6)
	await _frames(60)
	_check("it is over and the hero can move again", not game.shard_screen.is_playing() and game.player.input_enabled)
	game.guardian_defeated("t2", 1)
	await _frames(10)
	_check("the second shard joins the first into a whole crystal", game.shard_screen.is_playing() and game.shard_screen._whole)
	_check("and flies to the new crystal's place in the row", game.shard_screen._target == game.hud.pip_center(6))
	await _frames(240)
	_check("it lands: two shards, seven crystals, healed", game.vitals.shards == 2 and game.vitals.max_health == 7 and game.vitals.health == 7)
	await _frames(60)
	_check("the toast about the guardian follows", game.toast.visible)
	# a skip: the words are up, jump hurries it on
	game.guardian_defeated("t3", 2)
	await _frames(100)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(100)
	_check("jump hurries it on (the third shard has landed well before the full time)", game.vitals.shards == 3)
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	print("RESULT: %d failure(s)" % _failures)
	quit()
