extends Node
## Automated play-through for checking the game. Inactive unless launched with
##   GG_TOUR=<folder> godot --path .
## It drives the real scenes with real input events and saves screenshots there.

const D := preload("res://scripts/core/game_data.gd")

var _dir := ""
var _errors: Array[String] = []


func _ready() -> void:
	_dir = OS.get_environment("GG_TOUR")

	if _dir != "":
		_run()
	elif OS.has_environment("GG_NET_BOT"):
		add_child(load("res://tests/net_bot.gd").new())


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir + "/" + file_name + ".png")
	print("shot ", file_name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL "), what)
	if not cond:
		_errors.append(what)


func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	# Input events are in window pixels; our positions are in game pixels.
	pos *= Vector2(get_window().size) / Vector2(get_window().content_scale_size)
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	Input.parse_input_event(move)
	await get_tree().process_frame
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
		await get_tree().process_frame
	await get_tree().process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().process_frame


func _world_to_screen(game: Node2D, pos: Vector2) -> Vector2:
	return game.world.get_global_transform_with_canvas() * pos


func _find_button(root: Node, text: String) -> Button:
	if root is Button and root.text == text and root.is_visible_in_tree():
		return root
	for c in root.get_children():
		var b := _find_button(c, text)
		if b:
			return b
	return null


func _click_button(text: String) -> void:
	var b := _find_button(get_tree().root, text)
	_check(b != null, "button exists: " + text)
	if b:
		await _click(b.get_global_rect().get_center())
		await _wait(0.1)


## One whole lap of the menu's camera: steady speed, every direction, never at the world's edge.
func _check_menu_drift() -> void:
	var menu: Node = get_tree().current_scene
	var camera := menu.get_viewport().get_camera_2d()
	var half: Vector2 = menu.get_viewport_rect().size * 0.5
	var world: Vector2 = GameData.WORLD_PX
	var step := 0.1
	var slowest := INF
	var fastest := 0.0
	var dirs := {}
	var inside := true
	var last := camera.position
	for i in 700:
		menu.drift(step)
		var move: Vector2 = camera.position - last
		last = camera.position
		slowest = minf(slowest, move.length() / step)
		fastest = maxf(fastest, move.length() / step)
		dirs[Vector2i(signi(int(signf(move.x))), signi(int(signf(move.y))))] = true
		inside = inside and last.x >= half.x and last.x <= world.x - half.x and last.y >= half.y and last.y <= world.y - half.y
	print("MENU DRIFT: speed %.1f to %.1f px/s, %d directions" % [slowest, fastest, dirs.size()])
	_check(fastest - slowest < 1.0 and slowest > 15.0, "menu camera keeps one speed")
	_check(dirs.has(Vector2i(1, 1)) and dirs.has(Vector2i(-1, 1)) and dirs.has(Vector2i(-1, -1)) and dirs.has(Vector2i(1, -1)), "menu camera goes every way")
	_check(inside, "menu camera stays inside the world")


func _clear_gardens() -> void:
	for g in Session.garden_list():
		Session.delete_garden(g["path"])
	Session.delete_garden(Session.gardens_dir + Session.MAIN_FILE)


func _find_buttons(root: Node, text: String) -> Array[Button]:
	var out: Array[Button] = []
	if root is Button and root.text == text and root.is_visible_in_tree():
		out.append(root)
	for c in root.get_children():
		out.append_array(_find_buttons(c, text))
	return out


## A save from before there were several gardens must become a garden, not vanish.
func _check_old_save_adopted() -> void:
	_clear_gardens()
	var f := FileAccess.open(Session.old_save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"money": 777.0, "saved_at": 1000.0}))
	f.close()
	Session.adopt_old_save()
	var gardens := Session.garden_list()
	_check(gardens.size() == 1 and gardens[0]["money"] == 777.0, "old save becomes a garden")
	_check(not FileAccess.file_exists(Session.old_save_path), "old save file moved away")
	_clear_gardens()


func _pause_and_quit_to_menu() -> void:
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	await _click_button("SAVE & QUIT TO MENU")
	await _wait(0.8)


func _menu_line() -> String:
	return get_tree().current_scene._play_info.text


