class_name KeyBindings
extends RefCounted
## Rebindable gameplay keys, saved to user://bindings.cfg and applied to the InputMap.
## Each action has one rebindable key; arrow keys always also move left and right.

const PATH := "user://bindings.cfg"
const ACTIONS: Array[String] = ["move_left", "move_right", "jump", "dash", "pound", "eat", "interact", "inventory", "pause"]
const LABELS := {
	"move_left": "MOVE LEFT",
	"move_right": "MOVE RIGHT",
	"jump": "JUMP / DOUBLE JUMP",
	"dash": "DASH",
	"pound": "GROUND POUND",
	"eat": "EAT AND HEAL",
	"interact": "INTERACT",
	"inventory": "INVENTORY",
	"pause": "PAUSE",
}
const DEFAULTS := {
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"dash": KEY_SHIFT,
	"pound": KEY_S,
	"eat": KEY_F,
	"interact": KEY_E,
	"inventory": KEY_I,
	"pause": KEY_ESCAPE,
}
const FIXED := {"move_left": KEY_LEFT, "move_right": KEY_RIGHT, "pound": KEY_DOWN}
const RESERVED: Array[Key] = [KEY_ESCAPE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]

static var keys: Dictionary = {}


static func setup() -> void:
	keys = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for action in ACTIONS:
			keys[action] = int(cfg.get_value("keys", action, keys[action]))
	apply()


static func apply() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		_add_key(action, keys[action])
		if FIXED.has(action):
			_add_key(action, FIXED[action])


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
