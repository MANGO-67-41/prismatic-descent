class_name ReacherCreature
extends Creature
## Soot wraith, a long-legs of the Ash Deep: a smouldering clot of a body that creeps along the floor, and six long tentacles
## that wander around it and reach for the hero when they come near. It cannot be killed: the stick makes it pull every
## tentacle in for a moment.

var _arms: Array[PackedVector2Array] = []
var _tips: Array[Vector2] = []
const N := 6
const SEGS := 12
const SEG := 5.5


func born() -> void:
	for i in N:
		var a := -PI + i * PI / (N - 1)
		_arms.append(line_of(global_position + Vector2(0, -16), Vector2(cos(a), sin(a)), SEGS, SEG))
		_tips.append(global_position + Vector2(cos(a), 0.4) * 30.0)


func think(delta: float) -> void:
	var hc := hero_center()
	if hunting():
		var route := chase_dir(delta)
		if route != 0:
			facing = route
		walk(facing * float(spec["speed"]) if route != 0 else 0.0, delta)
	elif hero_near(200.0):
		facing = 1 if hc.x > global_position.x else -1
		if blocked_ahead(10.0):
			walk(0.0, delta)
		else:
			walk(facing * float(spec["speed"]), delta)
	else:      # nobody about: it creeps along the floor, feeling the way with its arms
		if blocked_ahead(14.0):
			facing = -facing
		walk(facing * float(spec["speed"]) * 0.6, delta)


func _physics_process(delta: float) -> void:
	super(delta)
	var root := global_position + Vector2(0, -16)
	var hc := hero_center()
	var reaching := hero_near(130.0) and stun_left <= 0.0
	for i in N:
		var want: Vector2
		if stun_left > 0.0:
			want = root + Vector2((i - 2.5) * 3.0, 6.0)
		elif reaching and i % 2 == 0:
			want = hc + Vector2(sin(clock * 3.0 + i) * 6.0, cos(clock * 2.0 + i) * 4.0)
		else:
			var a := clock * 0.6 + i * TAU / N
			var g := ground_below(root + Vector2(cos(a) * 28.0, 0), 40.0)
			want = Vector2(root.x + cos(a) * 28.0, g if g != INF else root.y + 20.0)
		var sp := 80.0 if reaching else 40.0
		_tips[i] = _tips[i].move_toward(want, sp * delta)
		if _tips[i].distance_to(root) > SEG * (SEGS - 1):
			_tips[i] = root + (_tips[i] - root).normalized() * SEG * (SEGS - 1)
		# two passes: from the tip back to the body, then from the body out, so the arm reaches but stays attached
		var arm := _arms[i]
		arm[SEGS - 1] = _tips[i]
		for k in range(SEGS - 2, -1, -1):
			var d := arm[k] - arm[k + 1]
			arm[k] = arm[k + 1] + d.normalized() * SEG
		arm = follow(arm, root, SEG, 0.0, delta)
		_arms[i] = arm


func hit_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(global_position + Vector2(-14, -30), Vector2(28, 24))]
	if stun_left <= 0.0:
		for arm in _arms:
			out.append(Rect2(arm[SEGS - 1] - Vector2(3, 3), Vector2(6, 6)))
	return out


func stun_anchor() -> Vector2:
	return Vector2(0, -36)


func draw_body() -> void:
	var body: Color = spec["body"]
	var accent: Color = spec["accent"]
	var hi: Color = spec["hi"]
	# the arms: thick at the root, thin and smouldering at the tips, a bead of fire every few joints
	for arm in _arms:
		for k in range(1, SEGS):
			var t := float(k) / SEGS
			var w := lerpf(3.0, 1.0, t)
			CDraw.limb(self, local(arm[k - 1]) + wob, local(arm[k]) + wob, body if k % 4 else hi, w)
			if k % 3 == 0:
				draw_rect(Rect2((local(arm[k]) + wob).floor(), Vector2(1, 1)), Color(accent, 0.5 + 0.5 * sin(clock * 5.0 + k)))
		var tip := local(arm[SEGS - 1]) + wob
		CDraw.glow(self, tip, 2.0, accent, 0.6 + 0.3 * sin(clock * 6.0))
	art("stun" if stun_left > 0.0 else "idle", by_time("stun" if stun_left > 0.0 else "idle", 5.0), Vector2(0, -16))
	if int(clock * 10.0) % 4 == 0:
		burst(global_position + Vector2(randf_range(-10, 10), -30), 1, 15.0)