## Settings starts a garden, chooses the main one that Play opens, and deletes only what was asked.
func _check_gardens(plants: int, cash: float) -> void:
	await _pause_and_quit_to_menu()
	_check(_menu_line().begins_with("Garden 1"), "the line under Play names the main garden")
	await _shot("23b_menu_names_garden")
	await _click_button("SETTINGS")
	await _wait(0.2)
	await _click_button("NEW GARDEN")
	await _wait(3.4)
	var fresh: Node2D = get_tree().current_scene
	_check(fresh.name == "Garden", "New Garden opens a garden")
	_check(fresh.sim.s["plants"].is_empty() and fresh.sim.s["money"] == 40.0, "New Garden starts from nothing")
	_check(Session.current_garden_name() == "Garden 2", "the new garden is named Garden 2")
	fresh.sim.s["money"] = 123.0
	await _wait(1.1)
	await _pause_and_quit_to_menu()
	_check(Session.garden_list().size() == 2, "two gardens are saved")
	_check(_menu_line().begins_with("Garden 2"), "a new garden becomes the main one")
	await _click_button("SETTINGS")
	await _wait(0.2)
	await _shot("24_gardens")
	var choose := _find_buttons(get_tree().root, "SET MAIN")
	_check(choose.size() == 1, "only the other garden offers Set Main")
	if choose.size() == 1:
		await _click(choose[0].get_global_rect().get_center())
		await _wait(0.1)
	_check(Session.main_garden().get("name", "") == "Garden 1", "Set Main chooses the garden")
	await _click_button("DONE")
	await _wait(0.1)
	_check(_menu_line().begins_with("Garden 1"), "the menu shows the chosen garden")
	await _click_button("PLAY")
	await _wait(3.4)
	var old: Node2D = get_tree().current_scene
	_check(old.name == "Garden", "Play opens a garden")
	_check(old.sim.s["plants"].size() == plants and absf(float(old.sim.s["money"]) - cash) < 1.0, "Play opens the main garden, unchanged")
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	await _click_button("SETTINGS")
	await _wait(0.2)
	await _shot("25_gardens_while_playing")
	# Newest first: Garden 2, then the Garden 1 being played.
	var deletes := _find_buttons(get_tree().root, "DELETE")
	_check(deletes.size() == 2, "both gardens can be deleted")
	if deletes.size() == 2:
		await _click(deletes[1].get_global_rect().get_center())
		_check(Session.garden_list().size() == 2, "the first press only asks")
	await _click_button("SURE?")
	await _wait(0.8)
	_check(get_tree().current_scene.name == "MainMenu", "deleting the open garden returns to the menu")
	var left := Session.garden_list()
	_check(left.size() == 1 and left[0]["money"] == 123.0, "delete removes only that garden")
	_check(_menu_line().begins_with("Garden 2"), "Play moves on when the main garden is deleted")
	await _click_button("SETTINGS")
	await _wait(0.2)
	await _click_button("DELETE")
	await _click_button("SURE?")
	await _wait(0.1)
	await _click_button("DONE")
	await _wait(0.1)
	_check(Session.garden_list().is_empty() and _menu_line() == "New garden", "with no gardens Play starts a new one")


