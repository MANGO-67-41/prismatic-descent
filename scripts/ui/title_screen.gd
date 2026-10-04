extends Control
## Title screen and main menu: "The Shaft".
## You look straight down the shaft you will descend; the prismatic lake glimmers at the bottom.
## Keyboard: Up/Down (or W/S) move, Left/Right (or A/D) adjust, Enter/Space select, Esc back.
## Mouse: hover selects, click activates (click a pip to set volume), right click goes back.

signal start_requested(slot: int)

enum Screen { MAIN, SETTINGS, CONTROLS, PROFILES }

const PIPS := 10
const TEXT_SIZE := 16
const ROW_HEIGHT := 18
const BAR_X := 292
const PREVIEW_SCENE := "res://scenes/game/game.tscn"


## Prismatic glimmer at the bottom of the shaft. The only saturated colour on screen.
class LakeGlow extends Control:
	var intensity := 0.4

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(480, 270)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var calm := SettingsStore.reduce_flashing
		var drift := 0.02 if calm else 0.06
		var cx := 240
		for row in 10:
			var y := 259 + row
			var span := 96 - row * 4
			for x in range(cx - span, cx + span, 4):
				var wave := sin(x * 0.35 + t * (0.6 if calm else 1.8) + row)
				if wave > 0.2:
					var hue := fposmod(UITheme.PRISM_HUE + t * drift + x * 0.0015 + row * 0.01, 1.0)
					var alpha := (0.2 + 0.55 * intensity) * (1.0 - row / 11.0)
					draw_rect(Rect2(x, y, 3, 1), Color.from_hsv(hue, 0.45, 1.0, alpha))
		for dy in range(-10, 11):
			var half := (10 - absi(dy)) * 4
			var hue := fposmod(UITheme.PRISM_HUE + t * drift + dy * 0.03, 1.0)
			var alpha := (0.4 + 0.6 * intensity) * (1.0 - absf(dy) / 12.0)
			draw_rect(Rect2(cx - half, 256 + dy, half * 2 + 1, 1), Color.from_hsv(hue, 0.4, 1.0, alpha))


## The selector: a small drop that falls from item to item.
class DropSelector extends Control:
	const SHAPE: Array[String] = ["00100", "01110", "01110", "11111", "11111", "11111", "01110"]
	var tint := UITheme.CREAM

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(5, 7)

	func _draw() -> void:
		for r in SHAPE.size():
			for c in SHAPE[r].length():
				if SHAPE[r][c] == "1":
					draw_rect(Rect2(c - 1, r - 1, 3, 3), UITheme.INK)
		for r in SHAPE.size():
			for c in SHAPE[r].length():
				if SHAPE[r][c] == "1":
					draw_rect(Rect2(c, r, 1, 1), tint)


## Hover effect: a rust line that draws itself under the highlighted row.
class Underline extends Control:
	var line_width := 0.0:
		set(value):
			line_width = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(200, 2)

	func _draw() -> void:
		var w := int(line_width)
		draw_rect(Rect2(0, 0, w, 1), UITheme.RUST)
		draw_rect(Rect2(0, 1, w, 1), UITheme.INK)


## Thin rusted line with a diamond at its centre, between title and menu.
class Divider extends Control:
	var half := 58
	var ornate := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(480, 7)

	func _draw() -> void:
		var cx := 240
		for side in [-1, 1]:
			var x0: int = cx + 6 if side == 1 else cx - half
			draw_rect(Rect2(x0, 3, half - 6, 1), UITheme.RUST)
			draw_rect(Rect2(x0, 4, half - 6, 1), UITheme.INK)
			var tick_x: int = cx + half - 1 if side == 1 else cx - half
			draw_rect(Rect2(tick_x, 1, 1, 5), UITheme.RUST)
		var widths := [1, 3, 5, 3, 1]
		for i in widths.size():
			draw_rect(Rect2(cx - widths[i] / 2, 1 + i, widths[i], 1), UITheme.CREAM_DIM)
		if ornate:
			for side in [-1, 1]:
				for step in [16, 28]:
					var dx: int = cx + side * step
					draw_rect(Rect2(dx - 1, 2, 3, 3), UITheme.INK)
					draw_rect(Rect2(dx, 3, 1, 1), UITheme.CREAM_DIM)
					draw_rect(Rect2(dx - 1, 3, 3, 1), UITheme.CREAM_DIM)
					draw_rect(Rect2(dx, 2, 1, 3), UITheme.CREAM_DIM)


