extends PanelContainer
## Slide-in panel for the shops, Sell Stand, Backpack, Greenhouse and Quests.

const D := preload("res://scripts/core/game_data.gd")
const TITLES := {"seed": "SEED SHOP", "gear": "GEAR SHOP", "sell": "SELL STAND", "backpack": "BACKPACK",
	"greenhouse": "GREENHOUSE", "quests": "DAILY QUESTS"}
const MAX_FRUIT_ROWS := 60
const TEXT_WIDTH := 270

var hud: CanvasLayer
var sim: GardenSim
var id := ""
var _list: VBoxContainer
var _scroll: ScrollContainer
var _subtitle: Label
var _growth_labels: Array = []
var _quests_refresh := 0.0


func setup(panel_id: String, owner_hud: CanvasLayer, garden: GardenSim, width: int) -> void:
	id = panel_id
	hud = owner_hud
	sim = garden
	# Sits to the left of the button column and above the hotbar.
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -(width + 96)
	offset_right = -96
	offset_top = 4
	offset_bottom = -52
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := Ui.vbox(4)
	add_child(v)
	var head := Ui.hbox(4)
	head.add_child(Ui.label(TITLES[id], Ui.GOLD, 16))
	head.add_child(Ui.spacer())
	var close := Ui.button("X", "red")
	close.custom_minimum_size = Vector2(18, 18)
	close.pressed.connect(hud.close_panel)
	head.add_child(close)
	v.add_child(head)
	_subtitle = Ui.label("", Ui.MUTED)
	v.add_child(_subtitle)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_list = Ui.vbox(2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	refresh()


func _process(delta: float) -> void:
	match id:
		"seed", "gear":
			_subtitle.text = "Restocks in " + Ui.time_text(sim.s["restock_in"])
		"greenhouse":
			for e: Array in _growth_labels:
				e[0].text = _growth_text(e[1])
		"quests":
			_subtitle.text = "New quests in " + Ui.time_text(sim.day_seconds_left())
			_quests_refresh -= delta
			if _quests_refresh <= 0.0:
				_quests_refresh = 0.5
				refresh()


func refresh() -> void:
	var offset := _scroll.scroll_vertical
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	match id:
		"seed":
			_fill_seeds()
		"gear":
			_fill_gear()
		"sell":
			_fill_sell()
		"backpack":
			_fill_backpack()
		"greenhouse":
			_fill_greenhouse()
		"quests":
			_fill_quests()
	_scroll.set_deferred("scroll_vertical", offset)


func _row(icon_tex: Texture2D) -> Array:
	var row := Ui.panel()
	row.add_theme_stylebox_override("panel", Ui.style("ui/slot", 4, Vector4(4, 3, 4, 3)))
	var h := Ui.hbox(5)
	row.add_child(h)
	h.add_child(Ui.icon(icon_tex))
	var text := Ui.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text)
	_list.add_child(row)
	return [h, text]


func _fill_seeds() -> void:
	for seed_id in D.SEEDS:
		var def: Dictionary = D.SEEDS[seed_id]
		var stock := int(sim.s["stock_seeds"].get(seed_id, 0))
		var parts := _row(Art.tex("item/seed/" + seed_id))
		var color := Color(D.RARITIES[def["rar"]]["color"])
		parts[1].add_child(Ui.label("%s  (%s)" % [def["name"], D.RARITIES[def["rar"]]["name"]], color))
		var info := "Grows in %s" % Ui.time_text(def["grow"])
		info += ", then every %s" % Ui.time_text(def["fruit_time"]) if def["multi"] else ", single harvest"
		parts[1].add_child(Ui.label(info, Ui.MUTED))
		var stock_text := "In stock: x%d   Sells ~%s" % [stock, Ui.money(def["value"])] if stock > 0 else "Out of stock"
		parts[1].add_child(Ui.label(stock_text, Ui.CREAM if stock > 0 else Ui.RED))
		var buy := Ui.button(Ui.money(def["price"]), "green")
		buy.custom_minimum_size = Vector2(58, 0)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.disabled = stock <= 0 or sim.s["money"] < def["price"]
		_style_disabled(buy)
		var bought_id: String = seed_id
		buy.pressed.connect(func(): _buy(sim.buy_seed(bought_id)))
		parts[0].add_child(buy)


