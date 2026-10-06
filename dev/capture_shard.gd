extends SceneTree
## Dev tool: the crystal shard moment at six moments, in a 3 x 2 sheet at 1x. SHOT_MODE=half (the first shard) or whole (the second, which
## completes a crystal). SHOT_OUT=path. Uses profile slot 4.
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
	var whole := OS.get_environment("SHOT_MODE") == "whole"
	if whole:
		game.vitals.shards = 1
	game.guardian_defeated("shot", 0)
	var moments := [0.3, 0.7, 1.0, 1.2, 2.2, 2.8] if whole else [0.3, 0.7, 1.5, 2.6, 2.95, 3.2]
	if whole:
		moments = [0.5, 0.9, 1.2, 2.0, 3.25, 3.7]
	var sheet := Image.create(480 * 3, 270 * 2, false, Image.FORMAT_RGBA8)
	for i in moments.size():
		while game.shard_screen._t < moments[i] and game.shard_screen.is_playing():
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
