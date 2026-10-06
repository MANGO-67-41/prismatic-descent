class_name Hud
extends Control
## In-game HUD, bottom-left, laid out like Rain World's: the energy circle on the left, round health pips beside it
## (a divider marks where the crystals earned from shards begin), small cooldown dots above for ground pound and the
## invincible dash once learned, currency below. Pips burst when hurt and swell back when healed. Bind it to a VitalsState.

const MARGIN := Vector2(10, 10)
const SHATTER_TIME := 0.42
const REGROW_TIME := 0.5
const PIP_PITCH := 14.0
const PIP_R := 5.5

var player: Player  ## optional: lets the HUD show ability cooldowns

var state: VitalsState

var _modes: Array[int] = []
var _clock: Array[float] = []  # seconds since each crystal's animation began
var _time := 0.0
var _currency_label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_currency_label = Label.new()
	_currency_label.label_settings = UITheme.label_settings(12, UITheme.CREAM, false, 1)
	_currency_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_currency_label)


func bind(vitals: VitalsState) -> void:
	state = vitals
	_modes.clear()
	_clock.clear()
	for i in state.max_health:
		_modes.append(Glyphs.Crystal.FULL if i < state.health else Glyphs.Crystal.EMPTY)
		_clock.append(0.0)
	state.damaged.connect(_on_damaged)
	state.healed.connect(_on_healed)
	state.changed.connect(_on_changed)
	_on_changed()


func _on_damaged(first: int, count: int) -> void:
	for i in range(first, first + count):
		_modes[i] = Glyphs.Crystal.SHATTER
		_clock[i] = 0.0


func _on_healed(first: int, count: int) -> void:
	while _modes.size() < state.max_health:
		_modes.append(Glyphs.Crystal.EMPTY)
		_clock.append(0.0)
	for i in range(first, first + count):
		_modes[i] = Glyphs.Crystal.REGROW
		_clock[i] = 0.0


func _on_changed() -> void:
	while _modes.size() < state.max_health:
		_modes.append(Glyphs.Crystal.EMPTY)
		_clock.append(0.0)
	_currency_label.text = str(state.currency)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for i in _modes.size():
		_clock[i] += delta
		if _modes[i] == Glyphs.Crystal.SHATTER and _clock[i] >= SHATTER_TIME:
			_modes[i] = Glyphs.Crystal.EMPTY
		elif _modes[i] == Glyphs.Crystal.REGROW and _clock[i] >= REGROW_TIME:
			_modes[i] = Glyphs.Crystal.FULL
	queue_redraw()


## Where the shard circle is, and where crystal number `index` (0-based) sits in the row (the shard animation flies to these).
func circle_center() -> Vector2:
	return Vector2(MARGIN.x + 14.0, size.y - MARGIN.y - 18.0)


func pip_center(index: int) -> Vector2:
	var c := circle_center()
	return Vector2(c.x + 26.0 + index * PIP_PITCH + (6.0 if index >= VitalsState.BASE_HEALTH else 0.0) + PIP_R, c.y + 2.0)


func _draw() -> void:
	if state == null:
		return
	var base := Vector2(MARGIN.x, size.y - MARGIN.y)
	var circle := base + Vector2(14, -18)
	Glyphs.draw_energy(self, circle, 13.0, state.energy, _time, state.heal_progress)
	var glow := 1.0
	if state.health > 0 and state.health <= 2 and not SettingsStore.reduce_flashing:
		glow = 0.55 + 0.45 * sin(_time * 3.0)
	var row := Vector2(circle.x + 26.0, circle.y + 2.0)
	var x := row.x
	for i in state.max_health:
		if i == VitalsState.BASE_HEALTH and state.max_health > VitalsState.BASE_HEALTH:
			draw_rect(Rect2(x + 1.0, row.y - 9.0, 1, 18), UITheme.CREAM_DIM)    # divider: earned crystals beyond the base six
			x += 6.0
		var mode: int = _modes[i]
		var t := 0.0
		if mode == Glyphs.Crystal.SHATTER:
			t = clampf(_clock[i] / SHATTER_TIME, 0.0, 1.0)
		elif mode == Glyphs.Crystal.REGROW:
			t = clampf(_clock[i] / REGROW_TIME, 0.0, 1.0)
		Glyphs.draw_life_pip(self, Vector2(x + PIP_R, row.y), mode, t, glow, PIP_R)
		x += PIP_PITCH
	# cooldown dots above the pips (rust when spent, cream when ready), like Rain World's small row
	if player != null:
		var dx := row.x + 2.0
		var dy := row.y - 15.0
		for group in [["pound", Player.POUND_COOLDOWN, 4], ["dash_iframes", Player.IFRAME_COOLDOWN, 3]]:
			if not bool(state.unlocked.get(group[0], false)):
				continue
			var ready := player.cooldown_fraction(group[0])
			var n: int = group[2]
			for k in n:
				var lit := ready >= float(k + 1) / n
				_dot(Vector2(dx, dy), lit, ready >= 1.0)
				dx += 8.0
			draw_rect(Rect2(dx - 2.0, dy - 4.0, 1, 7), UITheme.CREAM_DIM)
			dx += 6.0
	var cur := Vector2(row.x, row.y + 12.0)
	Glyphs.draw_diamond(self, cur + Vector2(1, 3), 2, UITheme.CREAM_DIM)
	_currency_label.position = Vector2(cur.x + 7, cur.y - 3)


func _dot(c: Vector2, lit: bool, ready: bool) -> void:
	var col := (UITheme.CREAM if ready else Color("e0806a")) if lit else UITheme.RUST_DARK
	for dy in range(-2, 3):
		var half := 2 - absi(dy) / 2
		draw_rect(Rect2(c.x - half, c.y + dy, half * 2 + 1, 1), col if absi(dy) < 2 else UITheme.INK)
