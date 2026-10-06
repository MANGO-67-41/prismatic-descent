extends SceneTree
## Dev tool: in-game screenshots of every screen of THE PRISMATIC LAKE (3x2), saved one by one (3x) and as a mosaic.
## Uses profile slot 4 and removes it again.

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

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
	await _frames(20)
	var lake := WorldData.pieces.size() - 1
	var p: Dictionary = WorldData.pieces[lake]
	var o := Vector2(float(p["x"]), float(p["y"]))
	for k in WorldData.pieces.size():
		game.discovered[k] = true
	# hero spots: top row floats hidden (camera only), bottom row stands on the stair foot, the bridge, the temple plinth
	var spots := [[Vector2(240, 150), false], [Vector2(720, 150), false], [Vector2(1200, 150), false],
			[Vector2(420, 478), true], [Vector2(760, 478), true], [Vector2(1220, 430), true]]
	var shots: Array[Image] = []
	for i in spots.size():
		var at: Vector2 = o + spots[i][0]
		game.player.respawn_at(at)
		game.world.update_focus(at, true)
		game.player.visible = spots[i][1]
		game.player.set_frozen(not spots[i][1])
		game.player.position = at
		await _frames(70)
		game.area_title.visible = false
		print(i, " hero ", game.player.position - o, " frozen ", game.player.frozen, " cam ", game.cam.global_position - o, " piece ", game.piece, " cer ", game.in_ceremony)
		await _frames(2)
		RenderingServer.force_draw(false)
		await _frames(1)
		RenderingServer.force_draw(false)
		var img := vp.get_texture().get_image()
		shots.append(img.duplicate())
		var big := img.duplicate()
		big.resize(1440, 810, Image.INTERPOLATE_NEAREST)
		big.save_png("res://.shots/lake_%d.png" % (i + 1))
	var mosaic := Image.create_empty(480 * 3, 270 * 2, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var s := shots[i]
		s.convert(Image.FORMAT_RGBA8)
		mosaic.blit_rect(s, Rect2i(0, 0, 480, 270), Vector2i((i % 3) * 480, (i / 3) * 270))
	mosaic.save_png("res://.shots/lake_mosaic.png")
	print("saved 6 + mosaic")
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	quit()
