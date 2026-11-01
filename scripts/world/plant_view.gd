extends Node2D
## Draws one plant and its fruit. Redraws only when something visible changed,
## or a few times a second while it has sparkling fruit.

const REFRESH := 0.2

var sim: GardenSim
var plant: Dictionary
var hovered_fruit: Dictionary = {}
var _left := randf() * REFRESH
var _key := ""
var _animated := false


func setup(garden: GardenSim, p: Dictionary) -> void:
	sim = garden
	plant = p
	position = Vector2(p["x"], p["y"])


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = REFRESH
	var key := _state_key()
	if key != _key or _animated:
		_key = key
		queue_redraw()


func _state_key() -> String:
	var parts := [sim.growth_stage(plant), plant["x"], plant["y"], hovered_fruit.get("slot", -1)]
	for f in plant["fruits"]:
		parts.append(f["slot"])
		parts.append(Art.fruit_size(sim.seed_def(plant), f))
		parts.append(Art.fruit_tint(f))
		parts.append(f["m"].size())
	return str(parts)


func _draw() -> void:
	var def := sim.seed_def(plant)
	Art.draw(self, "plant/%s/%d/%d" % [plant["seed"], sim.growth_stage(plant), plant["var"]], Vector2.ZERO)
	var now := Time.get_ticks_msec() / 1000.0
	var rainbow_frame := int(now * 5.0) % 8
	_animated = false
	for f in plant["fruits"]:
		var size := Art.fruit_size(def, f)
		var tint := Art.fruit_tint(f)
		var pos: Vector2 = (sim.fruit_pos(plant, f) - position).round()
		var half := Vector2(size + 2, size + 2) * 0.5
		var frame := rainbow_frame if tint == "rainbow" else 0
		if f == hovered_fruit:
			var outline := Art.fruit_tex(plant["seed"], size, "white")
			for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_texture(outline, (pos - half + off).floor())
		draw_texture(Art.fruit_tex(plant["seed"], size, tint, frame), (pos - half).floor())
		if tint == "rainbow":
			_animated = true
		if f["t"] >= 1.0:
			_animated = true
			_sparkle(pos, size, f["slot"] * 1.7 + plant["uid"], now)
		if "wet" in f["m"]:
			_animated = true
			var drip := fmod(now * 0.8 + f["slot"] * 0.37, 1.0)
			draw_rect(Rect2(pos + Vector2(size * 0.3, size * 0.5 + drip * 5.0), Vector2.ONE), Color("#7fd0ff"))
		if "shocked" in f["m"] and fmod(now * 2.0 + f["slot"], 1.0) < 0.3:
			_animated = true
			draw_rect(Rect2(pos + Vector2(-size * 0.5, -size * 0.5), Vector2(1, 2)), Color("#fff36b"))
			draw_rect(Rect2(pos + Vector2(size * 0.5, 0), Vector2(2, 1)), Color("#fff36b"))
		if "golden" in f["m"] or "frozen" in f["m"]:
			_animated = true
			_sparkle(pos, size, f["slot"] * 3.1 + 5.0, now)


func _sparkle(pos: Vector2, size: int, phase: float, now: float) -> void:
	var t := fmod(now * 0.55 + phase * 0.31, 1.0)
	if t > 0.28:
		return
	var a := int(phase * 13.0)
	var p := pos + Vector2(((a % 5) - 2) * size * 0.22, ((a % 3) - 1) * size * 0.3).round()
	var c := Color(1, 1, 1, 1)
	draw_rect(Rect2(p, Vector2.ONE), c)
	if t > 0.07 and t < 0.21:
		draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), c)
		draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), c)
