class_name StoryData
extends RefCounted
## What the world tells you: region names and colours, the crystal guardians' colours, the key names and the scroll texts
## (data/scrolls.json, written by dev/make_wings.py). Scroll texts name keys as {jump}, {interact} ...; they are filled in with
## the player's own bindings when read.

const SCROLLS_PATH := "res://data/scrolls.json"
const REGIONS := ["THE OVERGROWTH", "THE RUSTWORKS", "THE DROWNED WORKS", "THE BONE STACKS", "THE ASH DEEP"]
const COLOURS := [Color("8f9d5e"), Color("d0743a"), Color("56a3a6"), Color("d8c9a0"), Color("a98bb0")]
## Guardian crystal per region: body, light facet, dark facet, glow.
const CRYSTAL := [
	[Color("4f8f6a"), Color("9ae0a0"), Color("2a5a44"), Color("c8ff9a")],
	[Color("c0702e"), Color("ffc080"), Color("7a3a1c"), Color("ffd8a0")],
	[Color("3a9aa6"), Color("9af0ee"), Color("1e5a66"), Color("c8fff6")],
	[Color("cfc29a"), Color("f6efd4"), Color("8a7e62"), Color("ffffff")],
	[Color("8a3a6a"), Color("e07aa0"), Color("4a1a3a"), Color("ff9a68")],
]
const GUARDIAN_HP := [3, 4, 5, 6, 7]

static var _scrolls: Dictionary = {}


static func scroll(id: String) -> Dictionary:
	if _scrolls.is_empty():
		var file := FileAccess.open(SCROLLS_PATH, FileAccess.READ)
		if file != null:
			_scrolls = JSON.parse_string(file.get_as_text())
	return _scrolls.get(id, {"title": "", "pages": ["The writing has faded."]})


## Fills {action} tokens in with the player's key for that action.
static func format(text: String) -> String:
	var out := text
	for action in KeyBindings.ACTIONS:
		out = out.replace("{%s}" % action, KeyBindings.key_name(action) if KeyBindings.keys.has(action) else action.to_upper())
	return out


const KEY_SHORT := ["OVERGROWTH KEY", "RUSTWORKS KEY", "DROWNED KEY", "BONE KEY", "ASH KEY"]


## The short form for narrow places (the inventory's description column).
static func key_short_name(region: int) -> String:
	return KEY_SHORT[clampi(region, 0, KEY_SHORT.size() - 1)]


static func key_name(region: int) -> String:
	return "KEY OF " + REGIONS[clampi(region, 0, REGIONS.size() - 1)]
