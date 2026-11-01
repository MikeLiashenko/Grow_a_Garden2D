extends RefCounted
## The garden itself: the ground map and every prop that stands on it.

const Painter := preload("res://tools/art/painter.gd")
const ItemArt := preload("res://tools/art/item_art.gd")
const D := preload("res://scripts/core/game_data.gd")

const GRASS := ["#2a7030", "#338238", "#3c9640", "#47a848", "#5cbc52"]
const WOOD := ["#3a2210", "#5a3618", "#7c5228", "#9a6e3c", "#bb9058"]
const STONE := ["#4e4a50", "#6e6a6e", "#8e8a88", "#b0aca4", "#d2cec2"]
const LEAF := ["#153f26", "#1f6b33", "#2f9140", "#4cb84a", "#86dc57"]
const DARK_LEAF := ["#0e2c26", "#15463a", "#1f6640", "#2c8a48", "#52b45a"]
const BLOSSOM := ["#7a2860", "#b84888", "#e878b0", "#ffa8d0", "#ffd8ea"]
const OUT := "#141c14"


# --- Ground --------------------------------------------------------------------

static func _on_path(x: int, y: int) -> bool:
	return D.on_path(x, y)


static func _in_garden(x: int, y: int) -> bool:
	return x >= D.FENCE_X1 * 16 and x < (D.FENCE_X2 + 1) * 16 and y >= D.FENCE_Y1 * 16 and y < (D.FENCE_Y2 + 1) * 16


