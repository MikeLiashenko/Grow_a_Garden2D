extends SceneTree
## Rules tests. Run: godot --headless --path . --script tests/test_sim.gd

const D := preload("res://scripts/core/game_data.gd")
var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func _init() -> void:
	test_planting()
	test_harvest_and_sell()
	test_multi_regrow()
	test_shops()
	test_mutations()
	test_save_roundtrip()
	test_legacy_save()
	test_all_content()
	test_seasons()
	test_winter_and_greenhouse()
	test_daily_quests()
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)


func test_planting() -> void:
	print("planting")
	var g := GardenSim.new()
	var bed: Rect2 = D.BEDS[0]["rect"]
	var pos := bed.get_center()
	check(g.plant("carrot", pos) == "", "plants inside an unlocked bed")
	var p: Dictionary = g.s["plants"][0]
	check(p["x"] == roundf(pos.x) and p["y"] == roundf(pos.y), "grows exactly where clicked")
	check(g.plant("carrot", pos) != "", "refuses overlapping plant")
	check(g.plant("carrot", Vector2(5, 5)) != "", "refuses outside beds")
	check(g.plant("carrot", (D.BEDS[2]["rect"] as Rect2).get_center()) != "", "refuses locked bed")
	check(g.item_count("seed:carrot") == 2, "consumes exactly one seed")
	check(g.plant("tulip", pos + Vector2(40, 0)) != "", "refuses seeds you don't own")


func test_harvest_and_sell() -> void:
	print("harvest and sell")
	var g := GardenSim.new()
	var pos := (D.BEDS[0]["rect"] as Rect2).get_center()
	g.plant("carrot", pos)
	var p: Dictionary = g.s["plants"][0]
	check(g.pick_ripe(pos + Vector2(0, -6)).is_empty(), "unripe is not pickable")
	for i in 40:
		g.update(1.0)
	check(g.is_mature(p), "matures with time")
	var hit := g.pick_ripe(g.fruit_pos(p, p["fruits"][0]))
	check(not hit.is_empty(), "ripe fruit is pickable")
	check(g.harvest(hit["plant"], hit["fruit"]) == "", "harvest works")
	check(g.s["plants"].is_empty(), "single-harvest plant is removed")
	check(g.s["fruits"].size() == 1, "fruit goes to backpack")
	var before: float = g.s["money"]
	var value := g.fruit_value(g.s["fruits"][0])
	check(g.sell_all() == value and g.s["money"] >= before + value, "selling pays out")
	check(g.s["fruits"].is_empty(), "backpack is emptied")


func test_multi_regrow() -> void:
	print("multi-harvest")
	var g := GardenSim.new()
	g.add_item("seed:strawberry")
	var pos := (D.BEDS[0]["rect"] as Rect2).get_center()
	g.plant("strawberry", pos)
	var p: Dictionary = g.s["plants"][0]
	for i in 200:
		g.update(1.0)
	var ripe: Array = p["fruits"].filter(func(f): return f["t"] >= 1.0)
	check(ripe.size() == D.SEEDS["strawberry"]["slots"].size(), "all slots fruit")
	check(g.harvest(p, ripe[0]) == "", "harvest fruit")
	check(g.s["plants"].size() == 1, "plant survives harvest")
	for i in 60:
		g.update(1.0)
	check(p["fruits"].size() == D.SEEDS["strawberry"]["slots"].size(), "fruit regrows")
	g.s["capacity"] = g.s["fruits"].size()
	check(g.harvest(p, p["fruits"][0]) != "", "full backpack refuses harvest")


func test_shops() -> void:
	print("shops")
	var g := GardenSim.new()
	g.s["money"] = 100000.0
	g.s["stock_seeds"]["carrot"] = 1
	check(g.buy_seed("carrot") == "", "buys in-stock seed")
	check(g.buy_seed("carrot") != "", "out of stock refused")
	g.s["money"] = 0.0
	g.s["stock_seeds"]["carrot"] = 5
	check(g.buy_seed("carrot") != "", "no money refused")
	g.s["money"] = 100000.0
	var cap: int = g.s["capacity"]
	var price := g.backpack_price()
	check(g.buy_gear("backpack") == "", "buy upgrade")
	check(g.s["capacity"] == cap + 50 and g.backpack_price() == price * 2, "upgrade applies and price doubles")
	check(g.buy_gear("golden_sickle") == "", "buy tool")
	check(g.buy_gear("golden_sickle") != "", "permanent tool bought once")
	g.s["money"] = 10000000.0
	check(g.unlock_bed(2) == "" and g.s["beds"][2], "unlock bed")
	check(g.plant("carrot", (D.BEDS[2]["rect"] as Rect2).get_center()) == "", "new bed accepts plants")


