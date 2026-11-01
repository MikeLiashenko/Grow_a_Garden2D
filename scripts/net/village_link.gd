class_name VillageLink
extends GardenLink
## The Open Village: press Play, land on a random server of up to six gardeners,
## each with their own garden. Other gardens cost nothing until someone actually
## walks over: only then does the owner start sending theirs.

const SERVERS := 16
const MAX_PLAYERS := 6
const DIFF_EVERY := 0.75
const CORRECT_EVERY := 45.0
const CLOUD_EVERY := 300.0
const LOCAL_DIR := "user://garden_times/"
const INDEX_FRESH := 360.0
const INDEX_REFRESH := 170.0

## The garden being looked at while visiting, and whose it is.
signal visit_ready(owner_id: String)

var server := ""
var visit_sim: SharedSim
var visiting := ""

var _replica := GardenReplica.new()
var _publishing := false
var _n := 0
var _events := []
var _diff_left := 0.0
var _correct_left := CORRECT_EVERY
var _cloud_left := CLOUD_EVERY
var _index_left := INDEX_REFRESH
var _cloud_rev := ""
var _visit_n := 0
var _visit_synced := false
var _joined := false


func _init(server_id: String) -> void:
	server = server_id
	base = "v/" + server_id


func title() -> String:
	return "Open Village  #" + server.trim_prefix("s")


func _presence_key() -> String:
	return "p"


static func local_path() -> String:
	return "%svillage_%s.json" % [LOCAL_DIR, Net.uid]


## Picks a server at random among those with room, preferring ones with people.
static func pick_server(wanted := "") -> String:
	var index: Variant = (await Net.read("vi"))["data"]
	var counts := {}
	var now := Time.get_unix_time_from_system()
	if index is Dictionary:
		for sid: String in index:
			var n := 0
			for id: String in index[sid]:
				if now - float(index[sid][id]) < INDEX_FRESH or id == Net.uid:
					n += 1
			counts[sid] = n
	if wanted != "" and int(counts.get(wanted, 0)) < MAX_PLAYERS:
		return wanted
	var lively := []
	var empty := []
	for i in SERVERS:
		var sid := "s%d" % (i + 1)
		var n: int = counts.get(sid, 0)
		if n > 0 and n < MAX_PLAYERS:
			lively.append(sid)
		elif n == 0:
			empty.append(sid)
	if not lively.is_empty():
		return lively[randi() % lively.size()]
	return empty[randi() % empty.size()] if not empty.is_empty() else ""


