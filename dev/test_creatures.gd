extends SceneTree
## Dev test: all twenty creatures in the real game, and the lizards' tricks (ambush and tongue, blind hearing, the spark
## lizard's cry, climbing any wall). Each is dropped into an empty, flat room (a ruin hall) and must: keep living
## and moving for a few seconds without leaving the room, hurt the hero on contact (when it can), be stunned by the stick, and
## follow its stomp rule. Also checks how they are spread over the world. Uses profile slot 4.
## Run: Godot --headless --path . --script res://dev/test_creatures.gd

var _failures := 0
var game: Game

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures += 1

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame

func elsewhere_of(_o: Vector2) -> Vector2:
	return Vector2(float(WorldData.pieces[0]["x"]) + 120.0, float(WorldData.pieces[0]["y"]) + 200.0)

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		print("slot 4 in use; skipping")
		quit()
		return
	WorldData.ensure_loaded()
	# --- spread over the world
	var threat := [0, 0, 0, 0, 0]
	var kinds := {}
	for p in WorldData.pieces:
		for c in p.get("creatures", []):
			var s := CreatureTypes.spec(str(c["t"]))
			threat[int(s["region"])] += mini(int(s["hp"]), 6)     # how much it takes to get past: its hits, the unkillable ones count 6
			kinds[str(c["t"])] = true
	_check("every one of the 20 creatures lives somewhere in the world", kinds.size() == 20)
	_check("each region is more dangerous than the last (threat %s)" % str(threat), threat[0] < threat[1] and threat[1] < threat[2] and threat[2] < threat[3] and threat[3] < threat[4])
	var first: Dictionary = WorldData.pieces[0]
	_check("none in the first room", (first.get("creatures", []) as Array).is_empty())
	game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(game)
	await _frames(30)
	for a in game.vitals.unlocked:
		game.vitals.unlocked[a] = true
	# a flat, empty room to test in: the first ruin hall
	var hall := -1
	for i in WorldData.pieces.size():
		if bool(WorldData.pieces[i].get("wing", false)) and WorldData.pieces[i]["wing_kind"] == "ruin":
			hall = i
			break
	var hp_: Dictionary = WorldData.pieces[hall]
	var origin := Vector2(float(hp_["x"]), float(hp_["y"]))
	var floor_y := 26.0 * 8.0
	var far := origin + Vector2(60, floor_y - 1)
	game.player.respawn_at(far)
	game.world.update_focus(far, true)
	await _frames(20)
	var node: Node2D = game.world._nodes[hall]
	var all_ok := true
	for kind in CreatureTypes.all_kinds():
		var s := CreatureTypes.spec(kind)
		var entry := {"t": kind, "x": 300, "y": floor_y}
		match str(s["arch"]):
			"flit", "dive", "wyrm":
				entry["y"] = floor_y - 60
			"swim", "angler":
				entry = {"t": kind, "x": 300, "y": floor_y - 20, "wy": floor_y - 44, "fy": floor_y}
		var c := CreatureTypes.make(kind)
		c.setup(entry, game, WorldData.rect(hall))
		node.add_child(c)
		game.player.respawn_at(far)
		game.player.grant_invincibility(30.0)
		await _frames(150)
		var alive := is_instance_valid(c) and not c.dead
		var inside := alive and WorldData.rect(hall).grow(8.0).has_point(c.global_position)
		# the hero walks into it
		var hurt_ok := true
		if alive and kind != "marrow_worm":
			game.player._inv_t = 0.0
			game.vitals.health = game.vitals.max_health
			var r: Rect2 = c.hit_rects()[0] if not c.hit_rects().is_empty() else Rect2(c.global_position, Vector2.ONE)
			game.player.global_position = r.get_center() + Vector2(0, 7)
			game.player.velocity = Vector2.ZERO
			await _frames(2)
			hurt_ok = game.vitals.health < game.vitals.max_health
			game.vitals.health = game.vitals.max_health
			game.player.grant_invincibility(30.0)
			game.player.respawn_at(far)
		# the stick
		var stun_ok := true
		if alive and kind != "marrow_worm":
			var rr: Array[Rect2] = c.hit_rects()
			stun_ok = not rr.is_empty() and c.stick_hit(rr[0], c.global_position.x - 10.0) == 1 and c.stun_left > 0.0
		# the stomp rule
		var stomp_ok := true
		if alive:
			match str(s["stomp"]):
				"always":
					stomp_ok = c.can_be_stomped()
				"stunned":
					stomp_ok = c.stun_left > 0.0 and c.can_be_stomped()
				"never":
					stomp_ok = not c.can_be_stomped()
		var ok := alive and inside and hurt_ok and stun_ok and stomp_ok
		if not ok:
			all_ok = false
			print("  ", kind, " alive ", alive, " inside ", inside, " hurts ", hurt_ok, " stuns ", stun_ok, " stomp rule ", stomp_ok, " at ", c.global_position - origin if is_instance_valid(c) else Vector2.ZERO)
		if is_instance_valid(c):
			c.queue_free()
		await _frames(2)
	_check("all 20 creatures live, stay in their room, hurt on contact, are stunned by the stick and keep their stomp rule", all_ok)
	# a crevice: two walls 32 px high either side of a walker; it has to climb out
	var pit := StaticBody2D.new()
	pit.collision_layer = 1
	for wx in [300 - 34, 300 + 34]:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(8, 32)
		cs.shape = sh
		cs.position = Vector2(wx, floor_y - 16)
		pit.add_child(cs)
	node.add_child(pit)
	var stuck: Array = []
	for kind in CreatureTypes.all_kinds():
		if not str(CreatureTypes.spec(kind)["arch"]) in ["lizard", "hound", "reach"]:
			continue
		var w := CreatureTypes.make(kind)
		w.setup({"t": kind, "x": 300, "y": floor_y}, game, WorldData.rect(hall))
		node.add_child(w)
		game.player.respawn_at(far)
		await _frames(2)
		if w.ambusher():
			w._notice(w.hero_real(), 0.1)      # an ambusher sits still until it has seen the hero: make it hunt
		var escaped := false
		var climbed := false
		for f in 600:
			await physics_frame
			if not is_instance_valid(w):
				break
			climbed = climbed or w.climbing
			var lx := w.global_position.x - origin.x
			if absf(lx - 300.0) > 28.0 and w.global_position.y - origin.y < floor_y - 28.0:   # up on top of a wall: out
				escaped = true
				break
		if not escaped:
			stuck.append(kind)
			print("  ", kind, " still in the crevice at ", w.global_position - origin if is_instance_valid(w) else Vector2.ZERO, " climbed ", climbed)
		if is_instance_valid(w):
			w.queue_free()
		await _frames(2)
	pit.queue_free()
	_check("walkers climb out of a crevice (%s)" % (", ".join(stuck) if stuck.size() > 0 else "all out"), stuck.is_empty())
	# a sprout lizard (2 hits) dies to two stomps
	var grub := CreatureTypes.make("sprout_lizard")
	grub.setup({"t": "sprout_lizard", "x": 300, "y": floor_y}, game, WorldData.rect(hall))
	node.add_child(grub)
	await _frames(20)
	for k in 2:
		game.player.grant_invincibility(5.0)
		grub._touch_lock = 0.0
		game.player.global_position = grub.hit_rects()[0].position + Vector2(4, -1)
		game.player.velocity = Vector2(0, 120)
		await _frames(3)
	_check("two stomps kill a sprout lizard", not is_instance_valid(grub) or grub.dead)
	# --- turning: the hero hopping from side to side right over a hunting lizard does not make it flip every frame
	var turner := CreatureTypes.make("moss_lizard")
	turner.piece_id = hall
	turner.setup({"t": "moss_lizard", "x": 300, "y": floor_y}, game, WorldData.rect(hall))
	node.add_child(turner)
	game.player.grant_invincibility(60.0)
	game.player.respawn_at(origin + Vector2(300, floor_y - 1))
	await _frames(20)
	turner._notice(turner.hero_real(), 0.01)
	await _frames(5)
	var flips := 0
	var last_face := turner.facing
	for f in 120:
		if f % 4 == 0:
			game.player.global_position = Vector2(turner.global_position.x + (14.0 if (f / 4) % 2 == 0 else -14.0), origin.y + floor_y - 1)
		await physics_frame
		if turner.facing != last_face:
			flips += 1
			last_face = turner.facing
	_check("a lizard with the hero hopping over it turns at most every 0.3 s (%d turns in 2 s)" % flips, flips <= 7)
	turner.queue_free()
	# --- the lizards' tricks
	var lizards := 0
	for kind in CreatureTypes.all_kinds():
		if str(CreatureTypes.spec(kind)["arch"]) == "lizard":
			lizards += 1
	_check("most of the roster are lizards (%d of 20)" % lizards, lizards >= 11)
	game.player.grant_invincibility(0.0)
	game.player._inv_t = 0.0
	# the bark lizard waits faded into the room and does not notice the hero just for coming in
	var bark := CreatureTypes.make("bark_lizard")
	bark.piece_id = hall
	bark.setup({"t": "bark_lizard", "x": 520, "y": floor_y}, game, WorldData.rect(hall))
	node.add_child(bark)
	game.player.respawn_at(origin + Vector2(60, floor_y - 1))
	await _frames(90)
	_check("a bark lizard waiting in ambush is nearly invisible and has not noticed the hero far off", bark.modulate.a < 0.4 and bark.state == CreatureBrain.S.IDLE)
	# the hero walks up: it sees them, shows itself, and its tongue yanks them in
	game.player.respawn_at(origin + Vector2(440, floor_y - 1))
	game.player.grant_invincibility(0.0)
	game.player._inv_t = 0.0
	var start_x := game.player.global_position.x
	var yanked := false
	var shown := false
	for f in 360:
		await physics_frame
		game.player._inv_t = 0.0 if not yanked else game.player._inv_t
		shown = shown or bark._mark_t > 0.0
		if bark._tongue_caught:
			yanked = true
			break
	_check("it sees the hero close by and a red ! shows", shown)
	_check("its tongue catches the hero", yanked)
	await _frames(6)
	_check("and pulls them toward it", game.player.global_position.x > start_x + 4.0)
	bark.queue_free()
	game.player.grant_invincibility(60.0)
	# the crypt lizard is blind: the hero coming in is not enough, a noise is
	var crypt := CreatureTypes.make("crypt_lizard")
	crypt.piece_id = hall
	crypt.setup({"t": "crypt_lizard", "x": 400, "y": floor_y}, game, WorldData.rect(hall))
	node.add_child(crypt)
	game.player.respawn_at(origin + Vector2(200, floor_y - 1))
	await _frames(30)
	crypt.forget(0.0)            # (the hero's landing was a noise it heard: start again with them standing still)
	crypt._armed = true
	await _frames(60)
	_check("a blind crypt lizard does not see the hero standing in plain view", crypt.state == CreatureBrain.S.IDLE)
	game._noise(game.player.global_position, 70.0)
	await _frames(2)
	_check("but hears them land", crypt.state != CreatureBrain.S.IDLE)
	crypt.queue_free()
	# the spark lizard's cry wakes the whole room at once
	var spark := CreatureTypes.make("spark_lizard")
	var mate := CreatureTypes.make("crypt_lizard")
	for pair in [[spark, "spark_lizard", 300.0], [mate, "crypt_lizard", 560.0]]:
		var cr: Creature = pair[0]
		cr.piece_id = hall
		cr.setup({"t": pair[1], "x": pair[2], "y": floor_y}, game, WorldData.rect(hall))
		node.add_child(cr)
	game.player.respawn_at(elsewhere_of(origin))
	await _frames(10)
	game.player.respawn_at(origin + Vector2(60, floor_y - 1))
	await _frames(12)
	_check("a spark lizard's cry wakes even a blind lizard across the room", spark.state != CreatureBrain.S.IDLE and mate.state != CreatureBrain.S.IDLE)
	spark.queue_free()
	mate.queue_free()
	# the bloom lizard climbs a wall far taller than the others can
	var tall := StaticBody2D.new()
	tall.collision_layer = 1
	var tcs := CollisionShape2D.new()
	var tsh := RectangleShape2D.new()
	tsh.size = Vector2(40, 96)
	tcs.shape = tsh
	tcs.position = Vector2(340, floor_y - 48)
	tall.add_child(tcs)
	node.add_child(tall)
	game.player.respawn_at(elsewhere_of(origin))
	var bloom := CreatureTypes.make("bloom_lizard")
	bloom.setup({"t": "bloom_lizard", "x": 300, "y": floor_y}, game, WorldData.rect(hall))
	bloom.facing = 1
	node.add_child(bloom)
	await _frames(5)
	bloom.facing = 1
	bloom._turn = 99.0
	var top := false
	for f in 400:
		await physics_frame
		if bloom.global_position.y - origin.y < floor_y - 90.0:
			top = true
			break
	_check("a bloom lizard climbs a wall 96 px high", top)
	bloom.queue_free()
	tall.queue_free()
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	print("RESULT: %d failure(s)" % _failures)
	quit()
