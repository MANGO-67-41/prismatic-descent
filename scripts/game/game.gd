class_name Game
extends Node2D
## The playable game: the fixed world streamed around the hero, the Rain World-style camera, and the UI on top
## (HUD, inventory, map, pause). Enemies come later.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const DEMO_KEYS: Array[Key] = [KEY_H, KEY_K, KEY_U, KEY_G, KEY_T, KEY_C, KEY_R]
const REST_REACH := Vector2(20, 26)
## The ability each region gives the first time the hero enters it (region index -> ability id).
const REGION_ABILITY := ["", "pound", "double_jump", "dash_iframes", "fast_heal", ""]

var vitals := VitalsState.new()
var world: World
var player: Player
var cam: GameCamera
var hud: Hud
var inventory: InventoryScreen
var pause_menu: PauseMenu
var world_map: WorldMap
var ceremony: UpgradeCeremony
var area_title: AreaTitle
const LANTERN_ROOM := "LANTERN ROOM"
var scroll_reader: ScrollReader
var toast: Toast
var boss_bar: BossBar
var death_screen: DeathScreen
var dying := false  ## the fade out and back in after the hero's last crystal breaks
var _fade_rect: ColorRect
var _region_idx := -1
var in_ceremony := false
var _grounded := 0.0  ## how long the hero has stood on solid ground (the gift waits for a real landing)
var discovered: Dictionary = {}  ## piece id -> true
var piece := 0
var rest_pos := Vector2.ZERO

var _rests: Array[Vector2] = []
var _away := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(UITheme.INK)
	SettingsStore.load_settings()
	SettingsStore.apply()
	KeyBindings.setup()
	WorldData.ensure_loaded()
	_load_vitals()
	for p in WorldData.pieces:
		for r in p["rest"]:
			_rests.append(Vector2(float(p["x"]) + float(r[0]), float(p["y"]) + float(r[1])))
	world = World.new()
	world.game = self
	add_child(world)
	player = Player.new()
	player.world = world
	player.vitals = vitals
	player.pounded.connect(_on_pounded)
	player.hit.connect(_on_hero_hit)
	player.swung.connect(_on_swung)
	player.landed.connect(func() -> void: _noise(player.global_position, 70.0))
	add_child(player)
	cam = GameCamera.new()
	add_child(cam)
	cam.make_current()
	_build_ui()
	hud.player = player
	_spawn()


func _load_vitals() -> void:
	var summary := SaveSlots.read(SaveSlots.current_slot)
	vitals.currency = int(summary.get("currency", 0))
	vitals.region = str(summary.get("location", "THE OVERGROWTH"))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UITheme.build()
	layer.add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	hud.bind(vitals)
	inventory = InventoryScreen.new()
	ui.add_child(inventory)
	inventory.bind(vitals)
	world_map = WorldMap.new()
	ui.add_child(world_map)
	world_map.bind_discovered(discovered)
	world_map.opened.connect(_set_overlay_ui.bind(false))
	world_map.closed.connect(_set_overlay_ui.bind(true))
	ceremony = UpgradeCeremony.new()
	ui.add_child(ceremony)
	area_title = AreaTitle.new()
	ui.add_child(area_title)
	boss_bar = BossBar.new()
	ui.add_child(boss_bar)
	toast = Toast.new()
	ui.add_child(toast)
	scroll_reader = ScrollReader.new()
	ui.add_child(scroll_reader)
	pause_menu = PauseMenu.new()
	ui.add_child(pause_menu)
	death_screen = DeathScreen.new()
	ui.add_child(death_screen)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(UITheme.INK, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade_rect)
	pause_menu.quit_to_menu.connect(_go_title)
	inventory.opened.connect(_set_overlay_ui.bind(false))
	inventory.closed.connect(_set_overlay_ui.bind(true))


