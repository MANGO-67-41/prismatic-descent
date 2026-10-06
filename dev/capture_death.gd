extends SceneTree
## Dev tool: the death screen at six moments (the crystal rises, it cracks, it bursts, the words, the ink closing, waking at the
## lantern), in a 3 x 2 sheet at 1x. SHOT_OUT=path. Uses profile slot 4.
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
	for _i in 60:
		await physics_frame
	game.vitals.health = 1
	game.player.take_hit(game.player.position.x - 8.0)
	var moments := [0.3, 0.8, 1.04, 2.5, 3.3, 4.25]
	var sheet := Image.create(480 * 3, 270 * 2, false, Image.FORMAT_RGBA8)
	for i in moments.size():
		while game.death_screen._t < moments[i] and game.death_screen.is_playing():
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, 480, 270), Vector2i((i % 3) * 480, (i / 3) * 270))
	sheet.save_png(OS.get_environment("SHOT_OUT"))
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	quit()
