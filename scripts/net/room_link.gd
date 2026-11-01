class_name RoomLink
extends GardenLink
## A Garden Club: up to four members sharing one garden. The database only passes
## messages on. Every member keeps the garden in a file of their own, and whoever
## has the newest copy runs it while the others follow.

const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6
const MAX_MEMBERS := 4
const DIFF_EVERY := 0.5
const CORRECT_EVERY := 30.0
const META_EVERY := 60.0
const SAVE_EVERY := 60.0
## A snapshot is big compared to the rest, so it leaves the database soon after.
const SNAPSHOT_LIFETIME := 20.0
const ROOMS_DIR := "user://garden_times/"

var code := ""
var is_host := false

var _new_room := false
var _epoch := 0
var _n := 0
var _synced := false
var _replica := GardenReplica.new()
var _events := []
var _diff_left := 0.0
var _correct_left := CORRECT_EVERY
var _meta_left := META_EVERY
var _save_left := SAVE_EVERY
var _snapshot_left := 0.0
var _seen_ops := {}
var _acks := {}
var _ops := []
var _op_n := 0
var _published_rev := -1
var _started := false


static func new_code() -> String:
	var out := ""
	for i in CODE_LENGTH:
		out += CODE_CHARS[randi() % CODE_CHARS.length()]
	return out


static func copy_path(room_code: String) -> String:
	return "%s%s/room_%s.json" % [ROOMS_DIR, Net.uid, room_code]


## Reserves a new code and makes this player its first member. Returns the code, or "".
static func create() -> String:
	for attempt in 5:
		var room := new_code()
		var found: Dictionary = await Net.read_tagged("rooms/%s/mem" % room)
		if found["code"] != 200:
			return ""
		if found["data"] != null:
			continue
		var put: Dictionary = await Net.write_if("rooms/%s/mem" % room, {Net.uid: Net.nickname}, found["etag"])
		if put["code"] < 300 and put["code"] > 0:
			await Net.write("users/%s/rooms/%s" % [Net.uid, room], true)
			return room
	return ""


## Adds this player to the member list, safely against others joining at once.
## Returns an error for the player, or "".
static func enter(room: String) -> String:
	for attempt in 5:
		var found: Dictionary = await Net.read_tagged("rooms/%s/mem" % room)
		if found["code"] != 200:
			return "No connection to the server"
		if not found["data"] is Dictionary:
			return "No club with that code"
		var members: Dictionary = found["data"]
		if members.has(Net.uid):
			return ""
		if members.size() >= MAX_MEMBERS:
			return "This club is full (%d of %d)" % [members.size(), MAX_MEMBERS]
		members[Net.uid] = Net.nickname
		var put: Dictionary = await Net.write_if("rooms/%s/mem" % room, members, found["etag"])
		if put["code"] < 300 and put["code"] > 0:
			await Net.write("users/%s/rooms/%s" % [Net.uid, room], true)
			return ""
		if put["code"] != 412:
			return "Could not join the club"
	return "The club is busy. Try again"


func _init(room_code: String, is_new := false) -> void:
	code = room_code
	_new_room = is_new
	base = "rooms/" + room_code


func title() -> String:
	return "Club " + code


func start() -> void:
	DirAccess.make_dir_recursive_absolute(copy_path(code).get_base_dir())
	set_status("Connecting...")
	_heartbeat()
	flush()
	Net.set_where("r", code)
	super()


func _local_copy() -> Variant:
	return Net.read_json(copy_path(code))


func _alive_host() -> String:
	var h: Variant = tree.get("h")
	if h is Dictionary and peers().has(h.get("u", "")) and h["u"] != Net.uid:
		return h["u"]
	return ""


func _on_first_load() -> void:
	if not _started or sim == null:
		_decide()


## Who runs the garden, now that it is known who is here.
func _decide() -> void:
	if _alive_host() != "":
		set_status("Getting the garden from %s..." % peer_name(_alive_host()))
		_ask_for_garden()
		return
	var mine: Variant = _local_copy()
	var meta: Dictionary = tree.get("meta", {})
	if mine == null and meta.is_empty():
		_start_hosting(null)
		return
	if mine == null:
		set_status("Waiting for a member who has this garden")
		return
	var newest := int(meta.get("rev", 0))
	if int(mine.get("rev", 0)) >= newest:
		_start_hosting(mine)
	else:
		set_status("%s has a newer garden. Waiting for them..." % meta.get("by", "Someone"))


