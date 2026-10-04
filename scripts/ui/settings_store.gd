class_name SettingsStore
extends RefCounted
## Player settings: loaded from and saved to user://settings.cfg, applied to the engine.

const PATH := "user://settings.cfg"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

static var music: int = 8  ## 0-10 pips
static var sfx: int = 8  ## 0-10 pips
static var screen_shake: bool = true
static var reduce_flashing: bool = false
static var fullscreen: bool = false


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music = clampi(int(cfg.get_value("audio", "music", music)), 0, 10)
	sfx = clampi(int(cfg.get_value("audio", "sfx", sfx)), 0, 10)
	screen_shake = bool(cfg.get_value("comfort", "screen_shake", screen_shake))
	reduce_flashing = bool(cfg.get_value("comfort", "reduce_flashing", reduce_flashing))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("comfort", "screen_shake", screen_shake)
	cfg.set_value("comfort", "reduce_flashing", reduce_flashing)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)


static func apply() -> void:
	_set_bus_pips(BUS_MUSIC, music)
	_set_bus_pips(BUS_SFX, sfx)
	if not OS.has_feature("web"):  # browsers only allow fullscreen from a user gesture
		apply_fullscreen()


static func apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


static func _set_bus_pips(bus_name: String, pips: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_mute(idx, pips == 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(pow(float(pips) / 10.0, 2.0)) if pips > 0 else -80.0)
