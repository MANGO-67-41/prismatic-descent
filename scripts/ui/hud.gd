class_name Hud
extends Control
## In-game HUD, bottom-left: health crystals, food pips, currency.
## Crystals shatter when hurt and regrow when healed. Bind it to a VitalsState.

const MARGIN := Vector2(10, 10)
const SHATTER_TIME := 0.42
const REGROW_TIME := 0.5

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


func _draw() -> void:
	if state == null:
		return
	var origin := Vector2(MARGIN.x, size.y - MARGIN.y - 40.0)
	# Crystals, with a slow pulse on the survivors when health is critical.
	var glow := 1.0
	if state.health > 0 and state.health <= 2 and not SettingsStore.reduce_flashing:
		glow = 0.55 + 0.45 * sin(_time * 3.0)
	for i in state.max_health:
		var mode: int = _modes[i]
		var t := 0.0
		if mode == Glyphs.Crystal.SHATTER:
			t = clampf(_clock[i] / SHATTER_TIME, 0.0, 1.0)
		elif mode == Glyphs.Crystal.REGROW:
			t = clampf(_clock[i] / REGROW_TIME, 0.0, 1.0)
		Glyphs.draw_crystal(self, origin + Vector2(i * Glyphs.CRYSTAL_PITCH, 0), mode, t, glow)
	# Food pips. An empty row pulses rust: starving.
	var alarm := 0.0
	if state.food == 0:
		alarm = 0.5 + 0.5 * sin(_time * 2.0) if not SettingsStore.reduce_flashing else 1.0
	var food_origin := origin + Vector2(1, 17)
	for i in state.max_food:
		Glyphs.draw_food_pip(self, food_origin + Vector2(i * Glyphs.FOOD_PITCH, 0), i < state.food, alarm)
	# Currency.
	var cur := origin + Vector2(4, 31)
	Glyphs.draw_diamond(self, cur + Vector2(0, 3), 3, UITheme.CREAM_DIM)
	_currency_label.position = Vector2(cur.x + 8, cur.y - 4)
