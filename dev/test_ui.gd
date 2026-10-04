extends SceneTree
## Dev test: drives the title screen with simulated mouse and keyboard input and checks the result.
## Run: Godot --path . --script res://dev/test_ui.gd
## Note: rebinding writes user://bindings.cfg; this test resets it to defaults when it finishes.

var _failures := 0


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures += 1


func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = true
	return ev


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: Control = load("res://scenes/ui/title_screen.tscn").instantiate()
	vp.add_child(scene)
	scene.open_game_on_start = false
	for _i in 5:
		await process_frame

	# Mouse hover selects a row.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(240, 114 + 19 * 2 + 8)  # third row (CONTROLS)
	vp.push_input(motion)
	await process_frame
	_check("hover selects CONTROLS (index 2)", scene._index == 2)

	# Click opens the controls screen.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = motion.position
	vp.push_input(click)
	await process_frame
	await process_frame
	_check("click opens CONTROLS screen", scene._screen == 2)

	# Keyboard: Down three times to JUMP (after MOVE LEFT, MOVE RIGHT, CLIMB UP), Enter starts capture, press K to bind.
	scene._select(0)
	for _n in 3:
		vp.push_input(_key(KEY_S))
		await process_frame
	_check("S moves selection down to JUMP", scene._rows[scene._index]["id"] == "jump")
	var accept := InputEventKey.new()
	accept.physical_keycode = KEY_ENTER
	accept.keycode = KEY_ENTER
	accept.pressed = true
	vp.push_input(accept)
	await process_frame
	_check("Enter starts key capture", scene._capturing_row == scene._index)
	vp.push_input(_key(KEY_K))
	await process_frame
	_check("capture binds K to JUMP", KeyBindings.keys["jump"] == KEY_K and scene._capturing_row == -1)
	_check("InputMap jump action has K", InputMap.action_has_event("jump", _key(KEY_K)))

	# Duplicate key swaps with the other action.
	scene._select(0)
	scene._begin_capture(0)
	vp.push_input(_key(KEY_K))
	await process_frame
	_check("binding MOVE LEFT to K swaps with JUMP", KeyBindings.keys["move_left"] == KEY_K and KeyBindings.keys["jump"] == KEY_A)

	# Reserved key is refused and capture stays open.
	scene._begin_capture(0)
	vp.push_input(_key(KEY_LEFT))
	await process_frame
	_check("arrow key refused as reserved", scene._capturing_row == 0)
	vp.push_input(_key(KEY_ESCAPE))
	await process_frame
	_check("Escape cancels capture", scene._capturing_row == -1)

	# Reset defaults.
	KeyBindings.reset_defaults()
	_check("reset restores A for MOVE LEFT", KeyBindings.keys["move_left"] == KEY_A)

	# Back to main and back via right click.
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = Vector2(10, 10)
	vp.push_input(right)
	await process_frame
	_check("right click goes back to MAIN", scene._screen == 0)

	# Profiles: START GAME opens the slot screen; a new slot is created, then cleared in two steps.
	var had_saves: Array[bool] = []
	for slot in range(1, 5):
		had_saves.append(SaveSlots.exists(slot))
	scene._select(0)
	scene._activate()
	await process_frame
	_check("START GAME opens SELECT PROFILE", scene._screen == 3 and scene._rows.size() == 4)
	scene._select(2)
	if not had_saves[2]:
		scene._activate()
		await process_frame
		_check("NEW GAME on slot 3 creates a save", SaveSlots.exists(3) and SaveSlots.read(3)["max_health"] == 6)
		scene._request_clear()
		_check("first clear press only arms", SaveSlots.exists(3) and scene._clear_armed == 3)
		scene._request_clear()
		_check("second clear press erases the save", not SaveSlots.exists(3))
	else:
		print("SKIP  slot 3 already holds a real save; not touching it")
	scene._back()
	await process_frame
	_check("Esc from profiles returns to MAIN", scene._screen == 0)

	# Health crystals: 6 to start, +1 per 2 shards, capped at 11.
	var v := VitalsState.new()
	var shattered := []
	v.damaged.connect(func(first: int, count: int) -> void: shattered.append([first, count]))
	_check("starts with 6 crystals", v.max_health == 6 and v.health == 6)
	v.hurt(2)
	_check("hurt(2) leaves 4 and shatters crystals 4 and 5", v.health == 4 and shattered == [[4, 2]])
	v.heal(1)
	_check("heal(1) regrows one crystal", v.health == 5)
	v.add_shard()
	_check("one shard does not add a crystal", v.max_health == 6)
	v.add_shard()
	_check("two shards add a crystal and fully heal", v.max_health == 7 and v.health == 7)
	for _n in 20:
		v.add_shard()
	_check("crystals cap at 11 with 10 shards", v.max_health == 11 and v.shards == 10)
	v.hurt(99)
	_check("health never drops below zero", v.health == 0)
	_check("abilities unlock in order", v.unlock_next() == "pound" and v.unlock_next() == "double_jump" and v.unlock_next() == "dash_iframes" and v.unlock_next() == "fast_heal" and v.unlock_next() == "")

	# Controls include the new actions with the requested defaults.
	_check("inventory action defaults to I", KeyBindings.keys["inventory"] == KEY_I and InputMap.has_action("inventory"))
	_check("ground pound and eat actions exist", InputMap.has_action("pound") and InputMap.has_action("eat"))

	_check("quick map defaults to Tab, full map to M", KeyBindings.keys["map"] == KEY_TAB and KeyBindings.keys["full_map"] == KEY_M \
			and InputMap.has_action("map") and InputMap.has_action("full_map"))
	var wm := WorldMap.new()
	vp.add_child(wm)
	wm.set_region("THE RUSTWORKS")
	_check("map knows the current region", wm.current_region == 1)
	wm.set_region("NOWHERE")
	_check("unknown region falls back to the first", wm.current_region == 0)
	wm.press_quick()
	_check("quick key shows the quick map", wm.mode == WorldMap.Mode.QUICK and wm.visible)
	wm.press_full()
	_check("full key opens the full map from the quick map", wm.is_full())
	wm.press_quick()
	_check("quick key closes the full map", wm.mode == WorldMap.Mode.CLOSED and not wm.visible)
	wm.press_full()
	wm.press_full()
	_check("full key toggles the full map", wm.mode == WorldMap.Mode.CLOSED)
	_check("the map covers the five regions and the 99 pieces of the real world", WorldMap.REGIONS.size() == 5 and WorldData.pieces.size() == 99)
	wm.queue_free()

	# Inventory: open, navigate, close.
	var inv := InventoryScreen.new()
	var vs := VitalsState.new()
	vp.add_child(inv)
	inv.bind(vs)
	inv.open()
	await process_frame
	_check("inventory opens", inv.is_open and inv.visible)
	var first_sel: int = inv._sel
	inv._navigate(Vector2.RIGHT)
	_check("navigating right moves selection", inv._sel != first_sel)
	_check("inventory has no items yet, only the four ability slots", inv._slots.size() == 4)
	var reached_ability := false
	for _n in 8:
		inv._navigate(Vector2.DOWN)
		inv._navigate(Vector2.LEFT)
		if inv._slots[inv._sel]["kind"] == "ability":
			reached_ability = true
	_check("navigating down and left reaches an ability badge", reached_ability)
	inv.close()
	_check("inventory closes", not inv.is_open and not inv.visible)

	# Preview scene end to end: HUD must always match the health state, no stray demo text.
	var preview: Control = load("res://scenes/ui/ui_preview.tscn").instantiate()
	vp.add_child(preview)
	await process_frame
	await process_frame
	var pv: VitalsState = preview.vitals
	var healed_total := [0]
	pv.healed.connect(func(_first: int, count: int) -> void: healed_total[0] += count)
	pv.hurt(3)
	pv.add_shard()
	pv.add_shard()
	_check("new crystal heal reports every restored crystal (3 missing + 1 new)", healed_total[0] == 4)
	for _n in 70:
		await process_frame
	var in_sync := true
	for i in pv.max_health:
		var want: int = Glyphs.Crystal.FULL if i < pv.health else Glyphs.Crystal.EMPTY
		if preview.hud._modes[i] != want:
			in_sync = false
	_check("HUD crystals match health after hurt + shard heal", in_sync and preview.hud._modes.size() == pv.max_health)
	pv.hurt(2)
	for _n in 70:
		await process_frame
	in_sync = true
	for i in pv.max_health:
		var want2: int = Glyphs.Crystal.FULL if i < pv.health else Glyphs.Crystal.EMPTY
		if preview.hud._modes[i] != want2:
			in_sync = false
	_check("HUD crystals match health after damage", in_sync)
	var labels := 0
	for child in preview.get_children():
		if child is Label:
			labels += 1
	_check("preview has no demo hint label", labels == 0)
	var press_i := _key(KEY_I)
	vp.push_input(press_i)
	await process_frame
	_check("I opens the inventory and hides the HUD", preview.inventory.is_open and not preview.hud.visible)
	var esc := _key(KEY_ESCAPE)
	vp.push_input(esc)
	await process_frame
	_check("Esc closes the inventory and shows the HUD", not preview.inventory.is_open and preview.hud.visible)

	# Pause menu: Esc opens it (and pauses), Options page works, settings change and restore, Esc closes.
	var pause: PauseMenu = preview.pause_menu
	vp.push_input(_key(KEY_ESCAPE))
	await process_frame
	_check("Esc opens the pause menu and pauses the tree", pause.is_open and paused)
	_check("pause menu lists Continue, Options, Quit To Menu", pause._rows.size() == 3 and pause._rows[0]["id"] == "continue" and pause._rows[2]["id"] == "quit")
	vp.push_input(_key(KEY_S))
	await process_frame
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.keycode = KEY_ENTER
	enter.pressed = true
	vp.push_input(enter)
	await process_frame
	_check("Options opens the options page", pause._page == 1 and pause._rows.size() == 6)
	pause._select(2)
	for _n in 60:
		await process_frame
	_check("selector drop lands beside the highlighted Options row", pause._drop_pos.is_equal_approx(pause._selector_target(pause._rows[2])))
	_check("underline has drawn to the full text width", is_equal_approx(pause._line_w, float(pause._rows[2]["width"])))
	var music_before := SettingsStore.music
	pause._index = 0
	vp.push_input(_key(KEY_D))
	await process_frame
	var music_after := SettingsStore.music
	_check("Right raises the music pips by one (or stays at the cap)", music_after == mini(music_before + 1, 10))
	SettingsStore.music = music_before
	SettingsStore.save_settings()
	SettingsStore.apply()
	vp.push_input(_key(KEY_ESCAPE))
	await process_frame
	_check("Esc on Options returns to the main page, still paused", pause._page == 0 and pause.is_open and paused)
	vp.push_input(_key(KEY_ESCAPE))
	await process_frame
	_check("Esc on the main page resumes", not pause.is_open and not paused)

	print("RESULT: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
