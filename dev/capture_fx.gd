extends SceneTree
## Dev tool: the ability effects in the real game, two moments each (wings, shockwave, streamer), 4x crops in one strip.
## Env: SHOT_OUT=path. Uses profile slot 4 and removes it again.

var game: Game
var vp: SubViewport
var shots: Array[Image] = []

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame
	await process_frame

func _crop(centre: Vector2) -> void:
	var img := vp.get_texture().get_image()
	var at := centre - game.cam.global_position + Vector2(240, 135)
	var w := 96
	var h := 60
	var c := img.get_region(Rect2i(int(at.x) - w / 2, int(at.y) - h + 12, w, h))
	c.resize(w * 4, h * 4, Image.INTERPOLATE_NEAREST)
	shots.append(c)

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		quit()
		return
	vp = SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	game = load("res://scenes/game/game.tscn").instantiate()
	vp.add_child(game)
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _frames(40)
	for a in game.vitals.unlocked:
		game.vitals.unlocked[a] = true
	var floor_at := game.player.position + Vector2(40, 0)
	game.player.respawn_at(floor_at)
	await _frames(20)
	# wings
	Input.action_press("jump"); await _frames(16); Input.action_release("jump"); await _frames(1)
	Input.action_press("jump"); await _frames(3); _crop(game.player.global_position)
	await _frames(6); _crop(game.player.global_position)
	Input.action_release("jump"); await _frames(60)
	# shockwave
	game.player.respawn_at(floor_at + Vector2(0, -50)); await _frames(2)
	Input.action_press("pound"); await _frames(1); Input.action_release("pound")
	var landed := false
	for _i in 60:
		await physics_frame
		if game.player.is_on_floor():
			landed = true
			break
	await _frames(3); _crop(floor_at)
	await _frames(8); _crop(floor_at)
	await _frames(40)
	# streamer
	game.player.respawn_at(floor_at + Vector2(-60, 0)); await _frames(20)
	Input.action_press("dash"); await _frames(6); _crop(game.player.global_position + Vector2(-20, 0)); Input.action_release("dash")
	await _frames(6); _crop(game.player.global_position + Vector2(-20, 0))
	var wsum := 0
	for s in shots: wsum += s.get_width() + 4
	var strip := Image.create_empty(wsum, shots[0].get_height(), false, Image.FORMAT_RGBA8)
	strip.fill(Color("120d14"))
	var x := 0
	for s in shots:
		strip.blit_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i(x, 0))
		x += s.get_width() + 4
	strip.save_png(OS.get_environment("SHOT_OUT") if OS.get_environment("SHOT_OUT") != "" else "/tmp/fx.png")
	print("saved, landed ", landed)
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	quit()
