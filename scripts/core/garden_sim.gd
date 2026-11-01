class_name GardenSim
extends RefCounted
## All garden rules and state, independent of rendering. The state is a plain
## JSON-friendly Dictionary so Garden Times can later sync it over the network.

signal sim_event(type: String, data: Dictionary)

const D := preload("res://scripts/core/game_data.gd")

var s: Dictionary
var day_night_enabled := true
var rng := RandomNumberGenerator.new()
var _tick := 0.0


func _init(saved: Variant = null) -> void:
	rng.randomize()
	s = _new_state()
	if saved is Dictionary:
		_merge_saved(saved)
	else:
		restock()
	_check_new_day()


func _new_state() -> Dictionary:
	return {
		"money": 40.0,
		"time": D.DAY_LENGTH * 0.08,
		"played_days": true,
		"next_uid": 1,
		"plants": [],
		"greenhouse": [],
		"gadgets": [],
		"fruits": [],
		"capacity": D.START_CAPACITY,
		"backpack_level": 0,
		"items": {"seed:carrot": 3, "gear:shovel": 1},
		"hot": ["seed:carrot", "gear:shovel", "", "", "", "", "", "", ""],
		"selected": "",
		"beds": [true, true, false, false, false, false],
		"stock_seeds": {},
		"stock_gear": {},
		"restock_in": D.RESTOCK_TIME,
		"weather": "",
		"weather_left": 0.0,
		"next_weather": 150.0,
		"strike_in": 5.0,
		"daily": {},
		"stats": {},
		"saved_at": 0.0,
		"player": [D.SPAWN.x, D.SPAWN.y],
	}


func _merge_saved(saved: Dictionary) -> void:
	_migrate_seeds(saved)
	# Older saves counted days during time away too: keep the hour, restart the count.
	if not saved.has("played_days"):
		saved["time"] = fmod(float(saved.get("time", s["time"])), D.DAY_LENGTH)
	for k in saved:
		s[k] = saved[k]
	# Quests used to be one long chain; they are daily now.
	s.erase("quest")
	# JSON turns ints into floats; these are used as keys, indexes and counts.
	s["next_uid"] = int(s["next_uid"])
	s["capacity"] = int(s["capacity"])
	s["backpack_level"] = int(s["backpack_level"])
	for k in s["items"]:
		s["items"][k] = int(s["items"][k])
	for p in s["plants"] + s["greenhouse"]:
		p["uid"] = int(p["uid"])
		p["var"] = int(p["var"])
		for f in p["fruits"]:
			f["slot"] = int(f["slot"])


## Renames seeds from saves made by earlier versions.
func _migrate_seeds(saved: Dictionary) -> void:
	var rename := func(id: String) -> String: return D.LEGACY_SEEDS.get(id, id)
	var rename_key := func(key: String) -> String:
		return "seed:" + rename.call(key.substr(5)) if key.begins_with("seed:") else key
	for f in saved.get("fruits", []):
		f["seed"] = rename.call(f["seed"])
	for p in saved.get("plants", []):
		p["seed"] = rename.call(p["seed"])
		for f in p["fruits"]:
			f["seed"] = rename.call(f["seed"])
	var items := {}
	for k in saved.get("items", {}):
		items[rename_key.call(k)] = saved["items"][k]
	saved["items"] = items
	var hot: Array = saved.get("hot", [])
	for i in hot.size():
		hot[i] = rename_key.call(hot[i])
	saved["selected"] = rename_key.call(saved.get("selected", ""))
	var stock := {}
	var old_stock: Dictionary = saved.get("stock_seeds", {})
	for k in old_stock:
		stock[rename.call(k)] = old_stock[k]
	saved["stock_seeds"] = stock
	var stats: Dictionary = saved.get("stats", {})
	for k: String in stats.keys():
		if k.begins_with("planted_") and D.LEGACY_SEEDS.has(k.substr(8)):
			stats["planted_" + D.LEGACY_SEEDS[k.substr(8)]] = stats[k]
			stats.erase(k)


func to_save() -> Dictionary:
	s["saved_at"] = Time.get_unix_time_from_system()
	return s


# --- Queries -----------------------------------------------------------------

