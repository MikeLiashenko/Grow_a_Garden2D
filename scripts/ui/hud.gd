extends CanvasLayer
## Everything on top of the garden: money, hotbar, the shop buttons on the right,
## shop panels, toasts, tooltips and the pause menu.

const D := preload("res://scripts/core/game_data.gd")
const ShopPanels := preload("res://scripts/ui/shop_panels.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const Layout := preload("res://scripts/world/layout.gd")
const PlayersPanel := preload("res://scripts/ui/players_panel.gd")

const SLOTS := 9
const SHOP_WIDTH := 296

var game: Node2D
var sim: GardenSim

var _root: Control
var _money: Label
var _shown_money := 0.0
var _bag: Label
var _quest_button: Button
var _season_label: Label
var _clock: Label
var _weather_label: Label
var _restock: Label
var _hint: Label
var _prompt: Button
var _panel_dirty := false
var _fps: Label
var _slots: Array[Dictionary] = []
var _toasts: VBoxContainer
var _tip: PanelContainer
var _tip_lines: VBoxContainer
var _panel_host: Control
var _panel: Control
var _panel_id := ""
var _modal: Control
var _pause: Control
var _settings: Control


func _ready() -> void:
	layer = 10
	sim = game.sim
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top_left()
	_build_top_center()
	_build_right()
	_build_hotbar()
	_build_toasts()
	_panel_host = Control.new()
	_panel_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel_host)
	_build_tooltip()
	_fps = Ui.label("", Ui.GREEN)
	_fps.position = Vector2(4, 0)
	_root.add_child(_fps)
	_shown_money = sim.s["money"]
	sim.sim_event.connect(_on_sim_event)
	_refresh_hotbar()
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()


# --- Layout --------------------------------------------------------------------

func _build_top_left() -> void:
	var box := Ui.vbox(2)
	box.position = Vector2(4, 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var money := Ui.panel()
	money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := Ui.hbox(4)
	row.add_child(Ui.icon(Art.tex("ui/coin")))
	_money = Ui.label("$0", Ui.GOLD, 16)
	row.add_child(_money)
	money.add_child(row)
	box.add_child(money)
	var bag := Ui.panel()
	bag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bag_row := Ui.hbox(4)
	bag_row.add_child(Ui.icon(Art.tex("item/gear/backpack")))
	_bag = Ui.label("0/100")
	_bag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bag_row.add_child(_bag)
	bag.add_child(bag_row)
	box.add_child(bag)


func _build_top_center() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.position = Vector2(0, 4)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	var p := Ui.panel()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := Ui.vbox(1)
	_season_label = Ui.label("")
	_season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_season_label)
	_clock = Ui.label("")
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_clock)
	_weather_label = Ui.label("", Color("#8fd8ff"))
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_weather_label)
	p.add_child(v)
	holder.add_child(p)


func _build_right() -> void:
	var box := Ui.vbox(3)
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.position = Vector2(-4, 4)
	box.custom_minimum_size.x = 88
	_root.add_child(box)
	var entries := [
		["seed", "SEED SHOP", "item/seed/carrot", "green"],
		["gear", "GEAR SHOP", "item/gear/watering_can", "blue"],
		["sell", "SELL", "ui/coin", "gold"],
		["greenhouse", "GREENHOUSE", "ui/greenhouse", "green"],
		["backpack", "BACKPACK", "item/gear/backpack", ""],
		["quests", "QUESTS", "ui/quest", ""],
	]
	for e in entries:
		var b := Ui.button(e[1], e[3])
		b.icon = Art.tex(e[2])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(88, 26)
		var id: String = e[0]
		# Places are walked up to in the world; only what you carry opens anywhere.
		if Layout.PLACES.has(id):
			b.pressed.connect(func(): game.go_to_place(id))
		else:
			b.pressed.connect(func(): open_panel(id))
		if id == "quests":
			_quest_button = b
		box.add_child(b)
	_restock = Ui.label("", Ui.CREAM)
	_restock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plate := Ui.panel()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := Ui.vbox(0)
	var title := Ui.label("Restock", Ui.MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_restock)
	plate.add_child(v)
	box.add_child(plate)
	if Net.link:
		var people := Ui.button("PLAYERS", "blue")
		people.custom_minimum_size = Vector2(88, 20)
		people.pressed.connect(func(): _root.add_child(PlayersPanel.new()))
		box.add_child(people)
	var menu := Ui.button("MENU")
	menu.pressed.connect(toggle_pause)
	box.add_child(menu)


