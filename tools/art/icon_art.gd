extends RefCounted
## The application icon: one big strawberry, drawn pixel by pixel at icon size
## rather than enlarged from a game sprite.

const Painter := preload("res://tools/art/painter.gd")

const SIZE := 64
const OUT := "#3a0c1c"
const FLESH := ["#7c0f2a", "#a8152f", "#d11f38", "#ee3546", "#fb5a5c", "#ff8a80"]
const SHINE := "#ffd6cc"
const LEAF := ["#14562c", "#1f7a36", "#35a044", "#62c64e", "#a4e468"]
const SEED := "#ffe27a"
const SEED_LIT := "#fff6c4"
const SEED_PIT := "#8a1228"
const BODY_TOP := 15.0
const BODY_BOTTOM := 61.0
const BODY_RADIUS := 26.0
const WIDEST := 0.3
## Where the highlight sits, relative to the fruit's centre line.
const SHINE_AT := Vector2(-17.0, 27.0)
const GROUND := "#58ad4a"
const GROUND_LIT := "#65ba53"


## Half the fruit's width at height t (0 top, 1 tip): round shoulders, soft point.
static func _half_width(t: float) -> float:
	if t < WIDEST:
		var up := (WIDEST - t) / WIDEST
		return BODY_RADIUS * sqrt(maxf(1.0 - up * up, 0.0))
	var down := (t - WIDEST) / (1.0 - WIDEST)
	return BODY_RADIUS * pow(maxf(1.0 - down * down, 0.0), 0.8)


static func strawberry() -> RefCounted:
	var p: RefCounted = Painter.new(SIZE, SIZE)
	var c := SIZE * 0.5 - 0.5
	_flesh(p, c)
	_seeds(p, c)
	_shine(p, c)
	_leaves(p, c)
	p.outline(OUT)
	return p


static func _flesh(p: RefCounted, c: float) -> void:
	for y in range(int(BODY_TOP), int(BODY_BOTTOM) + 1):
		var t := (y - BODY_TOP) / (BODY_BOTTOM - BODY_TOP)
		var half := _half_width(t)
		for x in range(int(floorf(c - half)), int(ceilf(c + half)) + 1):
			var nx := (x - c) / maxf(half, 0.5)
			if absf(nx) > 1.0:
				continue
			var ny := t * 2.0 - 0.9
			var nz := sqrt(maxf(1.0 - nx * nx, 0.0))
			var light := (-0.5 * nx - 0.5 * ny + 0.7 * nz + 0.35) / 1.6
			var bayer: float = Painter.BAYER[y & 3][x & 3]
			var i := clampi(int((light + (bayer - 0.5) * 0.09) * FLESH.size()), 0, FLESH.size() - 1)
			p.px(x, y, FLESH[i])


## Staggered rows of seeds, each sitting in a small dark pit.
static func _seeds(p: RefCounted, c: float) -> void:
	var row := 0
	var y := BODY_TOP + 9.0
	while y < BODY_BOTTOM - 4.0:
		var half := _half_width((y - BODY_TOP) / (BODY_BOTTOM - BODY_TOP))
		var x := c - 21.0 + (4.0 if row % 2 == 1 else 0.0)
		while x <= c + 21.0:
			if absf(x - c) < half - 3.5 and Vector2(x - c, y).distance_to(SHINE_AT) > 7.0:
				_seed(p, x, y)
			x += 8.0
		y += 6.5
		row += 1


static func _seed(p: RefCounted, x: float, y: float) -> void:
	p.px(x - 1, y - 1, SEED_PIT)
	p.px(x + 1, y - 1, SEED_PIT)
	p.px(x - 1, y, SEED_PIT)
	p.px(x + 1, y, SEED_PIT)
	p.px(x - 1, y + 1, SEED_PIT)
	p.px(x, y + 2, SEED_PIT)
	p.px(x + 1, y + 1, SEED_PIT)
	p.px(x, y - 1, SEED_LIT)
	p.px(x, y, SEED)
	p.px(x, y + 1, SEED)