func test_mutations() -> void:
	print("mutations")
	var g := GardenSim.new()
	_set_season(g, 2)
	var pos := (D.BEDS[0]["rect"] as Rect2).get_center()
	g.plant("carrot", pos)
	var p: Dictionary = g.s["plants"][0]
	var f: Dictionary = p["fruits"][0]
	f["m"] = []
	f["w"] = D.SEEDS["carrot"]["kg"]
	var base := g.fruit_value(f)
	g._add_mutation(p, f, "wet")
	check(g.fruit_value(f) == base * 2, "wet doubles value")
	g._add_mutation(p, f, "chilled")
	check("frozen" in f["m"] and "wet" not in f["m"], "wet + chilled = frozen")
	check(g.fruit_value(f) == base * 10, "frozen is x10")
	g.s["weather"] = "rain"
	check(g.growth_speed(p) == 1.5, "rain speeds growth")
	g.s["weather"] = ""
	g.add_item("gear:godly_sprinkler")
	g.place_gadget("godly_sprinkler", pos + Vector2(10, 0))
	check(g.growth_speed(p) == 2.0, "sprinkler speeds growth")
	for i in 301:
		g.update(1.0)
	check(g.s["gadgets"].is_empty(), "sprinkler expires")


func test_save_roundtrip() -> void:
	print("save")
	var g := GardenSim.new()
	var pos := (D.BEDS[0]["rect"] as Rect2).get_center()
	g.plant("carrot", pos)
	g.add_item("seed:strawberry", 2)
	var text := JSON.stringify(g.to_save())
	var g2 := GardenSim.new(JSON.parse_string(text))
	check(g2.s["plants"].size() == 1, "plants survive")
	check(g2.item_count("seed:strawberry") == 2, "items survive")
	var p: Dictionary = g2.s["plants"][0]
	var clock: float = g2.s["time"]
	g2.advance_offline(1000.0)
	check(g2.is_mature(p), "offline growth")
	check(g2.s["time"] == clock, "days do not pass while away")
	var old_save: Dictionary = JSON.parse_string(text)
	old_save.erase("played_days")
	old_save["time"] = D.DAY_LENGTH * 100.25
	var old_game := GardenSim.new(old_save)
	check(is_equal_approx(old_game.s["time"], D.DAY_LENGTH * 0.25), "old saves restart the day count and keep the hour")
	var new_save: Dictionary = JSON.parse_string(JSON.stringify(old_game.to_save()))
	new_save["time"] = D.DAY_LENGTH * 3.5
	check(is_equal_approx(GardenSim.new(new_save).s["time"], D.DAY_LENGTH * 3.5), "played days survive saving")
	var hit := g2.pick_ripe(g2.fruit_pos(p, p["fruits"][0]))
	check(not hit.is_empty() and g2.harvest(hit["plant"], hit["fruit"]) == "", "harvest after loading")
	check(g2.plant("strawberry", pos) == "", "plant after loading")


func test_legacy_save() -> void:
	print("old saves")
	var g := GardenSim.new()
	var pos := (D.BEDS[0]["rect"] as Rect2).get_center()
	g.plant("carrot", pos)
	g.s["fruits"].append({"seed": "strawberry", "w": 0.3, "m": []})
	g.s["selected"] = "seed:carrot"
	g.s["stats"]["planted_strawberry"] = 2.0
	# Turn it back into a save from the invented-plants version.
	var text := JSON.stringify(g.to_save()).replace("carrot", "sunroot").replace("strawberry", "jellyberry")
	var old: GardenSim = GardenSim.new(JSON.parse_string(text))
	check(old.s["plants"][0]["seed"] == "carrot", "planted sunroot becomes carrot")
	check(old.s["plants"][0]["fruits"][0]["seed"] == "carrot", "its fruit too")
	check(old.s["fruits"][0]["seed"] == "strawberry", "backpack fruit is renamed")
	check(old.item_count("seed:carrot") == 2 and not old.s["items"].has("seed:sunroot"), "seed stack is renamed")
	check("seed:carrot" in old.s["hot"] and old.s["selected"] == "seed:carrot", "hotbar and held item are renamed")
	check(old.s["stock_seeds"].has("carrot") and not old.s["stock_seeds"].has("sunroot"), "shop stock is renamed")
	check(old.stat("planted_strawberry") == 2.0, "plant counts are kept")
	check(old.fruit_value(old.s["fruits"][0]) > 0, "renamed fruit can be priced")
	var older := GardenSim.new({"plants": [], "items": {"seed:moon": 1}, "hot": ["seed:moon"], "stock_seeds": {"moon": 1}})
	check(older.item_count("seed:starfall") == 1, "moon blossom becomes starfall")
	for id in D.LEGACY_SEEDS:
		check(D.SEEDS.has(D.LEGACY_SEEDS[id]), "legacy target exists: " + id)

