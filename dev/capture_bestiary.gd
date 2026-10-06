extends SceneTree
## Dev tool: a sheet of all twenty creatures, alive and moving (no hero), one row per region, saved 2x.
## Env: SHOT_OUT=path, SHOT_FRAMES=<physics frames to let them move first>

const CELL := Vector2(190, 120)
const TOP := 26.0

func _initialize() -> void:
	var out := OS.get_environment("SHOT_OUT") if OS.get_environment("SHOT_OUT") != "" else "/tmp/bestiary.png"
	var vp := SubViewport.new()
	vp.size = Vector2i(int(CELL.x * 4 + 20), int(TOP + CELL.y * 5 + 8))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("100c14")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var title := Label.new()
	title.text = "CREATURES OF THE DESCENT"
	title.label_settings = UITheme.label_settings(16, UITheme.CREAM, false, 2)
	title.position = Vector2(0, 4)
	title.size = Vector2(vp.size.x, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(title)
	var creatures: Array = []
	for r in 5:
		var row_col: Color = StoryData.COLOURS[r]
		var tag := Label.new()
		tag.text = StoryData.REGIONS[r]
		tag.label_settings = UITheme.label_settings(12, row_col, false, 1)
		tag.position = Vector2(6, TOP + r * CELL.y - 2)
		vp.add_child(tag)
		for c in 4:
			var kind: String = CreatureTypes.ORDER[r][c]
			var s := CreatureTypes.spec(kind)
			var cell := Rect2(Vector2(10 + c * CELL.x, TOP + r * CELL.y + 10), CELL - Vector2(10, 14))
			var panel := ColorRect.new()
			panel.color = Color(row_col.darkened(0.82), 1.0)
			panel.position = cell.position
			panel.size = cell.size
			vp.add_child(panel)
			var floor_y := cell.end.y - 16.0
			var body := StaticBody2D.new()
			body.collision_layer = 1
			for rect in [Rect2(cell.position.x, floor_y, cell.size.x, 16), Rect2(cell.position.x, cell.position.y - 6, cell.size.x, 8),
					Rect2(cell.position.x - 6, cell.position.y, 6, cell.size.y), Rect2(cell.end.x, cell.position.y, 6, cell.size.y)]:
				var cs := CollisionShape2D.new()
				var sh := RectangleShape2D.new()
				sh.size = rect.size
				cs.shape = sh
				cs.position = rect.get_center()
				body.add_child(cs)
			vp.add_child(body)
			var ground := ColorRect.new()
			ground.color = row_col.darkened(0.65)
			ground.position = Vector2(cell.position.x, floor_y)
			ground.size = Vector2(cell.size.x, 2)
			vp.add_child(ground)
			var x := cell.get_center().x
			var entry := {"t": kind, "x": x, "y": floor_y}
			match str(s["arch"]):
				"flit", "dive", "wyrm":
					entry["y"] = floor_y - 52.0
				"swim", "angler":
					entry = {"t": kind, "x": x, "y": floor_y - 14.0, "wy": floor_y - 44.0 - cell.position.y + 40.0, "fy": floor_y - cell.position.y + 40.0}
			var cr := CreatureTypes.make(kind)
			cr.setup(entry, null, Rect2(cell.position, cell.size).grow(40.0))
			if str(s["arch"]) == "swim":
				(cr as SwimmerCreature).top = floor_y - 44.0
				(cr as SwimmerCreature).bottom = floor_y - 4.0
			if str(s["arch"]) == "angler":
				(cr as AnglerCreature).top = floor_y - 44.0
				(cr as AnglerCreature).bottom = floor_y - 8.0
			vp.add_child(cr)
			creatures.append(cr)
			var name := Label.new()
			name.text = str(s["name"])
			name.label_settings = UITheme.label_settings(12, UITheme.CREAM_DIM, false, 1)
			name.position = Vector2(cell.position.x, cell.end.y - 14)
			name.size = Vector2(cell.size.x, 14)
			name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vp.add_child(name)
			if str(s["arch"]) == "burrow":
				var w := cr as BurrowerCreature
				w.set_meta("show_arc", true)
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var frames := int(OS.get_environment("SHOT_FRAMES")) if OS.get_environment("SHOT_FRAMES") != "" else 90
	for i in frames:
		for cr in creatures:
			if cr is BurrowerCreature:      # keep the worm out of the ground for the picture
				var w: BurrowerCreature = cr
				w._m = BurrowerCreature.M.ARC
				w._x0 = w.home.x - 50.0
				w._dir = 1
				w._floor = w.home.y
				w._mt = fmod(i / 60.0, 1.15) if i < frames - 1 else 0.62
		await physics_frame
	for cr in creatures:
		cr.modulate.a = 1.0          # the ambush lizards would be faded into the background: show them for the picture
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var k := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("saved ", out)
	quit()
