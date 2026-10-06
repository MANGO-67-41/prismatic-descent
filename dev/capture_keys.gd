extends SceneTree
## Dev tool: the inventory (the FAST HEAL text, the longest) and a scroll with the keys remapped (arrows and F keys), to see that the
## instructions follow them and still fit. SHOT_OUT=prefix (writes prefix_inventory.png and prefix_scroll.png). Uses profile slot 4.
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
	KeyBindings.keys = KeyBindings.DEFAULTS.duplicate()
	KeyBindings.keys["jump"] = KEY_UP
	KeyBindings.keys["dash"] = KEY_RIGHT
	KeyBindings.keys["eat"] = KEY_F5
	KeyBindings.keys["pound"] = KEY_DOWN
	KeyBindings.keys["attack"] = KEY_Z
	KeyBindings.apply()
	for a in game.vitals.unlocked:
		game.vitals.unlocked[a] = true
	var prefix := OS.get_environment("SHOT_OUT")
	game.inventory._build_slots()
	game.inventory.open()
	game.inventory._sel = 3
	game.inventory._refresh()
	for _i in 12:
		await process_frame
	var img := vp.get_texture().get_image()
	img.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	img.save_png(prefix + "_inventory.png")
	game.inventory.close()
	var sc := StoryData.scroll("s01")
	game.scroll_reader.open(str(sc["title"]), sc["pages"])
	for _i in 60:
		await process_frame
	img = vp.get_texture().get_image()
	img.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	img.save_png(prefix + "_scroll.png")
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	quit()
