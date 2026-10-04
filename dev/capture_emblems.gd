extends SceneTree
## Dev tool: renders the profile-row emblem for every region, lit and dim, at 3x. Env: SHOT_OUT=path
func _initialize() -> void:
	var out := OS.get_environment("SHOT_OUT")
	if out == "":
		out = "/tmp/emblems.png"
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var holder := Control.new()
	holder.theme = UITheme.build()
	vp.add_child(holder)
	var bg := ColorRect.new()
	bg.color = Color("120d14")
	bg.size = Vector2(480, 270)
	holder.add_child(bg)
	var regions := ["THE OVERGROWTH", "THE RUSTWORKS", "THE DROWNED WORKS", "THE BONE STACKS", "THE ASH DEEP"]
	for i in regions.size():
		var row := ProfileRow.new()
		holder.add_child(row)
		row.position = Vector2(60, 8 + i * 50)
		row.setup(i + 1, {"location": regions[i], "percent": 10 * (i + 1), "playtime": 3600, "max_health": 6, "health": 6, "currency": 100 * i})
		row.set_active(i % 2 == 0)
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for _i in 20:
		await process_frame
	var img := vp.get_texture().get_image()
	img.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("saved ", out)
	quit()