func test_all_content() -> void:
	print("content")
	var g := GardenSim.new()
	var bed: Rect2 = D.BEDS[0]["rect"]
	for id in D.SEEDS:
		var def: Dictionary = D.SEEDS[id]
		g.s["plants"].clear()
		g.add_item("seed:" + id)
		check(g.plant(id, bed.get_center()) == "", "plants " + id)
		var p: Dictionary = g.s["plants"][0]
		_set_season(g, 0)
		for i in 120:
			g.update(30.0)
		check(g.is_mature(p) and not p["fruits"].is_empty(), id + " produces fruit")
		g.s["fruits"].clear()
		var f: Dictionary = p["fruits"][0]
		check(f["t"] >= 1.0 and g.harvest(p, f) == "", id + " harvests")
		g.s["weather"] = ""
	# Every seed must pay back: single-harvest within one crop at average size.
	for id in D.SEEDS:
		var def: Dictionary = D.SEEDS[id]
		if not def["multi"]:
			check(float(def["value"]) > float(def["price"]), id + " sells above seed price")


## Puts the clock on the first morning of a season.
func _set_season(g: GardenSim, index: int) -> void:
	g.s["time"] = D.DAY_LENGTH * (D.SEASON_DAYS * index + 0.1)


func test_seasons() -> void:
	print("seasons")
	var g := GardenSim.new()
	check(g.day() == 1 and g.season()["name"] == "Spring" and g.season_day() == 1, "the game starts on spring's first day")
	g.s["time"] = D.DAY_LENGTH * (D.SEASON_DAYS - 0.5)
	check(g.season()["name"] == "Spring" and g.season_day() == D.SEASON_DAYS, "spring lasts until its last day")
	g.s["time"] = D.DAY_LENGTH * D.SEASON_DAYS
	check(g.season()["name"] == "Summer" and g.season_day() == 1, "then summer comes")
	_set_season(g, 3)
	check(g.is_winter(), "winter is the fourth season")
	_set_season(g, 4)
	check(g.season()["name"] == "Spring", "and the year starts over")
	g.plant("carrot", (D.BEDS[0]["rect"] as Rect2).get_center())
	var p: Dictionary = g.s["plants"][0]
	_set_season(g, 1)
	var summer := g.growth_speed(p)
	_set_season(g, 3)
	check(g.growth_speed(p) < summer, "plants grow slower in winter than in summer")
	_set_season(g, 3)
	var kinds := {}
	for i in 200:
		g._roll_weather()
		kinds[g.s["weather"]] = true
	check(not kinds.has("rain") and not kinds.has("storm"), "no rain or storms in winter")
	_set_season(g, 1)
	kinds.clear()
	for i in 200:
		g._roll_weather()
		kinds[g.s["weather"]] = true
	check(not kinds.has("frost"), "no frost in summer")


