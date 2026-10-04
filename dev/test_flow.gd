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
	_check("Enter on a profile loads the preview scene", current_scene != null and current_scene.name == "UiPreview")
	_press(KEY_I)
	await _frames(4)
	_check("I opens the inventory", current_scene.inventory.is_open)
	_press(KEY_ESCAPE)
	await _frames(4)
	_check("Esc closes the inventory and stays in the preview", current_scene.name == "UiPreview" and not current_scene.inventory.is_open)
	_press(KEY_ESCAPE)
	await _frames(10)
	_check("Esc in the preview returns to the title screen", current_scene != null and current_scene.name == "TitleScreen")
	SaveSlots.erase(slot)
	print("RESULT: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