func _run() -> void:
	_check_old_save_adopted()
	await _wait(0.8)
	await _shot("01_menu")
	_check_menu_drift()
	_check(Sfx.music_mood() == "menu" and Sfx.is_music_playing(), "menu music plays")
	await _check_bus_sound("Music")
	await _click_button("GARDEN TIMES")
	await _wait(0.6)
	_check(get_tree().current_scene.name == "GardenTimes", "Garden Times opens")
	await _shot("02_garden_times")
	await _click_button("BACK TO MENU")
	await _wait(0.6)
	await _click_button("SETTINGS")
	await _wait(0.2)
	await _shot("03_settings")
	await _click_button("GRAPHICS")
	await _wait(0.1)
	await _shot("03b_settings_graphics")
	await _click_button("AUDIO")
	await _wait(0.1)
	await _shot("03c_settings_audio")
	await _check_volume_bar()
	await _click_button("DONE")
	_check(_menu_line() == "New garden", "before the first garden Play says it starts one")
	_check(_find_button(get_tree().root, "NEW GAME") == null and _find_button(get_tree().root, "GARDENS") == null, "the menu has only its four buttons")
	await _click_button("PLAY")
	await _wait(0.8)
	_check(get_tree().current_scene.name == "Loading", "Play shows loading")
	await _shot("04_loading")
	await _wait(2.6)
	var game: Node2D = get_tree().current_scene
	_check(game.name == "Garden", "Loading leads to the garden")
	var sim: GardenSim = game.sim
	await _wait(0.4)
	_check(Sfx.music_mood() == "day" and Sfx.is_music_playing(), "day music plays")
	await _shot("05_garden_start")

	# Plant exactly where clicked, with the real mouse path.
	await _key(KEY_1)
	_check(sim.s["selected"] == "seed:carrot", "key 1 selects carrot seeds")
	var bed: Rect2 = D.BEDS[0]["rect"]
	var spots := [bed.position + Vector2(180, 40), bed.position + Vector2(200, 70), bed.position + Vector2(160, 80)]
	for s: Vector2 in spots:
		await _click(_world_to_screen(game, s))
	_check(sim.s["plants"].size() == 3, "three carrots planted by clicking")
	if sim.s["plants"].size() == 3:
		var p0: Dictionary = sim.s["plants"][0]
		_check(Vector2(p0["x"], p0["y"]).distance_to(spots[0]) <= 2.0, "plant is where the click was")
	await _shot("06_planted")

	# Grow and harvest by clicking the ripe crop.
	for i in 40:
		sim.update(1.0)
	await _wait(0.4)
	await _shot("07_ripe")
	for p in sim.s["plants"].duplicate():
		await _click(_world_to_screen(game, sim.fruit_pos(p, p["fruits"][0])))
	_check(sim.s["plants"].is_empty(), "carrots harvested by clicking")
	_check(sim.s["fruits"].size() == 3, "harvest is in the backpack")

	# Right side buttons bring the gardener to the shop; E opens its window.
	await _go_and_open(game, "SELL", "sell")
	await _shot("08_sell")
	var money: float = sim.s["money"]
	var sell_all: Button = _find_button_starting(get_tree().root, "SELL ALL")
	_check(sell_all != null, "sell all button exists")
	if sell_all:
		await _click(sell_all.get_global_rect().get_center())
	_check(sim.s["fruits"].is_empty() and sim.s["money"] > money, "selling works")
	await _go_and_open(game, "SEED SHOP", "seed")
	await _shot("09_seed_shop")
	var seeds_before := sim.item_count("seed:carrot")
	await _click_button(Ui.money(D.SEEDS["carrot"]["price"]))
	_check(sim.item_count("seed:carrot") == seeds_before + 1, "buying seeds works")
	await _go_and_open(game, "GEAR SHOP", "gear")
	await _shot("10_gear_shop")
	await _key(KEY_ESCAPE)
	await _wait(0.1)
	_check(game.hud._panel_id == "", "Esc closes the shop")
	await _key(KEY_E)
	await _wait(0.1)
	_check(game.hud._panel_id == "gear", "E opens it again")
	game.world.player.position += Vector2(0, 90)
	await _wait(0.1)
	_check(game.hud._panel_id == "", "walking away closes the shop")
	await _click_button("SEED SHOP")
	await _wait(0.1)
	var prompt: Button = _find_button_starting(get_tree().root, "E   Open")
	_check(prompt != null, "standing at a shop offers a button too")
	if prompt:
		await _click(prompt.get_global_rect().get_center())
		await _wait(0.1)
	_check(game.hud._panel_id == "seed", "the button opens the shop without a keyboard")
	await _key(KEY_ESCAPE)
	await _wait(0.1)

	await _check_quests(game)
	await _check_greenhouse(game)

	# A rich garden to look at every kind of plant, then each weather.
	sim.s["money"] = 900000.0
	for i in [2, 3]:
		sim.unlock_bed(i)
	var ids: Array = D.SEEDS.keys()
	var x := 190.0
	var y := 268.0
	for id: String in ids:
		sim.add_item("seed:" + id)
		sim.plant(id, Vector2(x, y))
		x += 36.0
		if x > 390.0:
			x = 190.0
			y += 56.0
	for i in 80:
		sim.update(30.0)
		if sim.s["weather"] != "":
			sim.s["weather"] = ""
	sim.s["weather"] = ""
	sim.s["next_weather"] = 100000.0
	sim.s["time"] = D.DAY_LENGTH * 0.2
	sim.add_item("gear:godly_sprinkler")
	sim.add_item("gear:lucky_gnome")
	sim.place_gadget("godly_sprinkler", Vector2(420, 330))
	sim.place_gadget("lucky_gnome", Vector2(420, 350))
	var mut := ["golden", "rainbow", "wet", "frozen", "shocked", "moonlit", "chilled"]
	var n := 0
	for p in sim.s["plants"]:
		for f in p["fruits"]:
			if n % 2 == 0:
				f["m"] = [mut[(n / 2) % mut.size()]]
			n += 1
	game.world.player.position = Vector2(420, 400)
	game.camera.reset_smoothing()
	await _wait(0.5)
	await _shot("11_all_plants")
	await _shot_at(game, "12_gate", Vector2(480, 500))
	await _shot_at(game, "13_market", Vector2(400, 640))
	await _shot_at(game, "14_top", Vector2(480, 190))
	await _shot_at(game, "15_pond", Vector2(780, 290))
	game.world.player.position = Vector2(420, 400)
	game.camera.reset_smoothing()
	for w in ["rain", "frost", "storm", "golden_hour"]:
		sim.start_weather(w)
		await _wait(0.8)
		await _shot("20_weather_" + w)
		var loop_id: String = {"rain": "amb_rain", "storm": "amb_rain", "frost": "amb_frost"}.get(w, "amb_day")
		_check(Sfx.ambience_level(loop_id) > 0.0, "%s plays during %s" % [loop_id, w])
	await _check_bus_sound("Ambience")
	sim.sim_event.emit("strike", {"pos": Vector2(420, 400)})
	await _check_bus_sound("Sounds")
	sim.s["weather"] = ""
	await _shot_seasons(game)
	sim.s["time"] = D.DAY_LENGTH * 0.8
	await _wait(1.5)
	await _shot("21_night")
	_check(Sfx.ambience_level("amb_night") > 0.0, "crickets play at night")
	_check(Sfx.music_mood() == "night" and Sfx.is_music_playing(), "night music plays")
	await _check_bus_sound("Music")
	sim.s["time"] = D.DAY_LENGTH * 0.2

	# Walking respects the fence and enters through the gate.
	game.world.player.position = Vector2(300, 500)
	Input.action_press("ui_cancel")
	Input.action_release("ui_cancel")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_S
	e.keycode = KEY_S
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(1.0)
	e = InputEventKey.new()
	e.physical_keycode = KEY_S
	e.keycode = KEY_S
	e.pressed = false
	Input.parse_input_event(e)
	await get_tree().process_frame
	_check(game.world.player.position.y < 530.0, "fence stops the gardener (y=%d)" % game.world.player.position.y)

	# Pause, save, leave, return.
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	if not game.paused:
		await _key(KEY_ESCAPE)
		await _wait(0.2)
	_check(game.paused, "Esc pauses")
	await _shot("22_pause")
	var plants: int = sim.s["plants"].size()
	var cash: float = sim.s["money"]
	await _click_button("SAVE & QUIT TO MENU")
	await _wait(0.8)
	_check(get_tree().current_scene.name == "MainMenu", "back at the menu")
	await _click_button("PLAY")
	await _wait(3.4)
	var game2: Node2D = get_tree().current_scene
	_check(game2.name == "Garden", "returned to the garden")
	if game2.name == "Garden":
		_check(game2.sim.s["plants"].size() == plants, "plants restored from save")
		_check(absf(float(game2.sim.s["money"]) - cash) < 1.0, "money restored from save")
		await _wait(0.4)
		await _shot("23_reloaded")
		game2.world.player.position = Vector2(480, 344)
	for id: String in Sfx.SOUNDS + Sfx.LOOPS:
		var stream: AudioStream = load(Sfx.DIR + id + ".wav")
		_check(stream != null and stream.get_length() > 0.02, "sound file has content: " + id)
	for id in ["ui_click", "panel_open", "panel_close", "slot_select", "plant", "harvest", "buy", "thunder"]:
		_check(Sfx.played.has(id), "sound played: " + id)
	_check(Sfx.played.has("sell_small") or Sfx.played.has("sell_big"), "sound played: sale")
	_check(Sfx.played.has("step_grass_1") or Sfx.played.has("step_grass_2"), "sound played: footsteps")
	if game2.name == "Garden":
		await _check_gardens(plants, cash)
	_clear_gardens()
	print("TOUR ERRORS: ", _errors.size())
	for err in _errors:
		print("  - ", err)
	get_tree().quit(1 if _errors.size() > 0 else 0)


