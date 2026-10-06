extends SceneTree
## Dev tool: SHOT_SCENE=rest|alert, SHOT_PIECE=<piece id>, SHOT_OUT=path. rest: the hero beside the room's resting lantern; alert: the first
## moments after the hero enters a room (the creatures' red marks). Uses profile slot 4.
func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		quit()
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	vp.add_child(game)
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for _i in 20:
		await process_frame
	for a in game.vitals.unlocked:
		game.vitals.unlocked[a] = true
	var i := int(OS.get_environment("SHOT_PIECE"))
	var p: Dictionary = WorldData.pieces[i]
	var org := Vector2(float(p["x"]), float(p["y"]))
	game.player.grant_invincibility(99.0)
	var wait := 90
	if OS.get_environment("SHOT_SCENE") == "rest":
		var r: Array = p["rest"][0]
		game.player.respawn_at(org + Vector2(float(r[0]) - 36.0, float(r[1]) - 1.0))
	else:
		game.player.respawn_at(org + Vector2(float(p["entry"][0]), 40.0))
		wait = int(OS.get_environment("SHOT_WAIT")) if OS.get_environment("SHOT_WAIT") != "" else 70
	game.world.update_focus(game.player.position, true)
	for _i in wait:
		await physics_frame
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	img.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	img.save_png(OS.get_environment("SHOT_OUT"))
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	quit()