static func _noise(x: float, y: float, s: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(xi, yi, s)
	var b := _hash(xi + 1, yi, s)
	var c := _hash(xi, yi + 1, s)
	var d := _hash(xi + 1, yi + 1, s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _hash(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 1274126177) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65536.0


## Cobblestones: Voronoi cells with mortar, lit on the top-left of each stone.
static func _cobble(x: int, y: int) -> Color:
	const CELL := 10
	var gx := floori(float(x) / CELL)
	var gy := floori(float(y) / CELL)
	var f1 := 1e9
	var f2 := 1e9
	var bx := 0.0
	var by := 0.0
	var id := 0.0
	for j in range(gy - 1, gy + 2):
		for i in range(gx - 1, gx + 2):
			var px_ := (i + 0.15 + 0.7 * _hash(i, j, 3)) * CELL
			var py_ := (j + 0.15 + 0.7 * _hash(i, j, 4)) * CELL
			var d := sqrt((px_ - x) * (px_ - x) + (py_ - y) * (py_ - y))
			if d < f1:
				f2 = f1
				f1 = d
				bx = px_
				by = py_
				id = _hash(i, j, 5)
			elif d < f2:
				f2 = d
	if f2 - f1 < 1.3:
		return Painter.col("#5c5448")
	var tones := ["#8d8579", "#9c9484", "#a8a08f", "#94897a", "#b0a792"]
	var base: Color = Painter.col(tones[int(id * tones.size())])
	var lit := (bx - x) + (by - y)
	if f2 - f1 < 2.4 and lit < 0.0:
		return base.darkened(0.16)
	if lit > 3.0 and f1 > 1.5:
		return base.lightened(0.12)
	return base


static func _grass(x: int, y: int) -> Color:
	var n := _noise(x / 26.0, y / 26.0, 1) * 0.6 + _noise(x / 9.0, y / 9.0, 2) * 0.4
	var inside := _in_garden(x, y)
	var v := n * 2.2 + 1.0
	if inside:
		# Neatly mowed stripes inside the fence.
		v = 2.0 + (n - 0.5) * 0.9 + (0.62 if (x / 32) % 2 == 0 else -0.05)
	else:
		v -= 0.35
	v += (Painter.BAYER[y & 3][x & 3] - 0.5) * 0.7
	var i := clampi(int(v), 0, GRASS.size() - 1)
	var h := _hash(x, y, 7)
	if h < 0.018:
		i = clampi(i + 1, 0, GRASS.size() - 1)
	elif h < 0.04:
		i = clampi(i - 1, 0, GRASS.size() - 1)
	return Painter.col(GRASS[i])


static func _soil(x: int, y: int, r: Rect2) -> Color:
	var ramp := ["#3b2214", "#4c2e1b", "#5e3a22", "#70482c", "#86583a"]
	var ly := y - int(r.position.y)
	var row := ly % 14
	var v := 2.0
	if row <= 2:
		v = 0.3 + row * 0.4
	elif row <= 5:
		v = 3.0
	else:
		v = 2.0
	v += (_noise(x / 5.0, y / 5.0, 8) - 0.5) * 1.6
	v += (Painter.BAYER[y & 3][x & 3] - 0.5) * 0.7
	var h := _hash(x, y, 9)
	if h < 0.02:
		v += 1.5
	elif h < 0.04:
		v -= 1.5
	return Painter.col(ramp[clampi(int(v), 0, ramp.size() - 1)])


static func ground() -> RefCounted:
	var w := D.WORLD_W * 16
	var h := D.WORLD_H * 16
	var p: RefCounted = Painter.new(w, h)
	for y in h:
		for x in w:
			p.img.set_pixel(x, y, _cobble(x, y) if _on_path(x, y) else _grass(x, y))
	_path_edges(p)
	_tufts(p)
	for bed in D.BEDS:
		_bed(p, bed["rect"])
	_flower_strips(p)
	_pond(p)
	return p


## Grass spills irregularly over the path edge so the cobbles sit in the lawn.
static func _path_edges(p: RefCounted) -> void:
	var out: Array[Vector2i] = []
	for y in p.h:
		for x in p.w:
			if not _on_path(x, y):
				continue
			if not _on_path(x - 3, y) or not _on_path(x + 3, y) or not _on_path(x, y - 3) or not _on_path(x, y + 3):
				if _hash(x / 2, y / 2, 11) < 0.55:
					out.append(Vector2i(x, y))
	for v in out:
		p.img.set_pixel(v.x, v.y, _grass(v.x, v.y).darkened(0.08))


static func _tufts(p: RefCounted) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var flowers := ["#ffffff", "#ffe060", "#ff90c0", "#a0c8ff"]
	for k in 2600:
		var x := rng.randi_range(2, p.w - 3)
		var y := rng.randi_range(3, p.h - 3)
		if _on_path(x, y) or _on_path(x, y - 3) or _on_path(x + 2, y):
			continue
		var inside := _in_garden(x, y)
		if inside and rng.randf() < 0.65:
			continue
		p.px(x, y, GRASS[4])
		p.px(x, y - 1, GRASS[4])
		p.px(x + 2, y, GRASS[4])
		p.px(x + 2, y - 1, "#7cd868")
		p.px(x + 1, y + 1, GRASS[0])
		p.px(x + 2, y + 1, GRASS[0])
		if rng.randf() < (0.1 if inside else 0.22):
			var c: String = flowers[rng.randi() % flowers.size()]
			p.px(x + 1, y - 3, c)
			p.px(x, y - 2, c)
			p.px(x + 2, y - 2, c)
			p.px(x + 1, y - 1, c)
			p.px(x + 1, y - 2, "#e8a020")


static func _bed(p: RefCounted, r: Rect2) -> void:
	var x0 := int(r.position.x)
	var y0 := int(r.position.y)
	var x1 := int(r.end.x)
	var y1 := int(r.end.y)
	for y in range(y0, y1):
		for x in range(x0, x1):
			p.img.set_pixel(x, y, _soil(x, y, r))
	# Inner shadow under the north frame, for depth.
	for x in range(x0, x1):
		for k in 4:
			var c: Color = p.img.get_pixel(x, y0 + 4 + k)
			p.img.set_pixel(x, y0 + 4 + k, c.darkened(0.3 - k * 0.07))
	for y in range(y0, y1):
		for k in 3:
			var c: Color = p.img.get_pixel(x0 + 4 + k, y)
			p.img.set_pixel(x0 + 4 + k, y, c.darkened(0.2 - k * 0.06))
	# Timber frame: planks with seams and little nail heads.
	_timber_h(p, x0, y0, r.size.x)
	_timber_h(p, x0, y1 - 5, r.size.x)
	_timber_v(p, x0, y0, r.size.y)
	_timber_v(p, x1 - 5, y0, r.size.y)
	p.rect(x0, y1, r.size.x, 2, Color(0.05, 0.1, 0.05, 0.35))


static func _timber_h(p: RefCounted, x: int, y: int, len_: float) -> void:
	for i in int(len_):
		var seam := (i + x) % 32 == 0
		p.px(x + i, y, WOOD[4])
		p.px(x + i, y + 1, WOOD[0] if seam else WOOD[3])
		p.px(x + i, y + 2, WOOD[0] if seam else (WOOD[3] if (i * 7) % 11 > 2 else WOOD[2]))
		p.px(x + i, y + 3, WOOD[0] if seam else WOOD[2])
		p.px(x + i, y + 4, WOOD[0])
		if (i + x) % 32 == 3:
			p.px(x + i, y + 2, "#d8d0c0")


static func _timber_v(p: RefCounted, x: int, y: int, len_: float) -> void:
	for i in int(len_):
		var seam := (i + y) % 32 == 0
		p.px(x, y + i, WOOD[3])
		p.px(x + 1, y + i, WOOD[0] if seam else WOOD[4])
		p.px(x + 2, y + i, WOOD[0] if seam else WOOD[3])
		p.px(x + 3, y + i, WOOD[0] if seam else WOOD[2])
		p.px(x + 4, y + i, WOOD[0])
		if (i + y) % 32 == 3:
			p.px(x + 2, y + i, "#d8d0c0")


## Overgrown plot shown over beds not bought yet, with a rope around it.
static func locked_bed() -> RefCounted:
	var p: RefCounted = Painter.new(224, 112)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ramp := ["#2a5a2c", "#34702f", "#3f8236", "#4f9640", "#6aa84c"]
	for y in 112:
		for x in 224:
			var n := _noise(x / 11.0, y / 11.0, 21)
			var v: float = n * 4.0 + (Painter.BAYER[y & 3][x & 3] - 0.5) * 1.2
			p.px(x, y, ramp[clampi(int(v), 0, 4)])
	for k in 340:
		var x := rng.randi_range(2, 220)
		var y := rng.randi_range(5, 108)
		var hgt := rng.randi_range(2, 5)
		p.line(x, y, x + rng.randi_range(-1, 1), y - hgt, ramp[4] if rng.randf() < 0.5 else "#8ab85a")
		p.px(x + 1, y, ramp[0])
	for k in 18:
		var x := rng.randi_range(8, 214)
		var y := rng.randi_range(8, 104)
		p.blob(x, y, 4, 3, ramp, 0.4)
		p.px(x - 1, y - 2, "#a8cc70")
	for k in 8:
		var x := rng.randi_range(8, 214)
		var y := rng.randi_range(8, 104)
		p.blob(x, y, 3, 2, ["#55504c", "#7a7670", "#a09a90"], 0.2)
	_timber_h(p, 0, 0, 224)
	_timber_h(p, 0, 107, 224)
	_timber_v(p, 0, 0, 112)
	_timber_v(p, 219, 0, 112)
	return p


static func _flower_strips(p: RefCounted) -> void:
	# Flower beds hugging the inside of the fence.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var colors := [["#c02a50", "#ff5a80"], ["#d8a010", "#ffe050"], ["#6a3ad0", "#a884ff"], ["#e05a20", "#ffa050"], ["#f0f0f0", "#ffffff"]]
	var strips: Array = [Rect2(160, 96, 640, 12), Rect2(152, 112, 18, 368), Rect2(792, 112, 18, 368), Rect2(160, 484, 272, 12), Rect2(528, 484, 272, 12)]
	for r: Rect2 in strips:
		for y in range(int(r.position.y), int(r.end.y)):
			for x in range(int(r.position.x), int(r.end.x)):
				var v := _noise(x / 3.0, y / 3.0, 31)
				p.px(x, y, ["#3b2214", "#4c2e1b", "#5e3a22"][clampi(int(v * 3), 0, 2)])
		var count := int(r.size.x * r.size.y / 10.0)
		for k in count:
			var x := rng.randf_range(r.position.x + 1, r.end.x - 2)
			var y := rng.randf_range(r.position.y + 1, r.end.y - 2)
			p.px(x, y, LEAF[2])
			p.px(x + 1, y, LEAF[3])
			p.px(x, y + 1, LEAF[1])
		var fl := int(count * 0.55)
		for k in fl:
			var x := rng.randf_range(r.position.x + 2, r.end.x - 3)
			var y := rng.randf_range(r.position.y + 2, r.end.y - 3)
			var c: Array = colors[rng.randi() % colors.size()]
			p.px(x - 1, y, c[0])
			p.px(x + 1, y, c[0])
			p.px(x, y - 1, c[1])
			p.px(x, y + 1, c[0])
			p.px(x, y, "#ffe860")


static func _pond(p: RefCounted) -> void:
	var c := Vector2(896, 280)
	var rx := 42.0
	var ry := 54.0
	p.disk(c.x + 1, c.y + 2, rx + 5, ry + 5, "#5c5a50")
	for k in 90:
		var a := k * TAU / 90.0
		p.blob(c.x + cos(a) * (rx + 3), c.y + sin(a) * (ry + 3), 3.5, 3, STONE.slice(1, 5), 0.2)
	var ramp := ["#1a5a8a", "#2274a4", "#2e8fbe", "#44a8d0"]
	for y in range(int(c.y - ry), int(c.y + ry)):
		for x in range(int(c.x - rx), int(c.x + rx)):
			var nx := (x - c.x) / rx
			var ny := (y - c.y) / ry
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var v: float = (1.0 - d) * 2.2 + _noise(x / 8.0, y / 3.0, 41) * 1.6 + (Painter.BAYER[y & 3][x & 3] - 0.5) * 0.6
			p.px(x, y, ramp[clampi(int(v), 0, 3)])
	for lily: Vector2 in [Vector2(878, 256), Vector2(912, 262), Vector2(884, 306), Vector2(910, 300), Vector2(896, 280)]:
		p.blob(lily.x, lily.y, 5, 3.5, ["#1f6b33", "#2f9140", "#4cb84a"], 0.2)
		p.px(lily.x + 3, lily.y - 1, "#1a5a8a")
		p.px(lily.x + 4, lily.y - 1, "#1a5a8a")
	p.px(879, 255, "#ffc0e0")
	p.px(880, 255, "#ffffff")
	p.px(879, 254, "#ff90c8")
	p.px(911, 299, "#ffc0e0")
	p.px(910, 299, "#ffffff")


# --- Props ---------------------------------------------------------------------

static func tree(kind: String, variant: int) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + variant * 31
	var w := 72
	var h := 92
	var p: RefCounted = Painter.new(w, h, w / 2, h - 5)
	var cx := w / 2.0
	var by := h - 5.0
	p.shadow(cx, by + 1, 22, 5, 0.3)
	var body: RefCounted = Painter.new(w, h)
	if kind == "pine":
		_trunk(body, cx, by, by - 16, 3.5)
		var ramp: Array = DARK_LEAF
		var tiers := 5
		for t in tiers:
			var u := float(t) / (tiers - 1)
			var y := by - 14 - t * 13.0
			var half := lerpf(25.0, 8.0, u)
			_pine_tier(body, cx, y, half, 18.0, ramp, rng)
	else:
		var ramp: Array = BLOSSOM if kind == "blossom" else LEAF
		_trunk(body, cx, by, by - 30, 5.0)
		body.line(cx - 2, by - 26, cx - 12, by - 38, WOOD[1], 3)
		body.line(cx + 2, by - 24, cx + 13, by - 38, WOOD[1], 3)
		var cy := by - 50.0
		var clusters: Array = [[-16, 10, 14, 11], [16, 9, 14, 11], [-20, -4, 13, 11], [20, -5, 13, 11], [0, 10, 15, 11], [-10, -14, 14, 12], [10, -15, 14, 12], [0, -2, 18, 15], [0, -24, 13, 10]]
		for c in clusters:
			_foliage(body, cx + c[0] + rng.randf_range(-2, 2), cy + c[1] + rng.randf_range(-2, 2), c[2], c[3], ramp, rng, 11)
		if kind == "blossom":
			for k in 20:
				var x := cx + rng.randf_range(-30, 30)
				var y := cy + rng.randf_range(-30, 22)
				if body.solid(int(x), int(y)):
					body.px(x, y, "#ffffff")
		elif kind == "oak" and variant == 1:
			# An apple tree among the oaks, for colour.
			for k in 12:
				var x := cx + rng.randf_range(-26, 26)
				var y := cy + rng.randf_range(-20, 18)
				if body.solid(int(x), int(y)):
					body.disk(x, y, 1, 1, "#d8303a")
					body.px(x - 1, y - 1, "#ff8a7a")
	body.outline(OUT)
	p.stamp(body, 0, 0)
	return p


static func _pine_tier(p: RefCounted, cx: float, y: float, half: float, hgt: float, ramp: Array, rng: RandomNumberGenerator) -> void:
	for j in int(hgt):
		var t := float(j) / hgt
		var w := half * t * (0.92 + 0.08 * sin(j * 1.7))
		var x := -w
		while x <= w:
			var n := x / maxf(w, 1.0)
			var lit := 0.6 - n * 0.45 - t * 0.25 + rng.randf_range(-0.1, 0.1)
			var idx := clampi(int(lit * 4.0) + 1, 0, 4)
			if j > hgt - 3 and int(x + cx) % 5 < 2:
				idx = 0
			p.px(cx + x, y - hgt + j, ramp[idx])
			x += 1.0


static func _trunk(p: RefCounted, cx: float, by: float, top: float, hw: float) -> void:
	var y := by
	while y >= top:
		var t := (by - y) / maxf(by - top, 1.0)
		var half := hw * (1.0 - t * 0.3) + maxf(0.0, 3.0 - (by - y)) * 1.2
		var x := -half
		while x <= half:
			var n := x / maxf(half, 0.5)
			var i := 4 if n < -0.65 else (3 if n < -0.15 else (2 if n < 0.35 else (1 if n < 0.75 else 0)))
			if _hash(int(x), int(y) / 3, 51) < 0.25:
				i = maxi(i - 1, 0)
			p.px(cx + x, y, WOOD[i])
			x += 1.0
		y -= 1.0


static func _foliage(p: RefCounted, cx: float, cy: float, rx: float, ry: float, ramp: Array, rng: RandomNumberGenerator, n := 12) -> void:
	p.blob(cx, cy, rx, ry, [ramp[0], ramp[1], ramp[1], ramp[2]], 0.3)
	for k in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf())
		var x := cx + cos(a) * d * rx * 0.85
		var y := cy + sin(a) * d * ry * 0.85
		var r := minf(rx, ry) * rng.randf_range(0.2, 0.34) + 0.5
		var lit := clampf(0.55 - (y - cy) / ry * 0.5 - (x - cx) / rx * 0.2, 0.0, 1.0)
		var base := int(lit * 2.0)
		p.blob(x, y, r, r * 0.9, ramp.slice(base, base + 3), 0.2)
	for k in n:
		var x := cx + rng.randf_range(-0.8, 0.3) * rx
		var y := cy + rng.randf_range(-0.8, 0.1) * ry
		if p.solid(int(x), int(y)):
			p.px(x, y, ramp[4])


static func bush(ramp_id: String, variant: int) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ramp_id) + variant
	var p: RefCounted = Painter.new(30, 26, 15, 22)
	p.shadow(15, 22, 12, 3)
	var body: RefCounted = Painter.new(30, 26)
	_foliage(body, 15, 13, 12, 9, LEAF, rng, 12)
	if ramp_id != "green":
		var c: Array = {"rose": ["#c02a50", "#ff5a80", "#ffb0c0"], "yellow": ["#d8a010", "#ffe050", "#fff4a0"], "violet": ["#6a3ad0", "#a884ff", "#d8c8ff"]}[ramp_id]
		for k in 12:
			var x := rng.randf_range(5, 25)
			var y := rng.randf_range(6, 19)
			if body.solid(int(x), int(y)):
				body.px(x, y, c[1])
				body.px(x - 1, y, c[0])
				body.px(x + 1, y, c[0])
				body.px(x, y + 1, c[0])
				body.px(x, y - 1, c[2])
	body.outline(OUT)
	p.stamp(body, 0, 0)
	return p


