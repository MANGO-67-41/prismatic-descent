extends SceneTree
## Dev test: the real flow with real scene changes and real key events, the way a player triggers it.
## Title -> Start Game -> pick a profile -> preview -> Esc -> title. Fails on any script error in the log.
## Run: Godot --path . --script res://dev/test_flow.gd   (then grep its output for "SCRIPT ERROR")

var _failures := 0


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures += 1


func _press(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Use a slot that is empty so we never touch a real save; remove it again at the end.
	var slot := 0
	for candidate in [4, 3, 2]:
		if not SaveSlots.exists(candidate):
			slot = candidate
			break
	if slot == 0:
		print("SKIP  no empty slot available")
		quit(0)
		return
	var title: Control = load("res://scenes/ui/title_screen.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await _frames(5)
	_press(KEY_ENTER)  # START GAME
	await _frames(5)
	_check("Enter on START GAME opens the profile screen", title._screen == 3)
	for _i in slot - 1:
		_press(KEY_DOWN)
		await _frames(2)
	_press(KEY_ENTER)  # choose the empty slot: creates a profile and loads the preview scene
	await _frames(10)
	_check("Enter on a profile loads the game", current_scene != null and current_scene.name == "Game")
	_press(KEY_I)
	await _frames(4)
	_check("I opens the inventory", current_scene.inventory.is_open)
	_press(KEY_ESCAPE)
	await _frames(4)
	_check("Esc closes the inventory and stays in the preview", current_scene.name == "Game" and not current_scene.inventory.is_open)
	_press(KEY_TAB)
	await _frames(3)
	_check("Tab shows the quick map", current_scene.world_map.mode == WorldMap.Mode.QUICK)
	_press(KEY_M)
	await _frames(3)
	_check("M opens the full map", current_scene.world_map.is_full() and not current_scene.hud.visible)
	_press(KEY_ESCAPE)
	await _frames(4)
	_check("Esc closes the full map without pausing", current_scene.world_map.mode == WorldMap.Mode.CLOSED and current_scene.hud.visible and not paused)
	_press(KEY_TAB)
	await _frames(3)
	_press(KEY_I)
	await _frames(3)
	_check("opening the inventory dismisses the quick map", current_scene.world_map.mode == WorldMap.Mode.CLOSED and current_scene.inventory.is_open)
	_press(KEY_ESCAPE)
	await _frames(4)
	# Custom bindings: the map keys follow a rebind, in the live scene, and survive a reload from disk.
	var original_keys: Dictionary = KeyBindings.keys.duplicate()
	var wm: WorldMap = current_scene.world_map
	KeyBindings.rebind("map", KEY_N)
	KeyBindings.rebind("full_map", KEY_P)
	_press(KEY_TAB)
	_press(KEY_M)
	await _frames(3)
	_check("old Tab and M do nothing after rebinding", wm.mode == WorldMap.Mode.CLOSED)
	_press(KEY_N)
	await _frames(3)
	_check("rebound quick map key (N) shows the quick map", wm.mode == WorldMap.Mode.QUICK)
	_press(KEY_P)
	await _frames(3)
	_check("rebound full map key (P) opens the full map", wm.is_full())
	_press(KEY_P)
	await _frames(3)
	_check("rebound full map key (P) closes it again", wm.mode == WorldMap.Mode.CLOSED)
	var swapped := KeyBindings.rebind("map", KEY_P)
	_check("giving the quick map the full map's key swaps them", swapped == "FULL MAP" and KeyBindings.keys["full_map"] == KEY_N)
	_press(KEY_N)
	await _frames(3)
	_check("after the swap N opens the full map", wm.is_full())
	_press(KEY_N)
	await _frames(3)
	KeyBindings.keys = {}
	KeyBindings.setup()
	_check("map bindings persist across a reload", KeyBindings.keys["map"] == KEY_P and KeyBindings.keys["full_map"] == KEY_N)
	KeyBindings.keys = original_keys
	KeyBindings.apply()
	KeyBindings.save()
	_check("original bindings restored", KeyBindings.keys["map"] == original_keys["map"] and InputMap.has_action("full_map"))
	_press(KEY_ESCAPE)
	await _frames(6)
	var game: Node = current_scene
	_check("Esc in the game opens the pause menu and pauses", game.pause_menu.is_open and paused)
	_press(KEY_ESCAPE)
	await _frames(6)
	_check("Esc again resumes the game", not game.pause_menu.is_open and not paused)
	_press(KEY_ESCAPE)
	await _frames(6)
	_press(KEY_DOWN)
	await _frames(3)
	_press(KEY_DOWN)
	await _frames(3)
	_press(KEY_ENTER)  # QUIT TO MENU
	await _frames(12)
	_check("Quit To Menu returns to the title screen and unpauses", current_scene != null and current_scene.name == "TitleScreen" and not paused)
	SaveSlots.erase(slot)
	print("RESULT: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