func _spawn() -> void:
	var progress := SaveSlots.read_progress(SaveSlots.current_slot)
	var start := Vector2.ZERO
	var first: Dictionary = WorldData.pieces[0]
	var s: Array = first["start"][0]
	start = Vector2(float(first["x"]) + float(s[0]), float(first["y"]) + float(s[1]))
	rest_pos = start
	if not progress.is_empty():
		start = progress["pos"]
		rest_pos = progress["rest_pos"] if progress["rest_pos"] != Vector2.ZERO else start
		for id in progress["rooms"]:
			discovered[int(id)] = true
		for a in progress.get("abilities", []):
			vitals.unlocked[str(a)] = true
		for b in progress.get("broken", []):
			world.broken[str(b)] = true
		vitals.energy = float(progress.get("energy", 0.0))
		for id in progress.get("items", []):
			vitals.items[str(id)] = true
		for id in progress.get("guardians", []):
			vitals.guardians[str(id)] = true
		for id in progress.get("doors", []):
			vitals.doors[str(id)] = true
		for id in progress.get("scrolls", []):
			vitals.read_scrolls[str(id)] = true
	player.position = start
	piece = maxi(WorldData.piece_at(start - Vector2(0, 7), 0), 0)
	world.update_focus(player.position, true)
	_enter_piece(piece)
	cam.follow(WorldData.rect(piece), player.position, WorldData.pieces[piece]["kind"] == "shaft", 1.0)


func _process(delta: float) -> void:
	var here := WorldData.piece_at(player.position - Vector2(0, 7), piece)
	if here >= 0:
		_away = 0.0
		if here != piece:
			piece = here
			_enter_piece(piece)
	else:
		_away += delta
		if _away > 2.0 or player.position.y > WorldData.size.y + 200.0:  # fell out of the world: back to the last rest
			player.respawn_at(rest_pos)
			_away = 0.0
	cam.follow(WorldData.rect(piece), player.position, WorldData.pieces[piece]["kind"] == "shaft", delta)
	world.update_focus(player.position)
	world_map.set_player(player.position, piece)
	if not in_ceremony:
		vitals.tick_energy(delta)
	player.input_enabled = not (inventory.is_open or world_map.is_full() or pause_menu.is_open or in_ceremony or scroll_reader.is_open or dying)
	_check_region_gift()
	# footsteps: running on the ground makes a little noise every few strides (the blind crypt lizard hunts by it)
	if player.is_on_floor() and absf(player.velocity.x) > 40.0 and not player.frozen:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.3
			_noise(player.global_position, 45.0)
	else:
		_step_t = 0.0


var _step_t := 0.0


func _enter_piece(id: int) -> void:
	_grounded = 0.0
	var is_new := not discovered.has(id)
	discovered[id] = true
	var region_index := int(WorldData.pieces[id]["region"])
	var region := WorldData.region_name(region_index)
	if region_index != _region_idx:
		_region_idx = region_index
		area_title.show_area(region, WorldMap.REGIONS[region_index]["colour"])
	elif str(WorldData.pieces[id].get("wing_kind", "")) == "shrine":
		area_title.show_area(LANTERN_ROOM, WorldMap.REGIONS[region_index]["colour"])      # walking into one of the lantern shrines
	if region != vitals.region:
		vitals.region = region
		vitals.changed.emit()
		SaveSlots.write(SaveSlots.current_slot, {"location": region})
	if is_new:
		vitals.completion = int(100.0 * discovered.size() / WorldData.pieces.size())
		vitals.changed.emit()


# --- Region abilities -----------------------------------------------------------------------


## The first time the hero stands in a region's room, they are lifted into the light and given that region's ability.
func _check_region_gift() -> void:
	_grounded = _grounded + get_process_delta_time() if (player.is_on_floor() and absf(player.velocity.y) < 1.0) else 0.0
	if in_ceremony or pause_menu.is_open or WorldData.pieces[piece]["kind"] != "room" or _grounded < 0.25:
		return
	var region := int(WorldData.pieces[piece]["region"])
	var gift: String = REGION_ABILITY[region]
	if gift == "" or bool(vitals.unlocked.get(gift, false)):
		return
	_ascend(gift)