func _build_hotbar() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.position.y = -3
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	var col := Ui.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(col)
	# A button as well as a key, so a phone without a keyboard can use it too.
	_prompt = Ui.button("", "gold")
	_prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt.visible = false
	_prompt.pressed.connect(func(): game.interact())
	col.add_child(_prompt)
	_hint = Ui.label("")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_shadow_color", Color("#1c120a"))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	col.add_child(_hint)
	var row := Ui.hbox(1)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var normal := Ui.style("ui/slot", 4, Vector4.ZERO)
	var selected := Ui.style("ui/slot_selected", 4, Vector4.ZERO)
	for i in SLOTS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(24, 24)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", selected)
		b.add_theme_stylebox_override("pressed", selected)
		var tex := TextureRect.new()
		tex.position = Vector2(4, 4)
		tex.size = Vector2(16, 16)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tex)
		var key := Ui.label(str(i + 1), Ui.MUTED)
		key.position = Vector2(2, 0)
		b.add_child(key)
		var count := Ui.label("", Color.WHITE)
		count.position = Vector2(0, 14)
		count.size = Vector2(22, 10)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(count)
		var slot_index := i
		b.pressed.connect(func(): _click_slot(slot_index))
		b.mouse_entered.connect(func(): _hover_slot(slot_index))
		b.mouse_exited.connect(hide_tooltip)
		row.add_child(b)
		_slots.append({"button": b, "tex": tex, "count": count, "normal": normal, "selected": selected})


func _build_toasts() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.position.y = -62
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	_toasts = Ui.vbox(1)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_toasts)


func _build_tooltip() -> void:
	_tip = Ui.panel()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 20
	_tip_lines = Ui.vbox(1)
	_tip_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_lines)
	_root.add_child(_tip)


func _on_settings_changed() -> void:
	_fps.visible = Settings.get_value("show_fps")


# --- Per-frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	var target: float = sim.s["money"]
	_shown_money = move_toward(_shown_money, target, maxf(absf(target - _shown_money) * delta * 7.0, 1.0))
	_money.text = Ui.money(_shown_money)
	_bag.text = "%d/%d" % [sim.s["fruits"].size(), sim.s["capacity"]]
	_bag.add_theme_color_override("font_color", Ui.RED if sim.s["fruits"].size() >= sim.s["capacity"] else Ui.CREAM)
	_restock.text = Ui.time_text(sim.s["restock_in"])
	_update_clock()
	_quest_button.text = "QUESTS %d/%d" % [sim.quests_done(), sim.daily_quests().size()]
	_update_place()
	_update_hint()
	if _panel_dirty:
		_panel_dirty = false
		_refresh_panel()
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if _tip.visible:
		_place_tooltip()


func _update_clock() -> void:
	var phase := fmod(float(sim.s["time"]), D.DAY_LENGTH) / D.DAY_LENGTH
	# Phase 0 is 6:00; a full cycle is one 24 hour day.
	var minutes := int(phase * 1440.0 + 360.0) % 1440
	_clock.text = "Day %d   %02d:%02d" % [sim.day(), minutes / 60, minutes % 60]
	var season := sim.season()
	_season_label.text = "%s  %d/%d" % [season["name"], sim.season_day(), D.SEASON_DAYS]
	_season_label.add_theme_color_override("font_color", Color(season["color"]))
	var w: String = sim.s["weather"]
	if w != "":
		_weather_label.text = "%s  %s" % [D.WEATHER[w]["name"], Ui.time_text(sim.s["weather_left"])]
	elif sim.is_night():
		_weather_label.text = "Night"
	else:
		_weather_label.text = "Clear"


