extends RefCounted
## Inventory icons, the player and shopkeepers, and placeable gear.

const Painter := preload("res://tools/art/painter.gd")
const FruitArt := preload("res://tools/art/fruit_art.gd")

const OUT := "#1c1420"
const METAL := ["#4a4e5e", "#7a8094", "#b0b6c8", "#e4e8f0"]
const BRASS := ["#7a4a14", "#b87e20", "#e8b83a", "#ffe880"]
const WOOD := ["#3a2210", "#5a3618", "#7c5228", "#9a6e3c"]


static func seed_packet(fruit_id: String, band: String) -> RefCounted:
	var p: RefCounted = Painter.new(16, 16, 8, 8)
	p.rect(2, 1, 12, 14, "#f0e4c4")
	p.rect(2, 1, 1, 14, "#fff6dc")
	p.rect(13, 1, 1, 14, "#c8b48c")
	p.rect(2, 14, 12, 1, "#c8b48c")
	p.rect(2, 1, 12, 3, band)
	p.rect(2, 1, 12, 1, Painter.shade(band, 0.3))
	p.rect(2, 3, 12, 1, Painter.shade(band, -0.3))
	var f: RefCounted = FruitArt.make(fruit_id, 8)
	p.stamp(f, 3, 5)
	p.outline(OUT)
	return p


static func gear_icon(id: String) -> RefCounted:
	var p: RefCounted = Painter.new(16, 16, 8, 8)
	Callable(Icons, id).call(p)
	p.outline(OUT)
	return p


## World sprite for placeable gear, anchored at its base.
static func gadget(id: String) -> RefCounted:
	var p: RefCounted = Painter.new(18, 22, 9, 19)
	p.shadow(9, 19, 6, 2.5)
	if id == "lucky_gnome":
		var body: RefCounted = Painter.new(18, 22)
		Icons._gnome_body(body, 3, 4)
		body.outline(OUT)
		p.stamp(body, 0, 1)
	else:
		var ramp: Array = METAL if id == "basic_sprinkler" else (BRASS if id == "adv_sprinkler" else ["#7a2a9a", "#b048d8", "#e080ff", "#ffd0ff"])
		var body: RefCounted = Painter.new(18, 22)
		body.rect(8, 8, 2, 11, ramp[1])
		body.px(8, 10, ramp[3])
		body.blob(9, 18, 4, 2, ramp, 0.3)
		body.blob(9, 7, 4, 3, ramp, 0.3)
		body.rect(4, 6, 2, 1, ramp[2])
		body.rect(12, 6, 2, 1, ramp[1])
		body.rect(8, 3, 2, 2, ramp[3])
		body.outline(OUT)
		p.stamp(body, 0, 0)
	return p


