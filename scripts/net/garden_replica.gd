class_name GardenReplica
extends RefCounted
## Finds what changed in a garden and applies those changes to a copy. Growth is
## left out: both sides compute it, and a rare correction fixes any drift.

const D := preload("res://scripts/core/game_data.gd")

## Whole values, sent when they change.
const FIELDS := ["money", "capacity", "backpack_level", "beds", "weather", "daily", "next_uid", "rev"]
## Dictionaries, of which only the changed keys are sent.
const MAPS := ["items", "stock_seeds", "stock_gear", "stats"]
## Belongs to each player, not to the garden.
const PERSONAL := ["hot", "selected", "player"]
## What a copy has to be told about, because it can't work it out itself.
const FORWARDED := ["harvested", "watered", "strike", "plant_died", "mutated", "quest_done", "new_day", "sold", "backpack_full"]

var _fields := {}
var _maps := {}
var _plants := {}
var _gadgets := {}
var _fruits := []
var _greenhouse := []


static func pack(sim: GardenSim) -> String:
	var copy: Dictionary = sim.s.duplicate()
	for key: String in PERSONAL:
		copy.erase(key)
	var raw := JSON.stringify(copy).to_utf8_buffer()
	return "%d:%s" % [raw.size(), Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))]


static func unpack(text: String) -> Variant:
	var size := text.get_slice(":", 0).to_int()
	var raw := Marshalls.base64_to_raw(text.get_slice(":", 1)).decompress(size, FileAccess.COMPRESSION_GZIP)
	return JSON.parse_string(raw.get_string_from_utf8())


## Makes the current state the one later changes are measured from.
func reset(sim: GardenSim) -> void:
	collect(sim as SharedSim)


func collect(sim: SharedSim) -> Dictionary:
	var s := sim.s
	var out := {}
	var fields := {}
	for key: String in FIELDS:
		if not _fields.has(key) or _fields[key] != s.get(key):
			_fields[key] = s.get(key).duplicate(true) if s.get(key) is Array or s.get(key) is Dictionary else s.get(key)
			fields[key] = s.get(key)
			if key == "weather":
				fields["weather_left"] = snappedf(s["weather_left"], 0.1)
	if not fields.is_empty():
		out["f"] = fields
	var maps := {}
	for key: String in MAPS:
		var delta := _map_delta(_maps.get(key, {}), s[key])
		if not delta.is_empty():
			maps[key] = delta
			_maps[key] = s[key].duplicate()
	if not maps.is_empty():
		out["m"] = maps
	_collect_fruits(s, out)
	_collect_plants(sim, out)
	_collect_gadgets(s, out)
	var house: Array = s["greenhouse"].map(func(p): return int(p["uid"]))
	if house != _greenhouse:
		_greenhouse = house
		out["h"] = s["greenhouse"].map(_encode_plant)
	return out


func _map_delta(before: Dictionary, now: Dictionary) -> Dictionary:
	var out := {}
	for k in now:
		if not before.has(k) or before[k] != now[k]:
			out[k] = now[k]
	for k in before:
		if not now.has(k):
			out[k] = null
	return out


## The backpack can hold hundreds of fruit, so picking one sends just that one.
func _collect_fruits(s: Dictionary, out: Dictionary) -> void:
	var now: Array = s["fruits"]
	if now == _fruits:
		return
	if now.size() > _fruits.size() and now.slice(0, _fruits.size()) == _fruits:
		out["fa"] = now.slice(_fruits.size())
	else:
		out["fs"] = now
	_fruits = now.duplicate()


func _plant_key(p: Dictionary) -> String:
	var parts := [p["x"], p["y"]]
	for f: Dictionary in p["fruits"]:
		parts.append_array([f["slot"], f["w"], f["m"]])
	return str(parts)


func _collect_plants(sim: SharedSim, out: Dictionary) -> void:
	var seen := {}
	var changed := []
	for p: Dictionary in sim.s["plants"]:
		var uid: int = p["uid"]
		seen[uid] = true
		var key := _plant_key(p)
		if _plants.get(uid, "") != key or sim.jumped.has(uid):
			_plants[uid] = key
			changed.append(_encode_plant(p))
	sim.jumped.clear()
	var gone := []
	for uid: int in _plants.keys():
		if not seen.has(uid):
			_plants.erase(uid)
			gone.append(uid)
	if not changed.is_empty():
		out["p"] = changed
	if not gone.is_empty():
		out["x"] = gone


