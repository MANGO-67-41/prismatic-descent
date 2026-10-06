class_name BambooStick
extends Node2D
## The hero's little bamboo stick, drawn in pixels from the hero's hand: slung across the back at rest; on a strike it snaps
## through in a blink and leaves a crescent slash in the air, like Hollow Knight's nail. Sideways slashes alternate (over the
## top and down, then from below and up); holding up slashes over the head. The crescent is thickest in its middle, white along
## its outer edge, and fades from its tail as it goes. A strike stuns what it hits for 1.5 seconds (see Guardian.stick_hit);
## it does no damage.

const LENGTH := 14.0
const SNAP := 0.3          ## the part of the swing (0..1) the cane takes to sweep through; the crescent lingers after
const CANE := Color("8fb04a")
const CANE_HI := Color("c8dc8a")
const NODE := Color("4f6e26")

var player: Player


func _process(_delta: float) -> void:
	if player != null:
		modulate = player.stick_modulate()
	queue_redraw()


## Start and end angle of a slash (radians, for a hero facing right; y down), where the crescent is centred and its radius.
func _sweep() -> Array:
	if player.swing_up():
		return [0.35, -2.65, Vector2(0, -15), 16.0]           # from in front, over the head, to behind
	if player.swing_alt():
		return [1.15, -1.75, Vector2(3, -10), 17.0]          # from below the feet up and over
	return [-1.75, 1.15, Vector2(3, -10), 17.0]              # from over the head down in front


func _draw() -> void:
	if player == null:
		return
	var f := float(player.facing)
	if player.is_swinging():
		z_index = 1
		var p := player.swing_progress()
		var sw := _sweep()
		var a0: float = sw[0]
		var a1: float = sw[1]
		var c: Vector2 = sw[2]
		var R: float = sw[3]
		c.x *= f
		var e := 1.0 - pow(1.0 - clampf(p / SNAP, 0.0, 1.0), 3.0)   # the cane: through in a snap, eased out
		var fade := 1.0 - smoothstep(SNAP, 1.0, p)                   # the crescent: full while it is cut, then gone
		var tail := clampf((p - SNAP * 0.5) / (1.0 - SNAP * 0.5), 0.0, 1.0)   # its tail end thins away first
		var n := 80
		for k in n + 1:
			var t := float(k) / n
			if t > e or t < tail * 0.9:
				continue
			var a := lerpf(a0, a1, t)
			var dir := Vector2(cos(a) * f, sin(a))
			var w := sin(t * PI) * 5.5 * (0.55 + 0.45 * fade) + 0.8
			var r := R - w
			while r <= R + 0.5:
				var edge := r > R - 1.2
				var col := Color.WHITE if edge else UITheme.CREAM
				var alpha := fade * (1.0 if edge else 0.62) * clampf((t - tail * 0.9) * 6.0, 0.0, 1.0)
				draw_rect(Rect2((c + dir * r).floor(), Vector2(1, 1)), Color(col, alpha))
				r += 0.5
		var ang := lerpf(a0, a1, e)
		var hand := c + Vector2(cos(ang) * f, sin(ang)) * 4.0
		_cane(hand, Vector2(cos(ang) * f, sin(ang)), LENGTH)
	else:
		z_index = -1
		# slung across the back: from behind the shoulder down past the tail
		_cane(Vector2(-6.0 * f, -16.0), Vector2(0.55 * f, 0.84).normalized(), 12.0)


## A cane of bamboo from `from` along `dir`: ink outline, green body, a lighter edge, a dark node every few pixels.
func _cane(from: Vector2, dir: Vector2, length: float) -> void:
	var n := int(length)
	for t in n + 1:
		var pt := (from + dir * t).floor()
		draw_rect(Rect2(pt - Vector2(1, 1), Vector2(3, 3)), UITheme.INK)
	for t in n + 1:
		var pt := (from + dir * t).floor()
		var c := NODE if t % 4 == 3 else CANE
		draw_rect(Rect2(pt, Vector2(2, 1)), c)
		draw_rect(Rect2(pt + Vector2(0, 1), Vector2(2, 1)), c.darkened(0.25) if c == CANE else c)
		if t % 4 == 1:
			draw_rect(Rect2(pt, Vector2(1, 1)), CANE_HI)
	# a leaf at the tip
	var tip := (from + dir * length).floor()
	draw_rect(Rect2(tip + Vector2(dir.x * 2.0, -1).floor(), Vector2(2, 1)), CANE_HI)


## A burst where the stick lands: a white star, a ring, a few chips of green.
class Impact extends Node2D:
	var _t := 0.0
	var _strong := true

	func _init(strong: bool) -> void:
		_strong = strong
		z_index = 20

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.28:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / 0.28
		var a := 1.0 - k
		var r := 3.0 + k * (10.0 if _strong else 6.0)
		for i in 8:
			var ang := i * TAU / 8.0 + 0.3
			var p := Vector2(cos(ang), sin(ang)) * r
			draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(UITheme.CREAM, a))
		if _t < 0.08:
			for i in 4:
				var ang := i * TAU / 4.0 + PI / 4.0
				for d in range(1, 7 if _strong else 4):
					draw_rect(Rect2((Vector2(cos(ang), sin(ang)) * d).floor(), Vector2(1, 1)), Color.WHITE)
			draw_rect(Rect2(-2, -2, 4, 4), Color.WHITE)
		if not _strong:
			draw_rect(Rect2(-1, -1, 2, 2), Color("8fb04a", a))
