class_name PauseMenu
extends Control
## In-game pause menu, laid out like Hollow Knight's: Continue / Options / Quit To Menu, ornate lines
## above and below, and the same selector as the title menu (raindrop on the left, line drawn
## beneath the highlighted item). Esc opens it from the game;
## Esc, Continue or right click closes it. Options holds the same audio and comfort settings
## as the title screen. Opening pauses the scene tree; closing (or leaving the tree) resumes it.

signal resumed
signal quit_to_menu

enum Page { MAIN, OPTIONS }

const PIPS := 10
const BAR_X := 292.0

var is_open := false

var _page: int = Page.MAIN
var _rows: Array[Dictionary] = []
var _index := 0
var _ls_normal: LabelSettings
var _ls_selected: LabelSettings
var _heading: Label
var _top_y := 84.0
var _bottom_y := 194.0
var _drop_pos := Vector2.ZERO
var _drop_tween: Tween
var _line_w := 0.0
var _line_tween: Tween


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep running while the tree is paused
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	_ls_normal = UITheme.label_settings(16, UITheme.CREAM_DIM)
	_ls_selected = UITheme.label_settings(16, UITheme.CREAM)
	_heading = Label.new()
	_heading.label_settings = UITheme.label_settings(20, UITheme.CREAM, false, 3, 2)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.position = Vector2(0, 48)
	_heading.size = Vector2(480, 24)
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading)


func _process(_delta: float) -> void:
	if is_open:
		queue_redraw()  # the drop and underline are tweened


func _exit_tree() -> void:
	if is_open and get_tree():
		get_tree().paused = false


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	_show_page(Page.MAIN)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	resumed.emit()


# --- Pages --------------------------------------------------------------------------------