## Ten discrete pips, like Hollow Knight's health, used for volume.
class PipBar extends Control:
	var value := 0
	var active := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(70, 7)

	func _draw() -> void:
		for i in 10:
			var filled := i < value
			var colour := UITheme.RUST_DARK
			if filled:
				colour = UITheme.CREAM if active else UITheme.CREAM_DIM
			draw_rect(Rect2(i * 7 - 1, -1, 6, 9), UITheme.INK)
			draw_rect(Rect2(i * 7, 0, 4, 7), colour)


var _screen: int = Screen.MAIN
var _rows: Array[Dictionary] = []
var _index := 0
var _return_index := 0
var _capturing_row := -1
var _time := 0.0

var _layers: Array[TextureRect] = []
var _sway: Array[Vector2] = [Vector2(1, 0.31), Vector2(2, 0.23), Vector2(3, 0.17), Vector2(3, 0.17)]
var _lake: LakeGlow
var _title_root: Control
var _header: Label
var _menu_root: Control
var _selector: DropSelector
var _selector_tween: Tween
var _underline: Underline
var _underline_tween: Tween
var _hint: Label
var _dim: ColorRect
var _header_divider: Divider
var _clear_armed := -1
## When true, choosing a profile opens the HUD and inventory preview. Tests switch it off.
var open_game_on_start := true

var _ls_normal: LabelSettings
var _ls_selected: LabelSettings
var _ls_value: LabelSettings
var _ls_dim: LabelSettings


func _ready() -> void:
	theme = UITheme.build()
	_ensure_keys()
	SettingsStore.load_settings()
	SettingsStore.apply()
	KeyBindings.setup()
	_ls_normal = UITheme.label_settings(TEXT_SIZE, UITheme.CREAM_DIM)
	_ls_selected = UITheme.label_settings(TEXT_SIZE, UITheme.CREAM)
	_ls_value = UITheme.label_settings(TEXT_SIZE, UITheme.CREAM)
	_ls_dim = UITheme.label_settings(12, UITheme.CREAM_DIM, false, 1)
	_build_background()
	_build_title()
	_menu_root = Control.new()
	_menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_root)
	_underline = Underline.new()
	add_child(_underline)
	_selector = DropSelector.new()
	add_child(_selector)
	_hint = _make_label("", _ls_dim, Rect2(0, 232, 480, 14))
	add_child(_hint)
	_show_screen(Screen.MAIN)
	_place_selector(false)


func _process(delta: float) -> void:
	_time += delta
	for i in _layers.size():
		var amp: float = _sway[i].x
		var off := roundf(sin(_time * _sway[i].y + i) * amp)
		_layers[i].position = Vector2(-ShaftArt.PAD + off, -ShaftArt.PAD)
	var target := 0.35
	if _screen == Screen.MAIN and _rows.size() > 1:
		target = 0.35 + 0.65 * float(_index) / float(_rows.size() - 1)
	_lake.intensity = lerpf(_lake.intensity, target, clampf(delta * 3.0, 0.0, 1.0))
	if _capturing_row != -1:
		var keys_label: Label = _rows[_capturing_row]["keys"]
		keys_label.modulate.a = 0.55 + 0.45 * sin(_time * 8.0)


