class_name Game
extends Node2D
## The playable game: the fixed world streamed around the hero, the Rain World-style camera, and the UI on top
## (HUD, inventory, map, pause). Enemies and food pickups come later.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const DEMO_KEYS: Array[Key] = [KEY_H, KEY_K, KEY_J, KEY_G, KEY_T, KEY_C, KEY_R]
const REST_REACH := Vector2(20, 26)
## The ability each region gives the first time the hero enters it (region index -> ability id).
const REGION_ABILITY := ["", "pound", "double_jump", "dash_iframes", "fast_heal"]

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
	add_child(world)
	player = Player.new()
	player.world = world
	player.vitals = vitals
	player.pounded.connect(_on_pounded)
	add_child(player)
	cam = GameCamera.new()
	add_child(cam)
	cam.make_current()
	_build_ui()
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
	pause_menu = PauseMenu.new()
	ui.add_child(pause_menu)
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
		vitals.food = int(progress.get("food", vitals.food))
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
	player.input_enabled = not (inventory.is_open or world_map.is_full() or pause_menu.is_open or in_ceremony)
	_check_region_gift()


func _enter_piece(id: int) -> void:
	_grounded = 0.0
	var is_new := not discovered.has(id)
	discovered[id] = true
	var region_index := int(WorldData.pieces[id]["region"])
	var region := WorldData.region_name(region_index)
	if region_index != _region_idx:
		_region_idx = region_index
		area_title.show_area(region, WorldMap.REGIONS[region_index]["colour"])
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


func _on_pounded(at: Vector2) -> void:
	AbilityFx.shockwave(self, at)
	var n := world.break_cracks_at(at)
	cam.shake(3.0 if n > 0 else 1.5)
	if n > 0:
		_save()


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
			{"abilities": abilities, "broken": world.broken.keys(), "food": vitals.food})


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
	if inventory.is_open or pause_menu.is_open or in_ceremony:
		return
	if full:
		world_map.press_full()
	else:
		world_map.press_quick()


func _toggle_inventory() -> void:
	if world_map.is_full() or in_ceremony:
		return
	if inventory.is_open:
		inventory.close()
	else:
		world_map.close()
		inventory.open()


func _interact() -> void:
	if inventory.is_open or pause_menu.is_open or world_map.is_full():
		return
	for r in _rests:
		var d := (player.position - r).abs()
		if d.x <= REST_REACH.x and d.y <= REST_REACH.y:
			rest_pos = r
			vitals.heal(vitals.max_health)
			_save()
			return


func _on_cancel() -> void:
	if not inventory.is_open and not pause_menu.is_open:
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
		KEY_J:
			vitals.heal(1)
		KEY_G:
			vitals.add_shard()
		KEY_T:
			vitals.eat(1)
		KEY_C:
			vitals.add_currency(25)
		KEY_R:
			vitals.unlock_next()