## Replaces the village garden with a copy of a saved single-player garden.
static func upload_garden(path: String) -> bool:
	var data: Variant = Net.read_json(path)
	if data == null:
		return false
	DirAccess.make_dir_recursive_absolute(LOCAL_DIR)
	var f := FileAccess.open(local_path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	var r: Dictionary = await Net.write("users/%s/garden" % Net.uid, {"t": float(data.get("saved_at", 0.0)), "z": GardenReplica.pack(SharedSim.new(data))})
	return r["code"] < 300 and r["code"] > 0


## Takes whichever is newer, this device's copy or the cloud's.
static func load_garden() -> Variant:
	var local: Variant = Net.read_json(local_path())
	# The time alone first: the garden itself is only fetched if it is really needed.
	var cloud_time: Variant = (await Net.read("users/%s/garden/t" % Net.uid))["data"]
	var local_time: float = local.get("saved_at", 0.0) if local is Dictionary else -1.0
	if (cloud_time is float or cloud_time is int) and float(cloud_time) > local_time:
		var z: Variant = (await Net.read("users/%s/garden/z" % Net.uid))["data"]
		if z is String:
			var data: Variant = GardenReplica.unpack(z)
			if data is Dictionary:
				return data
	return local


func start() -> void:
	DirAccess.make_dir_recursive_absolute(LOCAL_DIR)
	set_status("Finding your plot...")
	var saved: Variant = await load_garden()
	sim = SharedSim.new(saved)
	if saved is Dictionary and saved.get("saved_at", 0.0) > 0.0:
		sim.advance_offline(maxf(Time.get_unix_time_from_system() - saved["saved_at"], 0.0))
	sim.sim_event.connect(_on_own_event)
	_write_index()
	_heartbeat()
	flush()
	Net.set_where("v", server)
	super()


func _write_index() -> void:
	Net.write("vi/%s/%s" % [server, Net.uid], int(Time.get_unix_time_from_system()))


func _on_first_load() -> void:
	# Two people can take the last place together, so whoever sees it over goes elsewhere.
	if not _joined:
		if peers().size() > MAX_PLAYERS:
			lost.emit("This server just filled up")
			return
		_joined = true
		_clear_stale_players()
		set_status("")
		play_ready.emit()


## There is no server to tidy up after a crashed game, so whoever joins does it.
func _clear_stale_players() -> void:
	var alive := peers()
	var listed: Dictionary = tree.get("p", {})
	for id: String in listed:
		if not alive.has(id):
			put("p/" + id, null)
			put("m/" + id, null)
			put("g/" + id, null)
			Net.remove("vi/%s/%s" % [server, id])


# --- Who is where ----------------------------------------------------------------

func _where_is(id: String) -> String:
	var entry: Variant = tree.get("p", {}).get(id, {})
	return entry.get("at", "") if entry is Dictionary else ""


func garden_shown() -> String:
	return visiting if visiting != "" else Net.uid


## Only gardeners standing in the garden on this player's screen.
func visible_peers() -> Array:
	var out := []
	var here := garden_shown()
	for id: String in peers():
		if id == Net.uid:
			continue
		var at := _where_is(id)
		if (at if at != "" else id) == here:
			out.append(id)
	return out


func _anyone_watching() -> bool:
	return not visible_peers().is_empty()


func _on_presence() -> void:
	_update_publishing()


# --- Sharing this player's garden with visitors ----------------------------------

func _visitors() -> Array:
	var out := []
	for id: String in peers():
		if id != Net.uid and _where_is(id) == Net.uid:
			out.append(id)
	return out


func _update_publishing() -> void:
	var wanted := not _visitors().is_empty()
	if wanted == _publishing:
		return
	_publishing = wanted
	if wanted:
		_send_snapshot()
	else:
		put("g/" + Net.uid, null)


func _send_snapshot() -> void:
	_replica.reset(sim)
	_events.clear()
	put("g/%s/s" % Net.uid, {"n": _n, "z": GardenReplica.pack(sim)})
	put("g/%s/need" % Net.uid, null)


func _on_own_event(type: String, d: Dictionary) -> void:
	if _publishing and type in GardenReplica.FORWARDED:
		_events.append(GardenReplica.encode_event(type, d))


func _send_diff(correct: bool) -> void:
	var d := _replica.collect(sim)
	if correct:
		d["y"] = GardenReplica.correction(sim.s)
	if not _events.is_empty():
		d["e"] = _events
		_events = []
	if d.is_empty():
		return
	_n += 1
	put("g/%s/d" % Net.uid, {"n": _n, "j": JSON.stringify(d)})


func _tick(delta: float) -> void:
	if sim == null:
		return
	# Someone else's garden is on screen, so nothing else is running this one.
	if visiting != "":
		sim.update(delta)
		if visit_sim:
			visit_sim.update(delta)
	_index_left -= delta
	if _index_left <= 0.0:
		_index_left = INDEX_REFRESH
		_write_index()
	_cloud_left -= delta
	if _cloud_left <= 0.0:
		_cloud_left = CLOUD_EVERY
		_sync_cloud()
	if _publishing:
		_diff_left -= delta
		_correct_left -= delta
		if _diff_left <= 0.0:
			_diff_left = DIFF_EVERY
			var correct := _correct_left <= 0.0
			if correct:
				_correct_left = CORRECT_EVERY
			_send_diff(correct)


## Only writes when the garden really changed.
func _sync_cloud() -> void:
	if sim == null:
		return
	var packed := GardenReplica.pack(sim)
	var mark := str(sim.s["plants"].size(), sim.s["money"], sim.s["fruits"].size(), sim.s["items"].size())
	if mark == _cloud_rev:
		return
	_cloud_rev = mark
	Net.write("users/%s/garden" % Net.uid, {"t": Time.get_unix_time_from_system(), "z": packed})


# --- Visiting ---------------------------------------------------------------------

func visit(owner_id: String) -> void:
	visiting = owner_id
	visit_sim = null
	_visit_synced = false
	put("p/%s/at" % Net.uid, owner_id)
	put("g/%s/need/%s" % [owner_id, Net.uid], 1)
	flush()
	_on_visit_snapshot()


func go_home() -> void:
	visiting = ""
	visit_sim = null
	put("p/%s/at" % Net.uid, null)
	flush()


func _on_update(top: String, second: String) -> void:
	if top != "g":
		return
	if second == Net.uid:
		if _publishing and not tree.get("g", {}).get(Net.uid, {}).get("need", {}).is_empty():
			_send_snapshot()
	elif second == visiting and visiting != "":
		_on_visit_snapshot()
		_on_visit_diff()


func _on_visit_snapshot() -> void:
	if visiting == "" or _visit_synced:
		return
	var snap: Variant = tree.get("g", {}).get(visiting, {}).get("s")
	if not snap is Dictionary:
		return
	var data: Variant = GardenReplica.unpack(snap["z"])
	if not data is Dictionary:
		return
	_visit_n = int(snap["n"])
	_visit_synced = true
	if visit_sim == null:
		visit_sim = SharedSim.new(data)
		visit_sim.authority = false
		visit_sim.read_only = true
		visit_ready.emit(visiting)
	else:
		GardenReplica.adopt(visit_sim, data)


func _on_visit_diff() -> void:
	var d: Variant = tree.get("g", {}).get(visiting, {}).get("d")
	if not d is Dictionary or visit_sim == null or not _visit_synced:
		return
	var n := int(d["n"])
	if n <= _visit_n:
		return
	if n > _visit_n + 1:
		_visit_synced = false
		put("g/%s/need/%s" % [visiting, Net.uid], 1)
		return
	_visit_n = n
	var body: Variant = JSON.parse_string(d["j"])
	if body is Dictionary:
		GardenReplica.apply(visit_sim, body)


func _write_goodbye() -> void:
	super()
	put("g/" + Net.uid, null)
	Net.remove("vi/%s/%s" % [server, Net.uid])
	_sync_cloud()

