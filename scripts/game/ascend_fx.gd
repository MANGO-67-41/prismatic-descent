class_name AscendFx
extends Node2D
## The light around the hero while an ability is given: a soft prismatic beam from above, rising motes and a ring that
## spreads at the start. `strength` (0..1) is tweened by the game. Respects Reduce Flashing (no ring, gentler beam).

var strength := 0.0
var _t := 0.0
var _motes: Array[Vector3] = []  ## x, y, hue


func _ready() -> void:
	z_index = 9
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		_motes.append(Vector3(rng.randf_range(-16, 16), rng.randf_range(-110, 10), rng.randf()))


func _process(delta: float) -> void:
	_t += delta
	for i in _motes.size():
		var m := _motes[i]
		m.y -= delta * (14.0 + fmod(m.z * 37.0, 10.0))
		if m.y < -140.0:
			m.y = 10.0
		_motes[i] = m
	queue_redraw()


func _draw() -> void:
	if strength <= 0.0:
		return
	var gentle := SettingsStore.reduce_flashing
	# beam: dithered columns, brightest in the middle
	for x in range(-10, 11):
		var w := 1.0 - absf(x) / 11.0
		for y in range(-150, 4, 2):
			if (x + y / 2) % 2 == 0:
				var hue := 0.5 + 0.12 * sin(_t * 1.3 + y * 0.03)
				draw_rect(Rect2(x, y, 1, 2), Color.from_hsv(hue, 0.35, 1.0, strength * w * (0.28 if gentle else 0.45)))
	# rising motes
	for m in _motes:
		draw_rect(Rect2(m.x, m.y, 1, 1), Color.from_hsv(fmod(0.48 + m.z * 0.3, 1.0), 0.4, 1.0, strength))
	# spreading ring at the start
	if not gentle and _t < 0.9:
		var r := _t * 60.0
		for k in 32:
			var ang := k * TAU / 32.0
			draw_rect(Rect2(Vector2(cos(ang), sin(ang) * 0.4) * r + Vector2(0, -6), Vector2(1, 1)), Color(UITheme.CREAM, (1.0 - _t / 0.9) * strength))
