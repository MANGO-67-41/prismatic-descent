extends SceneTree
## Dev tool: renders the pause menu (main or options page) at 480x270, saved 3x.
## Env: SHOT_OUT=path, SHOT_PAGE=main|options, SHOT_INDEX=<row>

func _initialize() -> void:
	var out := OS.get_environment("SHOT_OUT")
	if out == "":
		out = "/tmp/pause.png"
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: Control = load("res://scenes/ui/ui_preview.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for _i in 30:
		await process_frame
	scene.pause_menu.open()
	if OS.get_environment("SHOT_PAGE") == "options":
		scene.pause_menu._show_page(1)
	scene.pause_menu._index = int(OS.get_environment("SHOT_INDEX"))
	scene.pause_menu._refresh()
	scene.pause_menu._place_selector(false)
	for _i in 60:
		await process_frame
	var img := vp.get_texture().get_image()
	img.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	scene.pause_menu.close()
	print("saved ", out)
	quit()