func _collect_gadgets(s: Dictionary, out: Dictionary) -> void:
	var seen := {}
	var added := []
	for g: Dictionary in s["gadgets"]:
		seen[g["uid"]] = true
		if not _gadgets.has(g["uid"]):
			_gadgets[g["uid"]] = true
			added.append([g["uid"], g["id"], g["x"], g["y"], snappedf(g["left"], 1.0)])
	var gone := []
	for uid: int in _gadgets.keys():
		if not seen.has(uid):
			_gadgets.erase(uid)
			gone.append(uid)
	if not added.is_empty():
		out["g"] = added
	if not gone.is_empty():
		out["gx"] = gone


## Corrects the clocks and whatever is still growing.
static func correction(s: Dictionary) -> Dictionary:
	var ages := []
	for p: Dictionary in s["plants"] + s["greenhouse"]:
		var entry := [p["uid"], snappedf(p["age"], 0.1)]
		var growing: bool = p["age"] < p["grow"]
		for f: Dictionary in p["fruits"]:
			entry.append(snappedf(f["t"], 0.01))
			growing = growing or f["t"] < 1.0
		if growing:
			ages.append(entry)
	return {"t": snappedf(s["time"], 0.1), "r": snappedf(s["restock_in"], 0.1), "w": snappedf(s["weather_left"], 0.1), "n": snappedf(s["next_weather"], 0.1), "a": ages}


static func _encode_plant(p: Dictionary) -> Array:
	var fruits := []
	for f: Dictionary in p["fruits"]:
		fruits.append([f["slot"], snappedf(f["t"], 0.01), snappedf(f["k"], 0.01), f["w"], f["m"]])
	return [p["uid"], p["seed"], p["x"], p["y"], snappedf(p["age"], 0.1), snappedf(p["grow"], 0.01), p["var"], fruits]


static func _decode_fruit(seed_id: String, e: Array) -> Dictionary:
	return {"seed": seed_id, "slot": int(e[0]), "t": float(e[1]), "k": float(e[2]), "w": float(e[3]), "m": e[4]}


static func _decode_plant(e: Array) -> Dictionary:
	var fruits := []
	for f: Array in e[7]:
		fruits.append(_decode_fruit(e[1], f))
	return {"uid": int(e[0]), "seed": e[1], "x": float(e[2]), "y": float(e[3]), "age": float(e[4]), "grow": float(e[5]), "var": int(e[6]), "fruits": fruits, "cd": 0.0}


# --- Applying to a copy -----------------------------------------------------------

static func apply(sim: SharedSim, d: Dictionary) -> void:
	var s := sim.s
	if d.has("f"):
		_apply_fields(sim, d["f"])
	var inventory_changed := false
	var maps: Dictionary = d.get("m", {})
	for key: String in maps:
		var target: Dictionary = s[key]
		for k: String in maps[key]:
			if maps[key][k] == null:
				target.erase(k)
			elif key == "items" or key == "stock_seeds" or key == "stock_gear":
				target[k] = int(maps[key][k])
			else:
				target[k] = maps[key][k]
		if key == "items":
			inventory_changed = true
		elif key == "stock_seeds":
			sim.sim_event.emit("restocked", {})
	if d.has("fa"):
		s["fruits"].append_array(d["fa"])
	if d.has("fs"):
		s["fruits"] = d["fs"]
	for uid: Variant in d.get("x", []):
		_remove_plant(sim, int(uid))
	for e: Array in d.get("p", []):
		_apply_plant(sim, e)
	for uid: Variant in d.get("gx", []):
		for g: Dictionary in s["gadgets"]:
			if g["uid"] == int(uid):
				s["gadgets"].erase(g)
				sim.sim_event.emit("gadget_removed", {"uid": g["uid"]})
				break
	for e: Array in d.get("g", []):
		var g := {"uid": int(e[0]), "id": e[1], "x": float(e[2]), "y": float(e[3]), "left": float(e[4])}
		s["gadgets"].append(g)
		sim.sim_event.emit("gadget_added", {"gadget": g})
	if d.has("h"):
		var house := []
		for e: Array in d["h"]:
			house.append(_decode_plant(e))
		s["greenhouse"] = house
	if d.has("y"):
		_apply_correction(s, d["y"])
	if inventory_changed:
		_tidy_hotbar(sim)
	sim.sim_event.emit("money", {})
	for ev: Array in d.get("e", []):
		var data: Dictionary = ev[1]
		if data.has("pos"):
			data["pos"] = Vector2(data["pos"][0], data["pos"][1])
		sim.sim_event.emit(ev[0], data)


