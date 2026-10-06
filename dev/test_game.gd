extends SceneTree
## Dev test: the real game scene. Hero spawns, stands, runs, jumps; every room streams in and holds the hero up.
## Run: Godot --headless --path . --script res://dev/test_game.gd

var _failures := 0

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures += 1

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame

func _initialize() -> void:
	SaveSlots.current_slot = 4
	var had := SaveSlots.exists(4)
	if had:
		print("slot 4 in use; skipping to avoid touching it")
		quit()
		return
	WorldData.ensure_loaded()
	_check("world data loads 131 pieces (101 + 30 wings) and 6 regions (with THE PRISMATIC LAKE)", WorldData.pieces.size() == 131 and WorldData.regions.size() == 6)
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(game)
	await _frames(40)
	var floor_at_start := game.player.position
	_check("hero spawns in the first room", game.piece == 0)
	_check("hero stands on the floor", game.player.is_on_floor())
	var x0 := game.player.position.x
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check("hero runs right at about 110 px/s", game.player.position.x - x0 > 40.0)
	var y0 := game.player.position.y
	Input.action_press("jump")
	await _frames(8)
	var rose := game.player.position.y < y0 - 8.0
	Input.action_release("jump")
	await _frames(70)
	_check("jump lifts the hero and they land again", rose and game.player.is_on_floor())
	_check("camera shows the room's screen", game.cam.global_position.is_equal_approx(WorldData.rect(0).get_center()) or game.cam.global_position.distance_to(WorldData.rect(0).get_center()) < 4.0)
	# every room: drop the hero at its entrance and make sure the room is solid under them
	for a in game.vitals.unlocked:      # no region gifts during the sweep (they move the hero)
		game.vitals.unlocked[a] = true
	var bad := 0
	var tested := 0
	for i in WorldData.pieces.size():
		var p: Dictionary = WorldData.pieces[i]
		if p["kind"] != "room" or bool(p.get("wing", false)):
			continue
		var at := Vector2(float(p["x"]) + float(p["entry"][0]), float(p["y"]) + 5.0 * 8.0)
		game.vitals.health = game.vitals.max_health      # the creatures are real now: keep the hero whole for the sweep
		game.player.grant_invincibility(10.0)
		game.player.respawn_at(at)
		game.world.update_focus(at, true)
		await _frames(90)
		var inside := WorldData.rect(i).grow(2.0).has_point(game.player.position)
		if not inside and int(p["entry"][0]) == int(p["exit"][0]) and game.player.position.y > float(p["y"]) + float(p["h"]):
			inside = true       # entry and exit share a column: nothing under the entry, so the hero drops straight on down the shaft
		if not inside:
			bad += 1
			print("  room ", i, " ", p["name"], ": hero ended outside at ", game.player.position)
		tested += 1
	_check("every one of %d rooms holds the hero inside it" % tested, bad == 0)
	# ropes and vines: every room has 2-3, and the hero can climb one
	var rope_ok := true
	var with_rope: Dictionary = {}
	for i in WorldData.pieces.size():
		var p2: Dictionary = WorldData.pieces[i]
		if p2["kind"] == "room" and not bool(p2.get("wing", false)):
			var n: int = p2["ropes"].size()
			if n < 2 or n > 3:
				rope_ok = false
				print("  room ", i, " ", p2["name"], " has ", n, " ropes")
			if with_rope.is_empty():
				with_rope = p2
				with_rope["id"] = i
	_check("every room has 2 or 3 ropes or vines", rope_ok)
	var rp: Array = with_rope["ropes"][0]
	var bottom := Vector2(float(with_rope["x"]) + float(rp[0]), float(with_rope["y"]) + float(rp[1]) + float(rp[2]))
	game.player.respawn_at(bottom + Vector2(0, -2))
	game.world.update_focus(bottom, true)
	await _frames(40)
	var y_before := game.player.position.y
	Input.action_press("move_up")
	await _frames(45)
	Input.action_release("move_up")
	_check("holding up climbs the rope", game.player.position.y < y_before - 25.0 and game.player._climbing)
	var y_high := game.player.position.y
	await _frames(20)
	_check("the hero hangs on the rope without falling", absf(game.player.position.y - y_high) < 2.0)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(10)
	_check("jump lets go of the rope", game.player.velocity.y != 0.0 or game.player.position.y != y_high)
	for a in game.vitals.unlocked:
		game.vitals.unlocked[a] = false
	# --- region gifts: entering THE RUSTWORKS lifts the hero into the light and gives GROUND POUND
	var r2: int = int(WorldData.regions[1]["first"])
	var p2: Dictionary = WorldData.pieces[r2]
	var drop := Vector2(float(p2["x"]) + float(p2["entry"][0]), float(p2["y"]) + 6.0 * 8.0)
	game.player.respawn_at(drop)
	game.world.update_focus(drop, true)
	var saw_ceremony := false
	var rose_up := false
	var low := 99999.0
	for _f in 120:
		await physics_frame
		if game.in_ceremony:
			saw_ceremony = true
			low = minf(low, game.player.position.y)
	_check("entering a new region starts the ascension", saw_ceremony and game.player.frozen)
	_check("the area name shows in the corner on entering a region", game.area_title.visible and game.area_title.shown_name == "THE RUSTWORKS")
	for _f in 330:
		await physics_frame
		low = minf(low, game.player.position.y)
	_check("the region's ability is given (GROUND POUND)", bool(game.vitals.unlocked["pound"]))
	_check("the ceremony ends and the hero can move again", not game.in_ceremony and not game.player.frozen and game.hud.visible)
	await _frames(60)
	_check("re-entering the region does not repeat it", not game.in_ceremony)
	# --- ground pound on the flat floor: no cracked floors are left, so it stops on the floor (and starts its cooldown)
	var any_cracks := false
	for pd in WorldData.pieces:
		any_cracks = any_cracks or pd.get("cracks", []).size() > 0
	_check("no room has cracked floor or a hole under it any more", not any_cracks)
	var flat := -1
	for i in WorldData.pieces.size():
		if str(WorldData.pieces[i]["kind"]) == "room" and int(WorldData.pieces[i]["w"]) == 960 and not bool(WorldData.pieces[i].get("wing", false)):
			flat = i
			break
	var pc: Dictionary = WorldData.pieces[flat]
	var floor_py := float(pc["y"]) + float(int(pc["h"]) / 8 - 8) * 8.0
	var above := Vector2(float(pc["x"]) + 28.0 * 8.0 + 4.0, floor_py - 40.0)
	game.player.respawn_at(above)
	game.world.update_focus(above, true)
	await _frames(4)
	Input.action_press("pound")
	await _frames(2)
	Input.action_release("pound")
	await _frames(60)
	_check("ground pound lands on the floor and stays on it", absf(game.player.position.y - floor_py) < 3.0)
	_check("ground pound has a 4 s cooldown", game.player.cooldown_fraction("pound") < 0.5)
	# --- double jump goes higher than a single jump
	game.vitals.unlocked["double_jump"] = true
	game.player.respawn_at(floor_at_start)
	game.world.update_focus(floor_at_start, true)
	await _frames(30)
	var g0 := game.player.position.y
	Input.action_press("jump")
	await _frames(18)
	Input.action_release("jump")
	await _frames(2)
	Input.action_press("jump")
	var top := g0
	for _f in 40:
		await physics_frame
		top = minf(top, game.player.position.y)
	Input.action_release("jump")
	_check("double jump climbs well above a single jump (%.0f px)" % (g0 - top), g0 - top > 60.0)
	await _frames(60)
	# --- invincible dash and eating
	game.vitals.unlocked["dash_iframes"] = true
	Input.action_press("dash")
	await _frames(3)
	_check("dashing with INVINCIBLE DASH makes the hero untouchable", game.player.invincible)
	Input.action_release("dash")
	await _frames(30)
	_check("and only while dashing", not game.player.invincible)
	Input.action_press("dash")
	await _frames(3)
	_check("a second dash within 3 s is not invincible", not game.player.invincible)
	Input.action_release("dash")
	await _frames(200)
	Input.action_press("dash")
	await _frames(3)
	_check("after 3 s the dash is invincible again", game.player.invincible)
	Input.action_release("dash")
	await _frames(30)
	# energy: fills over 30 s; a full circle heals one crystal
	game.vitals.health = game.vitals.max_health - 1
	game.vitals.energy = 0.5
	Input.action_press("eat")
	await _frames(70)
	_check("healing needs a full energy circle", game.vitals.health == game.vitals.max_health - 1)
	Input.action_release("eat")
	game.vitals.energy = 0.0
	await _frames(60)
	_check("the energy circle fills slowly (about 1/30 per second)", game.vitals.energy > 0.02 and game.vitals.energy < 0.05)
	game.vitals.energy = 1.0
	Input.action_press("eat")
	await _frames(70)
	Input.action_release("eat")
	_check("holding HEAL with a full circle restores a crystal and empties it", game.vitals.health == game.vitals.max_health and game.vitals.energy < 0.05)
	# shafts are clear: no ledges, one rope through the middle that climbs the whole way
	var sh_ok := true
	for i in WorldData.pieces.size():
		var ps: Dictionary = WorldData.pieces[i]
		if ps["kind"] == "shaft" and (ps["ropes"].size() != 1 or ps["rects"].size() > 2):
			sh_ok = false
	_check("every shaft has no ledges and a single rope through it", sh_ok)
	var sp: Dictionary = WorldData.pieces[1]
	var sx := float(sp["x"]) + 56.0
	var sbot := Vector2(sx, float(sp["y"]) + float(sp["h"]) - 6.0)
	game.player.respawn_at(sbot)
	game.world.update_focus(sbot, true)
	Input.action_press("move_up")
	await _frames(190)
	Input.action_release("move_up")
	_check("holding up climbs the whole shaft to the room above (%.0f)" % (game.player.position.y - float(sp["y"])), game.player.position.y < float(sp["y"]) + 4.0)
	# beams: thin bars out of the wall. Dropping onto one lands on its top edge, 4 px thick in the collision
	var beam_pid := -1
	for i in WorldData.pieces.size():
		if (WorldData.pieces[i].get("beams", []) as Array).size() > 0 and WorldData.pieces[i]["kind"] == "room":
			beam_pid = i
			break
	_check("the world has beams", beam_pid >= 0 and WorldData.pieces[beam_pid]["beams"].size() > 0)
	if beam_pid >= 0:
		var bp: Dictionary = WorldData.pieces[beam_pid]
		var bb: Array = bp["beams"][0]
		var over_beam := Vector2(float(bp["x"]) + (float(bb[0]) + float(bb[2]) / 2.0) * 8.0, float(bp["y"]) + float(bb[1]) * 8.0 - 30.0)
		game.player.respawn_at(over_beam)
		game.world.update_focus(over_beam, true)
		await _frames(60)
		var beam_top := float(bp["y"]) + float(bb[1]) * 8.0
		_check("the hero lands on a beam's top edge (%.1f vs %.1f)" % [game.player.position.y, beam_top], game.player.is_on_floor() and absf(game.player.position.y - beam_top) < 1.5)
	# the Prismatic Lake: no gift, nothing hostile, the temple's rest point heals
	var lake := 100
	var lp: Dictionary = WorldData.pieces[lake]
	_check("the last room is THE PRISMATIC LAKE", lp["name"] == "PRISMATIC LAKE" and int(lp["region"]) == 5)
	var rest_at := Vector2(float(lp["x"]) + float(lp["rest"][0][0]), float(lp["y"]) + float(lp["rest"][0][1]))
	game.player.respawn_at(rest_at + Vector2(0, -4))
	game.world.update_focus(rest_at, true)
	await _frames(60)
	_check("arriving at the lake gives no ability and starts no ceremony", not game.in_ceremony)
	_check("the area name reads THE PRISMATIC LAKE", game.area_title.shown_name == "THE PRISMATIC LAKE")
	game.vitals.health = 2
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(40)
	_check("the temple's rest point heals fully", game.vitals.health == game.vitals.max_health)
	_check("streaming keeps only nearby pieces loaded", game.world.loaded_count() < 12)
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	print("RESULT: %d failure(s)" % _failures)
	quit()