static func _shine(p: RefCounted, c: float) -> void:
	var x := c + SHINE_AT.x
	var y := SHINE_AT.y
	p.rect(x - 2, y - 1, 2, 5, SHINE)
	p.rect(x - 1, y - 3, 2, 3, SHINE)
	p.rect(x, y - 5, 3, 2, SHINE)
	p.rect(x - 1, y + 6, 2, 2, SHINE)


static func _leaves(p: RefCounted, c: float) -> void:
	var crown := Vector2(c, 12.0)
	# Far leaves first, so the front ones overlap them.
	for tip: Vector2 in [Vector2(-22, 7), Vector2(22, 7), Vector2(-13, 13), Vector2(13, 13), Vector2(0, 16)]:
		_leaf(p, crown, crown + tip)
	# Stem, curving up to the right.
	for y in range(1, 11):
		var x := c + (10 - y) * 0.35
		p.rect(x - 1, y, 3, 1, LEAF[1])
		p.px(x - 1, y, LEAF[3])
		p.px(x, y, LEAF[2])


## A pointed leaf from the crown to its tip: a shadow on the fruit, a dark rim,
## a lit upper side and a darker lower one.
static func _leaf(p: RefCounted, from: Vector2, to: Vector2) -> void:
	var axis := to - from
	var length := axis.length()
	var dir := axis / length
	var side := Vector2(-dir.y, dir.x)
	if side.y < 0.0:
		side = -side
	for y in range(int(minf(from.y, to.y)) - 5, int(maxf(from.y, to.y)) + 7):
		for x in range(int(minf(from.x, to.x)) - 5, int(maxf(from.x, to.x)) + 6):
			var at := Vector2(x, y) - from
			var u := at.dot(dir) / length
			if u < 0.0 or u > 1.0:
				continue
			var off := at.dot(side)
			var half := 4.2 * pow(sin(pow(u, 0.7) * PI), 0.8)
			if absf(off) > half + 1.0:
				continue
			if absf(off) > half:
				p.px(x, y, LEAF[0])
			elif absf(off) < 0.5:
				p.px(x, y, LEAF[1])
			elif off < -half * 0.55:
				p.px(x, y, LEAF[4])
			elif off < 0.0:
				p.px(x, y, LEAF[3])
			else:
				p.px(x, y, LEAF[2])


## Same picture scaled up by whole pixels.
static func scaled(p: RefCounted, factor: int) -> Image:
	var img: Image = p.img.duplicate()
	img.resize(SIZE * factor, SIZE * factor, Image.INTERPOLATE_NEAREST)
	return img


## Android adaptive layers are 432 px, and launchers may crop to the middle 264.
static func adaptive_foreground(p: RefCounted) -> Image:
	return _centred(scaled(p, 4))


static func adaptive_background() -> Image:
	var img := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	img.fill(Painter.col(GROUND))
	var lit := Painter.col(GROUND_LIT)
	# Scattered pixel-sized tufts, so the backdrop still reads as a garden lawn.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 180:
		var x := rng.randi_range(0, 53) * 8
		var y := rng.randi_range(0, 53) * 8
		img.fill_rect(Rect2i(x, y, 8, 4), lit)
		img.fill_rect(Rect2i(x + 8, y - 4, 4, 8), lit)
	return img


## One flat colour silhouette, as Android themes icons by tinting a single shape.
static func adaptive_monochrome(p: RefCounted) -> Image:
	var flat: Image = scaled(p, 4)
	for y in flat.get_height():
		for x in flat.get_width():
			if flat.get_pixel(x, y).a > 0.0:
				flat.set_pixel(x, y, Color.WHITE)
	return _centred(flat)


static func _centred(img: Image) -> Image:
	var out := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	var at := (432 - img.get_width()) / 2
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(at, at))
	return out