class Icons:
	static func shovel(p: RefCounted) -> void:
		p.line(11, 2, 6, 9, WOOD[3], 2)
		p.rect(10, 1, 4, 2, WOOD[2])
		p.blob(4.5, 11, 3, 3.6, METAL, 0.2)


	static func watering_can(p: RefCounted) -> void:
		var ramp := ["#1f5a7a", "#2c86b0", "#50b0e0", "#a0e0ff"]
		p.rect(5, 6, 8, 8, ramp[2])
		p.rect(5, 6, 2, 8, ramp[3])
		p.rect(11, 6, 2, 8, ramp[1])
		p.rect(5, 13, 8, 1, ramp[0])
		p.line(5, 11, 1, 6, ramp[1], 2)
		p.rect(0, 4, 3, 2, ramp[3])
		p.line(6, 5, 8, 2, ramp[0])
		p.line(8, 2, 11, 2, ramp[0])
		p.line(11, 2, 13, 5, ramp[0])
		p.rect(13, 7, 2, 1, ramp[0])
		p.rect(14, 7, 1, 5, ramp[0])
		p.rect(13, 11, 2, 1, ramp[0])


	static func trowel(p: RefCounted) -> void:
		p.rect(11, 1, 3, 4, "#c04030")
		p.rect(11, 1, 1, 4, "#f07050")
		p.line(11, 5, 8, 8, METAL[1], 2)
		for i in 6:
			p.line(8 - i, 7 + i, 8, 7 + i, METAL[2])
			p.px(8 - i, 7 + i, METAL[3])
		p.rect(2, 13, 7, 1, METAL[0])


	static func golden_sickle(p: RefCounted) -> void:
		for i in 15:
			var a := -0.5 + i * 0.27
			p.px(7 + cos(a) * 6.5, 7 + sin(a) * 6.5, BRASS[2])
			p.px(7 + cos(a) * 5.5, 7 + sin(a) * 5.5, BRASS[3] if i < 7 else BRASS[1])
		p.line(5, 14, 1, 10, WOOD[3], 2)
		p.px(2, 2, "#ffffff")


	static func _sprinkler(p: RefCounted, ramp: Array) -> void:
		p.blob(8, 13, 5, 2, ramp, 0.2)
		p.rect(7, 5, 2, 8, ramp[2])
		p.px(7, 7, ramp[3])
		p.blob(8, 5, 4, 2.5, ramp, 0.2)
		var w := "#6ec6ff"
		p.px(2, 2, w)
		p.px(4, 1, w)
		p.px(1, 5, w)
		p.px(14, 2, w)
		p.px(12, 1, w)
		p.px(15, 5, w)


	static func basic_sprinkler(p: RefCounted) -> void:
		_sprinkler(p, METAL)


	static func adv_sprinkler(p: RefCounted) -> void:
		_sprinkler(p, BRASS)


	static func godly_sprinkler(p: RefCounted) -> void:
		_sprinkler(p, ["#7a2a9a", "#b048d8", "#e080ff", "#ffd0ff"])


	static func _gnome_body(p: RefCounted, x: int, y: int) -> void:
		# Red hat, white beard, blue coat: stands about 15px tall.
		for i in 7:
			p.line(x + 6 - i * 0.7, y + i, x + 6 + i * 0.7, y + i, "#e03a30" if i % 3 != 2 else "#c02a24")
		p.px(x + 5, y + 2, "#ff8070")
		p.rect(x + 3, y + 7, 7, 2, "#f0c8a0")
		p.px(x + 5, y + 7, "#2a1a1a")
		p.px(x + 8, y + 7, "#2a1a1a")
		p.rect(x + 3, y + 9, 7, 3, "#f8f8f0")
		p.rect(x + 2, y + 12, 9, 2, "#3a60c0")
		p.rect(x + 4, y + 14, 2, 1, "#5a3618")
		p.rect(x + 7, y + 14, 2, 1, "#5a3618")


	static func lucky_gnome(p: RefCounted) -> void:
		_gnome_body(p, 1, 0)


	static func _totem(p: RefCounted, a: Variant, b: Variant) -> void:
		p.rect(5, 3, 6, 11, WOOD[2])
		p.rect(5, 3, 2, 11, WOOD[3])
		p.rect(10, 3, 1, 11, WOOD[0])
		p.rect(5, 7, 6, 1, WOOD[0])
		p.rect(6, 4, 1, 2, b)
		p.rect(9, 4, 1, 2, b)
		p.rect(3, 13, 10, 2, WOOD[1])
		p.blob(8, 2, 4, 2, [a, a, b], 0.0)


	static func rain_totem(p: RefCounted) -> void:
		_totem(p, "#3a80d0", "#a0e0ff")
		p.px(2, 6, "#6ec6ff")
		p.px(13, 8, "#6ec6ff")
		p.px(3, 10, "#6ec6ff")


	static func storm_totem(p: RefCounted) -> void:
		_totem(p, "#4a4e70", "#fff36b")
		p.line(13, 4, 12, 7, "#fff36b")
		p.line(12, 7, 14, 7, "#fff36b")
		p.line(14, 7, 12, 11, "#fff36b")


	static func backpack(p: RefCounted) -> void:
		var r := ["#5a3010", "#8a4f1c", "#b87430", "#e0a050"]
		p.blob(8, 8, 5.5, 6.5, r, 0.2)
		p.rect(4, 9, 8, 5, r[1])
		p.rect(4, 9, 8, 1, r[3])
		p.rect(7, 9, 2, 3, BRASS[2])
		p.line(5, 1, 11, 1, r[0])


static func coin() -> RefCounted:
	var p: RefCounted = Painter.new(12, 12, 6, 6)
	p.blob(5.5, 5.5, 5, 5, BRASS, 0.2)
	p.rect(5, 3, 1, 6, BRASS[0])
	p.rect(4, 4, 3, 1, BRASS[0])
	p.rect(4, 7, 3, 1, BRASS[0])
	p.outline("#3a2008")
	return p


## A note with a tick on it.
static func quest_icon() -> RefCounted:
	var p: RefCounted = Painter.new(12, 12, 6, 6)
	p.rect(2, 1, 8, 10, "#f4e8c0")
	p.rect(2, 10, 8, 1, "#c8b078")
	p.rect(3, 2, 6, 1, "#a08a58")
	p.rect(3, 8, 1, 1, "#2f9140")
	p.rect(4, 9, 1, 1, "#2f9140")
	p.rect(5, 8, 1, 1, "#2f9140")
	p.rect(6, 7, 1, 1, "#2f9140")
	p.rect(7, 6, 1, 1, "#2f9140")
	p.rect(8, 5, 1, 1, "#2f9140")
	p.outline("#3a2008")
	return p


## A small glass house.
static func greenhouse_icon() -> RefCounted:
	var p: RefCounted = Painter.new(12, 12, 6, 6)
	p.rect(1, 5, 10, 6, "#a8e0e8")
	p.rect(3, 3, 6, 2, "#c8f0f4")
	p.rect(5, 2, 2, 1, "#f4f2e8")
	p.rect(1, 5, 10, 1, "#f4f2e8")
	p.rect(1, 5, 1, 6, "#f4f2e8")
	p.rect(10, 5, 1, 6, "#f4f2e8")
	p.rect(5, 5, 2, 6, "#f4f2e8")
	p.rect(3, 8, 1, 3, "#2f9140")
	p.rect(8, 8, 1, 3, "#2f9140")
	p.outline("#3a2008")
	return p


