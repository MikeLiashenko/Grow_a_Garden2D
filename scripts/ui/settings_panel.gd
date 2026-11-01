extends Control
## Settings screen, shared by the main menu and the pause menu.

signal closed

const VolumeBar := preload("res://scripts/ui/volume_bar.gd")
const TABS := ["GARDENS", "DISPLAY", "GRAPHICS", "AUDIO", "GAMEPLAY", "CONTROLS", "DATA"]
const CONTROLS := [
	["W A S D / Arrows", "Walk"],
	["Shift", "Run"],
	["Left click", "Plant, harvest, use held item"],
	["Hold left + move", "Sweep harvest, drag planting"],
	["Right click", "Put away the held item"],
	["Hold right + move", "Look around"],
	["1 - 9 / Mouse wheel", "Choose a hotbar item"],
	["E", "Open the shop you stand at, or harvest around you"],
	["Z / X / C / G", "Go to Seeds / Gear / Sell / Greenhouse"],
	["B / Tab", "Backpack"],
	["J", "Quests"],
	["Q", "Put away the held item"],
	["Esc", "Close, or open the pause menu"],
]

var _body: VBoxContainer
var _tab := 0
var _tab_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.03, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(380, 280)
	center.add_child(p)
	var v := Ui.vbox(6)
	p.add_child(v)
	var head := Ui.hbox()
	head.add_child(Ui.label("SETTINGS", Ui.GOLD, 16))
	head.add_child(Ui.spacer())
	var close := Ui.button("DONE", "green")
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)
	v.add_child(head)
	var tabs := Ui.hbox(2)
	for i in TABS.size():
		var b := Ui.button(TABS[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tab_index := i
		b.pressed.connect(func(): _show_tab(tab_index))
		tabs.add_child(b)
		_tab_buttons.append(b)
	v.add_child(tabs)
	_body = Ui.vbox(3)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	_show_tab(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_ESCAPE and not get_parent() is CanvasLayer:
		if _is_menu_owner():
			get_viewport().set_input_as_handled()
			closed.emit()


func _is_menu_owner() -> bool:
	return get_tree().current_scene.name == "MainMenu"


func _show_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		var b := _tab_buttons[k]
		if k == i:
			b.add_theme_stylebox_override("normal", Ui.style("ui/btn_hover", 4, Vector4(6, 3, 6, 5)))
			b.add_theme_color_override("font_color", Ui.INK)
			b.add_theme_color_override("font_hover_color", Ui.INK)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_color_override("font_color")
			b.remove_theme_color_override("font_hover_color")
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match i:
		0:
			_gardens_tab()
		1:
			_choice("Window", "window_mode", [[0, "Windowed"], [1, "Fullscreen"]])
			_toggle("VSync", "vsync")
			_choice("Pixel size", "pixel_scale", [[0, "Auto"], [1, "1x"], [2, "2x"], [3, "3x"], [4, "4x"], [5, "5x"], [6, "6x"]])
			_toggle("Show FPS", "show_fps")
		2:
			_toggle("Day and night cycle", "day_night")
			_toggle("Weather effects", "weather_fx")
			_choice("Particles", "particles", [[0, "Off"], [1, "Low"], [2, "High"]])
			_toggle("Reduce lightning flashes", "reduce_flashes")
			_toggle("Butterflies and fireflies", "ambient")
		3:
			_volume("Master volume", "master_volume")
			_volume("Music", "music_volume")
			_volume("Sound effects", "sfx_volume")
			_volume("Ambience (birds, rain, wind)", "ambience_volume")
			_toggle("Mute when the game is in the background", "mute_unfocused")
		4:
			_toggle("Tooltips", "tooltips")
			_toggle("Ask before digging up valuable plants", "confirm_shovel")
			_toggle("Short numbers (1.2M)", "short_numbers")
			_toggle("Hold and drag to plant", "drag_plant")
			_choice("Auto-save", "autosave", [[0, "Off"], [15, "15 sec"], [30, "30 sec"], [60, "1 min"], [120, "2 min"]])
		5:
			for c: Array in CONTROLS:
				var row := Ui.hbox()
				var key := Ui.label(c[0], Ui.GOLD)
				key.custom_minimum_size.x = 130
				row.add_child(key)
				row.add_child(Ui.label(c[1]))
				_body.add_child(row)
		6:
			_data_tab()


func _row(text: String) -> HBoxContainer:
	var row := Ui.hbox()
	var l := Ui.label(text)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(Ui.spacer())
	_body.add_child(row)
	return row


func _toggle(text: String, key: String) -> void:
	var row := _row(text)
	var b := Ui.button("ON" if Settings.get_value(key) else "OFF", "green" if Settings.get_value(key) else "red")
	b.custom_minimum_size.x = 76
	b.pressed.connect(func():
		Settings.set_value(key, not Settings.get_value(key))
		_show_tab(_tab)
	)
	row.add_child(b)


func _volume(text: String, key: String) -> void:
	var row := _row(text)
	var bar := VolumeBar.new()
	bar.setup(key)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)


func _choice(text: String, key: String, options: Array) -> void:
	var row := _row(text)
	var current := 0
	for i in options.size():
		if options[i][0] == Settings.get_value(key):
			current = i
	var prev := Ui.button("<")
	prev.custom_minimum_size.x = 18
	var label := Ui.label(options[current][1])
	label.custom_minimum_size.x = 52
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := Ui.button(">")
	next.custom_minimum_size.x = 18
	var shift := func(dir: int) -> void:
		Settings.set_value(key, options[posmod(current + dir, options.size())][0])
		_show_tab(_tab)
	prev.pressed.connect(shift.bind(-1))
	next.pressed.connect(shift.bind(1))
	row.add_child(prev)
	row.add_child(label)
	row.add_child(next)


func _data_tab() -> void:
	var has_game := Session.sim != null
	var row := _row("Save the game now")
	var save := Ui.button("SAVE")
	save.disabled = not has_game
	save.custom_minimum_size.x = 76
	save.pressed.connect(func():
		Session.save_game()
		save.text = "SAVED"
	)
	row.add_child(save)
	var defaults := _row("Restore default settings")
	var reset_s := Ui.button("RESTORE")
	reset_s.custom_minimum_size.x = 76
	reset_s.pressed.connect(func():
		for k in Settings.DEFAULTS:
			Settings.values[k] = Settings.DEFAULTS[k]
		Settings.set_value("window_mode", 0)
		_show_tab(_tab)
	)
	defaults.add_child(reset_s)
	_body.add_child(Ui.label("Your gardens are saved on this device.", Ui.MUTED))


## Choose the garden Play opens, start another one, or delete one.
func _gardens_tab() -> void:
	var start := _row("Play opens your main garden")
	var fresh := Ui.button("NEW GARDEN", "blue")
	fresh.pressed.connect(func():
		if Session.sim != null:
			Session.leave_game()
		Session.open_new_garden()
		Session.go_to("res://scenes/loading.tscn")
	)
	start.add_child(fresh)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var list := Ui.vbox(5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var main := Session.main_garden()
	for g in Session.garden_list():
		list.add_child(_garden_row(g, g["path"] == main.get("path", "")))
	if list.get_child_count() == 0:
		list.add_child(Ui.label("No gardens yet. Press PLAY or NEW GARDEN to start one.", Ui.MUTED))


func _garden_row(g: Dictionary, is_main: bool) -> Control:
	var playing: bool = Session.sim != null and g["path"] == Session.save_path
	var row := Ui.hbox(4)
	var text := Ui.vbox(1)
	var title := Ui.hbox(6)
	title.add_child(Ui.label(g["name"], Ui.GOLD))
	if playing:
		title.add_child(Ui.label("Playing now", Ui.CREAM))
	else:
		title.add_child(Ui.label(_ago(g["saved_at"]), Ui.MUTED))
	text.add_child(title)
	text.add_child(Ui.label(Ui.garden_summary(g)))
	row.add_child(text)
	row.add_child(Ui.spacer())
	var choose := Ui.button("MAIN" if is_main else "SET MAIN", "green" if is_main else "")
	choose.custom_minimum_size.x = 64
	choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_main:
		choose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		choose.pressed.connect(func():
			Session.set_main_garden(g["path"])
			_show_tab(_tab)
		)
	row.add_child(choose)
	var wipe := Ui.button("DELETE", "red")
	wipe.custom_minimum_size.x = 52
	wipe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var armed := [false]
	wipe.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			wipe.text = "SURE?"
			return
		if playing:
			Session.delete_save()
			Session.go_to("res://scenes/main_menu.tscn")
			return
		Session.delete_garden(g["path"])
		_show_tab(_tab)
	)
	row.add_child(wipe)
	return row


func _ago(saved_at: float) -> String:
	var minutes := int(maxf(Time.get_unix_time_from_system() - saved_at, 0.0)) / 60
	if minutes < 1:
		return "just now"
	if minutes < 60:
		return "%d min ago" % minutes
	if minutes < 1440:
		return "%d h ago" % (minutes / 60)
	return "%d days ago" % (minutes / 1440)
