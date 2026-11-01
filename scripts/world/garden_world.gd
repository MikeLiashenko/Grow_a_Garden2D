extends Node2D
## The garden as seen on screen: ground, props, plants, lighting. Mirrors a
## GardenSim through its events; used by both the game and the menu backdrop.

const D := preload("res://scripts/core/game_data.gd")
const Layout := preload("res://scripts/world/layout.gd")
const PlantView := preload("res://scripts/world/plant_view.gd")
const FxLayer := preload("res://scripts/world/fx_layer.gd")
const WeatherLayer := preload("res://scripts/world/weather_layer.gd")
const Player := preload("res://scripts/world/player.gd")

var sim: GardenSim
var entities: Node2D
var fx: Node2D
var weather: CanvasLayer
var player: CharacterBody2D
var overlay: Node2D
var _modulate: CanvasModulate
var _ground: Sprite2D
var _season_tint: ColorRect
var _lights: Array[PointLight2D] = []
var _plant_views := {}
var _gadget_views := {}
var _locked := {}
var _doors: Array[Sprite2D] = []
var _gate_open := 0.0
var _spray_left := 0.0


func setup(garden: GardenSim, with_player: bool) -> void:
	sim = garden
	_build_static(with_player)
	for p in sim.s["plants"]:
		_add_plant(p)
	for g in sim.s["gadgets"]:
		_add_gadget(g)
	sim.sim_event.connect(_on_sim_event)


func _build_static(with_player: bool) -> void:
	_ground = Sprite2D.new()
	_ground.texture = Art.GROUND
	_ground.centered = false
	_ground.z_index = -10
	add_child(_ground)
	_season_tint = ColorRect.new()
	_season_tint.size = D.WORLD_PX
	_season_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_season_tint.z_index = -10
	_season_tint.color = Color(sim.season()["tint"])
	add_child(_season_tint)

	for i in D.BEDS.size():
		if not sim.s["beds"][i]:
			_add_locked_bed(i)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)

	var body := StaticBody2D.new()
	entities.add_child(body)
	for r: Rect2 in Layout.walls():
		_add_collider(body, r)

	for e in Layout.props():
		var s := Art.make_sprite(e["sprite"])
		s.position = e["pos"]
		entities.add_child(s)
		if e.has("col"):
			var r: Rect2 = e["col"]
			_add_collider(body, Rect2(r.position + e["pos"], r.size))
		if e["sprite"] == "prop/greenhouse":
			var title := Ui.label("GREENHOUSE", Color.WHITE)
			title.position = Vector2(-title.get_minimum_size().x / 2.0, -72)
			_add_shadowed(s, title)
		elif e["sprite"] == "prop/lamp":
			_add_light(e["pos"] + Vector2(0, -28), 1.1)
		elif e["sprite"] == "prop/pillar_lantern":
			_add_light(e["pos"] + Vector2(0, -38), 0.9)

	for st in Layout.STALLS:
		var s := Art.make_sprite(st["sprite"])
		s.position = st["pos"]
		entities.add_child(s)
		_add_collider(body, Rect2(st["pos"] + Vector2(-44, -18), Vector2(88, 19)))
		var title := Ui.label(st["title"], Color.WHITE)
		title.position = Vector2(-title.get_minimum_size().x / 2.0, -80)
		title.add_theme_color_override("font_outline_color", Color("#1c120a"))
		_add_shadowed(s, title)

	# Gate: two doors between the pillars and the arch overhead.
	for i in 2:
		var door := Art.make_sprite("prop/gate_door")
		door.position = Vector2(448.0 if i == 0 else 512.0, Layout.SOUTH_Y)
		door.flip_h = i == 1
		if i == 1:
			door.offset.x = -30
		entities.add_child(door)
		_doors.append(door)
	var arch := Art.make_sprite("prop/arch")
	arch.position = Vector2(480, Layout.SOUTH_Y + 4)
	entities.add_child(arch)
	var sign_text := Ui.label("MY GARDEN", Color("#2c1a0e"))
	sign_text.position = Vector2(-sign_text.get_minimum_size().x / 2.0 + 1, -53)
	arch.add_child(sign_text)

	if with_player:
		player = Player.new()
		player.position = Vector2(sim.s["player"][0], sim.s["player"][1])
		entities.add_child(player)

	overlay = Node2D.new()
	overlay.z_index = 40
	add_child(overlay)

	fx = FxLayer.new()
	add_child(fx)

	_modulate = CanvasModulate.new()
	add_child(_modulate)

	weather = WeatherLayer.new()
	weather.sim = sim
	add_child(weather)