func seed_def(p: Dictionary) -> Dictionary:
	return D.SEEDS[p["seed"]]


func bed_at(pos: Vector2) -> int:
	for i in D.BEDS.size():
		if (D.BEDS[i]["rect"] as Rect2).grow(-D.BED_INSET).has_point(pos):
			return i
	return -1


func can_plant(seed_id: String, pos: Vector2, ignore_uid := -1) -> String:
	var bed := bed_at(pos)
	if bed < 0:
		return "Plant inside a garden bed"
	if not s["beds"][bed]:
		return "This bed is locked"
	var r: float = D.SEEDS[seed_id]["r"]
	for p in s["plants"]:
		if p["uid"] == ignore_uid:
			continue
		var min_d: float = (r + float(seed_def(p)["r"])) * 0.85
		if Vector2(p["x"], p["y"]).distance_squared_to(pos) < min_d * min_d:
			return "Too close to another plant"
	return ""


func is_mature(p: Dictionary) -> bool:
	return p["age"] >= p["grow"]


func growth_ratio(p: Dictionary) -> float:
	return clampf(p["age"] / p["grow"], 0.0, 1.0)


## Stage 0-4, used to pick the plant texture.
func growth_stage(p: Dictionary) -> int:
	var g := growth_ratio(p)
	if g >= 1.0:
		return 4
	if g >= 0.6:
		return 3
	if g >= 0.35:
		return 2
	if g >= 0.12:
		return 1
	return 0


func fruit_pos(p: Dictionary, f: Dictionary) -> Vector2:
	var def := seed_def(p)
	var offset: Vector2 = def["slots"][f["slot"]]
	if not def["multi"]:
		offset *= lerpf(0.45, 1.0, clampf(f["t"], 0.0, 1.0))
	return Vector2(p["x"], p["y"]) + offset


func fruit_value(f: Dictionary) -> int:
	var def: Dictionary = D.SEEDS[f["seed"]]
	var ratio: float = f["w"] / def["kg"]
	var bonus := 1.0
	for m in f["m"]:
		bonus += float(D.MUTATIONS[m]["mult"]) - 1.0
	return maxi(1, int(roundf(def["value"] * ratio * ratio * bonus)))


func fruit_display_name(f: Dictionary) -> String:
	var parts: Array[String] = []
	for m in f["m"]:
		parts.append(D.MUTATIONS[m]["name"])
	parts.append(D.SEEDS[f["seed"]]["name"])
	return " ".join(parts)


