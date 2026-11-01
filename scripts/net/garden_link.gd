class_name GardenLink
extends Node
## A multiplayer session: one stream down, batched writes up, who is here and
## where they walk. Firebase's REST API has no way to notice a lost player, so
## each one says "still here" now and then and is forgotten after a silence.

signal status_changed(text: String)
signal play_ready
signal peers_changed
signal peer_moved(id: String, pos: Vector2, velocity: Vector2)
signal lost(reason: String)

const HEARTBEAT := 45.0
const STALE := 120.0
const FLUSH_EVERY := 0.25
## Walking is sent only when it changes, as the others keep a gardener walking
## straight on by themselves. These cap it and correct any drift.
const MOVE_MIN_GAP := 0.4
const MOVE_REFRESH := 2.5

var base := ""
var tree := {}
var sim: SharedSim
var status := ""

var _stream: FbStream
var _pending := {}
var _flush_left := 0.0
var _heartbeat_left := 0.0
var _heard := {}
var _first_load := true
var _leaving := false
var _move_left := 0.0
var _move_sent_at := 0.0
var _last_velocity := Vector2.ZERO
var _last_pos := Vector2.INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start() -> void:
	_open_stream()


func _open_stream() -> void:
	_stream = FbStream.new()
	_stream.received.connect(_on_received)
	_stream.token_expired.connect(func(): restart_stream())
	_stream.open(Net.db_host, Net.db_port, Net.db_tls, Net.url(base))


func restart_stream() -> void:
	if _stream:
		var carried := _stream.bytes_in
		_stream.close()
		_first_load = true
		_open_stream()
		_stream.bytes_in = carried


func stream_bytes() -> int:
	return _stream.bytes_in if _stream else 0


func set_status(text: String) -> void:
	status = text
	status_changed.emit(text)


func _process(delta: float) -> void:
	if _stream:
		_stream.poll(delta)
	_flush_left -= delta
	if _flush_left <= 0.0 and not _pending.is_empty():
		flush()
	_heartbeat_left -= delta
	if _heartbeat_left <= 0.0:
		_heartbeat_left = HEARTBEAT
		_heartbeat()
		_expire_peers()
	_move_left -= delta
	_tick(delta)


# --- Writing --------------------------------------------------------------------

## Queues a change. Several writes to one spot before the next flush become one.
func put(path: String, value: Variant) -> void:
	_pending[path] = value


func flush() -> void:
	_flush_left = FLUSH_EVERY
	if _pending.is_empty():
		return
	var batch := _pending
	_pending = {}
	Net.patch(base, batch)


# --- Reading --------------------------------------------------------------------

func _on_received(path: String, data: Variant, merge: bool) -> void:
	var keys := path.split("/", false)
	if merge:
		for k: String in (data as Dictionary):
			_store(keys + k.split("/", false), data[k])
	else:
		_store(keys, data)
	if _first_load:
		_first_load = false
		_mark_all_heard()
		_on_first_load()
		return
	if keys.is_empty():
		if merge:
			for k: String in (data as Dictionary):
				var parts := k.split("/", false)
				_dispatch(parts[0], parts[1] if parts.size() > 1 else "")
		else:
			_mark_all_heard()
			_on_first_load()
		return
	_dispatch(keys[0], keys[1] if keys.size() > 1 else "")


func _store(keys: PackedStringArray, value: Variant) -> void:
	if keys.is_empty():
		tree = value if value is Dictionary else {}
		return
	var at := tree
	for i in keys.size() - 1:
		if not at.get(keys[i]) is Dictionary:
			at[keys[i]] = {}
		at = at[keys[i]]
	if value == null:
		at.erase(keys[-1])
	else:
		at[keys[-1]] = value


func _dispatch(top: String, second: String) -> void:
	if top == "m":
		_on_move(second)
	elif top == _presence_key():
		if second != "":
			_heard[second] = Time.get_ticks_msec() / 1000.0
		_expire_peers()
		_on_presence()
		peers_changed.emit()
	else:
		_on_update(top, second)