## Clicks the first volume bar, then restores the player's real setting.
func _check_volume_bar() -> void:
	var bar := _find_volume_bar(get_tree().root)
	_check(bar != null, "volume bar exists")
	if bar == null:
		return
	var key: String = bar.key
	var before: int = Settings.get_value(key)
	await _click(bar.get_global_rect().position + Vector2(bar.size.x * 0.48, 4))
	_check(Settings.get_value(key) == 50, "clicking the volume bar sets the volume (%d)" % Settings.get_value(key))
	Settings.set_value(key, before)


func _find_volume_bar(root: Node) -> Control:
	if root.get_script() == preload("res://scripts/ui/volume_bar.gd"):
		return root
	for c in root.get_children():
		var b := _find_volume_bar(c)
		if b:
			return b
	return null


## The tour mutes the master bus only, so a real signal still shows on the others.
func _check_bus_sound(bus_name: String) -> void:
	await _wait(0.25)
	var i := AudioServer.get_bus_index(bus_name)
	var peak := AudioServer.get_bus_peak_volume_left_db(i, 0)
	_check(peak > -60.0, "%s bus carries audio (%.0f dB)" % [bus_name, peak])


func _shot_at(game: Node2D, file_name: String, pos: Vector2) -> void:
	game.world.player.position = pos
	game.camera.reset_smoothing()
	await _wait(0.35)
	await _shot(file_name)