## Finds the ripe fruit nearest to pos, or {} if none is under it.
func pick_ripe(pos: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for p in s["plants"]:
		var def := seed_def(p)
		var reach: float = float(def["fs"]) * 0.5 + 3.0
		for f in p["fruits"]:
			if f["t"] < 1.0:
				continue
			var d := fruit_pos(p, f).distance_squared_to(pos)
			if d < reach * reach and d < best_d:
				best_d = d
				best = {"plant": p, "fruit": f}
	return best


func pick_plant(pos: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for p in s["plants"]:
		var def := seed_def(p)
		var reach: float = float(def["r"]) + 5.0
		var d := Vector2(p["x"], p["y"]).distance_squared_to(pos)
		if d < reach * reach and d < best_d:
			best_d = d
			best = p
		for f in p["fruits"]:
			var fd := fruit_pos(p, f).distance_squared_to(pos)
			var fr: float = float(def["fs"]) * 0.5 + 2.0
			if fd < fr * fr and fd < best_d:
				best_d = fd
				best = p
	return best


func pick_gadget(pos: Vector2) -> Dictionary:
	for g in s["gadgets"]:
		if Vector2(g["x"], g["y"] - 5).distance_squared_to(pos) < 100.0:
			return g
	return {}


func item_count(key: String) -> int:
	return int(s["items"].get(key, 0))


func night_factor() -> float:
	var phase := fmod(s["time"], D.DAY_LENGTH) / D.DAY_LENGTH
	if phase < 0.62 or phase > 0.98:
		return 0.0
	if phase < 0.72:
		return (phase - 0.62) / 0.10
	if phase > 0.90:
		return (0.98 - phase) / 0.08
	return 1.0


func is_night() -> bool:
	return day_night_enabled and night_factor() > 0.8


func backpack_price() -> int:
	return int(D.GEAR["backpack"]["price"]) * int(pow(2.0, s["backpack_level"]))


func stat(key: String) -> float:
	return float(s["stats"].get(key, 0))


func day() -> int:
	return int(float(s["time"]) / D.DAY_LENGTH) + 1


## How far through its season a day is, from 1 to SEASON_DAYS.
func season_day() -> int:
	return (day() - 1) % D.SEASON_DAYS + 1


func season_index() -> int:
	return _season_of_day(day())


func season() -> Dictionary:
	return D.SEASONS[season_index()]


func is_winter() -> bool:
	return season_index() == D.WINTER_SEASON


func _season_of_day(d: int) -> int:
	return (d - 1) / D.SEASON_DAYS % D.SEASONS.size()


func day_seconds_left() -> float:
	return D.DAY_LENGTH - fmod(float(s["time"]), D.DAY_LENGTH)


func daily_quests() -> Array:
	return s["daily"].get("quests", [])


func quest_progress(q: Dictionary) -> float:
	return clampf(stat(q["stat"]) - float(q["start"]), 0.0, float(q["n"]))


func quests_done() -> int:
	return daily_quests().filter(func(q): return q["done"]).size()


# --- Inventory ---------------------------------------------------------------

func add_item(key: String, n := 1) -> void:
	s["items"][key] = item_count(key) + n
	if key not in s["hot"]:
		var i: int = s["hot"].find("")
		if i >= 0:
			s["hot"][i] = key
	sim_event.emit("inventory", {})


func remove_item(key: String, n := 1) -> void:
	var left := item_count(key) - n
	if left > 0:
		s["items"][key] = left
	else:
		s["items"].erase(key)
		var i: int = s["hot"].find(key)
		if i >= 0:
			s["hot"][i] = ""
		if s["selected"] == key:
			s["selected"] = ""
	sim_event.emit("inventory", {})


func select_item(key: String) -> void:
	if key != "" and item_count(key) <= 0:
		return
	s["selected"] = key
	if key != "" and key not in s["hot"]:
		var i: int = s["hot"].find("")
		s["hot"][i if i >= 0 else 8] = key
	sim_event.emit("inventory", {})


func _bump(key: String, n: float = 1.0) -> void:
	s["stats"][key] = stat(key) + n


# --- Planting and harvesting ---------------------------------------------------

func plant(seed_id: String, pos: Vector2) -> String:
	var key := D.seed_item(seed_id)
	if item_count(key) <= 0:
		return "No seeds left"
	var err := can_plant(seed_id, pos)
	if err != "":
		return err
	var def: Dictionary = D.SEEDS[seed_id]
	var p := {
		"uid": s["next_uid"], "seed": seed_id, "x": roundf(pos.x), "y": roundf(pos.y),
		"age": 0.0, "grow": float(def["grow"]) * rng.randf_range(0.92, 1.08),
		"var": rng.randi_range(0, 1), "fruits": [], "cd": 0.0,
	}
	s["next_uid"] += 1
	if not def["multi"]:
		p["fruits"].append(_make_fruit(p, 0))
	s["plants"].append(p)
	remove_item(key)
	_bump("planted")
	_bump("planted_" + seed_id)
	sim_event.emit("planted", {"plant": p})
	return ""


func _make_fruit(p: Dictionary, slot: int) -> Dictionary:
	var def := seed_def(p)
	var fx := _gadget_effects(Vector2(p["x"], p["y"]))
	var u := rng.randf()
	var w: float = 0.75 + 0.75 * u * u
	if rng.randf() < 0.01:
		w *= rng.randf_range(2.0, 3.0)
	w *= 1.0 + fx["size"]
	var f := {
		"seed": p["seed"], "slot": slot, "t": 0.0,
		"k": float(def["fruit_time"]) * rng.randf_range(0.8, 1.2),
		"w": snappedf(float(def["kg"]) * w, 0.01), "m": [],
	}
	if rng.randf() < D.RAINBOW_CHANCE * fx["luck"]:
		f["m"].append("rainbow")
	elif rng.randf() < D.GOLD_CHANCE * fx["luck"]:
		f["m"].append("golden")
	return f


func harvest(p: Dictionary, f: Dictionary) -> String:
	if f["t"] < 1.0:
		return "Not ripe yet"
	if s["fruits"].size() >= s["capacity"]:
		sim_event.emit("backpack_full", {})
		return "Backpack is full"
	var pos := fruit_pos(p, f)
	var item := {"seed": f["seed"], "w": f["w"], "m": f["m"]}
	s["fruits"].append(item)
	_bump("harvested")
	if not f["m"].is_empty():
		_bump("mutated")
	if seed_def(p)["multi"]:
		p["fruits"].erase(f)
		p["cd"] = maxf(p["cd"], 2.0)
	else:
		s["plants"].erase(p)
		sim_event.emit("removed", {"uid": p["uid"]})
	sim_event.emit("harvested", {"pos": pos, "fruit": item, "value": fruit_value(item)})
	return ""


func harvest_area(pos: Vector2, radius: float) -> int:
	var count := 0
	for p in s["plants"].duplicate():
		for f in p["fruits"].duplicate():
			if f["t"] >= 1.0 and fruit_pos(p, f).distance_squared_to(pos) <= radius * radius:
				if harvest(p, f) == "":
					count += 1
				else:
					return count
	return count


func dig_up(p: Dictionary) -> void:
	s["plants"].erase(p)
	sim_event.emit("removed", {"uid": p["uid"], "dug": true, "pos": Vector2(p["x"], p["y"])})


func water(p: Dictionary) -> String:
	var key := D.gear_item("watering_can")
	if item_count(key) <= 0:
		return "Watering can is empty"
	var changed := false
	if not is_mature(p):
		p["age"] = minf(p["grow"], p["age"] + p["grow"] * 0.15)
		changed = true
	for f in p["fruits"]:
		if f["t"] < 1.0 and seed_def(p)["multi"]:
			f["t"] = minf(1.0, f["t"] + 0.25)
			changed = true
	if not changed:
		return "This plant doesn't need water"
	_sync_single_fruit(p)
	remove_item(key)
	sim_event.emit("watered", {"pos": Vector2(p["x"], p["y"])})
	return ""


func move_plant(p: Dictionary, pos: Vector2) -> String:
	var key := D.gear_item("trowel")
	if item_count(key) <= 0:
		return "No trowel uses left"
	var err := can_plant(p["seed"], pos, p["uid"])
	if err != "":
		return err
	p["x"] = roundf(pos.x)
	p["y"] = roundf(pos.y)
	remove_item(key)
	sim_event.emit("moved", {"plant": p})
	return ""


func place_gadget(id: String, pos: Vector2) -> String:
	var key := D.gear_item(id)
	if item_count(key) <= 0:
		return "None left"
	if not D.fence_inner().has_point(pos):
		return "Place it inside the garden"
	var g := {"uid": s["next_uid"], "id": id, "x": roundf(pos.x), "y": roundf(pos.y), "left": float(D.GEAR[id]["time"])}
	s["next_uid"] += 1
	s["gadgets"].append(g)
	remove_item(key)
	sim_event.emit("gadget_added", {"gadget": g})
	return ""


func remove_gadget(g: Dictionary) -> void:
	s["gadgets"].erase(g)
	sim_event.emit("gadget_removed", {"uid": g["uid"]})


func use_totem(id: String) -> String:
	var key := D.gear_item(id)
	if item_count(key) <= 0:
		return "None left"
	remove_item(key)
	start_weather(D.GEAR[id]["weather"])
	return ""


# --- Greenhouse ----------------------------------------------------------------

func store_plant(p: Dictionary) -> String:
	if s["greenhouse"].size() >= D.GREENHOUSE_SLOTS:
		return "The greenhouse is full"
	s["plants"].erase(p)
	s["greenhouse"].append(p)
	sim_event.emit("removed", {"uid": p["uid"]})
	return ""


## Puts a plant back on the spot it came from.
func take_out_plant(p: Dictionary) -> String:
	if can_plant(p["seed"], Vector2(p["x"], p["y"])) != "":
		return "Its old spot is taken"
	s["greenhouse"].erase(p)
	s["plants"].append(p)
	sim_event.emit("planted", {"plant": p})
	return ""


## The most valuable plants go in first. Returns how many were stored.
func store_all() -> int:
	var order: Array = s["plants"].duplicate()
	order.sort_custom(func(a, b): return int(seed_def(a)["price"]) > int(seed_def(b)["price"]))
	var count := 0
	for p: Dictionary in order:
		if store_plant(p) != "":
			break
		count += 1
	return count


## Returns how many went back. Plants whose spot is taken stay inside.
func take_out_all() -> int:
	var count := 0
	for p: Dictionary in s["greenhouse"].duplicate():
		if take_out_plant(p) == "":
			count += 1
	return count


# --- Shops ---------------------------------------------------------------------

func restock() -> void:
	var seeds := {}
	for id in D.SEEDS:
		var def: Dictionary = D.SEEDS[id]
		seeds[id] = rng.randi_range(def["stock"][0], def["stock"][1]) if rng.randf() < def["chance"] else 0
	s["stock_seeds"] = seeds
	var gear := {}
	for id in D.GEAR:
		var def: Dictionary = D.GEAR[id]
		if def.has("stock"):
			gear[id] = rng.randi_range(def["stock"][0], def["stock"][1]) if rng.randf() < def["chance"] else 0
	s["stock_gear"] = gear
	s["restock_in"] = D.RESTOCK_TIME
	sim_event.emit("restocked", {})


func buy_seed(id: String) -> String:
	var price: int = D.SEEDS[id]["price"]
	if int(s["stock_seeds"].get(id, 0)) <= 0:
		return "Out of stock"
	if s["money"] < price:
		return "Not enough money"
	s["money"] -= price
	s["stock_seeds"][id] = int(s["stock_seeds"][id]) - 1
	add_item(D.seed_item(id))
	_bump("seeds_bought")
	sim_event.emit("money", {})
	return ""


func gear_price(id: String) -> int:
	return backpack_price() if id == "backpack" else int(D.GEAR[id]["price"])


func gear_available(id: String) -> bool:
	var def: Dictionary = D.GEAR[id]
	if def.get("hidden", false):
		return false
	if def["kind"] == "upgrade":
		return true
	if def.get("perm", false):
		return item_count(D.gear_item(id)) == 0
	return int(s["stock_gear"].get(id, 0)) > 0


func buy_gear(id: String) -> String:
	if not gear_available(id):
		return "Out of stock"
	var def: Dictionary = D.GEAR[id]
	var price := gear_price(id)
	if s["money"] < price:
		return "Not enough money"
	s["money"] -= price
	if def["kind"] == "upgrade":
		s["capacity"] += 50
		s["backpack_level"] += 1
	else:
		add_item(D.gear_item(id), int(def.get("pack", 1)))
		if not def.get("perm", false):
			s["stock_gear"][id] = int(s["stock_gear"][id]) - 1
	_bump("gear_bought")
	sim_event.emit("money", {})
	return ""


func sell_fruit(index: int) -> int:
	var f: Dictionary = s["fruits"][index]
	var value := fruit_value(f)
	s["fruits"].remove_at(index)
	_earn(value)
	return value


func sell_all() -> int:
	var total := 0
	for f in s["fruits"]:
		total += fruit_value(f)
	s["fruits"].clear()
	if total > 0:
		_earn(total)
	return total


func _earn(amount: int) -> void:
	s["money"] += amount
	_bump("earned", amount)
	sim_event.emit("sold", {"value": amount})
	sim_event.emit("money", {})


func unlock_bed(i: int) -> String:
	if s["beds"][i]:
		return ""
	var price: int = D.BEDS[i]["price"]
	if s["money"] < price:
		return "Not enough money"
	s["money"] -= price
	s["beds"][i] = true
	_bump("beds_unlocked")
	sim_event.emit("bed_unlocked", {"index": i})
	sim_event.emit("money", {})
	return ""


# --- Weather -------------------------------------------------------------------

func start_weather(id: String) -> void:
	s["weather"] = id
	s["weather_left"] = float(D.WEATHER[id]["time"])
	s["strike_in"] = rng.randf_range(3.0, 7.0)
	sim_event.emit("weather", {"id": id})


func _roll_weather() -> void:
	var weights: Dictionary = season()["weather"]
	var total := 0
	for id in weights:
		total += int(weights[id])
	var roll := rng.randi_range(1, total)
	for id in weights:
		roll -= int(weights[id])
		if roll <= 0:
			start_weather(id)
			return


func _update_weather(dt: float) -> void:
	if s["weather"] == "":
		s["next_weather"] -= dt
		if s["next_weather"] <= 0.0:
			_roll_weather()
		return
	s["weather_left"] -= dt
	if s["weather_left"] <= 0.0:
		s["weather"] = ""
		s["next_weather"] = rng.randf_range(240.0, 420.0)
		sim_event.emit("weather", {"id": ""})
	elif s["weather"] == "storm":
		s["strike_in"] -= dt
		if s["strike_in"] <= 0.0:
			s["strike_in"] = rng.randf_range(6.0, 12.0)
			_lightning_strike()


func _lightning_strike() -> void:
	var plants: Array = s["plants"]
	var with_fruit := plants.filter(func(p): return not p["fruits"].is_empty())
	if with_fruit.is_empty():
		var inner := D.fence_inner()
		sim_event.emit("strike", {"pos": Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))})
		return
	var p: Dictionary = with_fruit[rng.randi() % with_fruit.size()]
	for f in p["fruits"]:
		_add_mutation(p, f, "shocked")
	sim_event.emit("strike", {"pos": Vector2(p["x"], p["y"])})