## Offers the place the gardener stands at, and closes its window on walking away.
func _update_place() -> void:
	var place := Layout.place_near(game.world.player.position)
	if Layout.PLACES.has(_panel_id) and place != _panel_id:
		close_panel()
	_prompt.visible = place != "" and place != _panel_id and not game.paused
	if _prompt.visible:
		_prompt.text = "E   Open " + Layout.PLACES[place]["name"]


func _update_hint() -> void:
	var key: String = sim.s["selected"]
	if key == "":
		_hint.text = "Press 1-9 to pick an item. Click ripe fruit to harvest."
		return
	if key.begins_with("seed:"):
		_hint.text = "%s x%d - click a bed to plant it right there" % [D.item_name(key), sim.item_count(key)]
		return
	var def: Dictionary = D.GEAR[key.split(":")[1]]
	var text: String = def["desc"]
	if def.has("pack"):
		text = "%d uses left. %s" % [sim.item_count(key), text.split(". ", true, 1)[-1]]
	_hint.text = def["name"] + " - " + text


func _refresh_hotbar() -> void:
	for i in SLOTS:
		var key: String = sim.s["hot"][i]
		var s: Dictionary = _slots[i]
		s["tex"].texture = Art.item_icon(key) if key != "" else null
		var n := sim.item_count(key) if key != "" else 0
		var perm: bool = key.begins_with("gear:") and D.GEAR[key.split(":")[1]].get("perm", false)
		s["count"].text = str(n) if n > 0 and not perm else ""
		var is_sel: bool = key != "" and key == sim.s["selected"]
		s["button"].add_theme_stylebox_override("normal", s["selected"] if is_sel else s["normal"])


func _click_slot(i: int) -> void:
	var key: String = sim.s["hot"][i]
	if key != "":
		game.select_item(key)


func _hover_slot(i: int) -> void:
	var key: String = sim.s["hot"][i]
	if key != "":
		show_tooltip([[D.item_name(key), Ui.GOLD]])


func cycle_hotbar(dir: int) -> void:
	var hot: Array = sim.s["hot"]
	var i := hot.find(sim.s["selected"])
	for k in SLOTS:
		i = posmod(i + dir, SLOTS)
		if hot[i] != "":
			if hot[i] != sim.s["selected"]:
				game.select_item(hot[i])
			return


# --- Events --------------------------------------------------------------------

func _on_sim_event(type: String, d: Dictionary) -> void:
	match type:
		"inventory":
			_refresh_hotbar()
			_refresh_panel()
		"money", "restocked":
			_refresh_panel()
		"harvested":
			if _panel_id == "sell":
				_refresh_panel()
		"backpack_full":
			toast("Backpack is full! Sell your harvest.", Ui.RED)
		"sold":
			toast("Sold for " + Ui.money(d["value"]), Ui.GOLD)
		"quest_done":
			toast("Quest complete! +" + Ui.money(d["quest"]["reward"]), Ui.GREEN)
		"new_day":
			_toast_new_day(d["season_changed"])
		"plant_died":
			toast("Your %s died of cold!" % d["name"], Ui.RED)
		"planted", "removed":
			_panel_dirty = _panel_id == "greenhouse"
		"weather":
			if d["id"] != "":
				toast(D.WEATHER[d["id"]]["name"] + "! " + D.WEATHER[d["id"]]["desc"], Color("#8fd8ff"))
			else:
				toast("The sky clears.", Ui.CREAM)
	if type == "restocked":
		toast("The shops have restocked!", Ui.GREEN)


func _toast_new_day(season_changed: bool) -> void:
	var season := sim.season()
	if season_changed:
		toast("%s begins! %s" % [season["name"], season["desc"]], Color(season["color"]))
	toast("Day %d: 3 new quests" % sim.day(), Ui.GREEN)
	# Autumn's last day: one day left to bring the plants in.
	if sim.season_index() == D.WINTER_SEASON - 1 and sim.season_day() == D.SEASON_DAYS:
		toast("Winter starts tomorrow! Move your plants to the Greenhouse.", Color("#bfeaff"))