func _ascend(gift: String) -> void:
	in_ceremony = true
	world_map.close()
	inventory.close()
	hud.visible = false
	player.set_frozen(true)
	var fx := AscendFx.new()
	fx.position = player.position
	add_child(fx)
	var screen_y := player.global_position.y - cam.global_position.y + 135.0
	ceremony.show_for(gift, screen_y - 20.0)
	var ground := player.position.y
	var rise := 30.0
	while rise > 0.0 and player.test_move(player.global_transform, Vector2(0, -rise)):
		rise -= 2.0   # never float into a ceiling
	var tw := create_tween()
	tw.tween_property(fx, "strength", 1.0, 0.5)
	tw.parallel().tween_property(player, "position:y", ground - rise, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		vitals.unlocked[gift] = true
		vitals.changed.emit()
		_save()
	)
	tw.tween_property(ceremony, "banner", 1.0, 0.45)
	tw.tween_interval(2.6)
	tw.tween_property(ceremony, "banner", 0.0, 0.4)
	tw.parallel().tween_property(player, "position:y", ground, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(fx, "strength", 0.0, 0.7)
	tw.tween_callback(func() -> void:
		fx.queue_free()
		player.set_frozen(false)
		hud.visible = true
		in_ceremony = false
	)
	_ceremony_tween = tw


var _ceremony_tween: Tween


## A sound the creatures can hear: they turn toward it if it carries far enough for their region's ears.
func _noise(at: Vector2, radius: float) -> void:
	get_tree().call_group("creatures", "hear", at, radius)


func _on_pounded(at: Vector2) -> void:
	_noise(at, 240.0)
	AbilityFx.shockwave(self, at)
	var n := world.break_cracks_at(at)
	cam.shake(3.0 if n > 0 else 1.5)
	if n > 0:
		_save()


# --- The temples: scrolls, keys, gates, guardians, and being hurt -------------------------------------


func read_scroll(id: String) -> void:
	var data := StoryData.scroll(id)
	vitals.read_scrolls[id] = true
	scroll_reader.open(str(data["title"]), data["pages"])
	_save()


func collect_key(region: int) -> void:
	vitals.items["key_%d" % region] = true
	vitals.changed.emit()
	toast.show_message(StoryData.key_name(region), StoryData.COLOURS[region], "A GATE WILL OPEN FOR IT")
	_save()


func open_door(id: String) -> void:
	vitals.doors[id] = true
	toast.show_message("THE GATE OPENS", Color("e8d9a8"))
	cam.shake(2.0)
	_save()


func guardian_defeated(id: String, region: int) -> void:
	vitals.guardians[id] = true
	vitals.add_shard()
	var left := 5 - vitals.guardians.size()
	toast.show_message(StoryData.REGIONS[region] + " GUARDIAN FALLEN", StoryData.COLOURS[region],
			"THE SEAL ABOVE THE LAKE WILL OPEN" if left == 0 else "%d OF 5 GUARDIANS BROKEN" % vitals.guardians.size())
	_save()


## The bamboo stick landed: whatever can be stunned in its reach is (see Guardian.stick_hit). A clean stun freezes the
## world for a blink and shakes the camera; a glancing blow only sparks.
func _on_swung(box: Rect2, _dir: int) -> void:
	_noise(player.global_position, 80.0)
	var recoiled := false
	for node in get_tree().get_nodes_in_group("stunnable"):
		var result: int = node.stick_hit(box, player.global_position.x)
		if result == 0:
			continue
		if not recoiled:
			recoiled = true
			player.recoil()
		var fx := BambooStick.Impact.new(result == 1)
		fx.position = (box.get_center() + (Vector2.ZERO if player.swing_up() else Vector2(player.facing * 6.0, 0.0))).floor()
		add_child(fx)
		if result == 1:
			cam.shake(2.5)
			_hitstop(0.07)
		else:
			cam.shake(0.8)


func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _on_hero_hit(_from_x: float) -> void:
	cam.shake(2.5)
	if vitals.health <= 0:
		_die()


## The last crystal broke: fade out, wake at the last rest with full health, fade back in. Guardians reset.
func _die() -> void:
	if dying:
		return
	dying = true
	player.grant_invincibility(6.0)
	death_screen.finished.connect(func() -> void: dying = false, CONNECT_ONE_SHOT)
	death_screen.play(_wake_at_rest, func() -> void: cam.shake(3.0))


## Under the death screen's ink: the hero wakes at the last lantern with every crystal back.
func _wake_at_rest() -> void:
	player.respawn_at(rest_pos)
	vitals.heal(vitals.max_health)
	player.grant_invincibility(1.5)
	world.update_focus(rest_pos, true)
	piece = maxi(WorldData.piece_at(rest_pos - Vector2(0, 7), 0), 0)
	_enter_piece(piece)
	cam.follow(WorldData.rect(piece), rest_pos, WorldData.pieces[piece]["kind"] == "shaft", 1.0)
	# the corner says where they woke, as the ink lifts
	var colour: Color = WorldMap.REGIONS[int(WorldData.pieces[piece]["region"])]["colour"]
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		if is_instance_valid(area_title):
			area_title.show_area(LANTERN_ROOM, colour))


