class_name KeyBindings
extends RefCounted
## Rebindable gameplay keys, saved to user://bindings.cfg and applied to the InputMap.
## Each action has one rebindable key, any key but Esc. By default the bamboo stick is the left arrow and the dash the right arrow
## (the movement keys are A, D, W and S); the up and down arrows do nothing until bound. Menus, the map and
## the inventory follow the movement keys (left / right / up and the pound key for down), so whatever the player binds to move
## also moves through every menu.

const PATH := "user://bindings.cfg"
const ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "jump", "attack", "dash", "pound", "eat", "interact", "inventory", "map", "full_map", "pause"]
const LABELS := {
	"move_left": "MOVE LEFT",
	"move_right": "MOVE RIGHT",
	"move_up": "CLIMB UP",
	"jump": "JUMP / DOUBLE JUMP",
	"attack": "BAMBOO STICK",
	"dash": "DASH",
	"pound": "POUND / CLIMB DOWN",
	"eat": "HEAL",
	"interact": "INTERACT",
	"inventory": "INVENTORY",
	"map": "QUICK MAP",
	"full_map": "FULL MAP",
	"pause": "PAUSE",
}
const DEFAULTS := {
	"move_left": KEY_A,
	"move_right": KEY_D,
	"move_up": KEY_W,
	"jump": KEY_SPACE,
	"attack": KEY_LEFT,
	"dash": KEY_RIGHT,
	"pound": KEY_S,
	"eat": KEY_F,
	"interact": KEY_E,
	"inventory": KEY_I,
	"map": KEY_TAB,
	"full_map": KEY_M,
	"pause": KEY_ESCAPE,
}
const RESERVED: Array[Key] = [KEY_ESCAPE]   ## the arrow keys are free to bind like any other; they just do nothing until the player binds them
## The menu directions, each following one movement key.
const UI_FOLLOW := {"ui_left": "move_left", "ui_right": "move_right", "ui_up": "move_up", "ui_down": "pound"}

static var keys: Dictionary = {}
static var _names: Dictionary = {}  ## action -> label, so the label is not looked up every frame it is drawn


static func setup() -> void:
	keys = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for action in ACTIONS:
			keys[action] = int(cfg.get_value("keys", action, keys[action]))
	apply()


static func apply() -> void:
	_names.clear()
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		_add_key(action, keys[action])
	for ui in UI_FOLLOW:     # menus: drop every key (the arrows included), then follow the movement key
		if not InputMap.has_action(ui):
			InputMap.add_action(ui)
		for ev in InputMap.action_get_events(ui):
			if ev is InputEventKey:
				InputMap.action_erase_event(ui, ev)
		_add_key(ui, keys[UI_FOLLOW[ui]])


## "WASD" with the default keys: the four movement keys in the order up, left, down, right.
static func direction_keys() -> String:
	return key_name("move_up") + key_name("move_left") + key_name("pound") + key_name("move_right")


static func _add_key(action: String, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


static func save() -> void:
	var cfg := ConfigFile.new()
	for action in ACTIONS:
		cfg.set_value("keys", action, keys[action])
	cfg.save(PATH)


static func key_name(action: String) -> String:
	if _names.has(action):
		return _names[action]
	var label := _lookup_name(action)
	_names[action] = label
	return label


static func _lookup_name(action: String) -> String:
	var physical: Key = keys[action]
	var label := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(physical))
	if label == "":
		label = OS.get_keycode_string(physical)
	return label.to_upper()


static func is_reserved(key: Key) -> bool:
	return RESERVED.has(key)


## Binds `key` to `action`. If another action already used that key the two swap.
## Returns the label of the swapped action, or "" when there was no conflict.
static func rebind(action: String, key: Key) -> String:
	var swapped := ""
	for other in ACTIONS:
		if other != action and keys[other] == key:
			keys[other] = keys[action]
			swapped = LABELS[other]
	keys[action] = key
	apply()
	save()
	return swapped


static func reset_defaults() -> void:
	keys = DEFAULTS.duplicate()
	apply()
	save()
