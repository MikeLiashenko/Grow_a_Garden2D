extends Node
## Player preferences, stored in user://settings.cfg and applied on change.

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"window_mode": 0, # 0 windowed, 1 fullscreen
	"vsync": true,
	"pixel_scale": 0, # 0 = auto
	"show_fps": false,
	"day_night": true,
	"weather_fx": true,
	"particles": 2, # 0 off, 1 low, 2 high
	"reduce_flashes": false,
	"ambient": true,
	"master_volume": 100, # all volumes are percent, in steps of 10
	"music_volume": 50,
	"sfx_volume": 100,
	"ambience_volume": 70,
	"mute_unfocused": true,
	"tooltips": true,
	"confirm_shovel": true,
	"short_numbers": true,
	"drag_plant": true,
	"autosave": 30, # seconds, 0 = off
}

var values := DEFAULTS.duplicate()


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			values[k] = cfg.get_value("settings", k, DEFAULTS[k])
	get_window().size_changed.connect(_update_scale)
	if not DisplayServer.get_name() == "headless":
		apply()


func get_value(key: String) -> Variant:
	return values[key]


func set_value(key: String, v: Variant) -> void:
	values[key] = v
	apply()
	save()
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)


func apply() -> void:
	var fullscreen: bool = values["window_mode"] == 1
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
	_update_scale()


func current_scale() -> int:
	var win := get_window().size
	var s: int = values["pixel_scale"]
	if s <= 0:
		s = int(floorf(minf(win.x / 640.0, win.y / 360.0) + 0.5))
	return maxi(1, s)


func _update_scale() -> void:
	var win := get_window()
	var s := current_scale()
	win.content_scale_size = Vector2i(maxi(1, win.size.x / s), maxi(1, win.size.y / s))
	if has_node("/root/Ui"):
		get_node("/root/Ui").update_cursor(s)
