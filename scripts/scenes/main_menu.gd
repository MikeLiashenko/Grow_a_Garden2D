extends Node2D
## Title screen over a slowly drifting view of a thriving garden.

const D := preload("res://scripts/core/game_data.gd")
const GardenWorld := preload("res://scripts/world/garden_world.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const DRIFT_SPEED := 20.0
const DRIFT_MARGIN := 8.0

var _world: Node2D
var _demo: GardenSim
var _camera: Camera2D
var _time := 0.0
var _drift_angle := 0.0
var _settings: Control
var _ui: Control
var _logo: TextureRect
var _play_info: Label


func _ready() -> void:
	name = "MainMenu"
	Sfx.set_music("menu")
	_build_backdrop()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.06, 0.04, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(center)
	var col := Ui.vbox(6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	_logo = TextureRect.new()
	_logo.texture = Art.LOGO
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_logo)
	var buttons := Ui.vbox(5)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(buttons)
	_menu_button(buttons, "PLAY", "green", _play)
	_play_info = Ui.label("")
	_play_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(_play_info)
	_refresh_play()
	_menu_button(buttons, "GARDEN TIMES", "gold", func(): Session.go_to("res://scenes/garden_times.tscn"))
	_menu_button(buttons, "SETTINGS", "", _open_settings)
	if OS.get_name() != "Web":
		_menu_button(buttons, "QUIT", "red", func(): get_tree().quit())
	var version := Ui.label("Version " + str(ProjectSettings.get_setting("application/config/version")), Ui.CREAM)
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(4, -13)
	_ui.add_child(version)


func _menu_button(parent: Control, text: String, kind: String, action: Callable) -> void:
	var b := Ui.button(text, kind, 16)
	b.custom_minimum_size = Vector2(176, 26)
	b.pressed.connect(action)
	parent.add_child(b)


## The line under Play says which garden it opens.
func _refresh_play() -> void:
	var main := Session.main_garden()
	_play_info.text = "New garden" if main.is_empty() else "%s   %s" % [main["name"], Ui.garden_summary(main)]


func _play() -> void:
	Session.go_to("res://scenes/loading.tscn")


func _open_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.closed.connect(func():
		_settings.queue_free()
		_settings = null
		_refresh_play()
	)
	_ui.add_child(_settings)


## A fake, fully grown garden: every bed open and planted with a mix of crops.
func _build_backdrop() -> void:
	_demo = GardenSim.new()
	_demo.s["beds"] = [true, true, true, true, true, true]
	_demo.s["weather"] = ""
	_demo.s["next_weather"] = 1e9
	_demo.s["time"] = D.DAY_LENGTH * 0.2
	_demo.s["hot"] = ["", "", "", "", "", "", "", "", ""]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var ids: Array = D.SEEDS.keys()
	for bed in D.BEDS:
		var r: Rect2 = (bed["rect"] as Rect2).grow(-8.0)
		for k in 34:
			var id: String = ids[rng.randi() % ids.size()]
			var pos := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			_demo.s["items"]["seed:" + id] = 1
			if _demo.plant(id, pos) == "":
				var p: Dictionary = _demo.s["plants"][-1]
				p["age"] = p["grow"]
				var def: Dictionary = D.SEEDS[id]
				if def["multi"]:
					for i in def["slots"].size():
						var f := _demo._make_fruit(p, i)
						f["t"] = 1.0
						p["fruits"].append(f)
				else:
					p["fruits"][0]["t"] = 1.0
	_world = GardenWorld.new()
	add_child(_world)
	_world.setup(_demo, false)
	_camera = Camera2D.new()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(D.WORLD_PX.x)
	_camera.limit_bottom = int(D.WORLD_PX.y)
	add_child(_camera)
	_camera.make_current()
	_update_camera()


## The loop the camera can travel on this screen without reaching the world's edge.
func _drift_radius() -> Vector2:
	var room := (D.WORLD_PX - get_viewport_rect().size) * 0.5 - Vector2(DRIFT_MARGIN, DRIFT_MARGIN)
	return room.max(Vector2.ZERO)


func _update_camera() -> void:
	var r := _drift_radius()
	_camera.position = D.WORLD_PX * 0.5 + Vector2(cos(_drift_angle) * r.x, sin(_drift_angle) * r.y)


## Moves along the loop at one speed all the way round, in every direction.
func drift(delta: float) -> void:
	var r := _drift_radius()
	var stretch := Vector2(sin(_drift_angle) * r.x, cos(_drift_angle) * r.y).length()
	_drift_angle = fposmod(_drift_angle + DRIFT_SPEED * delta / maxf(stretch, 1.0), TAU)
	_update_camera()


func _process(delta: float) -> void:
	_time += delta
	drift(delta)
	_logo.position.y = sin(_time * 1.2) * 1.5