static func hedge(variant: int) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + variant
	var p: RefCounted = Painter.new(18, 26, 9, 22)
	p.shadow(9, 22, 9, 2.5)
	var body: RefCounted = Painter.new(18, 26)
	body.rect(0, 8, 18, 14, LEAF[1])
	for x in 18:
		for y in range(16, 22):
			if _hash(x, y, variant) < 0.3:
				body.px(x, y, LEAF[0])
	for k in 9:
		var x := rng.randf_range(1, 17)
		var y := rng.randf_range(7, 15)
		body.blob(x, y, 3.2, 2.8, LEAF.slice(1, 5), 0.2)
	for k in 8:
		body.px(rng.randf_range(1, 17), rng.randf_range(5, 12), LEAF[4])
	p.stamp(body, 0, 0)
	return p


static func fence_h() -> RefCounted:
	# Whitewashed picket section, 16px wide, repeating along north and south.
	var p: RefCounted = Painter.new(16, 24, 0, 21)
	var white := ["#8a8878", "#c4c0ac", "#ece8d4", "#fffef0"]
	p.rect(0, 20, 16, 2, Color(0.05, 0.1, 0.05, 0.3))
	for x in range(0, 16):
		p.px(x, 9, white[3])
		p.px(x, 10, white[1])
		p.px(x, 11, white[0])
		p.px(x, 16, white[3])
		p.px(x, 17, white[1])
		p.px(x, 18, white[0])
	for k in 3:
		var x := 1 + k * 5
		for y in range(5, 21):
			p.px(x, y, OUT if y == 20 else white[3])
			p.px(x + 1, y, OUT if y == 20 else white[2])
			p.px(x + 2, y, OUT if y == 20 else white[1])
			p.px(x + 3, y, OUT)
		p.px(x + 1, 3, OUT)
		p.px(x + 2, 3, OUT)
		p.px(x, 4, OUT)
		p.px(x + 1, 4, white[3])
		p.px(x + 2, 4, white[2])
		p.px(x - 1, 5, OUT)
		p.px(x - 1, 6, OUT)
		for y in range(7, 20):
			p.px(x - 1, y, OUT)
	return p


