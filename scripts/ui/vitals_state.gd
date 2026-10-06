class_name VitalsState
extends RefCounted
## The numbers the HUD and inventory display. UI-only for now: the player will own one of these later.
## Health is in crystals: 6 to start, +1 per 2 shards, up to 11 (10 shards in the whole game).

signal changed
signal damaged(first_index: int, count: int)  ## crystal indices that just shattered
signal healed(first_index: int, count: int)  ## crystal indices that just regrew

const BASE_HEALTH := 6
const MAX_HEALTH := 11
const SHARDS_PER_CRYSTAL := 2
const MAX_SHARDS := (MAX_HEALTH - BASE_HEALTH) * SHARDS_PER_CRYSTAL
const ENERGY_TIME := 30.0

## Order the abilities are granted: one on entering each region from region 2 on.
const ABILITY_ORDER: Array[String] = ["pound", "double_jump", "dash_iframes", "fast_heal"]

var max_health := BASE_HEALTH
var health := BASE_HEALTH
var shards := 0
## Energy: a circle that fills over ENERGY_TIME seconds. When full, holding Heal spends it to restore one crystal.
var energy := 0.0
var heal_progress := 0.0  ## 0..1 while the hero is channelling a heal (drawn around the circle)
var currency := 0
var region := "THE OVERGROWTH"
var completion := 0
var unlocked: Dictionary = {"pound": false, "double_jump": false, "dash_iframes": false, "fast_heal": false}
var items: Dictionary = {}  ## "key_0" .. "key_3": the region keys collected
var guardians: Dictionary = {}  ## "g_0" .. "g_4": guardians defeated
var doors: Dictionary = {}  ## gate ids already opened
var read_scrolls: Dictionary = {}  ## scroll ids already read


func hurt(amount: int) -> void:
	var lost := mini(amount, health)
	if lost <= 0:
		return
	health -= lost
	damaged.emit(health, lost)
	changed.emit()


func heal(amount: int) -> void:
	var gained := mini(amount, max_health - health)
	if gained <= 0:
		return
	var first := health
	health += gained
	healed.emit(first, gained)
	changed.emit()


func add_shard() -> void:
	if shards >= MAX_SHARDS:
		return
	shards += 1
	var new_max := BASE_HEALTH + shards / SHARDS_PER_CRYSTAL
	if new_max > max_health:
		max_health = new_max
		var first := health
		health = max_health  # a new crystal comes with a full heal, as in Hollow Knight
		healed.emit(first, max_health - first)
	changed.emit()


func tick_energy(delta: float) -> void:
	energy = minf(1.0, energy + delta / ENERGY_TIME)


func energy_full() -> bool:
	return energy >= 1.0


## Spends a full circle on one crystal. Returns false if the circle is not full or health is already full.
func spend_energy_heal() -> bool:
	if not energy_full() or health >= max_health:
		return false
	energy = 0.0
	heal(1)
	return true


func add_currency(amount: int) -> void:
	currency += amount
	changed.emit()


## Unlocks the next ability in order, returns its id or "" if all are unlocked.
func unlock_next() -> String:
	for id in ABILITY_ORDER:
		if not unlocked[id]:
			unlocked[id] = true
			changed.emit()
			return id
	return ""