## The newest copy's owner isn't coming: carry on from the copy this player has.
func use_my_copy() -> void:
	var mine: Variant = _local_copy()
	if mine != null:
		_start_hosting(mine)


func has_older_copy() -> bool:
	return _local_copy() != null and sim == null


func _ask_for_garden() -> void:
	put("need/" + Net.uid, 1)


func _begin_play() -> void:
	if not _started:
		_started = true
		set_status("")
		play_ready.emit()


# --- Running the garden -----------------------------------------------------------

func _start_hosting(saved: Variant) -> void:
	if sim == null:
		sim = SharedSim.new(saved)
		if saved is Dictionary and saved.get("saved_at", 0.0) > 0.0:
			sim.advance_offline(maxf(Time.get_unix_time_from_system() - saved["saved_at"], 0.0))
		sim.command.connect(_queue_op)
	_become_host()
	_begin_play()


func _become_host() -> void:
	is_host = true
	sim.authority = true
	_ops.clear()
	_synced = true
	var h: Variant = tree.get("h")
	_epoch = int(h.get("e", 0)) + 1 if h is Dictionary else _epoch + 1
	_n = 0
	if not sim.s.has("rev"):
		sim.s["rev"] = 0
	sim.s["rev"] = int(sim.s["rev"])
	_seen_ops.clear()
	for id: String in tree.get("c", {}):
		_seen_ops[id] = int(tree["c"][id].get("n", 0))
	if not sim.sim_event.is_connected(_on_host_event):
		sim.sim_event.connect(_on_host_event)
	put("h", {"u": Net.uid, "e": _epoch})
	_send_snapshot()
	_publish_meta()


func _stop_hosting() -> void:
	is_host = false
	sim.authority = false
	if sim.sim_event.is_connected(_on_host_event):
		sim.sim_event.disconnect(_on_host_event)
	_synced = false


func _on_host_event(type: String, d: Dictionary) -> void:
	if type in GardenReplica.FORWARDED:
		_events.append(GardenReplica.encode_event(type, d))


func _send_snapshot() -> void:
	_send_diff()
	_replica.reset(sim)
	put("s", {"e": _epoch, "n": _n, "z": GardenReplica.pack(sim)})
	put("need", null)
	_snapshot_left = SNAPSHOT_LIFETIME


func _send_diff(correct := false) -> void:
	var d := _replica.collect(sim)
	if correct and peers().size() > 1:
		d["y"] = GardenReplica.correction(sim.s)
	if not _events.is_empty():
		d["e"] = _events
		_events = []
	if not _acks.is_empty():
		d["k"] = _acks
		_acks = {}
	if d.is_empty():
		return
	if d.has("f") or d.has("m") or d.has("p") or d.has("x") or d.has("fa") or d.has("fs") or d.has("g") or d.has("gx"):
		sim.s["rev"] = int(sim.s["rev"]) + 1
	_n += 1
	if peers().size() > 1:
		put("d", {"e": _epoch, "n": _n, "j": JSON.stringify(d)})


func _publish_meta() -> void:
	if int(sim.s["rev"]) != _published_rev:
		_published_rev = int(sim.s["rev"])
		put("meta", {"rev": _published_rev, "by": Net.nickname, "t": int(Time.get_unix_time_from_system())})


func _tick(delta: float) -> void:
	if sim == null:
		return
	_save_left -= delta
	if _save_left <= 0.0:
		_save_left = SAVE_EVERY
		Session.save_game()
	if not is_host:
		return
	_diff_left -= delta
	_correct_left -= delta
	_meta_left -= delta
	if _diff_left <= 0.0:
		_diff_left = DIFF_EVERY
		var correct := _correct_left <= 0.0
		if correct:
			_correct_left = CORRECT_EVERY
		_send_diff(correct)
	if _meta_left <= 0.0:
		_meta_left = META_EVERY
		_publish_meta()
	if _snapshot_left > 0.0:
		_snapshot_left -= delta
		if _snapshot_left <= 0.0:
			put("s", null)


# --- Messages --------------------------------------------------------------------