## dir: 0 down, 1 up, 2 side. frame: 0..3 walk cycle.
static func person(dir: int, frame: int, pal: Dictionary) -> RefCounted:
	var p: RefCounted = Painter.new(18, 26, 9, 24)
	var body: RefCounted = Painter.new(18, 26)
	var step: int = [0, 1, 0, -1][frame]
	var bob := 1 if frame % 2 == 1 else 0
	var y0 := bob * -1 + 1
	# Legs and boots.
	if dir == 2:
		body.rect(7 + step, 19 + y0, 3, 3, pal["pants"])
		body.rect(7 + step, 22, 4, 2, pal["boots"])
		body.rect(8 - step, 19 + y0, 3, 3, Painter.shade(pal["pants"], -0.2))
		body.rect(8 - step, 22, 4, 2, Painter.shade(pal["boots"], -0.2))
	else:
		var left_h := 3 - maxi(step, 0)
		var right_h := 3 - maxi(-step, 0)
		body.rect(5, 19 + y0, 3, left_h, pal["pants"])
		body.rect(10, 19 + y0, 3, right_h, pal["pants"])
		body.rect(5, 19 + y0 + left_h, 3, 2, pal["boots"])
		body.rect(10, 19 + y0 + right_h, 3, 2, pal["boots"])
	# Torso.
	var ty := 12 + y0
	if dir == 2:
		body.rect(6, ty, 6, 7, pal["shirt"])
		body.rect(6, ty, 1, 7, Painter.shade(pal["shirt"], 0.2))
		body.rect(6, ty + 3, 6, 4, pal["pants"])
		var arm := 8 + step
		body.rect(arm, ty + 1, 2, 5, Painter.shade(pal["shirt"], -0.15))
		body.rect(arm, ty + 6, 2, 1, pal["skin"])
	else:
		body.rect(5, ty, 8, 7, pal["shirt"])
		body.rect(5, ty, 2, 7, Painter.shade(pal["shirt"], 0.2))
		body.rect(11, ty, 2, 7, Painter.shade(pal["shirt"], -0.15))
		body.rect(6, ty + 3, 6, 4, pal["pants"])
		body.rect(6, ty, 1, 3, pal["pants"])
		body.rect(11, ty, 1, 3, pal["pants"])
		if dir == 0:
			body.px(8, ty + 4, Painter.shade(pal["pants"], 0.3))
			body.px(9, ty + 4, Painter.shade(pal["pants"], 0.3))
		body.rect(3, ty + step, 2, 5, pal["shirt"])
		body.rect(3, ty + 5 + step, 2, 1, pal["skin"])
		body.rect(13, ty - step, 2, 5, Painter.shade(pal["shirt"], -0.15))
		body.rect(13, ty + 5 - step, 2, 1, pal["skin"])
	# Head.
	var hy := 5 + y0
	body.rect(5, hy, 8, 7, pal["skin"])
	body.rect(5, hy, 1, 7, Painter.shade(pal["skin"], 0.15))
	body.rect(12, hy, 1, 7, Painter.shade(pal["skin"], -0.15))
	if dir == 0:
		body.rect(6, hy + 3, 2, 2, "#ffffff")
		body.rect(10, hy + 3, 2, 2, "#ffffff")
		body.px(7, hy + 3, "#2a1a3a")
		body.px(7, hy + 4, "#2a1a3a")
		body.px(10, hy + 3, "#2a1a3a")
		body.px(10, hy + 4, "#2a1a3a")
		body.px(8, hy + 6, Painter.shade(pal["skin"], -0.3))
		body.px(9, hy + 6, Painter.shade(pal["skin"], -0.3))
	elif dir == 2:
		body.rect(10, hy + 3, 2, 2, "#ffffff")
		body.px(11, hy + 3, "#2a1a3a")
		body.px(11, hy + 4, "#2a1a3a")
		body.rect(5, hy + 1, 3, 4, pal["hair"])
	else:
		body.rect(5, hy + 1, 8, 6, pal["hair"])
		body.rect(5, hy + 1, 2, 6, Painter.shade(pal["hair"], 0.15))
	# Wide-brimmed hat.
	var hat: Color = Painter.col(pal["hat"])
	body.rect(2, hy + 1, 14, 2, hat)
	body.rect(2, hy + 2, 14, 1, Painter.shade(hat, -0.2))
	body.rect(2, hy + 1, 4, 1, Painter.shade(hat, 0.2))
	body.rect(5, hy - 3, 8, 4, hat)
	body.rect(5, hy - 3, 3, 4, Painter.shade(hat, 0.2))
	body.rect(11, hy - 3, 2, 4, Painter.shade(hat, -0.15))
	body.rect(5, hy, 8, 1, pal["band"])
	body.outline(OUT)
	p.shadow(9, 24, 6, 2)
	p.stamp(body, 0, 0)
	return p
