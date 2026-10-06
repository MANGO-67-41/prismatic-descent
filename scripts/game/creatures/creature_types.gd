class_name CreatureTypes
extends RefCounted
## The roster: four creatures for each region, the weakest first, worse region by region. Most are lizards, Rain World's way,
## each kind with its own trick (spec keys): "size" (smaller), "skittish" (bites and backs off), "climb_max" (climbs any wall),
## "camo" (fades into the room while it waits), "tongue" (reach, px: a sticky tongue that yanks the hero in), "caller" (wakes
## the whole room), "drop" (drops on the hero from above), "blind" (no eyes: hunts by sound, "ears" times as well as others),
## "jump" (leaps up to a ledge the hero is on), "double" (lunges twice). `arch` is the behaviour (a Creature
## subclass); the rest are its numbers. Their sprite sheets are assets/creatures/<kind>.png (dev/creature_art/build_all.py);
## they are placed in the rooms by dev/make_creatures.py.
## stomp: "always" (a stomp wounds it), "stunned" (only while stunned by the stick), "never" (landing on it hurts).

const ORDER := [
	["sprout_lizard", "moss_lizard", "bloom_lizard", "bark_lizard"],
	["spark_lizard", "carrion_kite", "furnace_hound", "slag_lizard"],
	["drip_lizard", "lure_angler", "mire_lizard", "tide_leviathan"],
	["pale_lizard", "crypt_lizard", "bone_vulture", "marrow_worm"],
	["ash_wyrm", "cinder_lizard", "ember_vulture", "soot_wraith"],
]

static var _specs: Dictionary = {}


static func spec(kind: String) -> Dictionary:
	if _specs.is_empty():
		_specs = _build()
	return _specs.get(kind, _specs["moss_lizard"])


static func all_kinds() -> Array:
	var out: Array = []
	for row in ORDER:
		out.append_array(row)
	return out


static func make(kind: String) -> Creature:
	match str(spec(kind)["arch"]):
		"flit":
			return FlitterCreature.new()
		"dive":
			return DiverCreature.new()
		"lizard":
			return LizardCreature.new()
		"swim":
			return SwimmerCreature.new()
		"burrow":
			return BurrowerCreature.new()
		"reach":
			return ReacherCreature.new()
		"wyrm":
			return WyrmCreature.new()
		"hound":
			return HoundCreature.new()
		"angler":
			return AnglerCreature.new()
	return LizardCreature.new()


static func _c(s: String) -> Color:
	return Color(s)