func _add_shadowed(parent: Node, l: Label) -> void:
	var shadow := Ui.label(l.text, Color("#1c120a"))
	shadow.position = l.position + Vector2(1, 1)
	parent.add_child(shadow)
	parent.add_child(l)


func _add_collider(body: StaticBody2D, r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	body.add_child(shape)


func _add_light(pos: Vector2, size: float) -> void:
	var l := PointLight2D.new()
	l.texture = Art.glow()
	l.texture_scale = size
	l.color = Color("#ffd890")
	l.energy = 0.0
	l.position = pos
	add_child(l)
	l.enabled = false
	_lights.append(l)


func _add_locked_bed(i: int) -> void:
	var r: Rect2 = D.BEDS[i]["rect"]
	var over := Sprite2D.new()
	over.texture = Art.LOCKED_BED
	over.centered = false
	over.position = r.position
	over.z_index = -9
	add_child(over)
	var sign_sprite := Art.make_sprite("prop/bed_sign")
	sign_sprite.position = r.get_center() + Vector2(0, 8)
	sign_sprite.z_index = -8
	add_child(sign_sprite)
	var price := Ui.label(Ui.money(D.BEDS[i]["price"]), Color("#2c1a0e"))
	price.position = Vector2(-price.get_minimum_size().x / 2.0, -25)
	sign_sprite.add_child(price)
	_locked[i] = [over, sign_sprite]


func _add_plant(p: Dictionary) -> void:
	var v: Node2D = PlantView.new()
	v.setup(sim, p)
	entities.add_child(v)
	_plant_views[p["uid"]] = v


func plant_view(uid: int) -> Node2D:
	return _plant_views.get(uid)


func _add_gadget(g: Dictionary) -> void:
	var s := Art.make_sprite("gadget/" + g["id"])
	s.position = Vector2(g["x"], g["y"])
	entities.add_child(s)
	_gadget_views[g["uid"]] = s


func _on_sim_event(type: String, d: Dictionary) -> void:
	match type:
		"planted":
			_add_plant(d["plant"])
			fx.burst(Vector2(d["plant"]["x"], d["plant"]["y"]), [Color("#5e3a22"), Color("#7a5234")], 6, 22.0)
		"moved":
			_plant_views[d["plant"]["uid"]].position = Vector2(d["plant"]["x"], d["plant"]["y"])
		"removed":
			var v: Node2D = _plant_views.get(d["uid"])
			if v:
				v.queue_free()
				_plant_views.erase(d["uid"])
			if d.get("dug", false):
				fx.burst(d["pos"], [Color("#5e3a22"), Color("#2f9140")], 10, 40.0)
		"plant_died":
			fx.burst(d["pos"], [Color("#bfeaff"), Color("#6a5a48"), Color.WHITE], 14, 36.0)
			fx.float_text(d["pos"] + Vector2(0, -10), "Frozen to death", Color("#bfeaff"))
		"gadget_added":
			_add_gadget(d["gadget"])
		"gadget_removed":
			var g: Node2D = _gadget_views.get(d["uid"])
			if g:
				g.queue_free()
				_gadget_views.erase(d["uid"])
		"harvested":
			fx.burst(d["pos"], [Color("#fff4d0"), Color("#8ee05a"), Color("#ffd23f")], 7, 34.0)
		"watered":
			fx.burst(d["pos"] + Vector2(0, -8), [Color("#6ec6ff"), Color("#c8ecff")], 12, 34.0)
		"mutated":
			var m: Dictionary = D.MUTATIONS[d["mutation"]]
			fx.burst(d["pos"], [Color(m["color"]), Color.WHITE], 8, 26.0, 30.0)
			# Common weather marks would flood the screen, so only rare ones get a caption.
			if d["mutation"] in ["golden", "rainbow", "frozen", "shocked"]:
				fx.float_text(d["pos"] + Vector2(0, -8), m["name"] + "!", Color(m["color"]))
		"ripe":
			fx.burst(d["pos"] + Vector2(0, -8), [Color.WHITE, Color("#fff4a0")], 4, 18.0, 10.0)
		"strike":
			fx.bolt(d["pos"])
			fx.burst(d["pos"], [Color("#fff36b"), Color.WHITE], 16, 60.0)
			weather.flash()
		"bed_unlocked":
			var e: Array = _locked.get(d["index"], [])
			for n in e:
				n.queue_free()
			_locked.erase(d["index"])
			var r: Rect2 = D.BEDS[d["index"]]["rect"]
			for i in 16:
				fx.burst(r.get_center() + Vector2(randf_range(-100, 100), randf_range(-46, 46)), [Color("#8ee05a"), Color("#ffd23f"), Color("#5e3a22")], 3, 40.0)


func _process(delta: float) -> void:
	_update_light()
	_season_tint.color = _season_tint.color.lerp(Color(sim.season()["tint"]), minf(delta, 1.0))
	if player:
		var near := player.position.distance_to(Vector2(480, Layout.SOUTH_Y)) < 54.0
		_gate_open = move_toward(_gate_open, 1.0 if near else 0.0, delta * 3.5)
		for door in _doors:
			door.scale.x = lerpf(1.0, 0.14, _gate_open)
	_spray_left -= delta
	if _spray_left <= 0.0:
		_spray_left = 0.09
		for g in sim.s["gadgets"]:
			if g["id"].ends_with("sprinkler"):
				var a := randf() * TAU
				fx.spray(Vector2(g["x"], g["y"]) + Vector2(cos(a) * 3.0, -14.0), Color("#a0dcff"))


func _update_light() -> void:
	var enabled: bool = Settings.get_value("day_night")
	sim.day_night_enabled = enabled
	var night := sim.night_factor() if enabled else 0.0
	fx.night = night
	var phase := fmod(float(sim.s["time"]), D.DAY_LENGTH) / D.DAY_LENGTH
	var c := Color.WHITE
	if enabled:
		if phase > 0.52 and phase <= 0.62:
			c = Color.WHITE.lerp(Color("#ffc890"), (phase - 0.52) / 0.10)
		elif phase > 0.62 and phase < 0.72:
			c = Color("#ffc890").lerp(Color("#4a5a9a"), (phase - 0.62) / 0.10)
		elif phase >= 0.72 and phase <= 0.90:
			c = Color("#4a5a9a")
		elif phase > 0.90 and phase < 0.98:
			c = Color("#4a5a9a").lerp(Color("#ffd8c0"), (phase - 0.90) / 0.08)
		elif phase >= 0.98 or phase < 0.05:
			var t := (phase - 0.98) / 0.07 if phase >= 0.98 else (phase + 0.02) / 0.07
			c = Color("#ffd8c0").lerp(Color.WHITE, t)
	var w: String = sim.s["weather"]
	if Settings.get_value("weather_fx"):
		match w:
			"rain": c *= Color(0.78, 0.82, 0.92)
			"storm": c *= Color(0.55, 0.58, 0.72)
			"frost": c *= Color(0.86, 0.94, 1.08)
			"golden_hour": c *= Color(1.1, 0.98, 0.72)
	if sim.is_winter():
		c *= Color(0.93, 0.97, 1.04)
	_modulate.color = c
	var lit := night > 0.05 or w == "storm"
	for l in _lights:
		l.enabled = lit
		l.energy = maxf(night, 0.6 if w == "storm" else 0.0) * 0.85