func _add_mutation(p: Dictionary, f: Dictionary, m: String) -> void:
	if m in f["m"]:
		return
	if m == "chilled" and "frozen" in f["m"]:
		return
	if m == "chilled" and "wet" in f["m"]:
		f["m"].erase("wet")
		m = "frozen"
	if m == "wet" and ("frozen" in f["m"]):
		return
	f["m"].append(m)
	sim_event.emit("mutated", {"pos": fruit_pos(p, f), "mutation": m})


# --- Update --------------------------------------------------------------------

func _gadget_effects(pos: Vector2) -> Dictionary:
	var fx := {"growth": 0.0, "size": 0.0, "luck": 1.0}
	for g in s["gadgets"]:
		var def: Dictionary = D.GEAR[g["id"]]
		if Vector2(g["x"], g["y"]).distance_squared_to(pos) <= float(def["radius"]) * float(def["radius"]):
			fx["growth"] = maxf(fx["growth"], def["growth"])
			fx["size"] = maxf(fx["size"], def["size"])
			fx["luck"] = maxf(fx["luck"], def["luck"])
	return fx


func growth_speed(p: Dictionary) -> float:
	var speed := (1.0 + float(_gadget_effects(Vector2(p["x"], p["y"]))["growth"])) * float(season()["growth"])
	if s["weather"] != "":
		speed *= float(D.WEATHER[s["weather"]]["growth"])
	return speed