static func _apply_fields(sim: SharedSim, f: Dictionary) -> void:
	var s := sim.s
	var beds_before: Array = s["beds"].duplicate()
	for key: String in f:
		match key:
			"capacity", "backpack_level", "next_uid", "rev":
				s[key] = int(f[key])
			_:
				s[key] = f[key]
	if f.has("beds"):
		for i in beds_before.size():
			if s["beds"][i] and not beds_before[i]:
				sim.sim_event.emit("bed_unlocked", {"index": i})
	if f.has("weather"):
		sim.sim_event.emit("weather", {"id": s["weather"]})


static func _remove_plant(sim: SharedSim, uid: int) -> void:
	for p: Dictionary in sim.s["plants"]:
		if p["uid"] == uid:
			sim.s["plants"].erase(p)
			sim.sim_event.emit("removed", {"uid": uid})
			return


## Views keep hold of the plant's Dictionary, so an existing one changes in place.
static func _apply_plant(sim: SharedSim, e: Array) -> void:
	var fresh := _decode_plant(e)
	for p: Dictionary in sim.s["plants"]:
		if p["uid"] == fresh["uid"]:
			var moved: bool = p["x"] != fresh["x"] or p["y"] != fresh["y"]
			p.merge(fresh, true)
			if moved:
				sim.sim_event.emit("moved", {"plant": p})
			return
	sim.s["plants"].append(fresh)
	sim.sim_event.emit("planted", {"plant": fresh})


static func _apply_correction(s: Dictionary, y: Dictionary) -> void:
	s["time"] = float(y["t"])
	s["restock_in"] = float(y["r"])
	s["weather_left"] = float(y["w"])
	s["next_weather"] = float(y["n"])
	var by_uid := {}
	for p: Dictionary in s["plants"] + s["greenhouse"]:
		by_uid[p["uid"]] = p
	for e: Array in y["a"]:
		var p: Dictionary = by_uid.get(int(e[0]), {})
		if p.is_empty():
			continue
		p["age"] = float(e[1])
		for i in mini(p["fruits"].size(), e.size() - 2):
			p["fruits"][i]["t"] = float(e[i + 2])


## New items take a free hotbar slot, and used up ones leave it.
static func _tidy_hotbar(sim: SharedSim) -> void:
	var s := sim.s
	for i in s["hot"].size():
		if s["hot"][i] != "" and sim.item_count(s["hot"][i]) <= 0:
			s["hot"][i] = ""
	if s["selected"] != "" and sim.item_count(s["selected"]) <= 0:
		s["selected"] = ""
	for key: String in s["items"]:
		if key not in s["hot"]:
			var i: int = s["hot"].find("")
			if i >= 0:
				s["hot"][i] = key
	sim.sim_event.emit("inventory", {})


## Replaces a running copy with a full state, telling the views what changed.
static func adopt(sim: SharedSim, data: Dictionary) -> void:
	var s := sim.s
	var fresh := SharedSim.new(data)
	var keep := {}
	for p: Dictionary in fresh.s["plants"]:
		keep[p["uid"]] = true
	for p: Dictionary in s["plants"].duplicate():
		if not keep.has(p["uid"]):
			_remove_plant(sim, p["uid"])
	for g: Dictionary in s["gadgets"].duplicate():
		s["gadgets"].erase(g)
		sim.sim_event.emit("gadget_removed", {"uid": g["uid"]})
	for key: String in fresh.s:
		if key != "plants" and key != "gadgets" and key not in PERSONAL:
			s[key] = fresh.s[key]
	for g: Dictionary in fresh.s["gadgets"]:
		g["uid"] = int(g["uid"])
		s["gadgets"].append(g)
		sim.sim_event.emit("gadget_added", {"gadget": g})
	for p: Dictionary in fresh.s["plants"]:
		var mine := sim._plant_by_uid(p["uid"])
		if mine.is_empty():
			s["plants"].append(p)
			sim.sim_event.emit("planted", {"plant": p})
		else:
			mine.merge(p, true)
	_tidy_hotbar(sim)
	sim.sim_event.emit("money", {})


## An event as it travels: JSON has no Vector2.
static func encode_event(type: String, d: Dictionary) -> Array:
	var data := d.duplicate()
	if data.get("pos") is Vector2:
		data["pos"] = [data["pos"].x, data["pos"].y]
	return [type, data]
