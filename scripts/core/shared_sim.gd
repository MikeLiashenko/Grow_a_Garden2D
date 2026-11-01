class_name SharedSim
extends GardenSim
## A garden more than one person can see. With authority it is a normal garden.
## Without, the same calls become commands for whoever has authority, and only
## the time-driven part keeps running here, so nothing needs sending every frame.

signal command(op: Array)

var authority := true
## Visitors can look but not touch.
var read_only := false
## Plants whose growth jumped, so the next update must carry it.
var jumped := {}


func _init(saved: Variant = null) -> void:
	super(saved)


func _busy() -> String:
	return "You are only visiting" if read_only else ""


func _send(op: Array) -> String:
	if read_only:
		return _busy()
	command.emit(op)
	return ""


func _plant_by_uid(uid: int, list := "plants") -> Dictionary:
	for p: Dictionary in s[list]:
		if p["uid"] == uid:
			return p
	return {}


# --- The calls the game makes ---------------------------------------------------

func plant(seed_id: String, pos: Vector2) -> String:
	if authority:
		return super(seed_id, pos)
	if item_count(D.seed_item(seed_id)) <= 0:
		return "No seeds left"
	var err := can_plant(seed_id, pos)
	return err if err != "" else _send(["plant", seed_id, roundf(pos.x), roundf(pos.y)])


func harvest(p: Dictionary, f: Dictionary) -> String:
	if authority:
		return super(p, f)
	if f["t"] < 1.0:
		return "Not ripe yet"
	if s["fruits"].size() >= s["capacity"]:
		sim_event.emit("backpack_full", {})
		return "Backpack is full"
	return _send(["harvest", p["uid"], f["slot"]])


func harvest_area(pos: Vector2, radius: float) -> int:
	if authority:
		return super(pos, radius)
	var count := 0
	for p: Dictionary in s["plants"]:
		for f: Dictionary in p["fruits"]:
			if f["t"] >= 1.0 and fruit_pos(p, f).distance_squared_to(pos) <= radius * radius:
				count += 1
	if count > 0:
		_send(["area", roundf(pos.x), roundf(pos.y), radius])
	return count


func dig_up(p: Dictionary) -> void:
	if authority:
		super(p)
	else:
		_send(["dig", p["uid"]])


func water(p: Dictionary) -> String:
	if authority:
		var err := super(p)
		if err == "":
			jumped[p["uid"]] = true
		return err
	if item_count(D.gear_item("watering_can")) <= 0:
		return "Watering can is empty"
	return _send(["water", p["uid"]])


func move_plant(p: Dictionary, pos: Vector2) -> String:
	if authority:
		return super(p, pos)
	if item_count(D.gear_item("trowel")) <= 0:
		return "No trowel uses left"
	var err := can_plant(p["seed"], pos, p["uid"])
	return err if err != "" else _send(["move", p["uid"], roundf(pos.x), roundf(pos.y)])


func place_gadget(id: String, pos: Vector2) -> String:
	if authority:
		return super(id, pos)
	if item_count(D.gear_item(id)) <= 0:
		return "None left"
	if not D.fence_inner().has_point(pos):
		return "Place it inside the garden"
	return _send(["gadget", id, roundf(pos.x), roundf(pos.y)])


func remove_gadget(g: Dictionary) -> void:
	if authority:
		super(g)
	else:
		_send(["ungadget", g["uid"]])


func use_totem(id: String) -> String:
	if authority:
		return super(id)
	if item_count(D.gear_item(id)) <= 0:
		return "None left"
	return _send(["totem", id])


func store_plant(p: Dictionary) -> String:
	if authority:
		return super(p)
	if s["greenhouse"].size() >= D.GREENHOUSE_SLOTS:
		return "The greenhouse is full"
	return _send(["store", p["uid"]])


func take_out_plant(p: Dictionary) -> String:
	if authority:
		return super(p)
	if can_plant(p["seed"], Vector2(p["x"], p["y"])) != "":
		return "Its old spot is taken"
	return _send(["takeout", p["uid"]])


func store_all() -> int:
	if authority:
		return super()
	_send(["store_all"])
	return mini(s["plants"].size(), D.GREENHOUSE_SLOTS - s["greenhouse"].size())


func take_out_all() -> int:
	if authority:
		return super()
	_send(["take_all"])
	return s["greenhouse"].size()


func buy_seed(id: String) -> String:
	if authority:
		return super(id)
	if int(s["stock_seeds"].get(id, 0)) <= 0:
		return "Out of stock"
	if s["money"] < int(D.SEEDS[id]["price"]):
		return "Not enough money"
	return _send(["seed", id])


func buy_gear(id: String) -> String:
	if authority:
		return super(id)
	if not gear_available(id):
		return "Out of stock"
	if s["money"] < gear_price(id):
		return "Not enough money"
	return _send(["gear", id])


func sell_fruit(index: int) -> int:
	if authority:
		return super(index)
	var f: Dictionary = s["fruits"][index]
	_send(["sell", f["seed"], f["w"]])
	return fruit_value(f)


