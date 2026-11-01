extends RefCounted
## Small pixel-art drawing kit used by the texture generator.

const BAYER := [[0.0, 0.5, 0.125, 0.625], [0.75, 0.25, 0.875, 0.375], [0.1875, 0.6875, 0.0625, 0.5625], [0.9375, 0.4375, 0.8125, 0.3125]]
static var _colors := {}

var img: Image
var w: int
var h: int
var ax := 0
var ay := 0


func _init(width: int, height: int, anchor_x := 0, anchor_y := 0) -> void:
	w = width
	h = height
	ax = anchor_x
	ay = anchor_y
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


static func col(c: Variant) -> Color:
	if c is Color:
		return c
	if not _colors.has(c):
		_colors[c] = Color(c)
	return _colors[c]


func px(x: float, y: float, c: Variant) -> void:
	var xi := int(floorf(x))
	var yi := int(floorf(y))
	if xi >= 0 and yi >= 0 and xi < w and yi < h:
		img.set_pixel(xi, yi, col(c))


func solid(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and img.get_pixel(x, y).a > 0.0


func rect(x: float, y: float, rw: float, rh: float, c: Variant) -> void:
	for j in range(int(floorf(y)), int(floorf(y + rh))):
		for i in range(int(floorf(x)), int(floorf(x + rw))):
			px(i, j, c)


func line(x0: float, y0: float, x1: float, y1: float, c: Variant, thick := 1) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0)))
	for i in steps + 1:
		var t := float(i) / maxf(steps, 1)
		var x := floorf(lerpf(x0, x1, t) + 0.5)
		var y := floorf(lerpf(y0, y1, t) + 0.5)
		if thick <= 1:
			px(x, y, c)
		else:
			rect(x - thick / 2, y - thick / 2, thick, thick, c)


func disk(cx: float, cy: float, rx: float, ry: float, c: Variant) -> void:
	for j in range(int(floorf(cy - ry)), int(ceilf(cy + ry)) + 1):
		for i in range(int(floorf(cx - rx)), int(ceilf(cx + rx)) + 1):
			var nx := (i + 0.5 - cx - 0.5) / maxf(rx, 0.5)
			var ny := (j + 0.5 - cy - 0.5) / maxf(ry, 0.5)
			if nx * nx + ny * ny <= 1.0:
				px(i, j, c)


## Ball shading lit from the top-left, quantized to the ramp with light dithering.
## ramp goes dark to light.
func blob(cx: float, cy: float, rx: float, ry: float, ramp: Array, dither := 0.5) -> void:
	for j in range(int(floorf(cy - ry)), int(ceilf(cy + ry)) + 1):
		for i in range(int(floorf(cx - rx)), int(ceilf(cx + rx)) + 1):
			var nx := (i - cx) / maxf(rx, 0.5)
			var ny := (j - cy) / maxf(ry, 0.5)
			var r2 := nx * nx + ny * ny
			if r2 > 1.0:
				continue
			var nz := sqrt(1.0 - r2)
			var l := (-0.5 * nx - 0.62 * ny + 0.6 * nz + 0.55) / 1.55
			var d: float = (BAYER[j & 3][i & 3] - 0.5) * dither / ramp.size()
			var idx := clampi(int((l + d) * ramp.size()), 0, ramp.size() - 1)
			px(i, j, ramp[idx])


## Dark contour around everything drawn so far, the hallmark of the Terraria look.
func outline(c: Variant, diagonal := false) -> void:
	var out: Array[Vector2i] = []
	for y in h:
		for x in w:
			if solid(x, y):
				continue
			var hit := solid(x - 1, y) or solid(x + 1, y) or solid(x, y - 1) or solid(x, y + 1)
			if not hit and diagonal:
				hit = solid(x - 1, y - 1) or solid(x + 1, y - 1) or solid(x - 1, y + 1) or solid(x + 1, y + 1)
			if hit:
				out.append(Vector2i(x, y))
	for v in out:
		px(v.x, v.y, c)


func stamp(other: RefCounted, x: int, y: int) -> void:
	var src: Image = other.img
	for j in src.get_height():
		for i in src.get_width():
			var c := src.get_pixel(i, j)
			if c.a > 0.0:
				px(x + i, y + j, c)


## Soft ground shadow; a translucent ellipse painted under everything else.
func shadow(cx: float, cy: float, rx: float, ry: float, alpha := 0.28) -> void:
	disk(cx, cy, rx, ry, Color(0.05, 0.1, 0.05, alpha))


static func shade(c: Variant, amount: float) -> Color:
	var base := col(c)
	return base.lightened(amount) if amount >= 0.0 else base.darkened(-amount)
