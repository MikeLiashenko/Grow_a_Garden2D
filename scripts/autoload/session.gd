extends Node
## Owns the running game: the saved gardens, autosave and fading between scenes.

const MAIN_FILE := "main.txt"

## The automated tour plays in its own folder so it never touches the real gardens.
var gardens_dir := "user://tour_gardens/" if OS.has_environment("GG_TOUR") else "user://gardens/"
## Where the save lived when there could only be one garden.
var old_save_path := "user://tour_save.json" if OS.has_environment("GG_TOUR") else "user://save.json"
## The garden being played. Empty means the main one.
var save_path := ""
## The name of a Garden Times garden being played. Empty in single player.
var shared_title := ""

var sim: GardenSim
var away_seconds := 0.0
var _fade: ColorRect
var _autosave_left := 0.0
var _busy := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color("#10140f")
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	DirAccess.make_dir_recursive_absolute(gardens_dir)
	adopt_old_save()


func _process(delta: float) -> void:
	if sim == null:
		return
	var interval: int = Settings.get_value("autosave")
	if interval <= 0:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = interval
		save_game()


func _notification(what: int) -> void:
	# On a phone the app is usually paused and then killed, never closed.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


## Moves a save from before there were several gardens into the gardens folder.
func adopt_old_save() -> void:
	if FileAccess.file_exists(old_save_path):
		DirAccess.rename_absolute(old_save_path, _next_garden_path())


func _garden_number(file_name: String) -> int:
	if file_name.begins_with("garden_") and file_name.ends_with(".json"):
		return file_name.trim_prefix("garden_").trim_suffix(".json").to_int()
	return 0


func _next_garden_path() -> String:
	var highest := 0
	for file_name in DirAccess.get_files_at(gardens_dir):
		highest = maxi(highest, _garden_number(file_name))
	return "%sgarden_%d.json" % [gardens_dir, highest + 1]


## Every saved garden, the newest first, so rows keep their place.
func garden_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for file_name in DirAccess.get_files_at(gardens_dir):
		var number := _garden_number(file_name)
		if number == 0:
			continue
		var path := gardens_dir + file_name
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			continue
		out.append({
			"path": path,
			"name": "Garden %d" % number,
			"number": number,
			"money": float(data.get("money", 0.0)),
			"plants": (data.get("plants", []) as Array).size() + (data.get("greenhouse", []) as Array).size(),
			"day": int(float(data.get("time", 0.0)) / GameData.DAY_LENGTH) + 1 if data.has("played_days") else 1,
			"saved_at": float(data.get("saved_at", 0.0)),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["number"] > b["number"])
	return out


## The garden Play opens: the one the player chose, or else the last one played.
func main_garden() -> Dictionary:
	var chosen := FileAccess.get_file_as_string(gardens_dir + MAIN_FILE).strip_edges()
	var latest := {}
	for g in garden_list():
		if String(g["path"]).get_file() == chosen:
			return g
		if latest.is_empty() or g["saved_at"] > latest["saved_at"]:
			latest = g
	return latest


func set_main_garden(path: String) -> void:
	var f := FileAccess.open(gardens_dir + MAIN_FILE, FileAccess.WRITE)
	if f:
		f.store_string(path.get_file())
		f.close()


func current_garden_name() -> String:
	if shared_title != "":
		return shared_title
	return "Garden %d" % _garden_number(save_path.get_file())


## Plays a Garden Times garden, kept in a file of its own outside the saved gardens.
func open_shared(garden: GardenSim, path: String, title: String) -> void:
	sim = garden
	save_path = path
	shared_title = title
	away_seconds = 0.0
	_autosave_left = float(Settings.get_value("autosave"))


func has_save() -> bool:
	return save_path != "" and FileAccess.file_exists(save_path)


## Starts a garden and makes it the main one. Its file appears at the first save.
func open_new_garden() -> void:
	save_path = _next_garden_path()
	set_main_garden(save_path)


func delete_garden(path: String) -> void:
	DirAccess.remove_absolute(path)


func load_game() -> void:
	if save_path == "":
		var main := main_garden()
		if main.is_empty():
			open_new_garden()
		else:
			save_path = main["path"]
	var data: Variant = null
	if has_save():
		var text := FileAccess.get_file_as_string(save_path)
		data = JSON.parse_string(text)
	sim = GardenSim.new(data)
	away_seconds = 0.0
	if data is Dictionary and data.get("saved_at", 0.0) > 0.0:
		away_seconds = maxf(Time.get_unix_time_from_system() - data["saved_at"], 0.0)
		sim.advance_offline(away_seconds)
	_autosave_left = float(Settings.get_value("autosave"))


func save_game() -> bool:
	if sim == null:
		return false
	# Write then rename, so a crash mid-save can't destroy the old file.
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(sim.to_save()))
	f.close()
	return DirAccess.rename_absolute(tmp, save_path) == OK


func delete_save() -> void:
	sim = null
	if has_save():
		delete_garden(save_path)
	save_path = ""


func leave_game() -> void:
	save_game()
	sim = null
	save_path = ""
	shared_title = ""


func go_to(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, 0.18)
	await t.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "modulate:a", 0.0, 0.22)
	_busy = false
