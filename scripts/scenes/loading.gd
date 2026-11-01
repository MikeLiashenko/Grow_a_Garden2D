extends Control
## Loading screen shown after pressing Play: a seedling grows with the progress.

const D := preload("res://scripts/core/game_data.gd")
const GARDEN := "res://scenes/garden.tscn"
const MIN_TIME := 1.8

var _time := 0.0
var _bar: ColorRect
var _bar_box: Control
var _label: Label
var _plant: Node2D
var _shown := 0.0
var _done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = Art.GROUND
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := Ui.vbox(8)
	center.add_child(col)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(200, 84)
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(stage)
	_plant = Node2D.new()
	_plant.position = Vector2(100, 78)
	_plant.draw.connect(_draw_plant)
	stage.add_child(_plant)
	_label = Ui.label("LOADING", Ui.GOLD, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_label)
	var frame := Ui.panel()
	frame.add_theme_stylebox_override("panel", Ui.style("ui/slot", 4, Vector4(4, 4, 4, 4)))
	frame.custom_minimum_size = Vector2(200, 16)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(frame)
	_bar_box = Control.new()
	_bar_box.custom_minimum_size = Vector2(192, 8)
	frame.add_child(_bar_box)
	_bar = ColorRect.new()
	_bar.color = Color("#8ee05a")
	_bar.size = Vector2(0, 8)
	_bar_box.add_child(_bar)
	var tip := Ui.label(D.TIPS[randi() % D.TIPS.size()], Ui.MUTED)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tip)
	Session.load_game()
	ResourceLoader.load_threaded_request(GARDEN)


func _draw_plant() -> void:
	var stage := clampi(int(_shown * 5.0), 0, 4)
	Art.draw(_plant, "plant/apple/%d/0" % stage, Vector2.ZERO)
	if stage == 4:
		var slots: Array = D.SEEDS["apple"]["slots"]
		for s: Vector2 in slots:
			_plant.draw_texture(Art.fruit_tex("apple", 9), s - Vector2(5, 5))


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(GARDEN, progress)
	var loaded: float = progress[0] if progress.size() > 0 else 0.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		loaded = 1.0
	var target := minf(loaded, _time / MIN_TIME)
	_shown = move_toward(_shown, target, delta * 1.5)
	_bar.size.x = floorf(_bar_box.size.x * _shown)
	_label.text = "LOADING" + ".".repeat(int(_time * 3.0) % 4)
	_plant.queue_redraw()
	if status == ResourceLoader.THREAD_LOAD_LOADED and _shown >= 1.0:
		_done = true
		Session.go_to(GARDEN)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_done = true
		_label.text = "COULD NOT LOAD THE GARDEN"
