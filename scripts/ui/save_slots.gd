class_name SaveSlots
extends RefCounted
## Four profile slots saved as user://save_1.cfg ... user://save_4.cfg.
## Only the summary shown on the profile screen lives here for now; real progress data comes later.

const COUNT := 4

## Slot chosen on the profile screen, read by the scene that follows.
static var current_slot := 1


static func path(slot: int) -> String:
	return "user://save_%d.cfg" % slot


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


## Summary for a slot, or an empty Dictionary if the slot is unused.
static func read(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path(slot)) != OK:
		return {}
	return {
		"location": str(cfg.get_value("summary", "location", "THE OVERGROWTH")),
		"percent": int(cfg.get_value("summary", "percent", 0)),
		"playtime": int(cfg.get_value("summary", "playtime", 0)),
		"max_health": int(cfg.get_value("summary", "max_health", 6)),
		"health": int(cfg.get_value("summary", "health", 6)),
		"currency": int(cfg.get_value("summary", "currency", 0)),
	}


static func write(slot: int, data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for key in data:
		cfg.set_value("summary", key, data[key])
	cfg.save(path(slot))


static func create_new(slot: int) -> void:
	write(slot, {
		"location": "THE OVERGROWTH",
		"percent": 0,
		"playtime": 0,
		"max_health": 6,
		"health": 6,
		"currency": 0,
	})


static func erase(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))


static func format_time(seconds: int) -> String:
	return "%dH %02dM" % [seconds / 3600, (seconds % 3600) / 60]
