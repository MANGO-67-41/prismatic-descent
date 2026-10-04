class_name GameCamera
extends Camera2D
## Rain World-style camera: a room is a set of fixed 480x272 screens and the view cuts from screen to screen as the hero
## crosses between them (with a quick ease so it does not pop). Shafts are narrower than the screen, so the view stays
## centred on the shaft and follows the hero up and down.

const SCREEN := Vector2(480, 272)
const EASE := 14.0

var _target := Vector2.ZERO
var _first := true
var _shake := 0.0


func _init() -> void:
	position_smoothing_enabled = false
	ignore_rotation = true


## Call every frame with the piece the hero is in and the hero's position.
func follow(piece_rect: Rect2, hero: Vector2, is_shaft: bool, delta: float) -> void:
	var focus := hero - Vector2(0, 7)
	if is_shaft:
		_target = Vector2(piece_rect.get_center().x, clampf(focus.y, piece_rect.position.y + 20.0, piece_rect.end.y - 20.0))
	else:
		var cx := clampi(int((focus.x - piece_rect.position.x) / SCREEN.x), 0, maxi(int(piece_rect.size.x / SCREEN.x) - 1, 0))
		var cy := clampi(int((focus.y - piece_rect.position.y) / SCREEN.y), 0, maxi(int(piece_rect.size.y / SCREEN.y) - 1, 0))
		_target = piece_rect.position + Vector2(cx * SCREEN.x + SCREEN.x / 2.0, cy * SCREEN.y + SCREEN.y / 2.0)
	if _first:
		_first = false
		global_position = _target.round()
		return
	global_position = global_position.lerp(_target, 1.0 - exp(-EASE * delta)).round()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 18.0)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * ceilf(_shake)
	else:
		offset = Vector2.ZERO


## A small jolt (ground pound landing). Off when Screen Shake is off in the settings.
func shake(amount: float) -> void:
	if SettingsStore.screen_shake:
		_shake = maxf(_shake, amount)
