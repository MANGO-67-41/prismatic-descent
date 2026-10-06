extends SceneTree
## Dev tool: a strip of the bamboo stick's slash, close up: the sideways slash at three moments, the alternate slash coming back
## up, and the up-slash. SHOT_OUT=path. Uses profile slot 4.
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
	for _i in 40:
		await physics_frame
	game.player.grant_invincibility(99.0)
	var shots: Array[Image] = []
	var plan := [["side", [2, 4, 7]], ["alt", [3]], ["up", [3, 6]]]
	for step in plan:
		var kind: String = step[0]
		for at: int in step[1]:
			if kind == "up":
				Input.action_press("move_up")
			if kind == "alt":
				game.player._swing_cool = 0.0
				game.player._last_swing = game.player._time     # the next slash alternates
				game.player._swing_alt = false
			game.player._swing_cool = 0.0
			Input.action_press("attack")
			await physics_frame
			Input.action_release("attack")
			for _i in at:
				await physics_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			var hp := game.player.get_global_transform_with_canvas().origin
			var crop := img.get_region(Rect2i(int(hp.x) - 40, int(hp.y) - 52, 80, 64))
			crop.resize(80 * 5, 64 * 5, Image.INTERPOLATE_NEAREST)
			shots.append(crop)
			Input.action_release("move_up")
			for _i in 24:
				await physics_frame
	var strip := Image.create(400 * shots.size() + 8 * (shots.size() - 1), 320, false, Image.FORMAT_RGBA8)
	strip.fill(Color("120d14"))
	for i in shots.size():
		var s := shots[i]
		s.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(s, Rect2i(0, 0, 400, 320), Vector2i(i * 408, 0))
	strip.save_png(OS.get_environment("SHOT_OUT"))
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	quit()