func _on_update(top: String, second: String) -> void:
	match top:
		"h":
			_on_host_changed()
		"need":
			if is_host and not tree.get("need", {}).is_empty():
				_send_snapshot()
		"c":
			if is_host and second != "":
				_run_commands(second)
		"d":
			if not is_host:
				_on_diff()
		"s":
			if not is_host:
				_on_snapshot()
		"mem":
			peers_changed.emit()


func _on_presence() -> void:
	if sim == null:
		if _alive_host() != "":
			_decide()
		return
	var h: Variant = tree.get("h")
	if is_host or (h is Dictionary and peers().has(h.get("u", ""))):
		return
	# The host has gone. Everyone follows the same order, so one steps up.
	var ids: Array = peers().keys()
	ids.sort()
	if not ids.is_empty() and ids[0] == Net.uid:
		_become_host()


func _on_host_changed() -> void:
	var h: Variant = tree.get("h")
	if not h is Dictionary:
		_on_presence()
		return
	if h["u"] == Net.uid:
		return
	if is_host:
		# Two claimed at once; the other write came last. Follow it.
		_stop_hosting()
	_ops.clear()
	_seen_ops.clear()
	if sim == null:
		_decide()
	else:
		_synced = false
		_ask_for_garden()


func _on_snapshot() -> void:
	var snap: Variant = tree.get("s")
	if not snap is Dictionary or _synced and int(snap["e"]) <= _epoch:
		return
	var data: Variant = GardenReplica.unpack(snap["z"])
	if not data is Dictionary:
		return
	_epoch = int(snap["e"])
	_n = int(snap["n"])
	_synced = true
	if sim == null:
		sim = SharedSim.new(_with_my_hotbar(data))
		sim.authority = false
		sim.command.connect(_queue_op)
		_begin_play()
	else:
		GardenReplica.adopt(sim, data)


## A member's own hotbar survives in their copy of the garden.
func _with_my_hotbar(data: Dictionary) -> Dictionary:
	var mine: Variant = _local_copy()
	if mine != null:
		for key: String in GardenReplica.PERSONAL:
			if mine.has(key):
				data[key] = mine[key]
	return data


func _on_diff() -> void:
	var d: Variant = tree.get("d")
	if not d is Dictionary or sim == null or not _synced or int(d["e"]) != _epoch:
		return
	var n := int(d["n"])
	if n <= _n:
		return
	if n > _n + 1:
		_synced = false
		_ask_for_garden()
		return
	_n = n
	var body: Variant = JSON.parse_string(d["j"])
	if body is Dictionary:
		var acks: Dictionary = body.get("k", {})
		if acks.has(Net.uid):
			var upto := int(acks[Net.uid])
			_ops = _ops.filter(func(e): return int(e[0]) > upto)
		GardenReplica.apply(sim, body)


func _queue_op(op: Array) -> void:
	_op_n += 1
	_ops.append([_op_n, op])
	put("c/" + Net.uid, {"n": _op_n, "o": JSON.stringify(_ops)})


func _run_commands(id: String) -> void:
	var c: Variant = tree.get("c", {}).get(id)
	if not c is Dictionary or id == Net.uid:
		return
	var ops: Variant = JSON.parse_string(c.get("o", "[]"))
	if not ops is Array:
		return
	var done: int = _seen_ops.get(id, 0)
	for e: Variant in ops:
		if e is Array and e.size() == 2 and e[1] is Array and int(e[0]) > done:
			done = int(e[0])
			sim.run_command(e[1])
	_seen_ops[id] = done
	_acks[id] = done


func _write_goodbye() -> void:
	super()
	put("c/" + Net.uid, null)
	if is_host:
		_send_diff()
		_publish_meta()
		put("h", null)
		put("s", null)
		put("d", null)


## Quits the club for good: no longer a member, and this copy is deleted.
static func quit_club(room: String) -> void:
	var found: Dictionary = await Net.read("rooms/%s/mem" % room)
	var members: Variant = found["data"]
	await Net.remove("users/%s/rooms/%s" % [Net.uid, room])
	DirAccess.remove_absolute(copy_path(room))
	if members is Dictionary and members.size() <= 1:
		await Net.remove("rooms/" + room)
	else:
		await Net.remove("rooms/%s/mem/%s" % [room, Net.uid])
