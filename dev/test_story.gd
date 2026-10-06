extends SceneTree
## Dev test: the temples, scrolls, keys, gates, guardians and being hurt, in the real game scene (profile slot 4).
## Run: Godot --headless --path . --script res://dev/test_story.gd

var _failures := 0
var game: Game

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures += 1

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame

func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(3)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)

func _props(kind: String) -> Array:
	var out: Array = []
	for p in WorldData.pieces:
		for pr in p.get("props", []):
			if pr["t"] == kind:
				out.append({"piece": p, "prop": pr})
	return out

func _goto(pos: Vector2, frames: int = 20) -> void:
	game.player.respawn_at(pos)
	game.world.update_focus(pos, true)
	await _frames(frames)

func _find_guardian(piece_id: int) -> Guardian:
	var node: Node = game.world._nodes.get(piece_id)
	if node == null:
		return null
	for c in node.get_children():
		if c is Guardian:
			return c
	return null

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		print("slot 4 in use; skipping to avoid touching it")
		quit()
		return
	WorldData.ensure_loaded()
	# --- the data
	var wings := 0
	for p in WorldData.pieces:
		if bool(p.get("wing", false)):
			wings += 1
	_check("30 wing rooms (6 per region: ruin hall, key chamber or second shrine, guardian temple, and 3 lantern shrines)", wings == 30)
	var shrines := [0, 0, 0, 0, 0]
	var shrine_ok := true
	for p in WorldData.pieces:
		if bool(p.get("wing", false)) and str(p["wing_kind"]) == "shrine":
			shrines[int(p["region"])] += 1
			shrine_ok = shrine_ok and (p["rest"] as Array).size() == 1 and (p["creatures"] as Array).is_empty() and (p["props"] as Array).is_empty()
	_check("15 lantern shrines, 3 in every region, each with one resting lantern and no creatures (%s)" % str(shrines), shrines == [3, 3, 3, 3, 3] and shrine_ok)
	_check("23 scrolls, 4 keys, 5 guardians, 5 gates", _props("scroll").size() == 23 and _props("key").size() == 4 and _props("guardian").size() == 5 and _props("door").size() == 5)
	var ids_ok := true
	for e in _props("scroll"):
		if str(StoryData.scroll(str(e["prop"]["id"]))["title"]) == "":
			ids_ok = false
	_check("every scroll has words", ids_ok)
	game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(game)
	await _frames(30)
	for a in game.vitals.unlocked:      # no region gifts during the test (their ascension moves the hero)
		game.vitals.unlocked[a] = true
	# --- a scroll
	var sc: Dictionary = _props("scroll")[0]
	var sp: Dictionary = sc["piece"]
	var spos := Vector2(float(sp["x"]) + float(sc["prop"]["x"]), float(sp["y"]) + float(sc["prop"]["y"]))
	await _goto(spos + Vector2(0, -1))
	await _press("interact")
	_check("interact beside a pedestal opens its scroll", game.scroll_reader.is_open)
	await _frames(40)
	_check("the scroll covers 80% of the screen", ScrollReader.SIZE == Vector2(384, 216) and is_equal_approx(ScrollReader.SIZE.x / 480.0, 0.8) and is_equal_approx(ScrollReader.SIZE.y / 270.0, 0.8))
	_check("the hero cannot move while reading", not game.player.input_enabled)
	await _press("interact")
	_check("interact closes the scroll", not game.scroll_reader.is_open)
	_check("the scroll is marked read", bool(game.vitals.read_scrolls.get(str(sc["prop"]["id"]), false)))
	# --- a key
	var ke: Dictionary = _props("key")[0]
	var kp: Dictionary = ke["piece"]
	var kpos := Vector2(float(kp["x"]) + float(ke["prop"]["x"]), float(kp["y"]) + float(ke["prop"]["y"]))
	await _goto(kpos + Vector2(0, 2), 30)
	_check("walking into a key picks it up", bool(game.vitals.items.get("key_0", false)))
	# --- a gate
	var gate: Dictionary = _props("door")[0]
	var gp: Dictionary = gate["piece"]
	var gpos := Vector2(float(gp["x"]) + float(gate["prop"]["x"]), float(gp["y"]) + float(gate["prop"]["y"]))
	game.vitals.items.erase("key_0")
	await _goto(gpos + Vector2(0, -20), 40)
	_check("the hero stands on the shut gate", game.player.position.y < gpos.y + 2.0)
	await _press("interact")
	_check("without the key the gate stays shut", not bool(game.vitals.doors.get("gate_0", false)))
	game.vitals.items["key_0"] = true
	await _press("interact")
	_check("with the key the gate opens", bool(game.vitals.doors.get("gate_0", false)))
	await _frames(120)
	_check("the hero falls through the open gate", game.player.position.y > gpos.y + 12.0)
	# --- the lake's seal
	var seal: Dictionary = _props("door")[4]
	var sep: Dictionary = seal["piece"]
	var sepos := Vector2(float(sep["x"]) + float(seal["prop"]["x"]), float(sep["y"]) + float(seal["prop"]["y"]))
	await _goto(sepos + Vector2(0, -20), 40)
	await _press("interact")
	_check("the seal holds while guardians remain", not bool(game.vitals.doors.get("seal", false)))
	for i in 5:
		game.vitals.guardians["g_%d" % i] = true
	await _press("interact")
	_check("the seal opens once all five guardians have fallen", bool(game.vitals.doors.get("seal", false)))
	for i in 5:
		game.vitals.guardians.erase("g_%d" % i)
	# --- being hurt
	var safe := Vector2(float(WorldData.pieces[0]["x"]) + 120.0, float(WorldData.pieces[0]["y"]) + 200.0)
	await _goto(safe, 60)
	game.vitals.health = game.vitals.max_health
	await _frames(100)
	var h0 := game.vitals.health
	var took := game.player.take_hit(game.player.position.x - 8.0)
	_check("a hit costs one crystal and knocks the hero back", took and game.vitals.health == h0 - 1 and game.player.velocity.x > 0.0)
	_check("a second hit right away does nothing", not game.player.take_hit(game.player.position.x - 8.0) and game.vitals.health == h0 - 1)
	await _frames(100)
	_check("after a moment the hero can be hurt again", game.player.take_hit(game.player.position.x - 8.0))
	game.vitals.health = 1
	await _frames(100)
	game.player.take_hit(game.player.position.x - 8.0)
	_check("the last crystal breaks: the hero is dying", game.vitals.health == 0 and game.dying)
	await _frames(20)
	_check("the death screen comes up", game.death_screen.visible and game.death_screen.is_playing())
	await _frames(70)
	_check("the crystal has burst and the words are coming up", game.death_screen._shards.size() > 0)
	await _frames(240)
	_check("the hero wakes at the last rest with full health", not game.dying and game.vitals.health == game.vitals.max_health)
	_check("waking at the lantern, the bottom right corner says NOW ENTERING LANTERN ROOM", game.area_title.shown_name == "LANTERN ROOM" and game.area_title.visible)
	# --- a guardian
	var gu: Dictionary = _props("guardian")[0]
	var gup: Dictionary = gu["piece"]
	var gid := int(gup["id"])
	var gpos0 := Vector2(float(gup["x"]) + float(gu["prop"]["x"]), float(gup["y"]) + float(gu["prop"]["y"]))
	await _goto(gpos0 + Vector2(-190, -2), 40)
	var g := _find_guardian(gid)
	_check("the temple holds its guardian", g != null)
	if g != null:
		_check("it sleeps until the hero comes close", g._state == Guardian.S.SLEEP or g._state == Guardian.S.WAKE)
		await _goto(gpos0 + Vector2(-140, -2), 90)
		_check("it wakes when the hero is near", g._state != Guardian.S.SLEEP and game.boss_bar.visible)
		# the bamboo stick: a swing, a stun that bares the heart for 1.5 s, then a moment it cannot be stunned again
		game.player.grant_invincibility(6.0)
		await _goto(gpos0 + Vector2(-26, -2), 30)
		game.player.facing = 1
		g._set_state(Guardian.S.IDLE)
		g._t = -10.0       # hold it idle: no attack while we line up
		g._stun_immune = 0.0
		await _press("attack")
		_check("the stick key swings the bamboo stick", game.player.is_swinging())
		await _frames(10)
		_check("the stick stuns the guardian", g.is_stunned() and g.is_vulnerable())
		await _frames(100)
		_check("the stun wears off after 1.5 seconds", not g.is_stunned())
		g._t = -10.0
		await _frames(30)
		await _press("attack")
		await _frames(10)
		_check("it cannot be stunned again straight away", not g.is_stunned())
		g._stun_immune = 0.0
		g._set_state(Guardian.S.IDLE)
		g._t = -10.0
		await _frames(30)
		await _press("attack")
		await _frames(10)
		var hp_before_stun_stomp := g.hp
		g._stomp_lock = 0.0
		game.player.global_position = Vector2(gpos0.x, g.heart_rect().position.y - 2.0)
		game.player.velocity.y = 120.0
		await _frames(2)
		_check("stomping a stunned guardian's heart hurts it", g.hp == hp_before_stun_stomp - 1)
		await _frames(50)
		var hp0 := g.hp
		# while its heart is shut a stomp only bounces
		g._set_state(Guardian.S.IDLE)
		game.player.global_position = Vector2(gpos0.x, g.heart_rect().position.y - 2.0)
		game.player.velocity.y = 120.0
		await _frames(2)
		_check("stomping the heart while it is shut does no harm", g.hp == hp0)
		# once it is tired a stomp lands
		g._set_state(Guardian.S.DAZED)
		g._stomp_lock = 0.0
		game.player.global_position = Vector2(gpos0.x, g.heart_rect().position.y - 2.0)
		game.player.velocity.y = 120.0
		await _frames(2)
		_check("stomping the open heart hurts the guardian", g.hp == hp0 - 1)
		_check("the hero bounces off", game.player.velocity.y < 0.0)
		var guard := 0
		while g.hp > 0 and guard < 20:
			g._set_state(Guardian.S.DAZED)
			g._stomp_lock = 0.0
			game.player.grant_invincibility(3.0)
			game.player.global_position = Vector2(gpos0.x, g.heart_rect().position.y - 2.0)
			game.player.velocity.y = 120.0
			await _frames(3)
			guard += 1
		_check("enough hits break the guardian", g.hp == 0)
		var shards0 := game.vitals.shards
		await _frames(150)
		_check("the fallen guardian is recorded and the boss bar goes", bool(game.vitals.guardians.get("g_0", false)) and not game.boss_bar.visible)
		_check("the shard moment plays", game.shard_screen.is_playing() or game.vitals.shards == shards0 + 1)
		await _frames(150)
		_check("a guardian leaves a crystal shard behind (it lands in the HUD)", game.vitals.shards == shards0 + 1)
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	print("RESULT: %d failure(s)" % _failures)
	quit()