func _fill_gear() -> void:
	for gear_id in D.GEAR:
		var def: Dictionary = D.GEAR[gear_id]
		if def.get("hidden", false):
			continue
		var parts := _row(Art.tex("item/gear/" + gear_id))
		parts[1].add_child(Ui.label(def["name"], Ui.GOLD))
		var desc := Ui.label(def["desc"], Ui.MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 170
		parts[1].add_child(desc)
		var price := sim.gear_price(gear_id)
		var available := sim.gear_available(gear_id)
		if def["kind"] == "upgrade":
			parts[1].add_child(Ui.label("Capacity: %d" % sim.s["capacity"], Ui.CREAM))
		elif def.get("perm", false):
			parts[1].add_child(Ui.label("Owned" if not available else "Yours forever", Ui.GREEN if not available else Ui.CREAM))
		else:
			var stock := int(sim.s["stock_gear"].get(gear_id, 0))
			parts[1].add_child(Ui.label("In stock: x%d" % stock if stock > 0 else "Out of stock", Ui.CREAM if stock > 0 else Ui.RED))
		var buy := Ui.button(Ui.money(price), "blue")
		buy.custom_minimum_size = Vector2(58, 0)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.disabled = not available or sim.s["money"] < price
		_style_disabled(buy)
		var bought_id: String = gear_id
		buy.pressed.connect(func(): _buy(sim.buy_gear(bought_id)))
		parts[0].add_child(buy)


func _style_disabled(b: Button) -> void:
	b.add_theme_stylebox_override("disabled", Ui.style("ui/btn_disabled", 4, Vector4(6, 3, 6, 5)))


func _buy(err: String) -> void:
	if err != "":
		hud.toast(err, Ui.RED)
	else:
		Sfx.play("buy")
	refresh()


func _fill_sell() -> void:
	var fruits: Array = sim.s["fruits"]
	var total := 0
	for f in fruits:
		total += sim.fruit_value(f)
	_subtitle.text = "%d of %d fruit in your backpack" % [fruits.size(), sim.s["capacity"]]
	var sell_all := Ui.button("SELL ALL  " + Ui.money(total), "gold")
	sell_all.disabled = fruits.is_empty()
	_style_disabled(sell_all)
	sell_all.pressed.connect(func():
		sim.sell_all()
		refresh()
	)
	_list.add_child(sell_all)
	if fruits.is_empty():
		var l := Ui.label("Nothing to sell yet.\nHarvest ripe crops and bring them here!", Ui.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(l)
		return
	# Most valuable first, without disturbing the order saved in the backpack.
	var order: Array = range(fruits.size())
	order.sort_custom(func(a, b): return sim.fruit_value(fruits[a]) > sim.fruit_value(fruits[b]))
	for n in mini(order.size(), MAX_FRUIT_ROWS):
		var i: int = order[n]
		var f: Dictionary = fruits[i]
		var parts := _row(Art.fruit_icon(f["seed"], Art.fruit_tint({"m": f["m"], "t": 1.0})))
		var color := Ui.CREAM
		if not f["m"].is_empty():
			color = Color(D.MUTATIONS[f["m"][0]]["color"])
		parts[1].add_child(Ui.label(sim.fruit_display_name(f), color))
		parts[1].add_child(Ui.label("%.2f kg" % f["w"], Ui.MUTED))
		var sell := Ui.button(Ui.money(sim.fruit_value(f)), "gold")
		sell.custom_minimum_size = Vector2(58, 0)
		sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var target := f
		sell.pressed.connect(func():
			var at: int = fruits.find(target)
			if at >= 0:
				sim.sell_fruit(at)
			refresh()
		)
		parts[0].add_child(sell)
	if order.size() > MAX_FRUIT_ROWS:
		_list.add_child(Ui.label("...and %d more" % (order.size() - MAX_FRUIT_ROWS), Ui.MUTED))


func _growth_text(p: Dictionary) -> String:
	if not sim.is_mature(p):
		return "Growing %d%%" % int(sim.growth_ratio(p) * 100.0)
	if not sim.seed_def(p)["multi"]:
		return "Ripe"
	var ripe := 0
	for f in p["fruits"]:
		if f["t"] >= 1.0:
			ripe += 1
	return "%d fruit ripe" % ripe


func _wrapped(text: String, color: Color) -> Label:
	var l := Ui.label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = TEXT_WIDTH
	return l


func _fill_greenhouse() -> void:
	_growth_labels.clear()
	var inside: Array = sim.s["greenhouse"]
	var outside: Array = sim.s["plants"].duplicate()
	outside.sort_custom(func(a, b): return int(sim.seed_def(a)["price"]) > int(sim.seed_def(b)["price"]))
	_subtitle.text = "%d of %d spots used" % [inside.size(), D.GREENHOUSE_SLOTS]
	_list.add_child(_wrapped("Plants in here grow all year and never die of cold. Take them out to harvest.", Ui.CREAM))
	var buttons := Ui.hbox(4)
	var store_all := Ui.button("STORE ALL", "green")
	store_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	store_all.disabled = outside.is_empty() or inside.size() >= D.GREENHOUSE_SLOTS
	_style_disabled(store_all)
	store_all.pressed.connect(func():
		sim.store_all()
		Sfx.play("place")
		refresh()
	)
	buttons.add_child(store_all)
	var put_back := Ui.button("PUT ALL BACK")
	put_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	put_back.disabled = inside.is_empty()
	_style_disabled(put_back)
	put_back.pressed.connect(func():
		var wanted: int = sim.s["greenhouse"].size()
		var moved := sim.take_out_all()
		if moved < wanted:
			hud.toast("%d stayed inside: their old spots are taken" % (wanted - moved), Ui.RED)
		refresh()
	)
	buttons.add_child(put_back)
	_list.add_child(buttons)
	if not inside.is_empty():
		_list.add_child(Ui.label("INSIDE", Ui.GOLD))
	for p: Dictionary in inside:
		_greenhouse_row(p, "TAKE OUT", "", func(): return sim.take_out_plant(p))
	if not outside.is_empty():
		_list.add_child(Ui.label("IN THE GARDEN", Ui.GOLD))
	for n in mini(outside.size(), MAX_FRUIT_ROWS):
		var p: Dictionary = outside[n]
		_greenhouse_row(p, "STORE", "green", func(): return sim.store_plant(p))


func _greenhouse_row(p: Dictionary, action: String, kind: String, move: Callable) -> void:
	var parts := _row(Art.tex("item/seed/" + p["seed"]))
	parts[1].add_child(Ui.label(sim.seed_def(p)["name"], Ui.CREAM))
	var growth := Ui.label(_growth_text(p), Ui.MUTED)
	parts[1].add_child(growth)
	_growth_labels.append([growth, p])
	var b := Ui.button(action, kind)
	b.custom_minimum_size = Vector2(58, 0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		var err: String = move.call()
		if err != "":
			hud.toast(err, Ui.RED)
		elif action == "STORE":
			Sfx.play("place")
		refresh()
	)
	parts[0].add_child(b)


func _quest_amount(q: Dictionary, n: float) -> String:
	return Ui.money(n) if q["money"] else Ui.number(n)


func _fill_quests() -> void:
	for q: Dictionary in sim.daily_quests():
		var done: bool = q["done"]
		var parts := _row(Art.tex("ui/quest"))
		var text: String = q["text"]
		if text.contains("%s"):
			text = text % _quest_amount(q, float(q["n"]))
		parts[1].add_child(Ui.label(text, Ui.GREEN if done else Ui.CREAM))
		var progress := "%s / %s" % [_quest_amount(q, sim.quest_progress(q)), _quest_amount(q, float(q["n"]))]
		parts[1].add_child(Ui.label(progress, Ui.MUTED))
		parts[0].add_child(Ui.label("DONE" if done else "+" + Ui.money(q["reward"]), Ui.GREEN if done else Ui.GOLD))
	var season := sim.season()
	var days_left: int = D.SEASON_DAYS - sim.season_day() + 1
	var next: Dictionary = D.SEASONS[(sim.season_index() + 1) % D.SEASONS.size()]
	_list.add_child(_wrapped("%s: %s" % [season["name"], season["desc"]], Color(season["color"])))
	_list.add_child(Ui.label("%s starts in %d day%s" % [next["name"], days_left, "" if days_left == 1 else "s"], Ui.MUTED))


func _fill_backpack() -> void:
	_subtitle.text = "Click an item to hold it"
	var keys: Array = sim.s["items"].keys()
	keys.sort()
	if keys.is_empty():
		_list.add_child(Ui.label("Your backpack is empty.", Ui.MUTED))
	for key: String in keys:
		var parts := _row(Art.item_icon(key))
		parts[1].add_child(Ui.label(D.item_name(key), Ui.CREAM))
		parts[1].add_child(Ui.label("x%d" % sim.item_count(key), Ui.MUTED))
		var hold := Ui.button("DROP" if sim.s["selected"] == key else "HOLD")
		hold.custom_minimum_size = Vector2(44, 0)
		hold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var k := key
		hold.pressed.connect(func():
			hud.game.select_item(k)
			refresh()
		)
		parts[0].add_child(hold)