func _sync_single_fruit(p: Dictionary) -> void:
	if not seed_def(p)["multi"] and not p["fruits"].is_empty():
		p["fruits"][0]["t"] = growth_ratio(p)


func _grow_plant(p: Dictionary, dt: float, announce := true) -> void:
	var def := seed_def(p)
	var was_ripe := is_mature(p)
	p["age"] = minf(p["grow"], p["age"] + dt)
	if not def["multi"]:
		_sync_single_fruit(p)
		if announce and not was_ripe and is_mature(p):
			sim_event.emit("ripe", {"pos": Vector2(p["x"], p["y"])})
		return
	if not is_mature(p):
		return
	for f in p["fruits"]:
		if f["t"] < 1.0:
			f["t"] = minf(1.0, f["t"] + dt / f["k"])
	p["cd"] = maxf(0.0, p["cd"] - dt)
	if p["cd"] <= 0.0 and p["fruits"].size() < def["slots"].size():
		var used := {}
		for f in p["fruits"]:
			used[f["slot"]] = true
		for i in def["slots"].size():
			if not used.has(i):
				p["fruits"].append(_make_fruit(p, i))
				p["cd"] = rng.randf_range(1.0, 4.0)
				break


func _mutation_tick() -> void:
	var w: String = s["weather"]
	var night := is_night()
	for p in s["plants"]:
		for f in p["fruits"]:
			if w == "rain" or w == "storm":
				if rng.randf() < 0.012:
					_add_mutation(p, f, "wet")
			elif w == "frost":
				if rng.randf() < 0.012:
					_add_mutation(p, f, "chilled")
			elif w == "golden_hour":
				if rng.randf() < 0.0012 and f["m"].find("rainbow") < 0:
					_add_mutation(p, f, "golden")
			if night and rng.randf() < 0.0012:
				_add_mutation(p, f, "moonlit")