static func fence_v() -> RefCounted:
	var p: RefCounted = Painter.new(10, 30, 5, 21)
	var white := ["#8a8878", "#c4c0ac", "#ece8d4", "#fffef0"]
	p.rect(6, 20, 3, 2, Color(0.05, 0.1, 0.05, 0.3))
	p.rect(4, 8, 2, 16, white[1])
	p.rect(4, 8, 1, 16, white[3])
	p.rect(6, 8, 1, 16, OUT)
	p.rect(3, 8, 1, 16, OUT)
	var post: RefCounted = Painter.new(10, 30)
	post.rect(3, 6, 5, 15, white[2])
	post.rect(3, 6, 2, 15, white[3])
	post.rect(7, 6, 1, 15, white[0])
	post.rect(3, 4, 5, 2, white[3])
	post.outline(OUT)
	p.stamp(post, 0, 0)
	return p


static func pillar(lantern: bool) -> RefCounted:
	var p: RefCounted = Painter.new(24, 48, 12, 44)
	p.shadow(12, 44, 11, 3)
	var body: RefCounted = Painter.new(24, 48)
	body.rect(4, 18, 16, 26, STONE[2])
	# Stone courses.
	for y in range(18, 44):
		for x in range(4, 20):
			var row := (y - 18) / 6
			var joint := (y - 18) % 6 == 5 or (x + row * 4) % 8 == 7
			var c: String = STONE[0] if joint else (STONE[3] if x < 7 else (STONE[1] if x > 16 else STONE[2]))
			body.px(x, y, c)
	body.rect(3, 14, 18, 4, STONE[3])
	body.rect(3, 14, 18, 1, STONE[4])
	body.rect(3, 17, 18, 1, STONE[1])
	if lantern:
		body.rect(9, 11, 6, 3, "#2a2a34")
		body.rect(8, 3, 8, 8, "#2a2a34")
		body.rect(9, 4, 6, 6, "#ffd860")
		body.rect(10, 5, 3, 4, "#fff6c0")
		body.rect(11, 4, 1, 6, "#2a2a34")
		body.rect(7, 2, 10, 2, "#3a3a48")
		body.rect(10, 0, 4, 2, "#3a3a48")
	body.outline(OUT)
	p.stamp(body, 0, 0)
	return p


