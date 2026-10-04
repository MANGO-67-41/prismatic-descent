extends SceneTree
## Dev tool: the hero in the real game, one crop per state (idle, run, jump, fall, wall, climb, dash), 4x, in a strip.
## Env: SHOT_OUT=path. Uses profile slot 4 and removes it again.

var game: Game
var vp: SubViewport

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame
	await process_frame

func _crop() -> Image:
	var img := vp.get_texture().get_image()
	var at := game.player.global_position - game.cam.global_position + Vector2(240, 135)
	var r := Rect2i(int(at.x) - 28, int(at.y) - 36, 56, 44)
	var c := img.get_region(r)
	c.resize(56 * 4, 44 * 4, Image.INTERPOLATE_NEAREST)
	return c

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
	var shots: Array[Image] = []
	var floor_at := game.player.position
	shots.append(_crop())                                        # idle
	Input.action_press("move_right"); await _frames(9); shots.append(_crop())   # run
	Input.action_press("jump"); await _frames(6); shots.append(_crop())         # jump (rising)
	await _frames(16); shots.append(_crop())                                     # fall
	Input.action_release("jump"); Input.action_release("move_right"); await _frames(40)
	var piece: Dictionary = WorldData.pieces[0]
	game.player.respawn_at(Vector2(float(piece["x"]) + 46.0, floor_at.y - 40.0))  # beside the left wall, in the air
	Input.action_press("move_left"); await _frames(10); shots.append(_crop())    # wall slide
	Input.action_release("move_left"); await _frames(30)
	var rp: Array = piece["ropes"][0]
	var bottom := Vector2(float(piece["x"]) + float(rp[0]), float(piece["y"]) + float(rp[1]) + float(rp[2]))
	game.player.respawn_at(bottom + Vector2(0, -2)); await _frames(20)
	Input.action_press("move_up"); await _frames(20); shots.append(_crop())      # climb
	Input.action_release("move_up"); await _frames(5)
	Input.action_press("jump"); await _frames(2); Input.action_release("jump"); await _frames(4)
	Input.action_press("dash"); await _frames(3); shots.append(_crop()); Input.action_release("dash")  # dash
	var w := 0
	for s in shots: w += s.get_width() + 4
	var strip := Image.create_empty(w, shots[0].get_height(), false, Image.FORMAT_RGBA8)
	strip.fill(Color("120d14"))
	var x := 0
	for s in shots:
		strip.blit_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i(x, 0))
		x += s.get_width() + 4
	strip.save_png(OS.get_environment("SHOT_OUT") if OS.get_environment("SHOT_OUT") != "" else "/tmp/hero.png")
	print("saved")
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	quit()
