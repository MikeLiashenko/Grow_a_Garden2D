extends Node2D
## World-space pixel particles, floating text, butterflies and water shimmer.

const D := preload("res://scripts/core/game_data.gd")

var _parts: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _bolts: Array[Dictionary] = []
var _flies: Array[Dictionary] = []
var _jet := 0.0
var night := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	z_index = 50
	var inner := D.fence_inner()
	for i in 14:
		_flies.append({
			"p": Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y)),
			"v": Vector2.ZERO, "t": rng.randf() * 10.0, "c": [Color("#ffb0d8"), Color("#fff09a"), Color("#a8d4ff"), Color("#ffffff")][i % 4],
		})


func burst(pos: Vector2, colors: Array, count := 8, speed := 40.0, gravity := 90.0) -> void:
	var level: int = Settings.get_value("particles")
	if level == 0:
		return
	if level == 1:
		count = maxi(1, count / 3)
	for i in count:
		var a := rng.randf() * TAU
		var v := Vector2(cos(a), sin(a) - 0.6) * rng.randf_range(speed * 0.35, speed)
		_parts.append({"p": pos, "v": v, "g": gravity, "l": rng.randf_range(0.35, 0.7), "c": colors[rng.randi() % colors.size()], "s": 1.0 if rng.randf() < 0.7 else 2.0})


func spray(pos: Vector2, color: Color) -> void:
	if Settings.get_value("particles") == 0:
		return
	var a := rng.randf() * TAU
	_parts.append({"p": pos, "v": Vector2(cos(a), sin(a) * 0.6 - 0.55) * rng.randf_range(10, 34), "g": 70.0, "l": rng.randf_range(0.4, 0.8), "c": color, "s": 1.0})


func float_text(pos: Vector2, text: String, color: Color) -> void:
	_texts.append({"p": pos, "t": text, "c": color, "l": 1.3})


func bolt(pos: Vector2) -> void:
	var pts := PackedVector2Array()
	var y := pos.y - 240.0
	var x := pos.x + rng.randf_range(-30, 30)
	while y < pos.y:
		pts.append(Vector2(x, y))
		x += rng.randf_range(-12, 12)
		y += rng.randf_range(12, 26)
	pts.append(pos)
	_bolts.append({"pts": pts, "l": 0.22})


func _process(delta: float) -> void:
	for i in range(_parts.size() - 1, -1, -1):
		var q: Dictionary = _parts[i]
		q["l"] -= delta
		if q["l"] <= 0.0:
			_parts.remove_at(i)
			continue
		q["v"].y += q["g"] * delta
		q["p"] += q["v"] * delta
	for i in range(_texts.size() - 1, -1, -1):
		_texts[i]["l"] -= delta
		_texts[i]["p"].y -= delta * 14.0
		if _texts[i]["l"] <= 0.0:
			_texts.remove_at(i)
	for i in range(_bolts.size() - 1, -1, -1):
		_bolts[i]["l"] -= delta
		if _bolts[i]["l"] <= 0.0:
			_bolts.remove_at(i)
	_jet -= delta
	if _jet <= 0.0:
		_jet = 0.05
		var top := D.FOUNTAIN + Vector2(0, -68)
		spray(top, Color("#c8f0ff"))
		var a := rng.randf() * TAU
		spray(D.FOUNTAIN + Vector2(cos(a) * 16.0, sin(a) * 5.0 - 56.0), Color("#8fdcf8"))
	if Settings.get_value("ambient"):
		for f in _flies:
			f["t"] += delta
			var wander := Vector2(sin(f["t"] * 0.9 + f["p"].y * 0.01), cos(f["t"] * 0.7 + f["p"].x * 0.01)) * 16.0
			f["p"] += (wander + Vector2(sin(f["t"] * 7.0), cos(f["t"] * 6.0)) * 8.0) * delta
			var inner := D.fence_inner()
			f["p"].x = clampf(f["p"].x, inner.position.x, inner.end.x)
			f["p"].y = clampf(f["p"].y, inner.position.y, inner.end.y)
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if Settings.get_value("ambient"):
		for f in _flies:
			if night > 0.5:
				# Fireflies at night.
				var on := sin(f["t"] * 2.0 + f["p"].x) > 0.0
				if on:
					draw_rect(Rect2(f["p"].round(), Vector2.ONE), Color("#e8ff80"))
				continue
			var flap := int(f["t"] * 9.0) % 2 == 0
			var p: Vector2 = f["p"].round()
			draw_rect(Rect2(p, Vector2(1, 2)), Color("#2a1a1a"))
			draw_rect(Rect2(p + Vector2(-1 if flap else -2, 0), Vector2(1 if flap else 2, 1)), f["c"])
			draw_rect(Rect2(p + Vector2(1, 0), Vector2(1 if flap else 2, 1)), f["c"])
	# Glints on the pond.
	for i in 7:
		var t := fmod(now * 0.5 + i * 0.37, 1.0)
		if t < 0.3:
			var gx := 870.0 + fmod(i * 47.3, 52.0)
			var gy := 240.0 + fmod(i * 91.7, 80.0)
			draw_rect(Rect2(gx, gy, 3 if t > 0.1 else 1, 1), Color(1, 1, 1, 0.8))
	for q in _parts:
		draw_rect(Rect2(q["p"].round(), Vector2(q["s"], q["s"])), q["c"])
	for b in _bolts:
		var pts: PackedVector2Array = b["pts"]
		for i in pts.size() - 1:
			draw_line(pts[i] + Vector2(1, 0), pts[i + 1] + Vector2(1, 0), Color("#7a9cff"), 1.0)
			draw_line(pts[i], pts[i + 1], Color.WHITE, 1.0)
	for t in _texts:
		var size := Ui.font.get_string_size(t["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
		var c: Color = t["c"]
		c.a = clampf(t["l"] * 3.0, 0.0, 1.0)
		var outline := Color("#1c120a", c.a)
		Ui.draw_outlined(self, (t["p"] - Vector2(size.x / 2.0, 0)).round(), t["t"], c, outline)