## One swinging gate door, 30px wide when closed.
static func gate_door() -> RefCounted:
	var p: RefCounted = Painter.new(30, 28, 0, 24)
	for y in [8, 19]:
		p.rect(0, y, 30, 3, WOOD[3])
		p.rect(0, y, 30, 1, WOOD[4])
	for k in 5:
		var x := 1 + k * 6
		p.rect(x, 3, 4, 21, WOOD[3])
		p.rect(x, 3, 1, 21, WOOD[4])
		p.rect(x + 3, 3, 1, 21, WOOD[1])
		p.px(x + 1, 2, WOOD[3])
		p.px(x + 2, 2, WOOD[2])
	p.line(1, 22, 28, 9, WOOD[2], 2)
	p.outline(OUT)
	return p


## Arch over the entrance, drawn above the player so you walk under it.
static func arch() -> RefCounted:
	var w := 112
	var h := 76
	var p: RefCounted = Painter.new(w, h, w / 2, 60)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var body: RefCounted = Painter.new(w, h)
	var cx := w / 2.0
	for k in 41:
		var a := PI + PI * k / 40.0
		var x := cx + cos(a) * 46.0
		var y := 40.0 + sin(a) * 30.0
		body.blob(x, y, 5, 4.5, WOOD, 0.1)
	for k in 26:
		var a := PI + PI * k / 25.0
		var x := cx + cos(a) * 46.0 + rng.randf_range(-3, 3)
		var y := 40.0 + sin(a) * 30.0 + rng.randf_range(-3, 3)
		_foliage(body, x, y, 5, 4, LEAF, rng, 3)
	for k in 22:
		var a := PI + PI * rng.randf()
		var x := cx + cos(a) * 46.0 + rng.randf_range(-5, 5)
		var y := 40.0 + sin(a) * 30.0 + rng.randf_range(-5, 5)
		var c: Array = [["#c02a50", "#ff6a90"], ["#e8e0f0", "#ffffff"], ["#d8a010", "#ffe050"]][rng.randi() % 3]
		body.disk(x, y, 1.5, 1.5, c[0])
		body.px(x, y, c[1])
		body.px(x - 1, y - 1, c[1])
	# Sign board hanging from the top of the arch.
	body.rect(cx - 30, 5, 60, 15, WOOD[0])
	body.rect(cx - 29, 6, 58, 13, WOOD[3])
	body.rect(cx - 29, 6, 58, 1, WOOD[4])
	body.rect(cx - 29, 18, 58, 1, WOOD[1])
	body.outline(OUT)
	p.stamp(body, 0, 0)
	return p


