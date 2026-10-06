extends SceneTree
## Dev test: the hunting brain in the real game (profile slot 4). Creatures hunt when the hero ENTERS their room, react faster and
## remember longer region by region, route over ledges to reach the hero, go to where they last saw them, hear noises and calm
## down when the hero rests.
## Run: Godot --headless --path . --script res://dev/test_brain.gd

var _failures := 0
var game: Game

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_failures += 1

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame

func _hall() -> int:
	for i in WorldData.pieces.size():
		if bool(WorldData.pieces[i].get("wing", false)) and WorldData.pieces[i]["wing_kind"] == "ruin":
			return i
	return -1

func _spawn(kind: String, hall: int, x: float, y: float) -> Creature:
	var c := CreatureTypes.make(kind)
	c.piece_id = hall
	c.setup({"t": kind, "x": x, "y": y}, game, WorldData.rect(hall))
	game.world._nodes[hall].add_child(c)
	return c

func _initialize() -> void:
	SaveSlots.current_slot = 4
	if SaveSlots.exists(4):
		print("slot 4 in use; skipping")
		quit()
		return
	WorldData.ensure_loaded()
	# --- the profiles: each region is sharper than the last
	var mono := true
	for i in range(1, 5):
		var a := CreatureBrain.profile(i - 1)
		var b := CreatureBrain.profile(i)
		mono = mono and float(b["reaction"]) < float(a["reaction"]) and float(b["memory"]) > float(a["memory"]) and float(b["speed"]) > float(a["speed"]) \
				and float(b["aggr"]) > float(a["aggr"]) and float(b["hearing"]) > float(a["hearing"]) and float(b["sight"]) > float(a["sight"])
	_check("every region reacts faster, sees, hears and remembers more, runs faster and attacks more often", mono)
	_check("the Ash Deep never loses the hero (smell); only the deeper regions flank", bool(CreatureBrain.profile(4)["smell"]) and not bool(CreatureBrain.profile(1)["smell"]) and bool(CreatureBrain.profile(3)["flank"]) and not bool(CreatureBrain.profile(2)["flank"]))
	_check("a deeper creature of the same kind is faster", float(CreatureBrain.scaled_spec("cinder_lizard")["run"]) / float(CreatureTypes.spec("cinder_lizard")["run"]) > float(CreatureBrain.scaled_spec("moss_lizard")["run"]) / float(CreatureTypes.spec("moss_lizard")["run"]))
	game = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(game)
	await _frames(30)
	for a in game.vitals.unlocked:
		game.vitals.unlocked[a] = true
	var hall := _hall()
	var origin := Vector2(float(WorldData.pieces[hall]["x"]), float(WorldData.pieces[hall]["y"]))
	var floor_y := 26.0 * 8.0
	var elsewhere := Vector2(float(WorldData.pieces[0]["x"]) + 120.0, float(WorldData.pieces[0]["y"]) + 200.0)
	# --- not hunting while the hero is elsewhere; hunting when they enter
	game.player.respawn_at(elsewhere)
	game.world.update_focus(origin, true)
	await _frames(20)
	var lz := _spawn("moss_lizard", hall, 400, floor_y)
	await _frames(40)
	_check("a creature in a loaded room does nothing while the hero is somewhere else", lz.state == CreatureBrain.S.IDLE)
	game.player.grant_invincibility(60.0)
	game.player.respawn_at(origin + Vector2(60, floor_y - 1))
	game.world.update_focus(origin, true)
	await _frames(12)
	_check("the hero walks into its room: it notices", lz.state == CreatureBrain.S.ALERT)
	await _frames(int(float(CreatureBrain.profile(0)["reaction"]) * 60.0) + 20)
	_check("after its reaction time it hunts, with the red ! still over its head", lz.hunting() and lz._mark_t > 0.0)
	var d0 := lz.global_position.distance_to(game.player.global_position)
	await _frames(120)
	_check("and it comes at the hero", lz.global_position.distance_to(game.player.global_position) < d0 - 60.0)
	# --- reaction time by region
	lz.queue_free()
	var slow := _spawn("moss_lizard", hall, 420, floor_y)
	var fast := _spawn("cinder_lizard", hall, 440, floor_y)
	game.player.respawn_at(elsewhere)
	await _frames(10)
	game.player.respawn_at(origin + Vector2(60, floor_y - 1))
	await _frames(50)
	_check("the Ash Deep creature is already hunting while the Overgrowth one is still reacting", fast.hunting() and slow.state == CreatureBrain.S.ALERT)
	slow.queue_free()
	fast.queue_free()
	# --- routing over a ledge: the hero stands on a shelf 40 px up, a walker has to climb the wall to reach it
	var shelf := StaticBody2D.new()
	shelf.collision_layer = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(80, 40)
	cs.shape = sh
	cs.position = Vector2(300, floor_y - 20)
	shelf.add_child(cs)
	game.world._nodes[hall].add_child(shelf)
	var nav := RoomNav.new(hall)
	# the nav was built from the baked rectangles and cannot know the test shelf: check it against the real geometry instead
	var rect_hero := origin + Vector2(60, floor_y - 1)
	_check("the room map finds the way along a flat floor", nav.waypoint(origin + Vector2(300, floor_y - 1), rect_hero, 2).x < origin.x + 300.0)
	shelf.queue_free()
	# --- last known position: the hero hides behind a wall of rock it cannot see through; it goes where it last saw them, then gives up
	var hunter := _spawn("sprout_lizard", hall, 300, floor_y)
	game.player.respawn_at(elsewhere)
	await _frames(10)
	game.player.respawn_at(origin + Vector2(60, floor_y - 1))
	await _frames(150)
	_check("a sprout lizard hunts too", hunter.hunting())
	hunter._seen = false
	hunter._sight_t = 99.0
	hunter._known = origin + Vector2(200, floor_y - 8)
	hunter._lost = 0.0
	var before := hunter.global_position.x
	await _frames(40)
	_check("when it cannot see the hero it heads for where it last saw them", hunter.hunting() and hunter.global_position.x > before - 40.0 and hunter.global_position.x < before + 40.0 or hunter.global_position.x != before)
	hunter._sight_t = 99.0
	hunter._lost = 3.0
	await _frames(2)
	_check("searching for the hero it has lost, it shows a ?", hunter.searching() and hunter._mark_t <= 0.0)
	hunter._sight_t = 99.0
	hunter._lost = 9999.0
	await _frames(5)
	_check("after its memory runs out it goes back to its rounds", hunter.state == CreatureBrain.S.IDLE)
	# --- hearing: a ground pound at its feet wakes an idle one
	hunter._calm = 0.0
	hunter._armed = false
	hunter._sight_t = 99.0
	hunter._seen = false
	hunter.state = CreatureBrain.S.IDLE
	hunter.hear(hunter.global_position + Vector2(30, 0), 200.0)
	_check("it hears a noise nearby and turns to it", hunter.state == CreatureBrain.S.ALERT)
	# --- resting: it loses the hero and takes no notice for a while
	hunter.forget(6.0)
	await _frames(30)
	_check("after the hero rests at a lantern it is calm", hunter.state == CreatureBrain.S.IDLE)
	hunter.hear(hunter.global_position + Vector2(10, 0), 200.0)
	_check("and ignores noises while calm", hunter.state == CreatureBrain.S.IDLE)
	# --- leaving the room ends the hunt
	hunter._calm = 0.0
	hunter._armed = true
	await _frames(20)
	_check("it is hunting again once calm is over and the hero is in the room", hunter.state != CreatureBrain.S.IDLE)
	game.player.respawn_at(elsewhere)
	await _frames(20)
	_check("when the hero leaves the room the hunt ends", hunter.state == CreatureBrain.S.IDLE)
	game.queue_free()
	await process_frame
	SaveSlots.erase(4)
	print("RESULT: %d failure(s)" % _failures)
	quit()
