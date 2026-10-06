class_name InventoryScreen
extends Control
## Inventory overlay, laid out like Hollow Knight's: character and abilities on the left,
## item grid in the middle, description on the right. Open and close from the owner with open() / close().
## The item grid holds the keys found so far (one per region gate); other items will be added later.

signal opened
signal closed

const GRID_ORIGIN := Vector2(200, 84)  ## centred on the column rules (y 48 to 224)
const CELL := 26
const COLUMNS := 4
const ROWS := 4
const ABILITY_Y := 199.0
const ABILITY_X := [48.0, 86.0, 124.0, 162.0]  ## spread across the column rule (x 36 to 176)

const ABILITY_TEXT := {
	"pound": ["GROUND POUND", "In the air, press {pound} to drop like a stone. It strikes a guardian's heart twice as hard."],
	"double_jump": ["DOUBLE JUMP", "One more push from the air. Press {jump} again while falling."],
	"dash_iframes": ["INVINCIBLE DASH", "Slip through danger. Press {dash}: nothing can touch you while you dash."],
	"fast_heal": ["FAST HEAL", "Heal in a heartbeat. Hold {eat} with a full circle and what took a long, dangerous moment is over at once."],
}

var state: VitalsState
var is_open := false

var _slots: Array[Dictionary] = []
var _sel := 0
var _title_label: Label
var _desc_title: Label
var _desc_body: Label
var _desc_extra: Label
var _completion: Label
var _vitality: Label
var _shards: Label
var _energy_label: Label
var _energy_value: Label
var _abilities_label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	var big := UITheme.label_settings(20, UITheme.CREAM, false, 3, 2)
	var mid := UITheme.label_settings(16, UITheme.CREAM)
	var small := UITheme.label_settings(12, UITheme.CREAM_DIM, false, 1)
	var small_lit := UITheme.label_settings(12, UITheme.CREAM, false, 1)
	_title_label = _label("INVENTORY", big, Rect2(0, 5, 480, 24), HORIZONTAL_ALIGNMENT_CENTER)
	_vitality = _label("", mid, Rect2(92, 56, 90, 18), HORIZONTAL_ALIGNMENT_LEFT)
	_shards = _label("", small, Rect2(92, 74, 90, 14), HORIZONTAL_ALIGNMENT_LEFT)
	# energy row: circle, label level with its centre, readiness on the right edge of the column
	_energy_label = _label("ENERGY", small, Rect2(60, 134, 70, 14), HORIZONTAL_ALIGNMENT_LEFT)
	_energy_value = _label("", small, Rect2(110, 134, 66, 14), HORIZONTAL_ALIGNMENT_RIGHT)
	_abilities_label = _label("ABILITIES", small, Rect2(36, 163, 100, 14), HORIZONTAL_ALIGNMENT_LEFT)
	_desc_title = _label("", mid, Rect2(334, 50, 130, 18), HORIZONTAL_ALIGNMENT_LEFT)
	_desc_body = _label("", small_lit, Rect2(334, 80, 128, 110), HORIZONTAL_ALIGNMENT_LEFT)
	_desc_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_extra = _label("", small, Rect2(334, 168, 128, 14), HORIZONTAL_ALIGNMENT_LEFT)
	_completion = _label("", small, Rect2(334, 214, 128, 14), HORIZONTAL_ALIGNMENT_LEFT)
	for node in [_title_label, _vitality, _shards, _energy_label, _energy_value, _abilities_label, _desc_title, _desc_body, _desc_extra, _completion]:
		add_child(node)