static func lamp() -> RefCounted:
	var p: RefCounted = Painter.new(16, 40, 8, 36)
	p.shadow(8, 36, 6, 2)
	var b: RefCounted = Painter.new(16, 40)
	b.rect(5, 33, 6, 3, "#2a2a34")
	b.rect(7, 12, 2, 22, "#3a3a48")
	b.px(7, 14, "#6a6a80")
	b.px(7, 20, "#6a6a80")
	b.px(7, 26, "#6a6a80")
	b.rect(5, 11, 6, 1, "#2a2a34")
	b.rect(4, 3, 8, 8, "#2a2a34")
	b.rect(5, 4, 6, 7, "#ffd860")
	b.rect(6, 5, 3, 5, "#fff6c0")
	b.rect(3, 2, 10, 2, "#3a3a48")
	b.rect(6, 0, 4, 2, "#3a3a48")
	b.outline(OUT)
	p.stamp(b, 0, 0)
	return p


static func bench() -> RefCounted:
	var p: RefCounted = Painter.new(40, 24, 20, 20)
	p.shadow(20, 20, 18, 3)
	var b: RefCounted = Painter.new(40, 24)
	b.rect(4, 2, 32, 3, WOOD[3])
	b.rect(4, 2, 32, 1, WOOD[4])
	b.rect(4, 6, 32, 3, WOOD[2])
	b.rect(5, 5, 2, 7, WOOD[0])
	b.rect(33, 5, 2, 7, WOOD[0])
	b.rect(3, 11, 34, 3, WOOD[3])
	b.rect(3, 11, 34, 1, WOOD[4])
	b.rect(3, 14, 34, 2, WOOD[1])
	b.rect(5, 16, 3, 4, "#2a2a34")
	b.rect(32, 16, 3, 4, "#2a2a34")
	b.outline(OUT)
	p.stamp(b, 0, 0)
	return p


static func rock(variant: int) -> RefCounted:
	var p: RefCounted = Painter.new(24, 18, 12, 15)
	p.shadow(12, 15, 10, 2.5)
	var b: RefCounted = Painter.new(24, 18)
	b.blob(12, 9, 9, 7, STONE, 0.4)
	if variant == 1:
		b.blob(6, 11, 5, 4, STONE, 0.4)
		b.blob(18, 12, 3.5, 3, STONE, 0.4)
	b.px(9, 6, STONE[4])
	b.line(14, 7, 17, 10, STONE[0])
	b.outline(OUT)
	p.stamp(b, 0, 0)
	return p


static func topiary() -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var p: RefCounted = Painter.new(26, 44, 13, 40)
	p.shadow(13, 40, 9, 2.5)
	var b: RefCounted = Painter.new(26, 44)
	b.rect(8, 33, 10, 7, "#b05a30")
	b.rect(8, 33, 2, 7, "#d87a48")
	b.rect(16, 33, 2, 7, "#7c3a1c")
	b.rect(7, 31, 12, 3, "#c86a3a")
	b.rect(7, 31, 12, 1, "#e88a5a")
	b.rect(12, 22, 2, 9, WOOD[1])
	_foliage(b, 13, 24, 7, 6, LEAF, rng, 5)
	_foliage(b, 13, 11, 10, 10, LEAF, rng, 11)
	b.outline(OUT)
	p.stamp(b, 0, 0)
	return p