func sell_all() -> int:
	if authority:
		return super()
	var total := 0
	for f: Dictionary in s["fruits"]:
		total += fruit_value(f)
	if total > 0:
		_send(["sell_all"])
	return total


func unlock_bed(i: int) -> String:
	if authority:
		return super(i)
	if s["beds"][i]:
		return ""
	if s["money"] < int(D.BEDS[i]["price"]):
		return "Not enough money"
	return _send(["bed", i])


# --- Running what others asked for ----------------------------------------------

## Commands come from other players' games, so nothing about them is trusted.
func run_command(op: Array) -> void:
	if op.is_empty() or not op[0] is String:
		return
	var a := op.slice(1)
	match op[0]:
		"plant" when _shape(a, [TYPE_STRING, TYPE_FLOAT, TYPE_FLOAT]) and D.SEEDS.has(a[0]):
			plant(a[0], Vector2(a[1], a[2]))
		"harvest" when _shape(a, [TYPE_FLOAT, TYPE_FLOAT]):
			var p := _plant_by_uid(int(a[0]))
			for f: Dictionary in p.get("fruits", []):
				if f["slot"] == int(a[1]):
					harvest(p, f)
					break
		"area" when _shape(a, [TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT]):
			harvest_area(Vector2(a[0], a[1]), minf(a[2], 64.0))
		"dig" when _shape(a, [TYPE_FLOAT]):
			var p := _plant_by_uid(int(a[0]))
			if not p.is_empty():
				dig_up(p)
		"water" when _shape(a, [TYPE_FLOAT]):
			var p := _plant_by_uid(int(a[0]))
			if not p.is_empty():
				water(p)
		"move" when _shape(a, [TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT]):
			var p := _plant_by_uid(int(a[0]))
			if not p.is_empty():
				move_plant(p, Vector2(a[1], a[2]))
		"gadget" when _shape(a, [TYPE_STRING, TYPE_FLOAT, TYPE_FLOAT]) and D.GEAR.has(a[0]):
			place_gadget(a[0], Vector2(a[1], a[2]))
		"ungadget" when _shape(a, [TYPE_FLOAT]):
			for g: Dictionary in s["gadgets"]:
				if g["uid"] == int(a[0]):
					remove_gadget(g)
					break
		"totem" when _shape(a, [TYPE_STRING]) and D.GEAR.has(a[0]):
			use_totem(a[0])
		"store" when _shape(a, [TYPE_FLOAT]):
			var p := _plant_by_uid(int(a[0]))
			if not p.is_empty():
				store_plant(p)
		"takeout" when _shape(a, [TYPE_FLOAT]):
			var p := _plant_by_uid(int(a[0]), "greenhouse")
			if not p.is_empty():
				take_out_plant(p)
		"store_all":
			store_all()
		"take_all":
			take_out_all()
		"seed" when _shape(a, [TYPE_STRING]) and D.SEEDS.has(a[0]):
			buy_seed(a[0])
		"gear" when _shape(a, [TYPE_STRING]) and D.GEAR.has(a[0]):
			buy_gear(a[0])
		"sell" when _shape(a, [TYPE_STRING, TYPE_FLOAT]):
			for i in s["fruits"].size():
				var f: Dictionary = s["fruits"][i]
				if f["seed"] == a[0] and is_equal_approx(float(f["w"]), a[1]):
					sell_fruit(i)
					break
		"sell_all":
			sell_all()
		"bed" when _shape(a, [TYPE_FLOAT]) and int(a[0]) >= 0 and int(a[0]) < D.BEDS.size():
			unlock_bed(int(a[0]))


func _shape(args: Array, types: Array) -> bool:
	if args.size() != types.size():
		return false
	for i in types.size():
		if typeof(args[i]) != types[i]:
			return false
	return true


# --- Time ----------------------------------------------------------------------

func update(dt: float) -> void:
	if authority:
		super(dt)
		return
	s["time"] += dt
	s["restock_in"] = maxf(0.0, s["restock_in"] - dt)
	if s["weather"] != "":
		s["weather_left"] = maxf(0.0, s["weather_left"] - dt)
	for g: Dictionary in s["gadgets"]:
		g["left"] = maxf(0.0, g["left"] - dt)
	for p: Dictionary in s["plants"]:
		_follow_growth(p, dt * growth_speed(p), true)
	for p: Dictionary in s["greenhouse"]:
		_follow_growth(p, dt, false)


## Growth with no dice: new fruit and everything random comes from the authority.
func _follow_growth(p: Dictionary, dt: float, announce: bool) -> void:
	var was_ripe := is_mature(p)
	p["age"] = minf(p["grow"], p["age"] + dt)
	if not seed_def(p)["multi"]:
		_sync_single_fruit(p)
		if announce and not was_ripe and is_mature(p):
			sim_event.emit("ripe", {"pos": Vector2(p["x"], p["y"])})
	elif is_mature(p):
		for f: Dictionary in p["fruits"]:
			if f["t"] < 1.0:
				f["t"] = minf(1.0, f["t"] + dt / f["k"])