func _input(event: InputEvent) -> void:
	if _capturing_row != -1:
		if event is InputEventKey and event.pressed and not event.echo:
			_finish_capture((event as InputEventKey).physical_keycode)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			_cancel_capture()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var hit := _row_at(make_input_local(event).position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hit != -1 else Control.CURSOR_ARROW
		if hit != -1 and hit != _index:
			_select(hit)
	elif event is InputEventMouseButton and event.pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				_click(make_input_local(event).position)
			MOUSE_BUTTON_RIGHT:
				_back()
			MOUSE_BUTTON_WHEEL_UP:
				_wheel(1, make_input_local(event).position)
			MOUSE_BUTTON_WHEEL_DOWN:
				_wheel(-1, make_input_local(event).position)


func _unhandled_input(event: InputEvent) -> void:
	var handler: Callable
	if event.is_action_pressed("ui_down", true):
		handler = _move.bind(1)
	elif event.is_action_pressed("ui_up", true):
		handler = _move.bind(-1)
	elif event.is_action_pressed("ui_left", true):
		handler = _adjust.bind(-1)
	elif event.is_action_pressed("ui_right", true):
		handler = _adjust.bind(1)
	elif event.is_action_pressed("ui_accept"):
		handler = _activate
	elif event.is_action_pressed("ui_cancel"):
		handler = _back
	elif _is_clear_key(event) and _screen == Screen.PROFILES:
		handler = _request_clear
	else:
		return
	# Mark the key handled BEFORE acting: _activate can change scene, and once this node has left
	# the tree get_viewport() is null (that crashed into the debugger on Enter).
	get_viewport().set_input_as_handled()
	handler.call()


## Dev helper used by dev/capture.gd to screenshot a given state.
func debug_show(screen: int, index: int, capturing: bool = false) -> void:
	_show_screen(screen)
	_index = clampi(index, 0, _rows.size() - 1)
	if capturing:
		_capturing_row = _index
	_refresh()
	_place_selector(false)


func _ensure_keys() -> void:
	var extra := {"ui_up": KEY_W, "ui_down": KEY_S, "ui_left": KEY_A, "ui_right": KEY_D}
	for action in extra:
		var ev := InputEventKey.new()
		ev.physical_keycode = extra[action]
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


# --- Building -----------------------------------------------------------------------------


func _build_background() -> void:
	_layers.append(_layer(ShaftArt.sky()))
	_lake = LakeGlow.new()
	add_child(_lake)
	_layers.append(_layer(ShaftArt.walls(false)))
	_layers.append(_layer(ShaftArt.walls(true)))
	_layers.append(_layer(ShaftArt.platforms()))
	add_child(_make_motes())
	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.03, 0.06, 0.0)
	_dim.size = Vector2(480, 270)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)


func _layer(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.position = Vector2(-ShaftArt.PAD, -ShaftArt.PAD)
	rect.size = Vector2(ShaftArt.W, ShaftArt.H)
	add_child(rect)
	return rect


func _make_motes() -> CPUParticles2D:
	var motes := CPUParticles2D.new()
	motes.position = Vector2(240, 135)
	motes.amount = 36
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(240, 135)
	motes.direction = Vector2(0.2, -1.0)
	motes.spread = 25.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 2.0
	motes.initial_velocity_max = 7.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.86, 0.6, 0.0))
	fade.set_color(1, Color(1.0, 0.86, 0.6, 0.0))
	fade.add_point(0.25, Color(1.0, 0.86, 0.6, 0.5))
	motes.color_ramp = fade
	return motes


func _build_title() -> void:
	_title_root = Control.new()
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_root)
	_title_root.add_child(_make_label("THE PRISMATIC", UITheme.label_settings(12, UITheme.CREAM, false, 4), Rect2(0, 26, 480, 16)))
	_title_root.add_child(_make_label("DESCENT", UITheme.label_settings(40, UITheme.CREAM, false, 3, 2), Rect2(0, 46, 480, 48)))
	var divider := Divider.new()
	divider.position = Vector2(0, 92)
	_title_root.add_child(divider)
	_header = _make_label("", UITheme.label_settings(20, UITheme.CREAM, false, 3, 2), Rect2(0, 34, 480, 24))
	add_child(_header)
	_header_divider = Divider.new()
	_header_divider.half = 120
	_header_divider.ornate = true
	_header_divider.position = Vector2(0, 42)
	_header_divider.visible = false
	add_child(_header_divider)


