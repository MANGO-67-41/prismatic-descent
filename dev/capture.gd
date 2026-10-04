extends SceneTree
## Dev tool: renders the title screen at its true 480x270 and saves it upscaled 3x (nearest).
## Usage: SHOT_SCREEN=0 SHOT_INDEX=0 SHOT_OUT=out.png Godot --path . --script res://dev/capture.gd

func _initialize() -> void:
	var screen := int(OS.get_environment("SHOT_SCREEN"))
	var index := int(OS.get_environment("SHOT_INDEX"))
	var out := OS.get_environment("SHOT_OUT")
	if out == "":
		out = "/tmp/title.png"
	# Optional sample profiles for screenshots; removed again afterwards (only slots that were empty).
	var fake: Array[int] = []
	if OS.get_environment("SHOT_FAKE") == "1":
		for slot in [1, 2]:
			if not SaveSlots.exists(slot):
				fake.append(slot)
		if fake.has(1):
			SaveSlots.write(1, {"location": "THE OVERGROWTH", "percent": 12, "playtime": 4980, "max_health": 5, "health": 5, "currency": 230})
		if fake.has(2):
			SaveSlots.write(2, {"location": "THE RUSTWORKS", "percent": 41, "playtime": 36420, "max_health": 7, "health": 4, "currency": 1876})
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: Control = load("res://scenes/ui/title_screen.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	await process_frame
	# The player's saved Fullscreen setting would hide this window on macOS; force windowed.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for _i in 30:
		await process_frame
	scene.debug_show(screen, index, OS.get_environment("SHOT_CAPTURE") == "1")
	for _i in 45:
		await process_frame
	var img := vp.get_texture().get_image()
	img.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	for slot in fake:
		SaveSlots.erase(slot)
	print("saved ", out)
	quit()