## Cold only kills while the game runs: the season clock waits while the player is away.
func _winter_tick() -> void:
	if not is_winter():
		return
	var chance: float = D.WINTER_DEATH_CHANCE * (D.FROST_DEATH_FACTOR if s["weather"] == "frost" else 1.0)
	for p in s["plants"].duplicate():
		if rng.randf() < chance:
			s["plants"].erase(p)
			sim_event.emit("removed", {"uid": p["uid"]})
			sim_event.emit("plant_died", {"name": seed_def(p)["name"], "pos": Vector2(p["x"], p["y"])})


func _update_quests() -> void:
	for q in daily_quests():
		if not q["done"] and quest_progress(q) >= float(q["n"]):
			q["done"] = true
			s["money"] += q["reward"]
			sim_event.emit("quest_done", {"quest": q})
			sim_event.emit("money", {})


func _check_new_day() -> void:
	var previous := int(s["daily"].get("day", 0))
	if previous == day():
		return
	_roll_daily_quests()
	if previous > 0:
		sim_event.emit("new_day", {"season_changed": _season_of_day(previous) != season_index()})


func _roll_daily_quests() -> void:
	var kinds: Array = D.FIRST_DAY_QUESTS.duplicate()
	if day() > 1:
		kinds = D.DAILY_QUESTS.keys()
		kinds.shuffle()
	var quests := []
	# Rewards and money goals keep up with what the garden already earns.
	var earned := stat("earned")
	var pay := maxf(20.0, earned * 0.01)
	for kind: String in kinds.slice(0, D.DAILY_QUEST_COUNT):
		var def: Dictionary = D.DAILY_QUESTS[kind]
		var n := 0
		if def.get("money", false):
			n = maxi(50, int(snappedf(earned * 0.05, 10.0)))
		else:
			n = mini(int(def["n"]) + int(def["per_day"]) * (day() - 1), int(def["max"]))
		quests.append({"text": def["text"], "stat": kind, "n": n, "start": stat(kind),
			"reward": int(snappedf(pay * float(def["reward"]), 5.0)), "done": false, "money": def.get("money", false)})
	s["daily"] = {"day": day(), "quests": quests}


