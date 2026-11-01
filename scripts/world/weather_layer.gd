extends CanvasLayer
## Screen-space weather: rain, snow, golden motes and lightning flashes.

var sim: GardenSim
var _drops: Array[Vector3] = []
var _flash := 0.0
var _canvas: Node2D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 2
	_canvas = Node2D.new()
	_canvas.draw.connect(_paint)
	add_child(_canvas)
	rng.randomize()


func flash() -> void:
	if not Settings.get_value("reduce_flashes"):
		_flash = 0.55
	else:
		_flash = 0.1


## What is falling right now. In winter a light snow falls even in clear weather.
func _effect() -> String:
	if sim == null or not Settings.get_value("weather_fx"):
		return ""
	if sim.s["weather"] == "" and sim.is_winter():
		return "frost"
	return sim.s["weather"]


func _process(delta: float) -> void:
	var view := _canvas.get_viewport_rect().size
	var id := _effect()
	var level: int = Settings.get_value("particles")
	var target := 0
	if id != "":
		target = int(view.x * view.y / (900.0 if id in ["rain", "storm"] else 1800.0))
		if sim.s["weather"] == "":
			target /= 2
		if id == "storm":
			target = int(target * 1.5)
		if level == 1:
			target /= 2
		elif level == 0:
			target /= 5
	while _drops.size() < target:
		_drops.append(Vector3(rng.randf() * view.x, rng.randf() * view.y, rng.randf()))
	if _drops.size() > target:
		_drops.resize(target)
	var speed := 0.0
	var drift := 0.0
	match id:
		"rain": speed = 230.0; drift = -30.0
		"storm": speed = 320.0; drift = -80.0
		"frost": speed = 26.0; drift = 8.0
		"golden_hour": speed = -8.0; drift = 5.0
	for i in _drops.size():
		var d := _drops[i]
		d.y += speed * (0.7 + d.z * 0.6) * delta
		d.x += (drift + (sin(d.y * 0.05 + d.z * 9.0) * 8.0 if id == "frost" else 0.0)) * delta
		if d.y > view.y:
			d.y -= view.y + 8.0
			d.x = rng.randf() * view.x
		elif d.y < -4.0:
			d.y += view.y + 4.0
		d.x = fposmod(d.x, view.x)
		_drops[i] = d
	_flash = maxf(0.0, _flash - delta * 2.2)
	_canvas.queue_redraw()


func _paint() -> void:
	match _effect():
		"rain", "storm":
			for d in _drops:
				var len_ := 3.0 + d.z * 4.0
				_canvas.draw_rect(Rect2(floorf(d.x), floorf(d.y), 1, len_), Color(0.72, 0.86, 1.0, 0.35 + d.z * 0.35))
		"frost":
			for d in _drops:
				var s := 1.0 if d.z < 0.7 else 2.0
				_canvas.draw_rect(Rect2(floorf(d.x), floorf(d.y), s, s), Color(1, 1, 1, 0.65 + d.z * 0.3))
		"golden_hour":
			for d in _drops:
				var a := 0.4 + 0.5 * absf(sin(d.y * 0.1 + d.z * 7.0))
				_canvas.draw_rect(Rect2(floorf(d.x), floorf(d.y), 1, 1), Color(1, 0.88, 0.4, a))
	if _flash > 0.0:
		_canvas.draw_rect(_canvas.get_viewport_rect(), Color(1, 1, 1, _flash))