func test_winter_and_greenhouse() -> void:
	print("winter and greenhouse")
	var g := GardenSim.new()
	var bed: Rect2 = D.BEDS[0]["rect"]
	g.s["items"]["seed:carrot"] = 40
	for i in 30:
		g.plant("carrot", bed.position + Vector2(14 + (i % 10) * 20, 14 + (i / 10) * 30))
	var count: int = g.s["plants"].size()
	check(count == 30, "a full bed is planted")
	var kept: Dictionary = g.s["plants"][0]
	var spot := Vector2(kept["x"], kept["y"])
	check(g.store_plant(kept) == "", "a plant goes into the greenhouse")
	check(g.s["greenhouse"].has(kept) and not g.s["plants"].has(kept), "it left the garden")
	var age: float = kept["age"]
	_set_season(g, 0)
	for i in 3000:
		g.s["weather"] = ""
		g.s["next_weather"] = 1000.0
		g.update(1.0)
		g.s["time"] = D.DAY_LENGTH * 0.1
	check(g.s["plants"].size() == count - 1, "nothing dies outside winter")
	check(float(kept["age"]) > age, "stored plants keep growing")
	var died := []
	g.sim_event.connect(func(type: String, d: Dictionary): if type == "plant_died": died.append(d))
	for i in 30000:
		g.s["weather"] = "frost"
		g.s["weather_left"] = 100.0
		g.s["time"] = D.DAY_LENGTH * (D.SEASON_DAYS * 3 + 0.1)
		g._winter_tick()
	check(g.s["plants"].is_empty() and died.size() == count - 1, "winter kills plants outside")
	check(g.s["greenhouse"].size() == 1, "but never inside the greenhouse")
	g.s["items"]["seed:carrot"] = 5
	g.plant("carrot", spot)
	check(g.take_out_plant(kept) != "" and g.s["greenhouse"].has(kept), "a taken spot refuses the plant")
	g.dig_up(g.s["plants"][0])
	check(g.take_out_plant(kept) == "" and g.s["plants"].has(kept), "it goes back to its spot")
	check(g.pick_plant(spot) == kept, "and can be picked again")
	check(g.store_all() == 1 and g.take_out_all() == 1, "store all and put back all")
	# Offline: the greenhouse grows too and nothing dies.
	var h := GardenSim.new()
	h.plant("carrot", bed.get_center())
	h.plant("carrot", bed.get_center() + Vector2(40, 0))
	var inside: Dictionary = h.s["plants"][0]
	h.store_plant(inside)
	_set_season(h, 3)
	h.advance_offline(36000.0)
	check(h.is_mature(inside), "stored plants grow while away")
	check(h.s["plants"].size() == 1, "winter does not kill while away")
	var loaded := GardenSim.new(JSON.parse_string(JSON.stringify(h.to_save())))
	check(loaded.s["greenhouse"].size() == 1 and loaded.s["greenhouse"][0]["uid"] is int, "the greenhouse survives saving")
	var old := GardenSim.new({"money": 5.0, "plants": [], "quest": 4, "items": {}})
	check(old.s["greenhouse"].is_empty() and old.daily_quests().size() == D.DAILY_QUEST_COUNT and not old.s.has("quest"), "saves from before seasons load")
	# Capacity.
	var full := GardenSim.new()
	full.s["greenhouse"].resize(D.GREENHOUSE_SLOTS)
	full.plant("carrot", bed.get_center())
	check(full.store_plant(full.s["plants"][0]) != "", "a full greenhouse refuses")


func test_daily_quests() -> void:
	print("daily quests")
	var g := GardenSim.new()
	check(g.daily_quests().size() == 3, "three quests on the first day")
	var planting: Dictionary = g.daily_quests()[0]
	check(planting["stat"] == "planted", "the first day teaches planting first")
	var money: float = g.s["money"]
	var bed: Rect2 = D.BEDS[0]["rect"]
	g.s["items"]["seed:carrot"] = 3
	for i in 3:
		g.plant("carrot", bed.position + Vector2(20 + i * 40, 40))
	check(g.quest_progress(planting) == 3.0, "planting counts towards it")
	g.update(1.1)
	check(planting["done"] and g.s["money"] == money + planting["reward"], "a finished quest pays")
	g.update(1.1)
	check(g.s["money"] == money + planting["reward"] and g.quests_done() == 1, "and pays only once")
	var seen := []
	g.sim_event.connect(func(type: String, _d: Dictionary): if type == "new_day": seen.append(g.day()))
	g.s["time"] = D.DAY_LENGTH + 1.0
	g.update(0.1)
	check(seen == [2], "a new day is announced")
	check(g.quests_done() == 0 and g.daily_quests().size() == 3, "three fresh quests each day")
	var q: Dictionary = g.daily_quests()[0]
	check(g.quest_progress(q) == 0.0, "yesterday's work doesn't count")
	var stats := {}
	for x: Dictionary in g.daily_quests():
		stats[x["stat"]] = true
	check(stats.size() == 3, "the three quests differ")
	var saved := GardenSim.new(JSON.parse_string(JSON.stringify(g.to_save())))
	check(saved.daily_quests()[0]["text"] == q["text"], "the day's quests survive saving")
	var clock: float = saved.s["time"]
	saved.advance_offline(36000.0)
	check(saved.s["time"] == clock and saved.daily_quests()[0]["text"] == q["text"], "being away brings no new day")
