extends Node2D
## The playable garden: turns mouse and keyboard into simulation commands.

const D := preload("res://scripts/core/game_data.gd")
const Layout := preload("res://scripts/world/layout.gd")
const GardenWorld := preload("res://scripts/world/garden_world.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const RemoteCrowd := preload("res://scripts/world/remote_crowd.gd")

const SICKLE_RADIUS := 34.0
const DRAG_PLANT_STEP := 6.0
## Each quick harvest in a row climbs this pentatonic scale, as pitch multipliers.
const HARVEST_SCALE := [1.0, 1.122, 1.26, 1.498, 1.682, 2.0]
const HARVEST_COMBO_GAP := 0.7
const BIG_SALE := 1000
const RARE_MUTATIONS := {"golden": "golden", "rainbow": "rainbow", "frozen": "mutate", "shocked": "mutate"}
const FOUNTAIN_EARSHOT := 150.0

var sim: GardenSim
var world: Node2D
var hud: CanvasLayer
var camera: Camera2D
var paused := false

var _moving_plant: Dictionary = {}
var _hover_fruit: Dictionary = {}
var _hover_view: Node2D
var _last_drag := Vector2(INF, INF)
var _panning := false
var _pan_start := Vector2.ZERO
var _pan_moved := 0.0
var _harvest_combo := 0
var _last_harvest := -100.0


func _ready() -> void:
	if Session.sim == null:
		Session.load_game()
	sim = Session.sim
	world = GardenWorld.new()
	add_child(world)
	world.setup(sim, true)
	world.overlay.draw.connect(_draw_overlay)

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(D.WORLD_PX.x)
	camera.limit_bottom = int(D.WORLD_PX.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	world.player.add_child(camera)
	camera.make_current()
	camera.reset_smoothing()

	hud = Hud.new()
	hud.game = self
	add_child(hud)

	sim.sim_event.connect(_on_sim_event)
	_update_held()
	if Net.link:
		var crowd := RemoteCrowd.new()
		add_child(crowd)
		crowd.setup(Net.link, world)
	if Session.away_seconds > 60.0:
		hud.toast("%s: welcome back! You were away for %s." % [Session.current_garden_name(), Ui.time_text(minf(Session.away_seconds, 43200.0))], Ui.GREEN)
		Session.away_seconds = 0.0
	else:
		hud.toast(Session.current_garden_name(), Ui.GREEN)


func _exit_tree() -> void:
	Sfx.set_ambience({})
	if sim and world and world.player:
		sim.s["player"] = [world.player.position.x, world.player.position.y]


func _process(delta: float) -> void:
	# Others are still playing, so a shared garden doesn't stop for the pause menu.
	if not paused or Net.link:
		sim.update(delta)
	sim.s["player"] = [world.player.position.x, world.player.position.y]
	if Net.link:
		Net.link.send_move(world.player.position, world.player.velocity)
	world.player.input_enabled = not paused
	_update_hover()
	if not _panning:
		camera.offset = camera.offset.move_toward(Vector2.ZERO, delta * (240.0 if world.player.velocity.length() > 1.0 else 0.0))
	world.overlay.queue_redraw()
	_update_ambience()


func _update_ambience() -> void:
	var w: String = sim.s["weather"]
	var night: float = sim.night_factor() if Settings.get_value("day_night") else 0.0
	Sfx.set_music("night" if night > 0.5 else "day")
	# Birds and crickets go quiet under bad weather.
	var calm := 0.25 if w in ["rain", "storm", "frost"] else 1.0
	var from_fountain: float = world.player.position.distance_to(D.FOUNTAIN)
	Sfx.set_ambience({
		"amb_day": (1.0 - night) * calm,
		"amb_night": night * calm,
		"amb_rain": 1.0 if w == "storm" else (0.7 if w == "rain" else 0.0),
		"amb_frost": 1.0 if w == "frost" else 0.0,
		"amb_fountain": clampf(1.0 - from_fountain / FOUNTAIN_EARSHOT, 0.0, 1.0) * 0.8,
	})


func mouse_world() -> Vector2:
	return world.get_global_mouse_position()


func selected() -> String:
	return sim.s["selected"]


func _selected_kind() -> String:
	var key := selected()
	if key == "":
		return ""
	if key.begins_with("seed:"):
		return "seed"
	return D.GEAR[key.split(":")[1]]["kind"]


func _selected_id() -> String:
	var key := selected()
	return key.split(":")[1] if key != "" else ""


# --- Hover ---------------------------------------------------------------------

func _pointer_free() -> bool:
	return get_viewport().gui_get_hovered_control() == null


func _update_hover() -> void:
	var hit := {}
	if _pointer_free() and not paused:
		hit = sim.pick_ripe(mouse_world())
	var new_fruit: Dictionary = hit.get("fruit", {})
	var new_view: Node2D = world.plant_view(hit["plant"]["uid"]) if not hit.is_empty() else null
	if _hover_view and is_instance_valid(_hover_view) and _hover_view != new_view:
		_hover_view.hovered_fruit = {}
	if new_view:
		new_view.hovered_fruit = new_fruit
	_hover_view = new_view
	_hover_fruit = new_fruit
	_update_tooltip()


func _update_tooltip() -> void:
	if paused or not _pointer_free() or not Settings.get_value("tooltips"):
		hud.hide_tooltip()
		return
	var pos := mouse_world()
	var p := sim.pick_plant(pos)
	if not p.is_empty():
		hud.show_tooltip(_plant_tooltip(p))
		return
	var place := _place_at(pos)
	if place != "":
		hud.show_tooltip([[Layout.PLACES[place]["name"], Ui.GOLD], ["Press E nearby", Ui.MUTED]])
		return
	var g := sim.pick_gadget(pos)
	if not g.is_empty():
		hud.show_tooltip([[D.GEAR[g["id"]]["name"], Ui.GOLD], [Ui.time_text(g["left"]) + " left", Ui.MUTED]])
		return
	hud.hide_tooltip()


func _plant_tooltip(p: Dictionary) -> Array:
	var def := sim.seed_def(p)
	var lines: Array = [[def["name"], Color(D.RARITIES[def["rar"]]["color"])]]
	if not sim.is_mature(p):
		var left: float = (p["grow"] - p["age"]) / sim.growth_speed(p)
		lines.append(["Growing %d%% - %s" % [int(sim.growth_ratio(p) * 100.0), Ui.time_text(left)], Ui.MUTED])
	elif def["multi"]:
		var ripe := 0
		for f in p["fruits"]:
			if f["t"] >= 1.0:
				ripe += 1
		lines.append(["%d ripe, %d growing" % [ripe, p["fruits"].size() - ripe], Ui.MUTED])
	else:
		lines.append(["Ripe! Click to harvest", Ui.GREEN])
	if not _hover_fruit.is_empty():
		var item: Dictionary = {"seed": p["seed"], "w": _hover_fruit["w"], "m": _hover_fruit["m"]}
		lines.append(["%s  %.2f kg" % [sim.fruit_display_name(item), item["w"]], Ui.CREAM])
		lines.append(["Worth " + Ui.money(sim.fruit_value(item)), Ui.GOLD])
	return lines


# --- Overlay: placement ghost and area rings ------------------------------------

func _draw_overlay() -> void:
	var o: Node2D = world.overlay
	var pos := mouse_world().round()
	var free := _pointer_free() and not paused
	var kind := _selected_kind()
	if not _moving_plant.is_empty():
		var seed_id: String = _moving_plant["seed"]
		_draw_ghost(o, seed_id, pos, sim.can_plant(seed_id, pos, _moving_plant["uid"]) == "")
	elif free and kind == "seed" and _hover_fruit.is_empty():
		_draw_ghost(o, _selected_id(), pos, sim.can_plant(_selected_id(), pos) == "")
	elif free and kind == "place":
		var ok := D.fence_inner().has_point(pos)
		var r: float = D.GEAR[_selected_id()]["radius"]
		_ring(o, pos, r, Color("#8ee05a") if ok else Color("#ff6a50"))
		Art.draw(o, "gadget/" + _selected_id(), pos, Color(1, 1, 1, 0.75))
	elif free and kind == "sickle":
		_ring(o, pos, SICKLE_RADIUS, Color("#ffd23f"))
	elif free and kind in ["shovel", "water", "trowel"]:
		var p := sim.pick_plant(mouse_world())
		if not p.is_empty():
			_ring(o, Vector2(p["x"], p["y"]), float(sim.seed_def(p)["r"]) + 2.0, Color("#ff6a50") if kind == "shovel" else Color("#8fd8ff"))
	# Show every placed gear's range while holding gear, so overlaps are easy to plan.
	if kind == "place":
		for g in sim.s["gadgets"]:
			_ring(o, Vector2(g["x"], g["y"]), D.GEAR[g["id"]]["radius"], Color(1, 1, 1, 0.3))


func _draw_ghost(o: Node2D, seed_id: String, pos: Vector2, ok: bool) -> void:
	var r: float = D.SEEDS[seed_id]["r"]
	var c := Color("#8ee05a") if ok else Color("#ff6a50")
	Art.draw(o, "plant/%s/0/0" % seed_id, pos, Color(1, 1, 1, 0.85) if ok else Color(1, 0.5, 0.45, 0.7))
	_ring(o, pos, r, c)


func _ring(o: Node2D, center: Vector2, r: float, c: Color) -> void:
	# Dotted pixel ring.
	var steps := int(r * 1.6) + 6
	for i in steps:
		var a := i * TAU / steps
		var p := center + Vector2(cos(a) * r, sin(a) * r * 0.7)
		o.draw_rect(Rect2(p.round(), Vector2.ONE), c)


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if paused:
		return
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion:
		_mouse_motion(event)


func _event_world(e: InputEventMouse) -> Vector2:
	return world.get_global_transform_with_canvas().affine_inverse() * e.position


func _mouse_button(e: InputEventMouseButton) -> void:
	match e.button_index:
		MOUSE_BUTTON_LEFT:
			if e.pressed:
				_last_drag = Vector2(INF, INF)
				_primary_click(_event_world(e))
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if e.pressed:
				_panning = true
				_pan_start = e.position
				_pan_moved = 0.0
			else:
				_panning = false
				if _pan_moved < 4.0 and e.button_index == MOUSE_BUTTON_RIGHT:
					_cancel()
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed:
				hud.cycle_hotbar(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				hud.cycle_hotbar(1)


func _mouse_motion(e: InputEventMouseMotion) -> void:
	if _panning:
		_pan_moved += e.relative.length()
		var half := get_viewport_rect().size * 0.5
		camera.offset = (camera.offset - e.relative).clamp(-half, half)
		return
	if e.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_sweep(_event_world(e))


## Holding the button: keep harvesting what passes under it, keep planting.
func _sweep(pos: Vector2) -> void:
	var hit := sim.pick_ripe(pos)
	if not hit.is_empty() and _selected_kind() not in ["shovel", "water", "trowel"]:
		sim.harvest(hit["plant"], hit["fruit"])
		return
	if _selected_kind() == "seed" and Settings.get_value("drag_plant") and _moving_plant.is_empty():
		if pos.distance_to(_last_drag) >= DRAG_PLANT_STEP and sim.can_plant(_selected_id(), pos) == "":
			_last_drag = pos
			sim.plant(_selected_id(), pos)
			_update_held()
	elif _selected_kind() == "sickle":
		sim.harvest_area(pos, SICKLE_RADIUS)


func _primary_click(pos: Vector2) -> void:
	world.player.face(pos)
	if not _moving_plant.is_empty():
		_finish_move(pos)
		return
	var kind := _selected_kind()
	match kind:
		"shovel":
			_use_shovel(pos)
			return
		"water":
			_report(_use_on_plant(pos, func(p): return sim.water(p)))
			return
		"trowel":
			var p := sim.pick_plant(pos)
			if p.is_empty():
				hud.toast("Click a plant to move it", Ui.MUTED)
			else:
				_moving_plant = p
				hud.toast("Click a new spot for your " + sim.seed_def(p)["name"], Ui.CREAM)
			return
		"sickle":
			var n := sim.harvest_area(pos, SICKLE_RADIUS)
			if n == 0:
				hud.toast("Nothing ripe here", Ui.MUTED)
			return
		"place":
			_report(sim.place_gadget(_selected_id(), pos))
			return
		"totem":
			_report(sim.use_totem(_selected_id()))
			return
	# Harvesting always wins over planting: ripe fruit under the cursor comes first.
	var hit := sim.pick_ripe(pos)
	if not hit.is_empty():
		_report(sim.harvest(hit["plant"], hit["fruit"]))
		return
	var bed := sim.bed_at(pos)
	if bed >= 0 and not sim.s["beds"][bed]:
		_offer_bed(bed)
		return
	if kind == "seed":
		_last_drag = pos
		_report(sim.plant(_selected_id(), pos))
		_update_held()
		return
	var place := _place_at(pos)
	if place != "":
		if Layout.place_near(world.player.position) == place:
			hud.open_panel(place)
		else:
			world.player.walk_to(Layout.PLACES[place]["stand"])
		return
	if bed >= 0:
		var p := sim.pick_plant(pos)
		if p.is_empty():
			hud.toast("Pick a seed first (keys 1-9)", Ui.MUTED)
		return
	world.player.walk_to(pos)


## Which shop or building is drawn at this spot.
func _place_at(pos: Vector2) -> String:
	for st in Layout.STALLS:
		if Rect2(st["pos"] + Vector2(-46, -78), Vector2(92, 80)).has_point(pos):
			return st["id"]
	if Rect2(Layout.GREENHOUSE_POS + Vector2(-66, -95), Vector2(132, 100)).has_point(pos):
		return "greenhouse"
	return ""


## The side buttons bring the gardener to a place. Already there, they open it.
func go_to_place(id: String) -> void:
	if Layout.place_near(world.player.position) == id:
		hud.open_panel(id)
		return
	hud.close_panel()
	var player: CharacterBody2D = world.player
	var stand: Vector2 = Layout.PLACES[id]["stand"]
	var puff := [Color.WHITE, Color("#c8ecff")]
	world.fx.burst(player.position, puff, 8, 30.0)
	player.position = stand
	player.stop_walking()
	player.face(stand + Vector2.UP)
	camera.offset = Vector2.ZERO
	camera.reset_smoothing()
	world.fx.burst(stand, puff, 8, 30.0)
	Sfx.play("slot_select", 1.3)


## What E does: open the place the gardener stands at, otherwise harvest around them.
func interact() -> void:
	var place := Layout.place_near(world.player.position)
	if place != "":
		hud.open_panel(place)
	else:
		_harvest_near_player()


func _use_on_plant(pos: Vector2, action: Callable) -> String:
	var p := sim.pick_plant(pos)
	if p.is_empty():
		return "Click on a plant"
	return action.call(p)


func _use_shovel(pos: Vector2) -> void:
	var p := sim.pick_plant(pos)
	if not p.is_empty():
		var def := sim.seed_def(p)
		var worth_asking: bool = Settings.get_value("confirm_shovel") and int(def["price"]) >= 400
		if worth_asking:
			hud.confirm("Dig up this %s?\nThe plant will be lost." % def["name"], func(): sim.dig_up(p))
		else:
			sim.dig_up(p)
		return
	var g := sim.pick_gadget(pos)
	if not g.is_empty():
		sim.remove_gadget(g)
		return
	hud.toast("Click a plant to dig it up", Ui.MUTED)


func _finish_move(pos: Vector2) -> void:
	var err := sim.move_plant(_moving_plant, pos)
	if err != "":
		_report(err)
		return
	_moving_plant = {}


func _offer_bed(i: int) -> void:
	var price: int = D.BEDS[i]["price"]
	hud.confirm("Clear this plot for %s?\nYou can plant on it afterwards." % Ui.money(price), func():
		var err := sim.unlock_bed(i)
		if err != "":
			hud.toast(err, Ui.RED)
		else:
			hud.toast("New garden bed unlocked!", Ui.GREEN)
	)


func _report(err: String) -> void:
	if err != "":
		hud.toast(err, Ui.RED)


func _cancel() -> void:
	if not _moving_plant.is_empty():
		_moving_plant = {}
		return
	if selected() != "":
		Sfx.play("slot_select", 0.8)
	sim.select_item("")
	_update_held()


func select_item(key: String) -> void:
	_moving_plant = {}
	Sfx.play("slot_select", 0.8 if selected() == key else 1.0)
	sim.select_item("" if selected() == key else key)
	_update_held()


func _update_held() -> void:
	var key := selected()
	world.player.set_held(Art.item_icon(key) if key != "" else null)


func _on_sim_event(type: String, d: Dictionary) -> void:
	match type:
		"inventory":
			_update_held()
		"removed":
			if not _moving_plant.is_empty() and _moving_plant["uid"] == d["uid"]:
				_moving_plant = {}
			if d.get("dug", false):
				Sfx.play("dig")
		"planted", "moved":
			Sfx.play("plant")
		"harvested":
			_harvest_sound(d["fruit"])
		"watered":
			Sfx.play("water")
		"gadget_added":
			Sfx.play("place")
		"gadget_removed":
			Sfx.play("place", 0.8)
		"sold":
			Sfx.play("sell_big" if d["value"] >= BIG_SALE else "sell_small")
		"restocked":
			Sfx.play("restock")
		"quest_done":
			Sfx.play("quest")
		"bed_unlocked":
			Sfx.play("bed_unlock")
		"strike":
			Sfx.play("thunder")
		"ripe":
			Sfx.play("ripe")
		"mutated":
			# Common weather marks would be constant, so only rare ones sound.
			if RARE_MUTATIONS.has(d["mutation"]):
				Sfx.play(RARE_MUTATIONS[d["mutation"]])


func _harvest_sound(fruit: Dictionary) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_harvest_combo = _harvest_combo + 1 if now - _last_harvest < HARVEST_COMBO_GAP else 0
	_last_harvest = now
	Sfx.play("harvest", HARVEST_SCALE[mini(_harvest_combo, HARVEST_SCALE.size() - 1)])
	for m: String in ["rainbow", "golden"]:
		if m in fruit["m"]:
			Sfx.play(m)
			return


func _unhandled_key_input(event: InputEvent) -> void:
	var e := event as InputEventKey
	if e == null or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE:
		hud.on_escape()
		return
	if paused:
		return
	if e.keycode >= KEY_1 and e.keycode <= KEY_9:
		var key: String = sim.s["hot"][e.keycode - KEY_1]
		if key != "":
			select_item(key)
		return
	match e.keycode:
		KEY_Q:
			_cancel()
		KEY_E:
			interact()
		KEY_Z:
			go_to_place("seed")
		KEY_X:
			go_to_place("gear")
		KEY_C:
			go_to_place("sell")
		KEY_G:
			go_to_place("greenhouse")
		KEY_B, KEY_TAB:
			hud.open_panel("backpack")
		KEY_J:
			hud.open_panel("quests")


func _harvest_near_player() -> void:
	var n := sim.harvest_area(world.player.position + Vector2(0, -8), 26.0)
	if n == 0:
		hud.toast("No ripe fruit within reach", Ui.MUTED)


func quit_to_menu() -> void:
	var shared := Net.link != null
	Session.save_game()
	await Net.leave_link()
	Session.leave_game()
	Session.go_to("res://scenes/garden_times.tscn" if shared else "res://scenes/main_menu.tscn")
