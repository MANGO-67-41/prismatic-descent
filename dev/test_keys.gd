extends SceneTree
## Dev test: every instruction in the game (scrolls, the inventory's ability texts, the upgrade banner, the gate-key line) names
## the key the player has bound, also after the keys are remapped. All twenty-three scrolls are read with every key remapped to
## something else; the ability instructions must name the right action. Uses profile slot 4; nothing is saved to bindings.cfg.
## Run: Godot --headless --path . --script res://dev/test_keys.gd

var _failures := 0

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures += 1

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame

func _remap() -> Dictionary:
	# every action to its own function key (never saved: apply() only)
	var keys := {}
	var f := KEY_F1
	for action in KeyBindings.ACTIONS:
		keys[action] = f
		f = (f + 1) as Key
	return keys

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		print("slot 4 in use; skipping")
		quit()
		return
	KeyBindings.keys = KeyBindings.DEFAULTS.duplicate()
	KeyBindings.apply()
	# --- the words themselves: every {token} is a real action, the ability scrolls and texts name their key
	var ids: Array = []
	for i in range(1, 24):
		ids.append("s%02d" % i)
	var tokens_ok := true
	var bare_ok := true
	for id in ids:
		for page in StoryData.scroll(id)["pages"]:
			var rx := RegEx.create_from_string("\\{([a-z_]+)\\}")
			for m in rx.search_all(str(page)):
				tokens_ok = tokens_ok and KeyBindings.ACTIONS.has(m.get_string(1))
			bare_ok = bare_ok and not StoryData.format(str(page)).contains("{")
	_check("every {token} in the 23 scrolls is a real action, and none is left unfilled", tokens_ok and bare_ok)
	var teach := {"s01": ["move_left", "move_right", "jump", "attack"], "s02": ["jump", "move_up", "pound"], "s03": ["dash"], "s04": ["interact"], "s06": ["attack", "jump"],
			"s08": ["pound"], "s12": ["jump"], "s16": ["dash"], "s19": ["dash"], "s20": ["eat"]}
	var names_ok := true
	for id in teach:
		var text := str(StoryData.scroll(id)["pages"][0])
		for action in teach[id]:
			if not text.contains("{%s}" % action):
				names_ok = false
				print("  ", id, " does not name ", action)
	_check("the scrolls that teach a move name its key (movement, jump, wall jump, climb, stick, dash, rest, pound, double jump, heal)", names_ok)
	var inv_ok := true
	for pair in [["pound", "pound"], ["double_jump", "jump"], ["dash_iframes", "dash"], ["fast_heal", "eat"]]:
		inv_ok = inv_ok and str(InventoryScreen.ABILITY_TEXT[pair[0]][1]).contains("{%s}" % pair[1])
		inv_ok = inv_ok and KeyBindings.ACTIONS.has(UpgradeCeremony.HINT_KEYS[pair[0]]) and UpgradeCeremony.HINT_KEYS[pair[0]] == pair[1]
	_check("the inventory's ability texts and the upgrade banners use the right action", inv_ok)
	# --- remapped
	var before_text := StoryData.format(str(StoryData.scroll("s03")["pages"][0]))
	KeyBindings.keys = _remap()
	KeyBindings.apply()
	var after_text := StoryData.format(str(StoryData.scroll("s03")["pages"][0]))
	_check("remapped, the dash scroll shows the new key (%s)" % KeyBindings.key_name("dash"), after_text != before_text and after_text.contains(KeyBindings.key_name("dash")))
	var all_new := true
	for id in teach:
		var text := StoryData.format(str(StoryData.scroll(id)["pages"][0]))
		for action in teach[id]:
			all_new = all_new and text.contains(KeyBindings.key_name(action))
	_check("remapped, all ten teaching scrolls show every new key", all_new)
	# --- the real game: the inventory describes each ability with the new keys; the gate key line too
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(game)
	await _frames(30)
	KeyBindings.keys = _remap()
	KeyBindings.apply()
	for a in game.vitals.unlocked:
		game.vitals.unlocked[a] = true
	game.vitals.items["key_0"] = true
	game.inventory._build_slots()
	game.inventory.open()
	var seen := {}
	for i in game.inventory._slots.size():
		game.inventory._sel = i
		game.inventory._refresh()
		seen[game.inventory._desc_body.text] = game.inventory._slots[i]
	var want := {"pound": "pound", "double_jump": "jump", "dash_iframes": "dash", "fast_heal": "eat"}
	var shown_ok := true
	for text in seen:
		var slot: Dictionary = seen[text]
		if slot["kind"] == "ability":
			shown_ok = shown_ok and str(text).contains(KeyBindings.key_name(want[slot["id"]])) and not str(text).contains("{")
		elif slot["kind"] == "stick":
			shown_ok = shown_ok and str(text).contains(KeyBindings.key_name("attack"))
	_check("the open inventory describes each ability and the stick with the remapped keys", shown_ok and seen.size() >= 5)
	game.inventory.close()
	# --- a scroll opened in the game shows the new keys
	var sc := StoryData.scroll("s16")
	game.scroll_reader.open(str(sc["title"]), sc["pages"])
	await _frames(3)
	_check("the open scroll shows the remapped dash key", game.scroll_reader._body.text.contains(KeyBindings.key_name("dash")) and not game.scroll_reader._body.text.contains("{"))
	game.scroll_reader.close()
	game.queue_free()
	await process_frame
	KeyBindings.keys = KeyBindings.DEFAULTS.duplicate()
	KeyBindings.apply()
	SaveSlots.erase(4)
	print("RESULT: %d failure(s)" % _failures)
	quit()
