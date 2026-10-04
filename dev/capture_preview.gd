extends SceneTree
## Dev tool: renders the HUD / inventory preview at 480x270 and saves it 3x (nearest).
## Env: SHOT_OUT=path, SHOT_INV=1 (open inventory), SHOT_SEL=<slot index>, SHOT_STATE=full|hurt|low|max, SHOT_SHATTER=1, SHOT_MAP=quick|full|full_low

func _initialize() -> void:
	var out := OS.get_environment("SHOT_OUT")
	if out == "":
		out = "/tmp/preview.png"
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
	var v: VitalsState = scene.vitals
	match OS.get_environment("SHOT_STATE"):
		"hurt":
			v.hurt(2)
		"low":
			v.hurt(v.health - 1)
			v.food = 0
		"max":
			for i in 10:
				v.add_shard()
			for id in VitalsState.ABILITY_ORDER:
				v.unlock_next()
			v.hurt(3)
	if OS.get_environment("SHOT_SHATTER") == "1":
		v.hurt(1)
	if OS.get_environment("SHOT_STATE") == "inv_partial":
		v.unlock_next()
		v.unlock_next()
		v.add_shard()
		v.add_shard()
		v.add_shard()
	if OS.get_environment("SHOT_INV") == "1":
		scene.inventory.open()
		var sel := int(OS.get_environment("SHOT_SEL"))
		scene.inventory._sel = sel
		scene.inventory._refresh()
	match OS.get_environment("SHOT_MAP"):
		"quick":
			scene.world_map.press_quick()
		"full":
			scene.world_map.press_full()
		"full_low":
			scene.world_map.press_full()
			scene.world_map._scroll = 999.0
			scene.world_map.queue_redraw()
	for _i in 60:
		await process_frame
	var img := vp.get_texture().get_image()
	img.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("saved ", out)
	quit()