func _make_label(text: String, settings: LabelSettings, rect: Rect2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _rows_for(screen: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	match screen:
		Screen.MAIN:
			rows.append({"id": "start", "label": "START GAME", "kind": "action"})
			rows.append({"id": "settings", "label": "SETTINGS", "kind": "action"})
			rows.append({"id": "controls", "label": "CONTROLS", "kind": "action"})
			if not OS.has_feature("web"):
				rows.append({"id": "quit", "label": "QUIT", "kind": "action"})
		Screen.SETTINGS:
			rows.append({"id": "music", "label": "MUSIC", "kind": "slider"})
			rows.append({"id": "sfx", "label": "EFFECTS", "kind": "slider"})
			rows.append({"id": "shake", "label": "SCREEN SHAKE", "kind": "toggle"})
			rows.append({"id": "flash", "label": "REDUCE FLASHING", "kind": "toggle"})
			rows.append({"id": "fullscreen", "label": "FULLSCREEN", "kind": "toggle"})
			rows.append({"id": "back", "label": "BACK", "kind": "back"})
		Screen.PROFILES:
			for slot in range(1, SaveSlots.COUNT + 1):
				rows.append({"id": "slot%d" % slot, "label": "", "kind": "slot", "slot": slot})
		Screen.CONTROLS:
			for action in KeyBindings.ACTIONS:
				rows.append({"id": action, "label": KeyBindings.LABELS[action], "kind": "bind"})
			rows.append({"id": "reset", "label": "RESET TO DEFAULTS", "kind": "action"})
			rows.append({"id": "back", "label": "BACK", "kind": "back"})
	return rows


func _text_width(text: String) -> float:
	return UITheme.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x


func _default_hint() -> String:
	var text := "ARROWS, WASD OR MOUSE     ENTER OR CLICK TO SELECT"
	if _screen == Screen.PROFILES:
		return "ARROWS OR MOUSE     ENTER SELECT     DELETE CLEAR     ESC BACK"
	if _screen != Screen.MAIN:
		text += "     ESC BACK"
	return text


func _show_screen(screen: int) -> void:
	_screen = screen
	_capturing_row = -1
	_title_root.visible = screen == Screen.MAIN
	_header.visible = screen != Screen.MAIN
	_header.text = {Screen.SETTINGS: "SETTINGS", Screen.CONTROLS: "CONTROLS", Screen.PROFILES: "SELECT PROFILE"}.get(screen, "")
	_header.position.y = 12.0 if screen == Screen.PROFILES else 34.0
	_header_divider.visible = screen == Screen.PROFILES
	_layers[3].visible = screen != Screen.PROFILES
	create_tween().tween_property(_dim, "color:a", 0.72 if screen == Screen.PROFILES else 0.0, 0.2)
	_clear_armed = -1
	for child in _menu_root.get_children():
		child.queue_free()
	_rows = _rows_for(screen)
	_index = 0
	var top := 114
	var pitch := 19
	if screen == Screen.SETTINGS:
		top = 88
		pitch = 18
	elif screen == Screen.CONTROLS:
		top = 50
		pitch = 12
	elif screen == Screen.PROFILES:
		top = 62
		pitch = 42
	for i in _rows.size():
		var row := _rows[i]
		var y := top + i * pitch
		var text_w := _text_width(row["label"])
		row["y"] = y
		row["text_w"] = text_w
		if screen == Screen.PROFILES:
			var profile := ProfileRow.new()
			profile.position = Vector2(60, y)
			profile.setup(int(row["slot"]), SaveSlots.read(int(row["slot"])))
			_menu_root.add_child(profile)
			row["node"] = profile
			row["left"] = true
			row["text_w"] = 0.0
			row["rect"] = Rect2(36, y - 2, 408, ProfileRow.HEIGHT + 4)
		elif screen == Screen.MAIN:
			var centered := _make_label(row["label"], _ls_normal, Rect2(0, y, 480, ROW_HEIGHT))
			_menu_root.add_child(centered)
			row["node"] = centered
			row["left"] = false
			row["rect"] = Rect2(150, y - 1, 180, ROW_HEIGHT + 1)
		else:
			var name_label := _make_label(row["label"], _ls_normal, Rect2(146, y, 140, ROW_HEIGHT), HORIZONTAL_ALIGNMENT_LEFT)
			_menu_root.add_child(name_label)
			row["node"] = name_label
			row["left"] = true
			row["rect"] = Rect2(124, y, 280, mini(pitch, ROW_HEIGHT + 1))
			match row["kind"]:
				"slider":
					var bar := PipBar.new()
					bar.position = Vector2(BAR_X, y + 6)
					_menu_root.add_child(bar)
					row["bar"] = bar
				"toggle":
					var state := _make_label("", _ls_normal, Rect2(BAR_X, y, 80, ROW_HEIGHT), HORIZONTAL_ALIGNMENT_LEFT)
					_menu_root.add_child(state)
					row["state"] = state
				"bind":
					name_label.size = Vector2(150, ROW_HEIGHT)
					var keys_label := _make_label("", _ls_value, Rect2(304, y, 90, ROW_HEIGHT), HORIZONTAL_ALIGNMENT_LEFT)
					_menu_root.add_child(keys_label)
					row["keys"] = keys_label
	_hint.text = _default_hint()
	_refresh()
	_menu_root.modulate.a = 0.0
	create_tween().tween_property(_menu_root, "modulate:a", 1.0, 0.18)


# --- State --------------------------------------------------------------------------------


func _get_value(id: String) -> Variant:
	match id:
		"music":
			return SettingsStore.music
		"sfx":
			return SettingsStore.sfx
		"shake":
			return SettingsStore.screen_shake
		"flash":
			return SettingsStore.reduce_flashing
		"fullscreen":
			return SettingsStore.fullscreen
	return null


func _refresh() -> void:
	for i in _rows.size():
		var row := _rows[i]
		var active := i == _index
		if row["kind"] == "slot":
			var profile: ProfileRow = row["node"]
			profile.set_active(active)
			profile.set_confirming(_clear_armed == int(row["slot"]) and active)
			continue
		var node: Label = row["node"]
		node.label_settings = _ls_selected if active else _ls_normal
		match row["kind"]:
			"slider":
				var bar: PipBar = row["bar"]
				bar.value = _get_value(row["id"])
				bar.active = active
				bar.queue_redraw()
			"toggle":
				var state: Label = row["state"]
				state.text = "ON" if _get_value(row["id"]) else "OFF"
				state.label_settings = _ls_selected if active else _ls_normal
			"bind":
				var keys_label: Label = row["keys"]
				keys_label.modulate.a = 1.0
				keys_label.text = "PRESS A KEY" if i == _capturing_row else KeyBindings.key_name(row["id"])
				keys_label.label_settings = _ls_value if active else _ls_normal
	_selector.tint = Color.from_hsv(fposmod(UITheme.PRISM_HUE + _index * 0.04, 1.0), 0.25, 1.0)
	_selector.queue_redraw()


func _selector_target() -> Vector2:
	var row := _rows[_index]
	var y: int = row["y"]
	if row["kind"] == "slot":
		return Vector2(46, y + 16)
	if row["left"]:
		return Vector2(132, y + 2)
	return Vector2(240 - int(float(row["text_w"]) / 2.0) - 14, y + 2)


func _place_selector(animated: bool) -> void:
	var target := _selector_target()
	var row := _rows[_index]
	var line_w: float = row["text_w"]
	var line_x := 146.0 if row["left"] else 240.0 - line_w / 2.0
	_underline.position = Vector2(roundf(line_x), float(row["y"]) + 12.0)
	if _selector_tween:
		_selector_tween.kill()
	if _underline_tween:
		_underline_tween.kill()
	if not animated:
		_selector.position = target
		_underline.line_width = line_w
		return
	var down := target.y > _selector.position.y
	_selector_tween = create_tween().set_parallel(true)
	_selector_tween.tween_property(_selector, "position:x", target.x, 0.12)
	var fall := _selector_tween.tween_property(_selector, "position:y", target.y, 0.32 if down else 0.16)
	if down:
		fall.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		fall.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_underline.line_width = 0.0
	_underline_tween = create_tween()
	_underline_tween.tween_property(_underline, "line_width", line_w, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _select(i: int) -> void:
	if i == _index:
		return
	_index = i
	_clear_armed = -1
	_refresh()
	_place_selector(true)


func _move(step: int) -> void:
	_select(posmod(_index + step, _rows.size()))


func _row_at(pos: Vector2) -> int:
	for i in _rows.size():
		if (_rows[i]["rect"] as Rect2).has_point(pos):
			return i
	return -1


func _commit(id: String) -> void:
	SettingsStore.apply()
	if id == "fullscreen":
		SettingsStore.apply_fullscreen()
	SettingsStore.save_settings()
	_refresh()


func _set_slider(id: String, value: int) -> void:
	match id:
		"music":
			SettingsStore.music = clampi(value, 0, PIPS)
		"sfx":
			SettingsStore.sfx = clampi(value, 0, PIPS)
	_commit(id)


func _adjust(step: int) -> void:
	var row := _rows[_index]
	var id: String = row["id"]
	match row["kind"]:
		"slider":
			_set_slider(id, int(_get_value(id)) + step)
		"toggle":
			match id:
				"shake":
					SettingsStore.screen_shake = not SettingsStore.screen_shake
				"flash":
					SettingsStore.reduce_flashing = not SettingsStore.reduce_flashing
				"fullscreen":
					SettingsStore.fullscreen = not SettingsStore.fullscreen
			_commit(id)


func _wheel(step: int, pos: Vector2) -> void:
	var hit := _row_at(pos)
	if hit != -1 and _rows[hit]["kind"] == "slider":
		_select(hit)
		_adjust(step)


func _click(pos: Vector2) -> void:
	var hit := _row_at(pos)
	if hit == -1:
		return
	_select(hit)
	var row := _rows[hit]
	if row["kind"] == "slot" and (row["node"] as ProfileRow).clear_rect().has_point(pos):
		_request_clear()
		return
	if row["kind"] == "slider":
		var local_x := pos.x - BAR_X
		if local_x >= -2.0 and local_x <= 72.0:
			var pip := clampi(floori((local_x + 1.0) / 7.0), 0, PIPS - 1) + 1
			var current: int = _get_value(row["id"])
			_set_slider(row["id"], pip - 1 if pip == current else pip)
		return
	_activate()


func _activate() -> void:
	var row := _rows[_index]
	match row["kind"]:
		"toggle":
			_adjust(1)
		"bind":
			_begin_capture(_index)
		"slot":
			_open_slot(row)
		"back":
			_back()
		"action":
			match row["id"]:
				"start":
					_return_index = _index
					_show_screen(Screen.PROFILES)
					_place_selector(false)
				"settings":
					_return_index = _index
					_show_screen(Screen.SETTINGS)
					_place_selector(false)
				"controls":
					_return_index = _index
					_show_screen(Screen.CONTROLS)
					_place_selector(false)
				"reset":
					KeyBindings.reset_defaults()
					_refresh()
					_flash_hint("KEYS RESET TO DEFAULTS")
				"quit":
					get_tree().quit()


func _back() -> void:
	if _screen == Screen.MAIN:
		return
	_show_screen(Screen.MAIN)
	_index = _return_index
	_refresh()
	_place_selector(false)


# --- Rebinding ----------------------------------------------------------------------------


func _begin_capture(i: int) -> void:
	_capturing_row = i
	_hint.text = "PRESS THE NEW KEY     ESC CANCEL"
	_refresh()


func _cancel_capture() -> void:
	_capturing_row = -1
	_hint.text = _default_hint()
	_refresh()


func _finish_capture(key: Key) -> void:
	if key == KEY_ESCAPE:
		_cancel_capture()
		return
	if key == KEY_NONE or KeyBindings.is_reserved(key):
		_flash_hint("THAT KEY IS RESERVED")
		return
	var action: String = _rows[_capturing_row]["id"]
	var swapped := KeyBindings.rebind(action, key)
	_capturing_row = -1
	_hint.text = _default_hint()
	_refresh()
	if swapped != "":
		_flash_hint("SWAPPED WITH " + swapped)


func _flash_hint(text: String) -> void:
	var previous := _hint.text
	_hint.text = text
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(_hint) and _hint.text == text:
			_hint.text = previous if _capturing_row == -1 else "PRESS THE NEW KEY     ESC CANCEL"
	)


# --- Profiles -----------------------------------------------------------------------------


func _is_clear_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		return key == KEY_DELETE or key == KEY_BACKSPACE
	return false


func _open_slot(row: Dictionary) -> void:
	var slot: int = row["slot"]
	var profile: ProfileRow = row["node"]
	if not SaveSlots.exists(slot):
		SaveSlots.create_new(slot)
		profile.setup(slot, SaveSlots.read(slot))
		profile.set_active(true)
	SaveSlots.current_slot = slot
	start_requested.emit(slot)
	if open_game_on_start:
		get_tree().change_scene_to_file(PREVIEW_SCENE)
	else:
		_flash_hint("PROFILE %d SELECTED" % slot)


## First press arms the erase, a second press on the same slot within 3 seconds performs it.
func _request_clear() -> void:
	var row := _rows[_index]
	if row["kind"] != "slot":
		return
	var slot: int = row["slot"]
	if not SaveSlots.exists(slot):
		return
	var profile: ProfileRow = row["node"]
	if _clear_armed == slot:
		SaveSlots.erase(slot)
		_clear_armed = -1
		profile.setup(slot, {})
		profile.set_active(true)
		_flash_hint("PROFILE %d CLEARED" % slot)
		return
	_clear_armed = slot
	profile.set_confirming(true)
	_flash_hint("PRESS DELETE OR CLICK AGAIN TO ERASE PROFILE %d" % slot)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if _clear_armed == slot:
			_clear_armed = -1
			if is_instance_valid(profile):
				profile.set_confirming(false)
	)