func _label(text: String, settings: LabelSettings, rect: Rect2, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func bind(vitals: VitalsState) -> void:
	state = vitals
	state.changed.connect(func() -> void:
		if is_open:
			_refresh()
	)


func open() -> void:
	if state == null:
		return
	is_open = true
	visible = true
	opened.emit()
	_sel = clampi(_sel, 0, maxi(_slots.size() - 1, 0))
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	closed.emit()


# --- Input --------------------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		var pos: Vector2 = make_input_local(event).position
		for i in _slots.size():
			if (_slots[i]["rect"] as Rect2).has_point(pos):
				_select(i)
				break
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right", true):
		_navigate(Vector2.RIGHT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left", true):
		_navigate(Vector2.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down", true):
		_navigate(Vector2.DOWN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up", true):
		_navigate(Vector2.UP)
		get_viewport().set_input_as_handled()


func _navigate(dir: Vector2) -> void:
	if _slots.is_empty():
		return
	var here := (_slots[_sel]["rect"] as Rect2).get_center()
	var best := -1
	var best_score := INF
	for i in _slots.size():
		if i == _sel:
			continue
		var delta := (_slots[i]["rect"] as Rect2).get_center() - here
		var along := delta.dot(dir)
		if along <= 0.5:
			continue
		var score := along + absf(delta.cross(dir)) * 2.5
		if score < best_score:
			best_score = score
			best = i
	if best != -1:
		_select(best)


func _select(i: int) -> void:
	if i == _sel:
		return
	_sel = i
	_refresh()


# --- Content ------------------------------------------------------------------------------


func _build_slots() -> void:
	_slots.clear()
	for i in VitalsState.ABILITY_ORDER.size():
		var id := VitalsState.ABILITY_ORDER[i]
		var centre := Vector2(ABILITY_X[i], ABILITY_Y)
		_slots.append({"kind": "ability", "id": id, "rect": Rect2(centre - Vector2(13, 13), Vector2(26, 26))})
	# the bamboo stick: always carried, first cell of the second row
	_slots.append({"kind": "stick", "id": "stick", "rect": Rect2(GRID_ORIGIN + Vector2(0, CELL), Vector2(CELL, CELL))})
	for i in 4:      # keys found: one cell each, in region order
		if bool(state.items.get("key_%d" % i, false)):
			_slots.append({"kind": "key", "id": "key_%d" % i, "region": i, "rect": Rect2(GRID_ORIGIN + Vector2(i * CELL, 0), Vector2(CELL, CELL))})


func _refresh() -> void:
	_build_slots()
	_sel = clampi(_sel, 0, _slots.size() - 1)
	_vitality.text = "%d / %d" % [state.health, state.max_health]
	if state.shards >= VitalsState.MAX_SHARDS:
		_shards.text = "SHARDS  MAX"
	else:
		_shards.text = "SHARDS  %d / %d" % [state.shards % VitalsState.SHARDS_PER_CRYSTAL, VitalsState.SHARDS_PER_CRYSTAL]
	if state.energy >= 1.0:
		_energy_value.text = "READY"
		_energy_value.label_settings = UITheme.label_settings(12, UITheme.CREAM, false, 1)
	else:
		_energy_value.text = "%d%%" % int(state.energy * 100.0)
		_energy_value.label_settings = UITheme.label_settings(12, UITheme.CREAM_DIM, false, 1)
	_completion.text = "COMPLETION  %d%%" % state.completion
	var slot: Dictionary = _slots[_sel]
	var id: String = slot["id"]
	if slot["kind"] == "stick":
		_desc_title.text = "BAMBOO STICK"
		_desc_body.text = "A little stick of bamboo. It does no harm, but a guardian it strikes reels for a moment and bares its heart. Swing it with {attack}."
	elif slot["kind"] == "key":
		var region := int(slot["region"])
		var opened := bool(state.doors.get("gate_%d" % region, false))
		_desc_title.text = StoryData.key_short_name(region)
		_desc_body.text = "Opens the gate at the foot of %s. %s" % [StoryData.REGIONS[region], "The gate stands open." if opened else "Find the gate and press {interact} above it."]
	else:
		var known: bool = state.unlocked[id]
		_desc_title.text = ABILITY_TEXT[id][0] if known else "???"
		_desc_body.text = ABILITY_TEXT[id][1] if known else "Not yet learned. Enter the next region to find it."
	_desc_body.text = StoryData.format(_desc_body.text)      # {action} becomes the key the player has bound to it
	_desc_extra.text = "GUARDIANS  %d / 5" % state.guardians.size()
	queue_redraw()


# --- Drawing ------------------------------------------------------------------------------


func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color(0.03, 0.02, 0.05, 0.94))
	Glyphs.draw_corner(self, Vector2(8, 8), 1, 1)
	Glyphs.draw_corner(self, Vector2(471, 8), -1, 1)
	Glyphs.draw_corner(self, Vector2(8, 261), 1, -1)
	Glyphs.draw_corner(self, Vector2(471, 261), -1, -1)
	Glyphs.draw_divider(self, 240, 30, 96, true)
	Glyphs.draw_divider(self, 240, 232, 52, false)
	for x in [184, 322]:
		draw_rect(Rect2(x, 48, 1, 176), UITheme.RUST)
		draw_rect(Rect2(x + 1, 48, 1, 176), UITheme.INK)
	_draw_shard_ring(Vector2(58, 72))
	var crystals_origin := Vector2(36, 104)
	for i in state.max_health:
		Glyphs.draw_crystal(self, crystals_origin + Vector2(i * Glyphs.CRYSTAL_PITCH, 0), Glyphs.Crystal.FULL if i < state.health else Glyphs.Crystal.EMPTY)
	# thin rules between the left column's sections
	for y in [126, 154]:
		draw_rect(Rect2(36, y, 140, 1), Color(UITheme.RUST_DARK, 0.9))
	# the description column uses the same rules: under the title, above the completion line
	for y in [70, 208]:
		draw_rect(Rect2(334, y, 130, 1), Color(UITheme.RUST_DARK, 0.9))
	Glyphs.draw_energy(self, Vector2(45, 141), 9.0, state.energy, 0.0)
	# Item grid (empty for now): every cell shows a dim dot.
	var held := {}
	for slot in _slots:
		if slot["kind"] == "key" or slot["kind"] == "stick":
			held[(slot["rect"] as Rect2).position] = true
	for i in COLUMNS * ROWS:
		var cell := Vector2(i % COLUMNS, i / COLUMNS)
		var rect := Rect2(GRID_ORIGIN + cell * CELL, Vector2(CELL, CELL))
		if not held.has(rect.position):
			draw_rect(Rect2(rect.get_center() - Vector2(1, 1), Vector2(2, 2)), UITheme.RUST_DARK)
	for i in _slots.size():
		var rect: Rect2 = _slots[i]["rect"]
		if _slots[i]["kind"] == "stick":
			_draw_stick_icon(rect.get_center())
			if i == _sel:
				Glyphs.draw_ring(self, rect.get_center(), 12.0, UITheme.CREAM)
		elif _slots[i]["kind"] == "key":
			var region := int(_slots[i]["region"])
			Glyphs.draw_key(self, rect.get_center() + Vector2(0, 1), StoryData.COLOURS[region], 1, 0.0)
			if i == _sel:
				Glyphs.draw_ring(self, rect.get_center(), 12.0, UITheme.CREAM)
		else:
			Glyphs.draw_ability(self, _slots[i]["id"], rect.get_center(), state.unlocked[_slots[i]["id"]], i == _sel)
	# the five guardians: a crystal for each, lit in its region's colour once it has fallen
	for g in 5:
		var c := Vector2(341 + g * 14, 192)
		Glyphs.draw_diamond(self, c, 5, UITheme.INK)
		if bool(state.guardians.get("g_%d" % g, false)):
			Glyphs.draw_diamond(self, c, 4, StoryData.COLOURS[g])
			Glyphs.draw_diamond(self, c, 1, Color(1, 1, 1, 0.85))
		else:
			Glyphs.draw_diamond(self, c, 4, Color("1c1218"))


## Circle split into two halves: one fills for each crystal shard collected toward the next crystal.
## Left half light blue, right half violet, like the facets of a crystal. At the 11-crystal cap both stay filled.
func _draw_shard_ring(centre: Vector2) -> void:
	var halves := state.shards % VitalsState.SHARDS_PER_CRYSTAL
	if state.shards >= VitalsState.MAX_SHARDS:
		halves = 2
	var radius := 17
	var empty := Color("1c1218")
	var left := Color.from_hsv(0.50, 0.45, 1.0) if halves >= 1 else empty
	var right := Color.from_hsv(0.64, 0.5, 0.82) if halves >= 2 else empty
	# backing disc and outer ring
	for dy in range(-radius - 3, radius + 4):
		var half := int(sqrt(maxf(0.0, (radius + 3) * (radius + 3) - dy * dy)))
		draw_rect(Rect2(centre.x - half, centre.y + dy, half * 2 + 1, 1), UITheme.INK)
	Glyphs.draw_ring(self, centre, radius + 2.5, UITheme.CREAM_DIM if halves > 0 else UITheme.RUST)
	# the two sections
	for dy in range(-radius, radius + 1):
		var half := int(sqrt(maxf(0.0, radius * radius - dy * dy)))
		draw_rect(Rect2(centre.x - half, centre.y + dy, half, 1), left)
		draw_rect(Rect2(centre.x + 1, centre.y + dy, half, 1), right)
	# divider between the sections
	draw_rect(Rect2(centre.x, centre.y - radius - 1, 1, radius * 2 + 3), UITheme.INK)
	# sparkle on filled sections
	if halves >= 1:
		draw_rect(Rect2(centre.x - 9, centre.y - 8, 2, 4), Color(1, 1, 1, 0.7))
	if halves >= 2:
		draw_rect(Rect2(centre.x + 7, centre.y - 6, 2, 3), Color(1, 1, 1, 0.5))


## The bamboo stick in its inventory cell: a short green cane leaning to the right, with dark nodes and a leaf.
func _draw_stick_icon(centre: Vector2) -> void:
	var from := centre.floor() + Vector2(-6, 7)
	for t in 15:
		var p := from + Vector2(t * 0.8, -t).floor()
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(4, 3)), UITheme.INK)
	for t in 15:
		var p := from + Vector2(t * 0.8, -t).floor()
		var c := BambooStick.NODE if t % 5 == 4 else BambooStick.CANE
		draw_rect(Rect2(p, Vector2(2, 1)), c)
		if t % 5 == 1:
			draw_rect(Rect2(p, Vector2(1, 1)), BambooStick.CANE_HI)
	var tip := from + Vector2(11, -14).floor()
	draw_rect(Rect2(tip + Vector2(1, 0), Vector2(3, 1)), BambooStick.CANE_HI)
	draw_rect(Rect2(tip + Vector2(3, 1), Vector2(2, 1)), BambooStick.CANE)
