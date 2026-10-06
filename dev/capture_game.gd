extends SceneTree
## Dev tool: renders the game at 480x270 (saved 3x). Env: SHOT_OUT=path, SHOT_PIECE=<piece id> (hero placed at its entrance),
## SHOT_MAP=quick|full, SHOT_REGION=<index> (start at that region's first room), SHOT_FRAMES=<physics frames to wait>. Uses profile slot 4 and removes it again.

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		print("slot 4 in use")
		quit()
		return
	var out := OS.get_environment("SHOT_OUT")
	if out == "":
		out = "/tmp/game.png"
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
	if OS.get_environment("SHOT_GIFTS") != "":   # unlock every gift so no ascension plays in the shot
		for a in game.vitals.unlocked:
			game.vitals.unlocked[a] = true
	var pid := OS.get_environment("SHOT_PIECE")
	if OS.get_environment("SHOT_REGION") != "":
		pid = str(int(WorldData.regions[int(OS.get_environment("SHOT_REGION"))]["first"]))
	if pid != "":
		var i := int(pid)
		var p: Dictionary = WorldData.pieces[i]
		var at := Vector2(float(p["x"]) + float(p["entry"][0]), float(p["y"]) + 5.0 * 8.0)
		# mark every earlier piece explored so the map has something to show
		for k in range(0, i + 1):
			game.discovered[k] = true
		game.player.respawn_at(at)
		game.world.update_focus(at, true)
		for _i in int(OS.get_environment("SHOT_FRAMES")) if OS.get_environment("SHOT_FRAMES") != "" else 80:
			await physics_frame
			if OS.get_environment("SHOT_TRACE") != "" and _i % 20 == 0:
				print(_i, " local ", game.player.position - Vector2(float(p["x"]), float(p["y"])), " floor ", game.player.is_on_floor(), " cer ", game.in_ceremony)
	if OS.get_environment("SHOT_HUD") != "":
		var v: VitalsState = game.vitals
		for k in 4: v.add_shard()
		v.hurt(3)
		v.energy = float(OS.get_environment("SHOT_HUD"))
		v.unlocked["pound"] = true
		v.unlocked["dash_iframes"] = true
		game.player._pound_cool = 2.0
		for _i in 50:
			await process_frame
	match OS.get_environment("SHOT_MAP"):
		"quick":
			game.world_map.press_quick()
		"full":
			game.world_map.press_full()
	for _i in 40:
		await process_frame
	print("hero at screen ", game.player.global_position - game.cam.global_position + Vector2(240, 135), " ceremony ", game.in_ceremony)
	var img := vp.get_texture().get_image()
	img.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("saved ", out)
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	quit()
