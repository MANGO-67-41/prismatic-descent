class_name ShaftArt
extends RefCounted
## Title-screen and menu backdrop, generated in code: dusk sky, two wall layers, metal platforms.
## This is the final look for the menus (kept by the project owner); game zones use their own art.
## Layers are drawn 6px larger than the 480x270 screen so they can sway without exposing edges.

const PAD := 3
const W := 480 + PAD * 2
const H := 270 + PAD * 2
const CX := W / 2

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

const SKY_STOPS: Array[Color] = [
	Color("c4875a"), Color("a8583f"), Color("7a3a3c"), Color("4a2a40"),
	Color("2e2238"), Color("1b1d2e"), Color("11202a"), Color("0a1519"),
]

const NEAR := {"seed": 29, "base": 52, "slope": 0.24, "body": "1c1418", "alt": "251a1d", "mortar": "120d10", "rim": "7a4128"}
const FAR := {"seed": 11, "base": 96, "slope": 0.15, "body": "2d2236", "alt": "372a41", "mortar": "211a29", "rim": "52405c"}

const PLATFORM_YS: Array[int] = [58, 104, 150, 196]


static func _dither(t: float, x: int, y: int) -> bool:
	return t > (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0


static func sky() -> ImageTexture:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var last := SKY_STOPS.size() - 1
	for y in H:
		for x in W:
			var pos := pow(float(y) / float(H - 1), 0.85)
			pos += pow(absf(x - CX) / float(CX), 2.0) * 0.18
			var glow := maxf(0.0, 1.0 - Vector2(x - CX, y + 30).length() / 190.0)
			pos -= glow * 0.22
			if y < 120:
				var streak := maxf(0.0, sin(x * 0.03 + y * 0.21) * sin(y * 0.09))
				pos -= streak * 0.07 * (1.0 - y / 120.0)
			pos = clampf(pos, 0.0, 1.0)
			var scaled := pos * last
			var i := mini(int(scaled), last - 1)
			var f := scaled - i
			img.set_pixel(x, y, SKY_STOPS[i + 1] if _dither(f, x, y) else SKY_STOPS[i])
	return ImageTexture.create_from_image(img)


## Per-row inner edge x of the left and right wall, stepped so the silhouette reads as masonry.
static func _edges(p: Dictionary, side: int) -> PackedInt32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed) * 7 + side * 131
	var edges := PackedInt32Array()
	edges.resize(H)
	var offset := 0
	var run := 0
	for y in H:
		if run <= 0:
			offset = rng.randi_range(-9, 9)
			run = rng.randi_range(5, 14)
		run -= 1
		edges[y] = int(p.base) + int(float(p.slope) * y) + offset
	return edges


static func walls(near: bool) -> ImageTexture:
	var p: Dictionary = NEAR if near else FAR
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var body := Color(p.body)
	var alt := Color(p.alt)
	var mortar := Color(p.mortar)
	var rim := Color(p.rim)
	var depth := Color("0a1519")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed)
	for side in 2:
		var edges := _edges(p, side)
		for y in H:
			var edge := edges[y]
			for d in edge:
				var x := d if side == 0 else W - 1 - d
				var from_edge := edge - d  # 1 at the rim, growing into the wall
				var row := y / 6
				var brick_x := (d + (row % 2) * 8) % 16
				var c := body
				if brick_x == 0 or y % 6 == 0:
					c = mortar
				elif ((x * 7 + y * 13) % 11) < 3:
					c = alt
				if from_edge <= (2 if near else 1):
					c = rim
				var shade := clampf(float(y) / float(H) * (0.55 if near else 0.4), 0.0, 1.0)
				img.set_pixel(x, y, c.lerp(depth, shade))
	return ImageTexture.create_from_image(img)


static func platforms() -> ImageTexture:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var plate := Color("3a2a2c")
	var top := Color("9a5a34")
	var under := Color("0f0b0f")
	var rivet := Color("b98856")
	var brace := Color("241a1c")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for side in 2:
		var edges := _edges(NEAR, side)
		for i in PLATFORM_YS.size():
			var y := PLATFORM_YS[i] + (side * 23) % 31 - 12  # stagger left and right
			var length := rng.randi_range(22, 34)
			var start := edges[y] - 2
			for d in range(start, start + length):
				var x := d if side == 0 else W - 1 - d
				img.set_pixel(x, y, top)
				img.set_pixel(x, y + 1, plate)
				img.set_pixel(x, y + 2, plate)
				img.set_pixel(x, y + 3, under)
				if (d - start) % 8 == 4:
					img.set_pixel(x, y + 1, rivet)
			# diagonal brace from the wall up to the platform edge
			for k in range(0, 18):
				var bx := start + k
				var bx2 := bx if side == 0 else W - 1 - bx
				var by := y + 4 + (18 - k) / 2
				if by < H:
					img.set_pixel(bx2, by, brace)
			# hanging chain at the free end
			var cx_free := start + length - 2
			var chain_x := cx_free if side == 0 else W - 1 - cx_free
			for k in rng.randi_range(8, 20):
				if y + 4 + k < H and k % 2 == 0:
					img.set_pixel(chain_x, y + 4 + k, rivet.lerp(under, 0.45))
	return ImageTexture.create_from_image(img)
