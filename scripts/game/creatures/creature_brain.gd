class_name CreatureBrain
extends RefCounted
## How hard the creatures of each region hunt. A creature starts hunting the moment the hero ENTERS its room (not before, and
## not beyond it): it freezes for its reaction time, turning to face the hero (a red "!" shows), then hunts: it always knows where
## the hero is while it can see them, goes to where it last saw them when it cannot, and keeps looking for `memory` seconds
## before it gives up and goes back to its patrol. It hears landings, ground pounds and stick swings. Deeper regions react
## faster, see and hear farther, remember longer, run faster, attack more often and, from the Bone Stacks on, come at the hero
## from different sides. From the Rustworks on, one that sees the hero tells the others in the room where they are (`share`).
## From the Drowned Works down, lizards sometimes hop back from a swing of the stick (`dodge`, the chance).
## In the Ash Deep they never lose the hero while they are in the same room (they smell them).

enum S { IDLE, ALERT, HUNT }

const PROFILES := [
	{"reaction": 1.1, "sight": 150.0, "memory": 10.0, "hearing": 0.5, "speed": 1.00, "aggr": 1.00, "flank": false, "share": false, "dodge": 0.0, "smell": false},
	{"reaction": 0.85, "sight": 190.0, "memory": 15.0, "hearing": 0.8, "speed": 1.08, "aggr": 1.15, "flank": false, "share": true, "dodge": 0.0, "smell": false},
	{"reaction": 0.60, "sight": 230.0, "memory": 22.0, "hearing": 1.1, "speed": 1.16, "aggr": 1.30, "flank": false, "share": true, "dodge": 0.25, "smell": false},
	{"reaction": 0.40, "sight": 280.0, "memory": 35.0, "hearing": 1.4, "speed": 1.25, "aggr": 1.50, "flank": true, "share": true, "dodge": 0.35, "smell": false},
	{"reaction": 0.20, "sight": 400.0, "memory": 999.0, "hearing": 2.0, "speed": 1.35, "aggr": 1.75, "flank": true, "share": true, "dodge": 0.45, "smell": true},
]
## Numbers in a creature's spec that are speeds: they are scaled by the region's `speed` (a copy per creature).
const SPEED_KEYS := ["speed", "run", "creep", "lunge", "strike", "dive", "leap", "dart", "climb"]


static func profile(region: int) -> Dictionary:
	return PROFILES[clampi(region, 0, PROFILES.size() - 1)]


static func scaled_spec(kind: String) -> Dictionary:
	var s: Dictionary = CreatureTypes.spec(kind).duplicate()
	var mul: float = profile(int(s["region"]))["speed"]
	for k in SPEED_KEYS:
		if s.has(k):
			s[k] = float(s[k]) * mul
	return s
