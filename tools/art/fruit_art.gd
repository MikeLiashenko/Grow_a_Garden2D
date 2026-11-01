extends RefCounted
## Fruit textures. Each painter works at any size so the same fruit can appear
## as a 16px icon, a small berry on a bush, or a growing crop.

const Painter := preload("res://tools/art/painter.gd")

const OUT := "#2a1a1a"


static func make(id: String, s: int) -> RefCounted:
	var p: RefCounted = Painter.new(s + 2, s + 2, (s + 2) / 2, (s + 2) / 2)
	var c := (s + 1) * 0.5
	var f := Callable(Fruit, id)
	f.call(p, s, c)
	p.outline(OUT)
	return p


class Fruit:
	static func _leaf_top(p: RefCounted, c: float, y: float, s: int) -> void:
		var len_ := maxf(1.0, s * 0.22)
		p.line(c, y, c - len_, y - 1, "#2f9140")
		p.line(c, y, c + len_, y - 1, "#4cb84a")
		p.px(c, y - 1, "#86dc57")


	static func carrot(p: RefCounted, s: int, c: float) -> void:
		var ramp := ["#b84a10", "#e8741a", "#ff9a2e", "#ffc060"]
		var top := 1.0 + s * 0.26
		var bottom := float(s)
		var y := top
		while y <= bottom:
			var t := (y - top) / maxf(bottom - top, 1.0)
			var half := (1.0 - t * t) * s * 0.3 * (1.0 - t * 0.35) + 0.4
			var x := -half
			while x <= half:
				var n := x / maxf(half, 0.5)
				var i := 3 if n < -0.45 else (2 if n < 0.15 else (1 if n < 0.65 else 0))
				p.px(c + x, y, ramp[i])
				x += 1.0
			if s >= 9 and int(y) % 3 == 0:
				p.px(c + half * 0.4, y, ramp[0])
				p.px(c + half * 0.1, y, ramp[0])
			y += 1.0
		for i in int(maxf(1.0, s * 0.26)):
			var yy := top - 1 - i
			p.px(c, yy, "#4cb84a")
			p.px(c - 1 - i * 0.6, yy, "#2f9140")
			p.px(c + 1 + i * 0.6, yy, "#86dc57")


	static func strawberry(p: RefCounted, s: int, c: float) -> void:
		var ramp := ["#8f1228", "#c91f37", "#ec3a48", "#ff6f6b"]
		var ctop := 1.0 + s * 0.2
		p.blob(c, ctop + s * 0.2, s * 0.42, s * 0.3, ramp)
		p.blob(c, ctop + s * 0.42, s * 0.28, s * 0.3, ramp)
		if s >= 7:
			for j in range(0, s, 2):
				for i in range(0, s, 3):
					var x := c - s * 0.3 + i + (j / 2 % 2)
					var y := ctop + s * 0.1 + j
					if p.solid(int(x), int(y)):
						p.px(x, y, "#ffe08a")
		_leaf_top(p, c, ctop, s)
		p.line(c - s * 0.3, ctop, c + s * 0.3, ctop, "#4cb84a")


	static func blueberry(p: RefCounted, s: int, c: float) -> void:
		p.blob(c, c, s * 0.46, s * 0.46, ["#1c2a6b", "#2c43a0", "#4466d0", "#7c9cf0"])
		var r := maxf(1.0, s * 0.14)
		p.rect(c - r + 1, c - r - s * 0.08, r * 1.4, r * 1.2, "#16204f")
		if s >= 8:
			p.px(c - s * 0.2, c - s * 0.26, "#d0e0ff")


	static func tulip(p: RefCounted, s: int, c: float) -> void:
		var ramp := ["#b02a10", "#e8501a", "#ff7a2e", "#ffb060"]
		p.blob(c, c + s * 0.1, s * 0.4, s * 0.38, ramp)
		var tips := [-0.3, 0.0, 0.3]
		for k in tips.size():
			var x: float = c + tips[k] * s
			var hgt := s * (0.4 if k == 1 else 0.32)
			p.line(x, c + s * 0.05, x, c - hgt, ramp[2 if k == 0 else (3 if k == 1 else 1)], 2 if s >= 9 else 1)
		if s >= 9:
			p.line(c - s * 0.15, c - s * 0.1, c - s * 0.15, c + s * 0.32, ramp[0])
			p.line(c + s * 0.15, c - s * 0.1, c + s * 0.15, c + s * 0.32, ramp[0])


	static func tomato(p: RefCounted, s: int, c: float) -> void:
		p.blob(c, c + s * 0.05, s * 0.47, s * 0.42, ["#8f1a18", "#cf2c20", "#f04a30", "#ff8a6a"])
		var y := c - s * 0.32
		p.line(c - s * 0.26, y + 1, c + s * 0.26, y + 1, "#2f9140")
		p.line(c - s * 0.12, y, c + s * 0.12, y, "#4cb84a")
		p.px(c, y - 1, "#1f6b33")


	static func daffodil(p: RefCounted, s: int, c: float) -> void:
		var ramp := ["#d09a10", "#f0c020", "#ffe040", "#fff4a0"]
		for k in 6:
			var a := k * TAU / 6.0 - PI / 2.0
			p.blob(c + cos(a) * s * 0.28, c + sin(a) * s * 0.28, s * 0.2, s * 0.2, ramp, 0.2)
		p.blob(c, c, s * 0.2, s * 0.2, ["#b84a10", "#e8741a", "#ff9a2e"], 0.2)
		if s >= 10:
			p.px(c, c, "#7a2a08")


	static func corn(p: RefCounted, s: int, c: float) -> void:
		var hw := maxf(1.0, s * 0.26)
		var ramp := ["#d09a10", "#f0c020", "#ffe040", "#fff4a0"]
		p.blob(c, c - s * 0.05, hw, s * 0.42, ramp, 0.2)
		if s >= 8:
			for y in range(int(c - s * 0.4), int(c + s * 0.35), 2):
				for x in range(int(c - hw) + (y & 1), int(c + hw) + 1, 2):
					if p.solid(x, y):
						p.px(x, y, "#c98a10")
		p.line(c - hw - 1, c + s * 0.45, c - hw * 0.6, c - s * 0.05, "#2f9140", 1)
		p.line(c + hw + 1, c + s * 0.45, c + hw * 0.6, c - s * 0.05, "#1f6b33", 1)
		p.line(c - hw, c + s * 0.47, c + hw, c + s * 0.47, "#4cb84a")
		p.line(c - hw * 0.5, c + s * 0.35, c - hw * 0.5, c + s * 0.1, "#4cb84a")


	static func watermelon(p: RefCounted, s: int, c: float) -> void:
		var rx := s * 0.48
		var ry := s * 0.38
		var ramp := ["#14632b", "#1f8a3a", "#34ad4a", "#6cd66a"]
		p.blob(c, c, rx, ry, ramp, 0.3)
		var stripes := 5
		for k in stripes:
			var u := (k + 0.5) / stripes * 2.0 - 1.0
			var y := c - ry
			while y <= c + ry:
				var v := (y - c) / ry
				var x := c + u * rx * sqrt(maxf(0.0, 1.0 - v * v))
				x += sin(y * 1.3 + k) * 0.6
				if p.solid(int(x), int(y)):
					p.px(x, y, "#0d4a20")
				y += 1.0
		p.px(c - rx * 0.45, c - ry * 0.55, "#b6f09a")
		p.px(c - rx * 0.35, c - ry * 0.6, "#b6f09a")


	static func pumpkin(p: RefCounted, s: int, c: float) -> void:
		var ramp := ["#a84a08", "#dd7410", "#ff9a20", "#ffc060"]
		var ry := s * 0.38
		var cy := c + s * 0.05
		p.blob(c - s * 0.3, cy, s * 0.19, ry * 0.9, ramp, 0.3)
		p.blob(c + s * 0.3, cy, s * 0.19, ry * 0.9, ramp, 0.3)
		p.blob(c - s * 0.15, cy, s * 0.2, ry, ramp, 0.3)
		p.blob(c + s * 0.15, cy, s * 0.2, ry, ramp, 0.3)
		p.blob(c, cy, s * 0.17, ry * 1.02, ramp, 0.3)
		if s >= 8:
			for off in [-0.24, -0.08, 0.08, 0.24]:
				var x: float = c + s * off
				p.line(x, cy - ry * 0.7, x, cy + ry * 0.7, ramp[0])
		var st := maxf(1.0, s * 0.1)
		p.rect(c - st / 2.0, cy - ry - st * 1.4, st, st * 1.8, "#3d7a22")
		p.px(c + st * 0.5, cy - ry - st * 1.4, "#6ab83a")


	static func apple(p: RefCounted, s: int, c: float) -> void:
		var ramp := ["#8f1228", "#cc2233", "#ee4040", "#ff8a7a"]
		p.blob(c - s * 0.12, c + s * 0.08, s * 0.33, s * 0.37, ramp)
		p.blob(c + s * 0.12, c + s * 0.08, s * 0.33, s * 0.37, ramp)
		p.px(c, c - s * 0.27, ramp[0])
		p.line(c, c - s * 0.25, c + 1, c - s * 0.46, "#5a3a1a")
		if s >= 7:
			p.line(c + 1, c - s * 0.34, c + s * 0.32, c - s * 0.42, "#4cb84a")
			p.px(c - s * 0.25, c - s * 0.1, "#ffd6c8")


	static func bamboo(p: RefCounted, s: int, c: float) -> void:
		var ramp := ["#2a7a2a", "#4aa83a", "#7cd058", "#b8ec86"]
		var hw := maxf(1.0, s * 0.2)
		var y := 1.0
		while y <= s:
			var x := -hw
			while x <= hw:
				var n := x / hw
				p.px(c + x, y, ramp[3 if n < -0.5 else (2 if n < 0.1 else (1 if n < 0.6 else 0))])
				x += 1.0
			y += 1.0
		for j in [s * 0.33, s * 0.66]:
			p.line(c - hw, j, c + hw, j, "#1f5a1f")
		if s >= 9:
			p.line(c + hw, s * 0.3, c + hw + s * 0.3, s * 0.12, "#4cb84a")
			p.line(c - hw, s * 0.62, c - hw - s * 0.3, s * 0.46, "#7cd058")


	static func coconut(p: RefCounted, s: int, c: float) -> void:
		p.blob(c, c, s * 0.46, s * 0.46, ["#3a2210", "#5a3618", "#7c5228", "#a07840"])
		if s >= 7:
			for k in int(s * 1.4):
				var x := c + sin(k * 12.9) * s * 0.38
				var y := c + cos(k * 7.3) * s * 0.38
				if p.solid(int(x), int(y)):
					p.px(x, y, "#2c180a")
			p.px(c - s * 0.1, c - s * 0.12, "#1a0e06")
			p.px(c + s * 0.12, c - s * 0.12, "#1a0e06")
			p.px(c, c + s * 0.06, "#1a0e06")


	static func cactus(p: RefCounted, s: int, c: float) -> void:
		var ramp := ["#a81a5a", "#d8307a", "#f85a9a", "#ff9ac0"]
		p.blob(c, c + s * 0.05, s * 0.38, s * 0.44, ramp)
		var y := c - s * 0.4
		p.line(c - s * 0.2, y, c + s * 0.2, y, "#4cb84a")
		if s >= 7:
			for k in 5:
				p.px(c + sin(k * 2.4) * s * 0.26, c + cos(k * 2.4) * s * 0.28 + s * 0.05, "#ffe08a")


	static func dragon(p: RefCounted, s: int, c: float) -> void:
		var ramp := ["#a01a60", "#d8308a", "#f860a8", "#ffa0cc"]
		p.blob(c, c, s * 0.4, s * 0.45, ramp)
		var scales := 3 if s < 9 else 5
		for k in scales:
			var a := k * TAU / scales + 0.4
			var x := c + cos(a) * s * 0.34
			var y := c + sin(a) * s * 0.38
			p.line(x, y, x + cos(a) * s * 0.18, y + sin(a) * s * 0.2 - 1, "#6ad04a")
		p.line(c, c - s * 0.42, c, c - s * 0.5, "#4cb84a")
		p.line(c - 1, c - s * 0.4, c - s * 0.2, c - s * 0.5, "#86dc57")
		p.line(c + 1, c - s * 0.4, c + s * 0.2, c - s * 0.5, "#2f9140")


	static func mango(p: RefCounted, s: int, c: float) -> void:
		p.blob(c, c + s * 0.03, s * 0.36, s * 0.46, ["#d05010", "#f08018", "#ffb020", "#ffd860"])
		for j in int(s * 0.35):
			for i in int(s * 0.3):
				var x := c + s * 0.05 + i
				var y := c - s * 0.42 + j
				if p.solid(int(x), int(y)) and (i + j) % 2 == 0 and i + j < s * 0.42:
					p.px(x, y, "#e8402a")
		p.px(c, c - s * 0.47, "#3d7a22")
		if s >= 8:
			p.line(c, c - s * 0.42, c - s * 0.25, c - s * 0.5, "#4cb84a")


	static func grape(p: RefCounted, s: int, c: float) -> void:
		var ramp := ["#2c1450", "#4c2484", "#7040b4", "#a880e0"]
		var r := maxf(1.2, s * 0.16)
		var rows := [3, 3, 2, 1]
		var y0 := c - s * 0.2
		for row in rows.size():
			var n: int = rows[row]
			for k in n:
				var x := c + (k - (n - 1) * 0.5) * r * 1.8
				p.blob(x, y0 + row * r * 1.55, r, r, ramp, 0.0)
		p.line(c, y0 - r - s * 0.2, c, y0 - r, "#5a3a1a")
		p.line(c, y0 - r - s * 0.08, c + s * 0.3, y0 - r - s * 0.12, "#4cb84a")


	static func mushroom(p: RefCounted, s: int, c: float) -> void:
		var hw := s * 0.18
		var stem := ["#c8b89a", "#e8dcc0", "#fff8e8"]
		var y := c - s * 0.05
		while y <= s:
			var x := -hw
			while x <= hw:
				var n := x / hw
				p.px(c + x, y, stem[2 if n < -0.3 else (1 if n < 0.4 else 0)])
				x += 1.0
			y += 1.0
		var ramp := ["#8f1228", "#cc2233", "#ee4040", "#ff7a6a"]
		var cy := c - s * 0.1
		p.blob(c, cy, s * 0.48, s * 0.36, ramp)
		var img: Image = p.img
		for j in range(int(cy + s * 0.14), int(cy + s * 0.14 + s * 0.25) + 1):
			for i in range(int(c - s * 0.5), int(c + s * 0.5) + 1):
				if i >= 0 and j >= 0 and i < p.w and j < p.h and absf(i - c) > hw:
					img.set_pixel(i, j, Color(0, 0, 0, 0))
		p.line(c - s * 0.46, cy + s * 0.14, c + s * 0.46, cy + s * 0.14, "#6a0f20")
		var dots: Array = [[-0.26, -0.1, 0.09], [0.08, -0.2, 0.07], [0.28, -0.02, 0.08], [-0.05, 0.03, 0.06]]
		for d in dots:
			p.disk(c + d[0] * s, cy + d[1] * s, maxf(0.6, d[2] * s), maxf(0.6, d[2] * s), "#fff4e0")


	## The one magical crop: a fallen star, gold and white, in a deep indigo orb.
	static func starfall(p: RefCounted, s: int, c: float) -> void:
		p.blob(c, c, s * 0.47, s * 0.47, ["#14104a", "#2a2080", "#4a3ab8", "#7a70e0"], 0.2)
		var r := s * 0.4
		p.line(c - r, c, c + r, c, "#ffe060")
		p.line(c, c - r, c, c + r, "#ffe060")
		var core := maxf(0.8, s * 0.13)
		p.disk(c, c, core, core, "#fff8c0")
		if s >= 9:
			p.line(c - r * 0.45, c - r * 0.45, c + r * 0.45, c + r * 0.45, "#fff0a0")
			p.line(c - r * 0.45, c + r * 0.45, c + r * 0.45, c - r * 0.45, "#fff0a0")