func _set_overlay_ui(show_hud: bool) -> void:
	hud.visible = show_hud


func _save() -> void:
	SaveSlots.write(SaveSlots.current_slot, {"location": vitals.region, "percent": vitals.completion, "max_health": vitals.max_health, "health": vitals.health, "currency": vitals.currency})
	var abilities: Array = []
	for a in vitals.unlocked:
		if vitals.unlocked[a]:
			abilities.append(a)
	var pos := player.position
	if in_ceremony:
		pos.y = rest_pos.y if pos.distance_to(rest_pos) < 1.0 else pos.y
	SaveSlots.write_progress(SaveSlots.current_slot, pos, discovered.keys(), rest_pos,
			{"abilities": abilities, "broken": world.broken.keys(), "energy": vitals.energy, "items": vitals.items.keys(),
			"guardians": vitals.guardians.keys(), "doors": vitals.doors.keys(), "scrolls": vitals.read_scrolls.keys()})


func _exit_tree() -> void:
	if player != null and is_instance_valid(player):
		_save()


# --- Input --------------------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if in_ceremony:
		if ceremony.banner > 0.9 and (event.is_action_pressed("jump") or event.is_action_pressed("interact")) and _ceremony_tween:
			_ceremony_tween.set_speed_scale(4.0)
			get_viewport().set_input_as_handled()
		if not event.is_action_pressed("ui_cancel"):
			return
	var handler: Callable
	if event.is_action_pressed("inventory"):
		handler = _toggle_inventory
	elif event.is_action_pressed("map"):
		handler = _press_map.bind(false)
	elif event.is_action_pressed("full_map"):
		handler = _press_map.bind(true)
	elif event.is_action_pressed("interact"):
		handler = _interact
	elif event.is_action_pressed("ui_cancel"):
		handler = _on_cancel
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode in DEMO_KEYS:
		handler = _demo_key.bind((event as InputEventKey).keycode)
	else:
		return
	# Mark handled before acting: _on_cancel may change scene, after which get_viewport() is null.
	get_viewport().set_input_as_handled()
	handler.call()


func _press_map(full: bool) -> void:
	if inventory.is_open or pause_menu.is_open or in_ceremony or scroll_reader.is_open:
		return
	if full:
		world_map.press_full()
	else:
		world_map.press_quick()


func _toggle_inventory() -> void:
	if world_map.is_full() or in_ceremony or scroll_reader.is_open:
		return
	if inventory.is_open:
		inventory.close()
	else:
		world_map.close()
		inventory.open()


func _interact() -> void:
	if inventory.is_open or pause_menu.is_open or world_map.is_full() or scroll_reader.is_open or dying:
		return
	for node in get_tree().get_nodes_in_group("interactable"):
		if node.has_method("can_interact") and node.can_interact(player.global_position):
			node.interact(self)
			return
	for r in _rests:
		var d := (player.position - r).abs()
		if d.x <= REST_REACH.x and d.y <= REST_REACH.y:
			rest_pos = r
			get_tree().call_group("creatures", "forget", 6.0)      # a lantern is a breather: whatever was hunting loses them
			vitals.heal(vitals.max_health)
			_save()
			return


func _on_cancel() -> void:
	if not inventory.is_open and not pause_menu.is_open and not scroll_reader.is_open:
		world_map.close()
		_save()
		pause_menu.open()


func _go_title() -> void:
	_save()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _demo_key(keycode: Key) -> void:
	match keycode:
		KEY_H:
			vitals.hurt(1)
		KEY_K:
			vitals.hurt(2)
		KEY_U:
			vitals.heal(1)
		KEY_G:
			vitals.add_shard()
		KEY_T:
			vitals.energy = 1.0
		KEY_C:
			vitals.add_currency(25)
		KEY_R:
			vitals.unlock_next()