func update(dt: float) -> void:
	s["time"] += dt
	_check_new_day()
	s["restock_in"] -= dt
	if s["restock_in"] <= 0.0:
		restock()
	_update_weather(dt)
	for g in s["gadgets"].duplicate():
		g["left"] -= dt
		if g["left"] <= 0.0:
			remove_gadget(g)
	for p in s["plants"]:
		_grow_plant(p, dt * growth_speed(p))
	for p in s["greenhouse"]:
		_grow_plant(p, dt, false)
	_tick += dt
	if _tick >= 1.0:
		_tick -= 1.0
		_mutation_tick()
		_winter_tick()
		_update_quests()


## Catches up after time away: plants grow, but weather and gear do not apply,
## and the day clock waits, so days and seasons only pass while playing.
func advance_offline(sec: float) -> void:
	sec = minf(sec, 12.0 * 3600.0)
	if sec <= 0.0:
		return
	s["restock_in"] -= sec
	if s["restock_in"] <= 0.0:
		restock()
	s["gadgets"] = s["gadgets"].filter(func(g): return g["left"] > sec)
	for g in s["gadgets"]:
		g["left"] -= sec
	for p in s["plants"] + s["greenhouse"]:
		var left := sec
		# Multi plants spawn fruit one at a time, so step them in short chunks.
		var step := left if not seed_def(p)["multi"] else maxf(left / 40.0, 2.0)
		while left > 0.0:
			_grow_plant(p, minf(step, left))
			left -= step
