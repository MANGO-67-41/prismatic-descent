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

## Order the abilities are granted: one on entering each region from region 2 on.
const ABILITY_ORDER: Array[String] = ["pound", "double_jump", "dash_iframes", "fast_heal"]

var max_health := BASE_HEALTH
var health := BASE_HEALTH
var shards := 0
var max_food := 6
var food := 4
var currency := 0
var region := "THE OVERGROWTH"
var completion := 0
var unlocked: Dictionary = {"pound": false, "double_jump": false, "dash_iframes": false, "fast_heal": false}
var items: Dictionary = {}


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


func eat(amount: int) -> void:
	food = clampi(food + amount, 0, max_food)
	changed.emit()


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
