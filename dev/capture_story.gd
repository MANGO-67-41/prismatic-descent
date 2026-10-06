extends SceneTree
## Dev tool: screenshots of the temples and story pieces in the real game (480x270, saved 3x). Uses profile slot 4.
## Env: SHOT_OUT=path, SHOT_SCENE=scroll|scroll2|temple|fight|key|gate|seal|wing|toast|inv|died|map
##      SHOT_WING=<0-14 wing number> for wing

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		print("slot 4 in use")
		quit()
		return
	var out := OS.get_environment("SHOT_OUT") if OS.get_environment("SHOT_OUT") != "" else "/tmp/story.png"
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	vp.add_child(game)
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for _i in 20:
		await process_frame
	for a in game.vitals.unlocked:
		game.vitals.unlocked[a] = true
	var scene := OS.get_environment("SHOT_SCENE")
	var wing_n := int(OS.get_environment("SHOT_WING")) if OS.get_environment("SHOT_WING") != "" else 0
	var wings: Array = []
	for p in WorldData.pieces:
		if bool(p.get("wing", false)):
			wings.append(p)
	for k in WorldData.pieces.size():
		game.discovered[k] = true
	match scene:
		"scroll", "scroll2":
			var which := 0 if scene == "scroll" else 7
			var sc: Array = []
			for p in WorldData.pieces:
				for pr in p.get("props", []):
					if pr["t"] == "scroll":
						sc.append({"p": p, "pr": pr})
			var e: Dictionary = sc[which]
			var at := Vector2(float(e["p"]["x"]) + float(e["pr"]["x"]), float(e["p"]["y"]) + float(e["pr"]["y"]))
			game.player.respawn_at(at + Vector2(0, -1))
			game.world.update_focus(at, true)
			for _i in 40:
				await physics_frame
			game.read_scroll(str(e["pr"]["id"]))
			for _i in 60:
				await process_frame
		"temple", "fight":
			var tp: Dictionary = {}
			for w in wings:
				if w["wing_kind"] == "temple" and int(w["region"]) == wing_n:
					tp = w
			var gx := float(tp["x"]) + 240.0
			var fy := float(tp["y"]) + 26.0 * 8.0
			var at := Vector2(gx - (110.0 if scene == "fight" else 150.0), fy - 1.0)
			game.player.respawn_at(at)
			game.world.update_focus(at, true)
			for _i in 80:
				await physics_frame
			if scene == "fight":
				var node: Node = game.world._nodes.get(int(tp["id"]))
				for c in node.get_children():
					if c is Guardian:
						(c as Guardian)._set_state(Guardian.S.TELL_SLAM if OS.get_environment("SHOT_TELL") == "slam" else Guardian.S.DAZED)
						if OS.get_environment("SHOT_TELL") == "shards":
							(c as Guardian)._start_shards()
				for _i in 30:
					await physics_frame
		"swing", "stun":
			var tp: Dictionary = {}
			for w in wings:
				if w["wing_kind"] == "temple" and int(w["region"]) == wing_n:
					tp = w
			var gx := float(tp["x"]) + 240.0
			var fy := float(tp["y"]) + 26.0 * 8.0
			game.player.respawn_at(Vector2(gx - 28.0, fy - 1.0))
			game.world.update_focus(game.player.position, true)
			for _i in 60:
				await physics_frame
			game.player.facing = 1
			game.player.grant_invincibility(9.0)
			var g: Guardian = null
			for c in game.world._nodes.get(int(tp["id"])).get_children():
				if c is Guardian:
					g = c
			g._set_state(Guardian.S.IDLE)
			g._t = -10.0
			var ev := InputEventAction.new()
			ev.action = "attack"
			ev.pressed = true
			Input.parse_input_event(ev)
			for _i in (3 if scene == "swing" else 40):
				await physics_frame
		"key":
			for w in wings:
				if w["wing_kind"] == "key" and int(w["region"]) == wing_n:
					var kp: Dictionary = w["props"][1]
					var at := Vector2(float(w["x"]) + float(kp["x"]), float(w["y"]) + float(kp["y"]))
					game.player.respawn_at(at + Vector2(-40, -2))
					game.world.update_focus(at, true)
			for _i in 50:
				await physics_frame
		"gate", "seal":
			var gp: Dictionary = WorldData.pieces[19 if scene == "gate" else 99]
			var at := Vector2(float(gp["x"]) + 56.0, float(gp["y"]) + 96.0 - 1.0)
			game.player.respawn_at(at)
			game.world.update_focus(at, true)
			for _i in 40:
				await physics_frame
		"wing":
			var w: Dictionary = wings[wing_n]
			var at := Vector2(float(w["x"]) + float(w["w"]) * 0.5, float(w["y"]) + 26.0 * 8.0 - 1.0)
			game.player.respawn_at(at)
			game.world.update_focus(at, true)
			for _i in 60:
				await physics_frame
		"toast":
			game.player.respawn_at(Vector2(float(WorldData.pieces[0]["x"]) + 120.0, float(WorldData.pieces[0]["y"]) + 200.0))
			for _i in 30:
				await physics_frame
			game.guardian_defeated("g_0", 0)
			for _i in 50:
				await process_frame
		"inv":
			for i in 3:
				game.vitals.items["key_%d" % i] = true
			game.vitals.doors["gate_0"] = true
			game.vitals.guardians["g_0"] = true
			game.vitals.guardians["g_1"] = true
			for _i in 20:
				await physics_frame
			game.inventory.open()
			game.inventory._sel = int(OS.get_environment("SHOT_SEL")) if OS.get_environment("SHOT_SEL") != "" else 4
			game.inventory._refresh()
			for _i in 40:
				await process_frame
		"map":
			game.world_map.press_full()
			game.world_map._scroll_x = float(OS.get_environment("SHOT_MAPX")) if OS.get_environment("SHOT_MAPX") != "" else 0.0
			for _i in 30:
				await process_frame
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	img.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("saved ", out)
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	quit()