static func _build() -> Dictionary:
	var d := {}
	# --- THE OVERGROWTH
	d["sprout_lizard"] = {"name": "SPROUT LIZARD", "region": 0, "arch": "lizard", "hp": 2, "stomp": "always", "speed": 26.0, "run": 84.0, "lunge": 140.0,
			"jump": false, "double": false, "size": 0.72, "skittish": true, "box": Vector2(12, 8), "body": _c("26331c"), "hi": _c("4f7a2e"), "accent": _c("f08aa8")}
	d["moss_lizard"] = {"name": "MOSS LIZARD", "region": 0, "arch": "lizard", "hp": 3, "stomp": "stunned", "speed": 20.0, "run": 70.0, "lunge": 160.0,
			"jump": false, "double": false, "box": Vector2(16, 10), "body": _c("23301f"), "hi": _c("3e5426"), "accent": _c("9aa860")}
	d["bloom_lizard"] = {"name": "BLOOM LIZARD", "region": 0, "arch": "lizard", "hp": 3, "stomp": "stunned", "speed": 22.0, "run": 78.0, "lunge": 165.0,
			"jump": false, "double": false, "climb_max": 999.0, "climb": 75.0, "box": Vector2(16, 10), "body": _c("2a1820"), "hi": _c("7a2048"), "accent": _c("ffb0d0")}
	d["bark_lizard"] = {"name": "BARK LIZARD", "region": 0, "arch": "lizard", "hp": 4, "stomp": "stunned", "speed": 16.0, "run": 66.0, "lunge": 150.0,
			"jump": false, "double": false, "camo": true, "tongue": 110.0, "box": Vector2(16, 10), "body": _c("2e2418"), "hi": _c("4a3a28"), "accent": _c("c8b48a"),
			"tongue_col": _c("c86a7a")}
	# --- THE RUSTWORKS
	d["spark_lizard"] = {"name": "SPARK LIZARD", "region": 1, "arch": "lizard", "hp": 3, "stomp": "stunned", "speed": 30.0, "run": 100.0, "lunge": 180.0,
			"jump": false, "double": false, "caller": true, "box": Vector2(16, 10), "body": _c("2a2214"), "hi": _c("8a6418"), "accent": _c("fff0a0")}
	# --- THE OVERGROWTH
	d["carrion_kite"] = {"name": "CARRION KITE", "region": 1, "arch": "flit", "fly": true, "hp": 2, "stomp": "stunned", "speed": 60.0, "reach": 180.0,
			"accent": _c("e09a4a"), "hi": _c("d8c8b0")}
	d["furnace_hound"] = {"name": "FURNACE HOUND", "region": 1, "arch": "hound", "hp": 3, "stomp": "stunned", "speed": 28.0, "run": 150.0, "leap": 220.0,
			"eye": 30.0, "box": Vector2(22, 12), "accent": _c("ff8a30"), "hi": _c("6a5a50")}
	d["slag_lizard"] = {"name": "SLAG LIZARD", "region": 1, "arch": "lizard", "hp": 3, "stomp": "stunned", "speed": 26.0, "run": 96.0, "lunge": 190.0,
			"jump": false, "double": false, "box": Vector2(16, 10), "body": _c("2a1a16"), "hi": _c("4a3028"), "accent": _c("ffb060")}
	# --- THE DROWNED WORKS
	d["drip_lizard"] = {"name": "DRIP LIZARD", "region": 2, "arch": "lizard", "hp": 3, "stomp": "stunned", "speed": 26.0, "run": 96.0, "lunge": 190.0,
			"jump": false, "double": false, "climb_max": 999.0, "climb": 85.0, "drop": true, "box": Vector2(16, 10), "body": _c("102226"), "hi": _c("1a6a70"),
			"accent": _c("a0fff0")}
	d["lure_angler"] = {"name": "LURE ANGLER", "region": 2, "arch": "angler", "fly": true, "hp": 3, "stomp": "stunned", "lunge": 210.0,
			"accent": _c("8affee"), "hi": _c("4a8aa0")}
	d["mire_lizard"] = {"name": "MIRE LIZARD", "region": 2, "arch": "lizard", "hp": 4, "stomp": "stunned", "speed": 30.0, "run": 112.0, "lunge": 210.0,
			"jump": true, "double": false, "box": Vector2(16, 10), "body": _c("141e2a"), "hi": _c("2a3a4e"), "accent": _c("8ad0ff")}
	d["tide_leviathan"] = {"name": "TIDE LEVIATHAN", "region": 2, "arch": "swim", "fly": true, "hp": 99, "stomp": "never", "speed": 34.0, "dart": 190.0,
			"accent": _c("7af0e8"), "hi": _c("2a4456")}
	# --- THE BONE STACKS
	d["pale_lizard"] = {"name": "PALE LIZARD", "region": 3, "arch": "lizard", "hp": 4, "stomp": "stunned", "speed": 26.0, "run": 104.0, "lunge": 205.0,
			"jump": true, "double": false, "camo": true, "tongue": 150.0, "box": Vector2(16, 10), "body": _c("6e6a5e"), "hi": _c("9a9482"), "accent": _c("fff8e8"),
			"tongue_col": _c("d84a4a")}
	d["crypt_lizard"] = {"name": "CRYPT LIZARD", "region": 3, "arch": "lizard", "hp": 5, "stomp": "stunned", "speed": 32.0, "run": 128.0, "lunge": 225.0,
			"jump": true, "double": false, "blind": true, "ears": 3.0, "box": Vector2(16, 10), "body": _c("17121c"), "hi": _c("2a2430"), "accent": _c("8a6ad0")}
	d["bone_vulture"] = {"name": "BONE VULTURE", "region": 3, "arch": "dive", "fly": true, "hp": 4, "stomp": "stunned", "speed": 72.0, "dive": 260.0,
			"shots": false, "accent": _c("4a5ad0"), "hi": _c("e8e4f0")}
	d["marrow_worm"] = {"name": "MARROW WORM", "region": 3, "arch": "burrow", "fly": true, "hp": 99, "stomp": "never",
			"accent": _c("4a5ad0"), "hi": _c("767880"), "body": _c("1e2a24")}
	# --- THE ASH DEEP
	d["ash_wyrm"] = {"name": "ASH WYRM", "region": 4, "arch": "wyrm", "fly": true, "hp": 4, "stomp": "stunned", "speed": 92.0,
			"accent": _c("ff7a3a"), "hi": _c("5a2a30")}
	d["cinder_lizard"] = {"name": "CINDER LIZARD", "region": 4, "arch": "lizard", "hp": 5, "stomp": "stunned", "speed": 34.0, "run": 132.0, "lunge": 235.0,
			"jump": true, "double": true, "box": Vector2(16, 10), "body": _c("1c0c10"), "hi": _c("3a1a20"), "accent": _c("ff8a40")}
	d["ember_vulture"] = {"name": "EMBER VULTURE", "region": 4, "arch": "dive", "fly": true, "hp": 5, "stomp": "stunned", "speed": 84.0, "dive": 290.0,
			"shots": true, "accent": _c("ff7a3a"), "hi": _c("f0e0d0")}
	d["soot_wraith"] = {"name": "SOOT WRAITH", "region": 4, "arch": "reach", "hp": 99, "stomp": "never", "speed": 14.0, "eye": 26.0, "box": Vector2(18, 12),
			"body": _c("120a10"), "accent": _c("ff6a2a"), "hi": _c("2a1a22")}
	return d
