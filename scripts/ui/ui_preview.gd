extends Control
## UI preview: the in-game HUD and inventory over a placeholder background, driven by demo values.
## There is no gameplay yet. Demo keys (H hurt, K hurt 2, J heal, G shard, T food, M scrap, R next
## ability) only exist to try the UI and only work in debug builds (the editor), not in exports.
## Esc closes the inventory, or returns to the title screen.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const DEMO_KEYS: Array[Key] = [KEY_H, KEY_K, KEY_J, KEY_G, KEY_T, KEY_M, KEY_R]

var vitals := VitalsState.new()
var hud: Hud
var inventory: InventoryScreen


func _ready() -> void:
	theme = UITheme.build()
	SettingsStore.load_settings()
	SettingsStore.apply()
	KeyBindings.setup()
	_load_demo_values()
	for texture in [ShaftArt.sky(), ShaftArt.walls(false), ShaftArt.walls(true), ShaftArt.platforms()]:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.stretch_mode = TextureRect.STRETCH_KEEP
		rect.position = Vector2(-ShaftArt.PAD, -ShaftArt.PAD)
		rect.size = Vector2(ShaftArt.W, ShaftArt.H)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
	hud = Hud.new()
	add_child(hud)
	hud.bind(vitals)
	inventory = InventoryScreen.new()
	add_child(inventory)
	inventory.bind(vitals)
	inventory.opened.connect(_set_overlay_ui.bind(false))
	inventory.closed.connect(_set_overlay_ui.bind(true))


func _set_overlay_ui(show_hud: bool) -> void:
	hud.visible = show_hud


func _load_demo_values() -> void:
	var summary := SaveSlots.read(SaveSlots.current_slot)
	vitals.currency = int(summary.get("currency", 0))
	vitals.completion = int(summary.get("percent", 0))
	vitals.region = str(summary.get("location", "THE OVERGROWTH"))


func _unhandled_input(event: InputEvent) -> void:
	var handler: Callable
	if event.is_action_pressed("inventory"):
		handler = _toggle_inventory
	elif event.is_action_pressed("ui_cancel"):
		handler = _on_cancel
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode in DEMO_KEYS:
		handler = _demo_key.bind((event as InputEventKey).keycode)
	else:
		return
	# Mark handled before acting: _on_cancel changes scene, after which get_viewport() is null.
	get_viewport().set_input_as_handled()
	handler.call()


func _toggle_inventory() -> void:
	if inventory.is_open:
		inventory.close()
	else:
		inventory.open()


func _on_cancel() -> void:
	if not inventory.is_open:
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
		KEY_M:
			vitals.add_currency(25)
		KEY_R:
			vitals.unlock_next()
