extends RefCounted
## Plant growth stages. g runs from 0 (sprout) to 1 (fully grown).

const Painter := preload("res://tools/art/painter.gd")

const OUT := "#0f2a1c"
const SOIL := ["#2e1a10", "#44291a", "#5c3a24", "#7a5234"]

## Sprite size per plant; the planted point sits at the bottom centre.
const SIZES := {
	"carrot": [26, 24], "strawberry": [34, 28], "blueberry": [36, 34], "tulip": [24, 34],
	"tomato": [36, 40], "daffodil": [26, 36], "corn": [34, 52], "watermelon": [44, 28],
	"pumpkin": [44, 28], "apple": [60, 72], "bamboo": [34, 62], "coconut": [66, 78],
	"cactus": [44, 60], "dragon": [40, 60], "mango": [60, 72], "mushroom": [36, 22],
	"grape": [46, 50], "starfall": [62, 74],
}
const TREES := ["apple", "mango", "coconut", "starfall"]


static func make(id: String, stage: int, variant: int) -> RefCounted:
	var size: Array = SIZES[id]
	var w: int = size[0]
	var h: int = size[1]
	var p: RefCounted = Painter.new(w, h, w / 2, h - 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + variant * 97 + stage * 13
	var g: float = [0.0, 0.3, 0.55, 0.8, 1.0][stage]
	var cx := float(w / 2)
	var by := float(h - 3)
	var body: RefCounted = Painter.new(w, h, w / 2, h - 3)
	if stage == 0:
		_sprout(body, cx, by, rng)
	else:
		Callable(Plants, id).call(body, cx, by, g, rng)
	body.outline(OUT)
	var mound := 3.0 + 5.0 * g
	if id in TREES:
		mound += 3.0 * g
	p.shadow(cx, by + 0.5, mound + 3.0, 3.0)
	p.blob(cx, by, mound, 2.4, SOIL, 0.4)
	p.stamp(body, 0, 0)
	return p


static func _sprout(p: RefCounted, cx: float, by: float, rng: RandomNumberGenerator) -> void:
	var lean := rng.randi_range(-1, 1)
	p.line(cx, by, cx + lean, by - 4, "#4cb84a")
	p.rect(cx + lean - 3, by - 6, 3, 2, "#4cb84a")
	p.rect(cx + lean + 1, by - 6, 3, 2, "#86dc57")
	p.px(cx + lean - 3, by - 7, "#86dc57")
	p.px(cx + lean + 3, by - 7, "#c0f080")


class Plants:
	const L := ["#153f26", "#1f6b33", "#2f9140", "#4cb84a", "#86dc57"]
	const DL := ["#102e2a", "#174a38", "#22693f", "#2f8f4a", "#5ab95c"]
	const INDIGO := ["#2a2078", "#4336b0", "#6a5ae0", "#9a8cf8", "#d8d0ff"]
	const WOOD := ["#3a2210", "#5a3618", "#7c5228", "#9a6e3c"]


	## Foliage cluster: lots of small balls gives a leafy, hand-placed feel.
	static func _foliage(p: RefCounted, cx: float, cy: float, rx: float, ry: float, ramp: Array, rng: RandomNumberGenerator, n := 12) -> void:
		p.blob(cx, cy, rx, ry, [ramp[0], ramp[1], ramp[1], ramp[2]], 0.3)
		for k in n:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf())
			var x := cx + cos(a) * d * rx * 0.85
			var y := cy + sin(a) * d * ry * 0.85
			var r := minf(rx, ry) * rng.randf_range(0.2, 0.36) + 0.5
			var lit := clampf(0.55 - (y - cy) / ry * 0.5 - (x - cx) / rx * 0.2, 0.0, 1.0)
			var base := int(lit * 2.0)
			p.blob(x, y, r, r * 0.9, ramp.slice(base, base + 3), 0.2)
		for k in n:
			var x := cx + rng.randf_range(-0.8, 0.3) * rx
			var y := cy + rng.randf_range(-0.8, 0.1) * ry
			if p.solid(int(x), int(y)):
				p.px(x, y, ramp[ramp.size() - 1])


	static func _leaf_blade(p: RefCounted, x0: float, y0: float, x1: float, y1: float, light: Variant, dark: Variant) -> void:
		p.line(x0, y0, x1, y1, dark, 2)
		p.line(x0, y0 - 1, x1, y1 - 1, light)


	static func _stem(p: RefCounted, cx: float, by: float, top: float) -> void:
		p.line(cx, by, cx, top, "#2f9140")
		p.line(cx + 1, by, cx + 1, top + 1, "#1f6b33")


	static func _trunk(p: RefCounted, cx: float, by: float, top: float, hw: float, ramp: Array = WOOD) -> void:
		var y := by
		while y >= top:
			var t := (by - y) / maxf(by - top, 1.0)
			var half := hw * (1.0 - t * 0.35) + (1.5 if t < 0.1 else 0.0)
			var x := -half
			while x <= half:
				var n := x / maxf(half, 0.5)
				var idx := 3 if n < -0.5 else (2 if n < 0.1 else (1 if n < 0.6 else 0))
				if int(y + x * 3.0) % 7 == 0:
					idx = maxi(idx - 1, 0)
				p.px(cx + x, y, ramp[idx])
				x += 1.0
			y -= 1.0


	static func carrot(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		var n := 3 + int(g * 4)
		for k in n:
			var a := -PI / 2.0 + (k - (n - 1) * 0.5) * 0.42
			var len_ := (5.0 + 12.0 * g) * rng.randf_range(0.8, 1.0)
			var x := cx + cos(a) * len_
			var y := by + sin(a) * len_
			p.line(cx, by - 1, x, y, "#2f9140")
			p.px(x, y, "#86dc57")
			p.px(x - 1, y, "#4cb84a")
			p.px(x + 1, y + 1, "#4cb84a")
			p.px((cx + x) / 2 + 1, (by + y) / 2, "#4cb84a")


	static func strawberry(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		_foliage(p, cx, by - 7 * g - 2, 6 + 9 * g, 4 + 7 * g, L, rng, 10)
		for k in int(2 + g * 3):
			p.px(cx + rng.randf_range(-11, 11) * g, by - rng.randf_range(2, 15) * g, "#fff4e0")


	static func blueberry(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		_foliage(p, cx, by - 10 * g - 2, 6 + 10 * g, 5 + 10 * g, DL, rng, 14)


	static func tulip(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		_stem(p, cx, by, by - 20 * g - 1)
		_leaf_blade(p, cx, by, cx - 3 - 4 * g, by - 6 - 10 * g, "#86dc57", "#2f9140")
		_leaf_blade(p, cx + 1, by, cx + 4 + 3 * g, by - 5 - 8 * g, "#4cb84a", "#1f6b33")


	static func tomato(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		if g > 0.4:
			p.line(cx + 1, by, cx + 1, by - 34 * g, "#b08a50")
			p.line(cx + 2, by, cx + 2, by - 34 * g, "#7c5228")
		_foliage(p, cx, by - 12 * g - 2, 5 + 9 * g, 5 + 12 * g, L, rng, 14)


	static func daffodil(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		_stem(p, cx, by, by - 21 * g - 1)
		for s in [-1, 1]:
			_leaf_blade(p, cx, by, cx + s * (3 + 3 * g), by - 6 - 12 * g, "#86dc57", "#2f9140")
			_leaf_blade(p, cx, by, cx + s * (6 + 3 * g), by - 3 - 6 * g, "#4cb84a", "#1f6b33")


	static func corn(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		var top := by - 42 * g - 3
		p.line(cx, by, cx, top, "#4cb84a", 2)
		p.line(cx + 1, by, cx + 1, top, "#2f9140")
		var y := by - 4
		var side := 1
		while y > top + 3:
			var len_ := (6.0 + 8.0 * g) * rng.randf_range(0.8, 1.1)
			var mx := cx + side * len_ * 0.6
			_leaf_blade(p, cx, y, mx, y - 5, "#86dc57", "#2f9140")
			p.line(mx, y - 5, cx + side * len_, y - 1, "#4cb84a")
			y -= 6.0
			side = -side
		if g >= 1.0:
			p.line(cx, top, cx - 3, top - 2, "#e0c060")
			p.line(cx, top, cx + 3, top - 2, "#f0d880")
			p.px(cx, top - 2, "#fff0a0")


	static func _vines(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		for k in 4:
			var a: float = [PI + 0.25, -0.25, PI - 0.05, 0.05][k]
			var len_ := (6.0 + 13.0 * g) * rng.randf_range(0.8, 1.0)
			var x := cx + cos(a) * len_
			var y := by - 2 + sin(a) * len_ * 0.45
			p.line(cx, by - 1, x, y, "#2f9140")
			p.blob(x, y, 2.6 + g * 2, 2 + g * 1.5, L.slice(1, 5), 0.2)
			p.blob((cx + x) * 0.5, (by + y) * 0.5 - 1, 1.5 + g * 2, 1.2 + g * 1.5, L.slice(1, 5), 0.2)


	static func watermelon(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		_vines(p, cx, by, g, rng)


	static func pumpkin(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		_vines(p, cx, by, g, rng)


	static func apple(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		_trunk(p, cx, by, by - 34 * g, 1.5 + 3 * g)
		var cy := by - 16 - 22 * g
		_foliage(p, cx - 9 * g, cy + 6 * g, 6 + 10 * g, 5 + 8 * g, L, rng, 8)
		_foliage(p, cx + 10 * g, cy + 5 * g, 6 + 10 * g, 5 + 8 * g, L, rng, 8)
		_foliage(p, cx, cy - 4 * g, 7 + 14 * g, 6 + 11 * g, L, rng, 14)


	static func bamboo(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		var ramp := ["#2a7a2a", "#4aa83a", "#7cd058", "#b8ec86"]
		for off: int in [-7, 7, 0]:
			var top := by - (20 + 36 * g) * (1.0 if off == 0 else 0.8) + rng.randf_range(-2, 2)
			var y := by
			while y >= top:
				p.px(cx + off - 1, y, ramp[3])
				p.px(cx + off, y, ramp[2])
				p.px(cx + off + 1, y, ramp[1])
				p.px(cx + off + 2, y, ramp[0])
				if int(by - y) % 9 == 8:
					for i in range(-1, 3):
						p.px(cx + off + i, y, "#1f5a1f")
					if g > 0.3:
						var s: int = 1 if rng.randf() < 0.5 else -1
						_leaf_blade(p, cx + off + 1, y, cx + off + 1 + s * 7, y - 3, "#86dc57", "#2f9140")
				y -= 1.0
			_leaf_blade(p, cx + off, top, cx + off - 6, top - 3, "#86dc57", "#2f9140")
			_leaf_blade(p, cx + off, top, cx + off + 6, top - 4, "#4cb84a", "#1f6b33")


	static func coconut(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		var h := 12 + 36 * g
		var bend := 5.0 * g
		var y := 0.0
		while y <= h:
			var t := y / h
			var x := cx + sin(t * 1.5) * bend
			var hw := 3.0 - t * 1.2
			var i := -hw
			while i <= hw:
				var n := i / hw
				var idx := 3 if n < -0.4 else (2 if n < 0.2 else (1 if n < 0.7 else 0))
				if int(y) % 4 == 0:
					idx = maxi(idx - 1, 0)
				p.px(x + i, by - y, WOOD[idx])
				i += 1.0
			y += 1.0
		var tx := cx + sin(1.5) * bend
		var ty := by - h
		var fronds := 8
		var reach := 8.0 + 20.0 * g
		for k in fronds:
			var a := -PI + (k + 0.5) / fronds * TAU * 0.5 + (0.0 if k % 2 == 0 else 0.1)
			if k >= fronds / 2:
				a = (k - fronds / 2.0 + 0.5) / (fronds / 2.0) * -PI
			var dx := cos(a)
			var x0 := tx
			var y0 := ty
			var seg := 7
			for j in seg:
				var t := float(j + 1) / seg
				var droop := t * t * reach * 0.55
				var x1 := tx + dx * reach * t
				var y1 := ty + sin(a) * reach * 0.42 * t + droop
				p.line(x0, y0, x1, y1, L[3] if k % 2 == 0 else L[2], 2 if t < 0.7 else 1)
				if j > 0:
					p.px(x1, y1 + 2, L[1])
					p.px(x1 - dx, y1 - 1, L[4])
				x0 = x1
				y0 = y1


	static func cactus(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		var ramp := ["#1f6b3a", "#2f9150", "#4cb86a", "#86dc90"]
		var h := 12 + 30 * g
		p.blob(cx, by - h * 0.5, 3 + 3 * g, h * 0.52, ramp, 0.2)
		if g > 0.4:
			var ah := 20.0 * g
			p.line(cx - 4, by - ah, cx - 12, by - ah, ramp[1], 3)
			p.blob(cx - 12, by - ah - 5 * g, 2.5, 6 * g + 1, ramp, 0.2)
			p.line(cx + 4, by - ah - 5, cx + 12, by - ah - 5, ramp[1], 3)
			p.blob(cx + 12, by - ah - 5 - 6 * g, 2.5, 8 * g + 1, ramp, 0.2)
		var y := by - 3
		while y > by - h:
			p.px(cx - 4 * (0.5 + g * 0.5), y, "#d8f8c0")
			p.px(cx + 3 * (0.5 + g * 0.5), y - 2, "#c8e8b0")
			p.px(cx, y - 3, "#d8f8c0")
			y -= 6.0


	static func dragon(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		var h := 12 + 30 * g
		p.line(cx, by, cx, by - h, "#7c5228", 3)
		p.line(cx + 1, by, cx + 1, by - h, "#5a3618")
		var ramp := ["#1f6b3a", "#2f9150", "#4cb86a", "#86dc90"]
		for side in [-1, 1]:
			var x0 := cx
			var y0 := by - 3
			var y := 5.0
			while y < h:
				var x1: float = cx + side * sin(y * 0.28) * (4.0 + 10.0 * g)
				var y1 := by - 3 - y
				p.line(x0, y0, x1, y1, ramp[2], 3)
				p.line(x0, y0 - 1, x1, y1 - 1, ramp[3])
				x0 = x1
				y0 = y1
				y += 4.0
		_foliage(p, cx, by - h, 3 + 5 * g, 2 + 4 * g, ["#1f6b3a", "#2f9150", "#4cb86a", "#86dc90", "#c0f0b0"], rng, 5)


	static func mango(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		_trunk(p, cx, by, by - 34 * g, 1.5 + 3 * g)
		var cy := by - 16 - 22 * g
		_foliage(p, cx - 9 * g, cy + 4 * g, 7 + 10 * g, 5 + 8 * g, DL, rng, 10)
		_foliage(p, cx + 9 * g, cy + 4 * g, 7 + 10 * g, 5 + 8 * g, DL, rng, 10)
		_foliage(p, cx, cy - 5 * g, 8 + 13 * g, 6 + 10 * g, DL, rng, 16)


	static func mushroom(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		var moss := ["#2a5a34", "#3c7a44", "#5a9e5a", "#86c470"]
		p.blob(cx, by - 1, 5 + 9 * g, 2 + 2 * g, moss, 0.4)
		for k in int(2 + g * 4):
			p.px(cx + rng.randf_range(-12, 12) * g, by - rng.randf_range(0, 3), "#c8f0a0")


	static func grape(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		var hw := 5 + 13 * g
		var h := 12 + 26 * g
		for s in [-1, 1]:
			p.line(cx + s * hw, by, cx + s * hw, by - h, WOOD[2], 2)
			p.line(cx + s * hw + 1, by, cx + s * hw + 1, by - h, WOOD[0])
		p.line(cx - hw - 2, by - h, cx + hw + 3, by - h, WOOD[3], 2)
		p.line(cx - hw, by - h * 0.55, cx + hw, by - h * 0.55, WOOD[1])
		_foliage(p, cx, by - h * 0.82, hw + 1, 4 + 6 * g, DL, rng, 12)
		_foliage(p, cx - hw * 0.5, by - h * 0.42, 3 + 5 * g, 3 + 4 * g, L, rng, 5)
		_foliage(p, cx + hw * 0.55, by - h * 0.46, 3 + 5 * g, 3 + 4 * g, L, rng, 5)


	## The one magical plant: an indigo tree full of tiny stars.
	static func starfall(p: RefCounted, cx: float, by: float, g: float, rng: RandomNumberGenerator) -> void:
		_trunk(p, cx, by, by - 34 * g, 1.5 + 2.5 * g, ["#2a2650", "#44407c", "#6a66a8", "#9c98d0"])
		var cy := by - 16 - 22 * g
		_foliage(p, cx - 9 * g, cy + 6 * g, 6 + 10 * g, 5 + 8 * g, INDIGO, rng, 8)
		_foliage(p, cx + 10 * g, cy + 5 * g, 6 + 10 * g, 5 + 8 * g, INDIGO, rng, 8)
		_foliage(p, cx, cy - 4 * g, 7 + 14 * g, 6 + 11 * g, INDIGO, rng, 14)
		for k in int(14 * g):
			var x := cx + rng.randf_range(-20, 20) * g
			var yy := cy + rng.randf_range(-14, 12) * g
			if p.solid(int(x), int(yy)):
				p.px(x, yy, "#ffffff" if k % 3 else "#ffe060")