static func fountain() -> RefCounted:
	var w := 112
	var h := 96
	var cx := w / 2.0
	var p: RefCounted = Painter.new(w, h, w / 2, h - 28)
	var rim_y := h - 30.0
	# Outer basin: wall first, then the rim ellipse on top, then the water.
	p.shadow(cx, rim_y + 11, 52, 15, 0.3)
	var b: RefCounted = Painter.new(w, h)
	b.disk(cx, rim_y + 8, 50, 20, STONE[0])
	for x in range(int(cx - 50), int(cx + 51)):
		for y in range(int(rim_y + 2), int(rim_y + 22)):
			if b.solid(x, y) and (x + y / 5 * 4) % 10 == 0:
				b.px(x, y, "#3a363c")
	b.disk(cx, rim_y, 50, 20, STONE[3])
	for k in 72:
		var a := k * TAU / 72.0
		var x := cx + cos(a) * 49.0
		var y := rim_y + sin(a) * 19.0
		b.px(x, y, STONE[4] if sin(a) < 0.2 else STONE[2])
		if k % 6 == 0:
			b.line(cx + cos(a) * 44, rim_y + sin(a) * 15, x, y, STONE[1])
	var water := ["#1f6ea0", "#2a86b8", "#3a9fce", "#58bade"]
	for y in range(int(rim_y - 16), int(rim_y + 17)):
		for x in range(int(cx - 43), int(cx + 44)):
			var nx := (x - cx) / 43.0
			var ny := (y - rim_y) / 15.5
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var v: float = _noise(x / 7.0, y / 3.0, 61) * 3.2 + (Painter.BAYER[y & 3][x & 3] - 0.5) * 0.6 - (0.8 if ny < -0.6 else 0.0)
			b.px(x, y, water[clampi(int(v), 0, 3)])
	# Pedestal, upper bowl and finial.
	var top := rim_y - 42.0
	for y in range(int(top + 14), int(rim_y + 2)):
		var half := 5.0 + maxf(0.0, (y - (rim_y - 6.0))) * 0.7
		var x := -half
		while x <= half:
			var n := x / half
			b.px(cx + x, y, STONE[4] if n < -0.55 else (STONE[3] if n < 0.1 else (STONE[2] if n < 0.6 else STONE[1])))
			x += 1.0
	b.disk(cx, top + 14, 18, 7, STONE[1])
	b.disk(cx, top + 11, 18, 7, STONE[3])
	b.disk(cx, top + 11, 14, 5, "#2a86b8")
	b.disk(cx - 2, top + 10, 8, 2, "#58bade")
	for y in range(int(top + 3), int(top + 12)):
		for x in range(-2, 3):
			b.px(cx + x, y, STONE[3] if x < 1 else STONE[1])
	b.blob(cx, top + 2, 3, 3, STONE, 0.1)
	p.stamp(b, 0, 0)
	return p


static func greenhouse() -> RefCounted:
	var w := 132
	var h := 100
	var p: RefCounted = Painter.new(w, h, w / 2, h - 5)
	p.shadow(w / 2.0, h - 5.0, 64, 5)
	var b: RefCounted = Painter.new(w, h)
	var frame := "#f4f2e8"
	var frame_d := "#b8b4a4"
	# Roof: slanted glass panels rising to a white ridge.
	for y in range(6, 42):
		var t := (y - 6) / 36.0
		var half := lerpf(38.0, 60.0, t)
		var x := -half
		while x <= half:
			var band := int((x + 200.0)) % 22
			var c: String = "#8ee0e8" if band > 8 else "#70c8d8"
			if (int(x + y) & 15) < 2:
				c = "#d8f8fa"
			b.px(w / 2.0 + x, y, c)
			x += 1.0
		b.px(w / 2.0 - half, y, frame)
		b.px(w / 2.0 + half, y, frame_d)
	for k in range(-5, 6):
		b.line(w / 2.0 + k * 7.2, 6, w / 2.0 + k * 11.6, 41, frame, 1)
	b.rect(w / 2.0 - 40, 3, 80, 4, frame)
	b.rect(w / 2.0 - 40, 3, 80, 1, "#ffffff")
	b.rect(w / 2.0 - 40, 6, 80, 1, frame_d)
	# Walls.
	var left := w / 2 - 60
	for y in range(42, 86):
		for x in range(left, left + 120):
			var c: String = "#a8e4e8"
			if ((x - y) & 31) < 3:
				c = "#e0fafa"
			elif y > 66:
				c = "#8ad0da"
			b.px(x, y, c)
	# Plants visible through the glass.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 30:
		var x := rng.randf_range(left + 4, left + 116)
		var y := rng.randf_range(62, 82)
		b.blob(x, y, 4, 4, ["#2a8a68", "#3aa878", "#5cc488"], 0.2)
		if k % 3 == 0:
			b.px(x, y, ["#ff6a80", "#ffe050", "#ff90d0"][k % 3 if k % 2 == 0 else 1])
	for k in 7:
		var x := left + k * 20
		b.rect(x, 42, 3, 44, frame)
		b.rect(x, 42, 1, 44, "#ffffff")
		b.rect(x + 2, 42, 1, 44, frame_d)
	b.rect(left, 42, 120, 3, frame)
	b.rect(left, 44, 120, 1, frame_d)
	b.rect(left, 62, 120, 2, frame)
	# Brick plinth.
	for y in range(84, 95):
		for x in range(left, left + 120):
			var row := (y - 84) / 3
			var joint := (y - 84) % 3 == 2 or (x + row * 4) % 8 == 7
			b.px(x, y, "#6a3a28" if joint else ("#b05a3a" if (x + row * 13) % 5 else "#c06a44"))
	# Double door on the centre line.
	var dx := w / 2 - 15
	b.rect(dx - 2, 50, 34, 45, frame)
	b.rect(dx - 2, 50, 34, 1, "#ffffff")
	for i in 2:
		var x := dx + i * 15
		b.rect(x, 52, 13, 43, "#a0dce4")
		b.rect(x, 52, 13, 1, frame_d)
		b.rect(x, 72, 13, 2, frame)
		b.line(x + 1, 70, x + 9, 54, "#e8fcfc")
		b.rect(x + (11 if i == 0 else 1), 72, 1, 3, "#c89a30")
	b.outline(OUT)
	p.stamp(b, 0, 0)
	return p