func toast(text: String, color := Ui.CREAM) -> void:
	if color == Ui.RED:
		Sfx.play("error")
	if _toasts.get_child_count() > 0:
		var last: Label = _toasts.get_child(-1)
		if last.text == text:
			return
	while _toasts.get_child_count() >= 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var l := Ui.label(text, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color("#1c120a"))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 1)
	_toasts.add_child(l)
	var t := l.create_tween()
	t.tween_interval(2.6)
	t.tween_property(l, "modulate:a", 0.0, 0.4)
	t.tween_callback(l.queue_free)


func show_tooltip(lines: Array) -> void:
	for c in _tip_lines.get_children():
		_tip_lines.remove_child(c)
		c.free()
	for line in lines:
		_tip_lines.add_child(Ui.label(line[0], line[1]))
	_tip.visible = true
	_tip.reset_size()
	_place_tooltip()


func hide_tooltip() -> void:
	_tip.visible = false


func _place_tooltip() -> void:
	var m := _root.get_local_mouse_position() + Vector2(10, 10)
	var size := _tip.get_combined_minimum_size()
	var view := _root.size
	if m.x + size.x > view.x:
		m.x = view.x - size.x - 2
	if m.y + size.y > view.y:
		m.y -= size.y + 16
	_tip.position = m.round()


# --- Panels --------------------------------------------------------------------

func open_panel(id: String) -> void:
	if _panel_id == id:
		close_panel()
		return
	_remove_panel()
	Sfx.play("panel_open")
	_panel_id = id
	_panel = ShopPanels.new()
	_panel.setup(id, self, sim, SHOP_WIDTH)
	_panel_host.add_child(_panel)


func close_panel() -> void:
	if _panel:
		Sfx.play("panel_close")
	_remove_panel()


func _remove_panel() -> void:
	if _panel:
		_panel.queue_free()
	_panel = null
	_panel_id = ""


func _refresh_panel() -> void:
	if _panel:
		_panel.refresh()


func on_escape() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null
	elif _modal:
		_close_modal()
	elif _pause:
		toggle_pause()
	elif _panel:
		close_panel()
	elif sim.s["selected"] != "":
		game._cancel()
	else:
		toggle_pause()


func confirm(text: String, on_yes: Callable) -> void:
	_close_modal()
	Sfx.play("panel_open")
	_modal = _dim_layer()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var p := Ui.panel()
	center.add_child(p)
	var v := Ui.vbox(8)
	p.add_child(v)
	var l := Ui.label(text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var row := Ui.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := Ui.button("YES", "green")
	yes.custom_minimum_size.x = 56
	yes.pressed.connect(func():
		_close_modal()
		on_yes.call()
	)
	row.add_child(yes)
	var no := Ui.button("NO", "red")
	no.custom_minimum_size.x = 56
	no.pressed.connect(_close_modal)
	row.add_child(no)
	v.add_child(row)


func _close_modal() -> void:
	if _modal:
		_modal.queue_free()
	_modal = null


func _dim_layer() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	return dim


func toggle_pause() -> void:
	if _pause:
		Sfx.play("panel_close")
		_pause.queue_free()
		_pause = null
		game.paused = false
		return
	game.paused = true
	_remove_panel()
	Sfx.play("panel_open")
	_pause = _dim_layer()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var p := Ui.panel()
	center.add_child(p)
	var v := Ui.vbox(4)
	v.custom_minimum_size.x = 140
	p.add_child(v)
	var title := Ui.label("PAUSED", Ui.GOLD, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var resume := Ui.button("RESUME", "green")
	resume.pressed.connect(toggle_pause)
	v.add_child(resume)
	var settings := Ui.button("SETTINGS")
	settings.pressed.connect(_open_settings)
	v.add_child(settings)
	var save := Ui.button("SAVE GAME")
	save.pressed.connect(func():
		toast("Game saved." if Session.save_game() else "Could not save!", Ui.GREEN)
	)
	v.add_child(save)
	var quit_btn := Ui.button("SAVE & QUIT TO MENU", "red")
	quit_btn.pressed.connect(game.quit_to_menu)
	v.add_child(quit_btn)


func _open_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.closed.connect(func():
		_settings.queue_free()
		_settings = null
	)
	_root.add_child(_settings)