func _show_page(page: int) -> void:
	_page = page
	_index = 0
	for row in _rows:
		(row["label"] as Label).queue_free()
		if row.has("state"):
			(row["state"] as Label).queue_free()
	_rows.clear()
	var defs: Array[Dictionary] = []
	var top := 112.0
	var pitch := 26.0
	if page == Page.MAIN:
		defs = [
			{"id": "continue", "text": "CONTINUE", "kind": "action"},
			{"id": "options", "text": "OPTIONS", "kind": "action"},
			{"id": "quit", "text": "QUIT TO MENU", "kind": "action"},
		]
		_heading.text = ""
		_top_y = 84.0
	else:
		defs = [
			{"id": "music", "text": "MUSIC", "kind": "slider"},
			{"id": "sfx", "text": "EFFECTS", "kind": "slider"},
			{"id": "shake", "text": "SCREEN SHAKE", "kind": "toggle"},
			{"id": "flash", "text": "REDUCE FLASHING", "kind": "toggle"},
			{"id": "fullscreen", "text": "FULLSCREEN", "kind": "toggle"},
			{"id": "back", "text": "BACK", "kind": "action"},
		]
		_heading.text = "OPTIONS"
		top = 98.0
		pitch = 18.0
		_top_y = 80.0
	for i in defs.size():
		var row := defs[i]
		var y := top + i * pitch
		row["y"] = y
		var label := Label.new()
		label.text = row["text"]
		label.label_settings = _ls_normal
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size = Vector2(150 if page == Page.OPTIONS else 480, 18)
		label.position = Vector2(146 if page == Page.OPTIONS else 0, y)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if page == Page.OPTIONS else HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		row["label"] = label
		row["width"] = UITheme.font().get_string_size(row["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		if page == Page.MAIN:
			row["rect"] = Rect2(150, y - 3, 180, pitch)
		else:
			row["rect"] = Rect2(124, y, 280, pitch)
		if row["kind"] == "toggle":
			var state := Label.new()
			state.label_settings = _ls_normal
			state.mouse_filter = Control.MOUSE_FILTER_IGNORE
			state.position = Vector2(BAR_X, y)
			state.size = Vector2(80, 18)
			add_child(state)
			row["state"] = state
		_rows.append(row)
	_bottom_y = top + defs.size() * pitch + (6.0 if page == Page.OPTIONS else 4.0)
	_refresh()
	_place_selector(false)


func _value(id: String) -> Variant:
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
		(row["label"] as Label).label_settings = _ls_selected if active else _ls_normal
		if row["kind"] == "toggle":
			var state: Label = row["state"]
			state.text = "ON" if _value(row["id"]) else "OFF"
			state.label_settings = _ls_selected if active else _ls_normal
	queue_redraw()


# --- Input --------------------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var handler: Callable
	if event is InputEventMouseMotion:
		var hit := _row_at(make_input_local(event).position)
		if hit != -1:
			_select(hit)
		return
	if event is InputEventMouseButton and event.pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				var pos: Vector2 = make_input_local(event).position
				handler = _click.bind(pos)
			MOUSE_BUTTON_RIGHT:
				handler = _back
			MOUSE_BUTTON_WHEEL_UP:
				handler = _adjust.bind(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				handler = _adjust.bind(-1)
	elif event.is_action_pressed("ui_down", true):
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
	if not handler.is_valid():
		return
	# Mark handled BEFORE acting: quitting to the menu changes scene, after which get_viewport() is null.
	get_viewport().set_input_as_handled()
	handler.call()


func _row_at(pos: Vector2) -> int:
	for i in _rows.size():
		if (_rows[i]["rect"] as Rect2).has_point(pos):
			return i
	return -1


func _move(step: int) -> void:
	_select(posmod(_index + step, _rows.size()))


func _select(i: int) -> void:
	if i == _index:
		return
	_index = i
	_refresh()
	_place_selector(true)


func _selector_target(row: Dictionary) -> Vector2:
	var y: float = row["y"]
	if _page == Page.MAIN:
		return Vector2(240.0 - int(float(row["width"]) / 2.0) - 14.0, y + 2.0)
	return Vector2(132.0, y + 2.0)


func _underline_start(row: Dictionary) -> Vector2:
	var y: float = row["y"]
	if _page == Page.MAIN:
		return Vector2(roundf(240.0 - float(row["width"]) / 2.0), y + 12.0)
	return Vector2(146.0, y + 12.0)


## Same behaviour as the title menu: the drop falls to the new item with a bounce (rises quickly
## going up) and the underline draws itself beneath it.
func _place_selector(animated: bool) -> void:
	var row := _rows[_index]
	var target := _selector_target(row)
	var line_w: float = row["width"]
	if _drop_tween:
		_drop_tween.kill()
	if _line_tween:
		_line_tween.kill()
	if not animated:
		_drop_pos = target
		_line_w = line_w
		queue_redraw()
		return
	var down := target.y > _drop_pos.y
	_drop_tween = create_tween().set_parallel(true)
	_drop_tween.tween_property(self, "_drop_pos:x", target.x, 0.12)
	var fall := _drop_tween.tween_property(self, "_drop_pos:y", target.y, 0.32 if down else 0.16)
	if down:
		fall.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		fall.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_line_w = 0.0
	_line_tween = create_tween()
	_line_tween.tween_property(self, "_line_w", line_w, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _adjust(step: int) -> void:
	var row := _rows[_index]
	var id: String = row["id"]
	match row["kind"]:
		"slider":
			_set_slider(id, int(_value(id)) + step)
		"toggle":
			match id:
				"shake":
					SettingsStore.screen_shake = not SettingsStore.screen_shake
				"flash":
					SettingsStore.reduce_flashing = not SettingsStore.reduce_flashing
				"fullscreen":
					SettingsStore.fullscreen = not SettingsStore.fullscreen
			_commit(id)


func _set_slider(id: String, value: int) -> void:
	if id == "music":
		SettingsStore.music = clampi(value, 0, PIPS)
	else:
		SettingsStore.sfx = clampi(value, 0, PIPS)
	_commit(id)


func _commit(id: String) -> void:
	SettingsStore.apply()
	if id == "fullscreen":
		SettingsStore.apply_fullscreen()
	SettingsStore.save_settings()
	_refresh()


func _click(pos: Vector2) -> void:
	var hit := _row_at(pos)
	if hit == -1:
		return
	_select(hit)
	var row := _rows[hit]
	if row["kind"] == "slider":
		var local_x := pos.x - BAR_X
		if local_x >= -2.0 and local_x <= 72.0:
			var pip := clampi(floori((local_x + 1.0) / 7.0), 0, PIPS - 1) + 1
			var current: int = _value(row["id"])
			_set_slider(row["id"], pip - 1 if pip == current else pip)
		else:
			_refresh()
		return
	_refresh()
	_activate()


func _activate() -> void:
	var row := _rows[_index]
	match row["id"]:
		"continue":
			close()
		"options":
			_show_page(Page.OPTIONS)
		"quit":
			is_open = false
			get_tree().paused = false
			quit_to_menu.emit()
		"back":
			_show_page(Page.MAIN)
			_index = 1
			_refresh()
			_place_selector(false)
		_:
			if row["kind"] == "toggle":
				_adjust(1)


func _back() -> void:
	if _page == Page.OPTIONS:
		_show_page(Page.MAIN)
		_index = 1
		_refresh()
		_place_selector(false)
	else:
		close()


# --- Drawing ------------------------------------------------------------------------------


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color(0.02, 0.02, 0.04, 0.62))
	if _rows.is_empty():
		return
	Glyphs.draw_flourish(self, 240, _top_y, 56 if _page == Page.MAIN else 70, _page == Page.MAIN)
	Glyphs.draw_flourish(self, 240, _bottom_y, 36 if _page == Page.MAIN else 54, false)
	for i in _rows.size():
		var row := _rows[i]
		if row["kind"] == "slider":
			Glyphs.draw_pips(self, Vector2(BAR_X, float(row["y"]) + 6.0), int(_value(row["id"])), i == _index)
	var tint := Color.from_hsv(fposmod(UITheme.PRISM_HUE + _index * 0.04, 1.0), 0.25, 1.0)
	Glyphs.draw_drop(self, _drop_pos, tint)
	Glyphs.draw_underline(self, _underline_start(_rows[_index]), _line_w)