static func stall(awning_a: String, awning_b: String, goods: Array, keeper: Dictionary) -> RefCounted:
	var w := 92
	var h := 84
	var p: RefCounted = Painter.new(w, h, w / 2, h - 6)
	p.shadow(w / 2.0, h - 6.0, 44, 5)
	var b: RefCounted = Painter.new(w, h)
	# Back wall and the shopkeeper behind the counter.
	b.rect(10, 24, 72, 38, WOOD[1])
	for x in range(10, 82, 8):
		b.rect(x, 24, 1, 38, WOOD[0])
	b.rect(10, 24, 72, 4, WOOD[0])
	var keeper_sprite: RefCounted = ItemArt.person(0, 0, keeper)
	b.stamp(keeper_sprite, w / 2 - 9, 26)
	# Posts.
	for x: int in [6, 82]:
		b.rect(x, 18, 4, 60, WOOD[3])
		b.rect(x, 18, 1, 60, WOOD[4])
		b.rect(x + 3, 18, 1, 60, WOOD[1])
	# Counter stacked with goods.
	b.rect(4, 52, 84, 26, WOOD[2])
	for y in range(56, 78, 7):
		b.rect(4, y, 84, 1, WOOD[0])
	for x in range(4, 88, 14):
		b.px(x + 7, 59, WOOD[0])
		b.px(x + 2, 66, WOOD[0])
	b.rect(2, 48, 88, 5, WOOD[4])
	b.rect(2, 52, 88, 2, WOOD[1])
	for i in goods.size():
		var g: RefCounted = goods[i]
		b.stamp(g, 8 + i * 17, 34)
	# Scalloped striped awning.
	for x in range(2, 90):
		var st := (x - 2) / 11
		var c: String = awning_a if st % 2 == 0 else awning_b
		var drop := 26 + int(absf(sin((x - 2) * PI / 11.0)) * 5.0)
		for y in range(8, drop):
			var t := (y - 8.0) / 22.0
			b.px(x, y, Painter.shade(c, 0.12 - t * 0.3))
		b.px(x, drop, Painter.shade(c, -0.45))
	for x in range(10, 82):
		b.px(x, 6, Painter.shade(awning_a, 0.25))
		b.px(x, 7, Painter.shade(awning_a, 0.1))
	b.outline(OUT)
	p.stamp(b, 0, 0)
	return p


static func bed_sign() -> RefCounted:
	var p: RefCounted = Painter.new(36, 30, 18, 27)
	p.shadow(18, 27, 7, 2)
	var b: RefCounted = Painter.new(36, 30)
	b.rect(16, 14, 4, 13, WOOD[2])
	b.rect(16, 14, 1, 13, WOOD[4])
	b.rect(2, 2, 32, 14, WOOD[3])
	b.rect(2, 2, 32, 1, WOOD[4])
	b.rect(2, 15, 32, 1, WOOD[1])
	for x in range(4, 34, 9):
		b.rect(x, 3, 1, 12, WOOD[2])
	b.outline(OUT)
	p.stamp(b, 0, 0)
	return p


static func house() -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var w := 108
	var h := 96
	var p: RefCounted = Painter.new(w, h, w / 2, h - 5)
	p.shadow(w / 2.0, h - 5.0, 52, 5)
	var b: RefCounted = Painter.new(w, h)
	for y in range(46, 91):
		for x in range(8, 100):
			b.px(x, y, "#e8d8b4" if (y % 6 != 5) else "#c0ac88")
	for x: int in [8, 96, 50]:
		b.rect(x, 46, 4, 45, WOOD[2])
		b.rect(x, 46, 1, 45, WOOD[4])
	b.rect(8, 88, 92, 3, WOOD[1])
	# Roof shingles.
	for y in range(4, 48):
		var t := (y - 4) / 44.0
		var half := lerpf(20.0, 54.0, t)
		var x := -half
		while x <= half:
			var row := y / 5
			var v := (int(x + 100.0) + row * 5) % 10
			var c: String = "#a84030" if v > 1 else "#7c2c24"
			if y % 5 == 4:
				c = "#6a241e"
			elif x < -half * 0.4 and v > 1:
				c = "#c85040"
			b.px(w / 2.0 + x, y, c)
			x += 1.0
	# Door and windows.
	b.rect(46, 62, 16, 29, WOOD[1])
	b.rect(47, 63, 14, 28, WOOD[3])
	b.rect(53, 63, 2, 28, WOOD[1])
	b.px(58, 77, "#ffe080")
	for x: int in [17, 72]:
		b.rect(x, 58, 20, 18, "#f4f2e8")
		b.rect(x + 2, 60, 16, 14, "#6fb8d0")
		b.rect(x + 9, 60, 2, 14, "#f4f2e8")
		b.rect(x + 2, 66, 16, 2, "#f4f2e8")
		b.line(x + 3, 72, x + 7, 62, "#c8ecf4")
		b.rect(x - 1, 76, 22, 5, WOOD[2])
		for k in 8:
			var fx := rng.randf_range(x, x + 20)
			b.px(fx, 75, ["#ff5a80", "#ffe050", "#ffffff"][k % 3])
			b.px(fx, 76, LEAF[3])
	b.outline(OUT)
	p.stamp(b, 0, 0)
	return p