# --- Presence -------------------------------------------------------------------

## Which top-level key holds {uid: {n: name, t: time}}.
func _presence_key() -> String:
	return "on"


func _heartbeat() -> void:
	if Net.uid == "":
		return
	put("%s/%s/n" % [_presence_key(), Net.uid], Net.nickname)
	put("%s/%s/t" % [_presence_key(), Net.uid], int(Time.get_unix_time_from_system()))


func _mark_all_heard() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var unix := Time.get_unix_time_from_system()
	var on: Dictionary = tree.get(_presence_key(), {})
	for id: String in on:
		var age: float = unix - float((on[id] as Dictionary).get("t", 0))
		_heard[id] = now - maxf(age, 0.0)


## Everyone here, this player included.
func peers() -> Dictionary:
	var out: Dictionary = tree.get(_presence_key(), {}).duplicate()
	var now := Time.get_ticks_msec() / 1000.0
	for id: String in out.keys():
		if id != Net.uid and now - float(_heard.get(id, -INF)) > STALE:
			out.erase(id)
	return out


func _expire_peers() -> void:
	var before: Dictionary = tree.get(_presence_key(), {})
	var alive := peers()
	if alive.size() != before.size():
		_on_presence()
		peers_changed.emit()


func peer_name(id: String) -> String:
	var on: Dictionary = tree.get(_presence_key(), {})
	var entry: Variant = on.get(id, {})
	return entry.get("n", "Gardener") if entry is Dictionary else "Gardener"


# --- Walking --------------------------------------------------------------------

## Called every frame with where this player is.
func send_move(pos: Vector2, velocity: Vector2) -> void:
	if not _anyone_watching():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var moving := velocity.length() > 1.0
	var changed := moving != (_last_velocity.length() > 1.0) or (moving and velocity.normalized().dot(_last_velocity.normalized()) < 0.95)
	var refresh := moving and now - _move_sent_at > MOVE_REFRESH
	if (changed and _move_left <= 0.0) or refresh:
		_move_left = MOVE_MIN_GAP
		_move_sent_at = now
		_last_velocity = velocity
		_last_pos = pos
		put("m/" + Net.uid, "%d,%d,%d,%d" % [pos.x, pos.y, velocity.x, velocity.y])


func _on_move(id: String) -> void:
	if id == "" or id == Net.uid:
		return
	var m: Variant = tree.get("m", {}).get(id)
	if m is String:
		var v: PackedFloat64Array = m.split_floats(",")
		if v.size() == 4:
			peer_moved.emit(id, Vector2(v[0], v[1]), Vector2(v[2], v[3]))


## Where everyone in view last stood, for gardeners that appear after a scene change.
func last_moves() -> Dictionary:
	return tree.get("m", {})


func _anyone_watching() -> bool:
	return peers().size() > 1


# --- For subclasses --------------------------------------------------------------

func _tick(_delta: float) -> void:
	pass


func _on_first_load() -> void:
	pass


func _on_presence() -> void:
	pass


func _on_update(_top: String, _second: String) -> void:
	pass


## Who else can be seen from this garden, by uid. Empty for none.
func visible_peers() -> Array:
	var out := []
	for id: String in peers():
		if id != Net.uid:
			out.append(id)
	return out


func title() -> String:
	return "Garden Times"


## Leaves properly. Waits until the last writes have gone.
func leave() -> void:
	_leaving = true
	_write_goodbye()
	flush()
	var waited := 0.0
	while Net.writes_pending() and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if _stream:
		_stream.close()
	Net.set_where("", "")


## The window is closing: one last attempt, without waiting for an answer.
func say_goodbye() -> void:
	_write_goodbye()
	flush()


func _write_goodbye() -> void:
	put("%s/%s" % [_presence_key(), Net.uid], null)
	put("m/" + Net.uid, null)
