extends SceneTree
## Dev check: for every room with walking creatures, let them hunt the hero (standing on the floor at the room's entrance, invincible)
## for 15 s and report (STUCK) any that barely moved, and (NOHUNT) any that the room map says can walk to the hero but never got
## within 40 px of them: a creature that cannot get at the hero when it should.
## Run: Godot --headless --path . --script res://dev/check_stuck.gd

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		quit()
		return
	WorldData.ensure_loaded()
	var game: Game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(game)
	for i in 30: await physics_frame
	for a in game.vitals.unlocked: game.vitals.unlocked[a] = true
	var walkers := ["lizard", "hound", "reach"]
	var waiting := 0
	var stuck := 0
	var total := 0
	var nohunt := 0
	var reachable_n := 0
	var reached := 0
	for i in WorldData.pieces.size():
		var p: Dictionary = WorldData.pieces[i]
		var has := false
		for c in p.get("creatures", []):
			if str(CreatureTypes.spec(str(c["t"]))["arch"]) in walkers:
				has = true
		if not has:
			continue
		var at := Vector2(float(p["x"]) + float(p["entry"][0]), float(p["y"]) + 5.0 * 8.0)
		game.player.respawn_at(at)
		game.world.update_focus(at, true)
		game.player.set_frozen(false)
		game.player.grant_invincibility(999.0)
		await physics_frame
		for k in 40:
			await physics_frame
		var node: Node = game.world._nodes.get(i)
		var watch: Array = []
		for ch in node.get_children():
			if ch is Creature and str((ch as Creature).spec["arch"]) in walkers:
				var cr := ch as Creature
				if cr.ambusher() or cr.blind:      # they sit and wait until they see / hear the hero: not counted (test_creatures checks them)
					waiting += 1
					continue
				var nav := RoomNav.for_piece(i)
				watch.append({"c": ch, "min": ch.global_position, "max": ch.global_position, "close": 99999.0,
						"can": nav.reachable(ch.global_position, game.player.global_position - Vector2(0, 7), cr.clearance(), mini(int(cr.climb_max() / 8.0), 40))})
		for f in 900:
			await physics_frame
			for w in watch:
				if is_instance_valid(w["c"]):
					var c: Creature = w["c"]
					w["min"] = (w["min"] as Vector2).min(c.global_position)
					w["max"] = (w["max"] as Vector2).max(c.global_position)
					w["close"] = minf(float(w["close"]), c.global_position.distance_to(game.player.global_position))
		for w in watch:
			if not is_instance_valid(w["c"]):
				continue
			total += 1
			var span: Vector2 = (w["max"] as Vector2) - (w["min"] as Vector2)
			var c: Creature = w["c"]
			if span.length() < 16.0:
				stuck += 1
				print("STUCK  room ", i, " ", p["name"], "  ", c.kind, " at ", (c.global_position - Vector2(float(p["x"]), float(p["y"]))).round(), " moved ", span.round())
			elif bool(w["can"]) and float(w["close"]) > 40.0:
				nohunt += 1
				print("NOHUNT room ", i, " ", p["name"], "  ", c.kind, " closest ", roundf(float(w["close"])), " moved ", span.round())
			if bool(w["can"]):
				reachable_n += 1
				if float(w["close"]) <= 40.0:
					reached += 1
		game.player.set_frozen(false)
	print("walkers checked ", total, " (", waiting, " ambush or blind ones left out), stuck ", stuck, ", the map says ", reachable_n, " can walk to the hero and ", reached, " did, never reached ", nohunt)
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	quit()