func _find_button_starting(root: Node, start: String) -> Button:
	if root is Button and root.text.begins_with(start) and root.is_visible_in_tree():
		return root
	for c in root.get_children():
		var b := _find_button_starting(c, start)
		if b:
			return b
	return null


## The button must only move the gardener; the window opens with E.
func _go_and_open(game: Node2D, button: String, place: String) -> void:
	await _click_button(button)
	await _wait(0.1)
	var stand: Vector2 = game.world.Layout.PLACES[place]["stand"]
	_check(game.world.player.position.distance_to(stand) < 8.0, button + " brings the gardener there")
	_check(game.hud._panel_id == "", button + " opens no window by itself")
	await _key(KEY_E)
	await _wait(0.1)
	_check(game.hud._panel_id == place, "E opens " + place)


func _check_quests(game: Node2D) -> void:
	var sim: GardenSim = game.sim
	var button := _find_button_starting(get_tree().root, "QUESTS")
	_check(button != null and button.text == "QUESTS %d/3" % sim.quests_done(), "the quest button shows progress")
	_check(sim.quests_done() >= 1, "the day's first quests finished by playing")
	if button:
		await _click(button.get_global_rect().get_center())
		await _wait(0.2)
	_check(game.hud._panel_id == "quests", "the quest button opens quests right away")
	await _shot("10b_quests")
	await _key(KEY_ESCAPE)
	await _wait(0.1)


## Through the real buttons: store a plant, it leaves the garden, put it back.
func _check_greenhouse(game: Node2D) -> void:
	var sim: GardenSim = game.sim
	sim.add_item("seed:carrot", 2)
	var bed: Rect2 = D.BEDS[0]["rect"]
	sim.plant("carrot", bed.position + Vector2(40, 40))
	sim.plant("carrot", bed.position + Vector2(90, 40))
	var uid: int = sim.s["plants"][0]["uid"]
	await _go_and_open(game, "GREENHOUSE", "greenhouse")
	await _wait(0.1)
	await _shot("10c_greenhouse")
	await _click_button("STORE ALL")
	await _wait(0.2)
	_check(sim.s["plants"].is_empty() and sim.s["greenhouse"].size() == 2, "Store All moves the plants inside")
	_check(game.world.plant_view(uid) == null, "they leave the garden on screen")
	await _shot("10d_greenhouse_full")
	await _click_button("TAKE OUT")
	await _wait(0.2)
	_check(sim.s["plants"].size() == 1 and sim.s["greenhouse"].size() == 1, "Take Out brings one back")
	await _click_button("PUT ALL BACK")
	await _wait(0.2)
	_check(sim.s["plants"].size() == 2 and sim.s["greenhouse"].is_empty(), "Put All Back empties it")
	_check(game.world.plant_view(uid) != null, "they are back on screen")
	await _key(KEY_ESCAPE)
	await _wait(0.1)
	for p in sim.s["plants"].duplicate():
		sim.dig_up(p)
	await _shot_at(game, "10e_greenhouse_outside", Vector2(480, 240))


func _shot_seasons(game: Node2D) -> void:
	var sim: GardenSim = game.sim
	var keep_at := Vector2(420, 400)
	for i in D.SEASONS.size():
		sim.s["time"] = D.DAY_LENGTH * (D.SEASON_DAYS * i + 0.2)
		game.world.player.position = keep_at
		game.world._season_tint.color = Color(sim.season()["tint"])
		await _wait(0.6)
		await _shot("20b_season_%d" % i)
	_check(game.hud._season_label.text.begins_with("Winter"), "the screen says it is winter")
	var dead: Dictionary = sim.s["plants"][0]
	sim.s["plants"].erase(dead)
	sim.sim_event.emit("removed", {"uid": dead["uid"]})
	sim.sim_event.emit("plant_died", {"name": sim.seed_def(dead)["name"], "pos": Vector2(dead["x"], dead["y"])})
	await _wait(0.2)
	await _shot("20c_plant_died")
	# Winter may take other plants meanwhile, so only this one is checked.
	_check(not sim.s["plants"].has(dead) and game.world.plant_view(dead["uid"]) == null, "a plant that dies disappears")
	sim.s["time"] = D.DAY_LENGTH * 0.2
	game.world._season_tint.color = Color(sim.season()["tint"])
