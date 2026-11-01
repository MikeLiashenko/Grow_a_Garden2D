extends Node
## Garden Times' connection to Firebase: the account, reads and writes, friends,
## and the running multiplayer session, which survives changing scenes.

signal account_changed
signal google_code(url: String, code: String)

const Config := preload("res://scripts/net/net_config.gd")

const ACCOUNT_FILE := "user://account.json"
const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token?key="
const GOOGLE_DEVICE_URL := "https://oauth2.googleapis.com/device/code"
const GOOGLE_TOKEN_URL := "https://oauth2.googleapis.com/token"
const NAME_MAX := 16
## "Where is my friend" expires by itself, as a closed game can't clear it.
const WHERE_FRESH := 600.0

var uid := ""
var nickname := ""
var link: GardenLink
var root: String = OS.get_environment("GG_NET_ROOT") if OS.has_environment("GG_NET_ROOT") else Config.ROOT

var db_host := Config.DB_HOST
var db_port := 443
var db_tls := true
var api_key := Config.API_KEY
var auth_url := AUTH_URL
var token_url := TOKEN_URL
var traffic_finished := 0

var _id_token := ""
var _refresh_token := ""
var _token_expires := 0.0
var _rest: FbRest
var _namespace := ""
var _google_cancelled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Automated tests can run against the local Firebase emulators.
	if OS.has_environment("GG_EMULATOR"):
		db_host = "127.0.0.1"
		db_port = 9000
		db_tls = false
		_namespace = "demo-gag-default-rtdb"
		api_key = "fake"
		auth_url = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:"
		token_url = "http://127.0.0.1:9099/securetoken.googleapis.com/v1/token?key="
	_rest = FbRest.new(db_host, db_port, db_tls)
	# Automated tests run without a real account, on their own data.
	if OS.has_environment("GG_NET_UID") and not OS.has_environment("GG_EMULATOR"):
		uid = OS.get_environment("GG_NET_UID")
		nickname = uid
		return
	_load_account()


func _process(delta: float) -> void:
	_rest.poll(delta)
	if _refresh_token != "" and Time.get_unix_time_from_system() > _token_expires - 120.0:
		_token_expires = INF
		_refresh()


func signed_in() -> bool:
	return uid != ""


func auth_available() -> bool:
	return api_key != "" or OS.has_environment("GG_NET_UID")


func google_available() -> bool:
	return Config.GOOGLE_CLIENT_ID != "" and api_key != ""


func traffic_in() -> int:
	return _rest.bytes_in + traffic_finished + (link.stream_bytes() if link else 0)


# --- Database -------------------------------------------------------------------

func url(path: String, query := "") -> String:
	var parts: Array[String] = []
	if _id_token != "":
		parts.append("auth=" + _id_token)
	if _namespace != "":
		parts.append("ns=" + _namespace)
	if query != "":
		parts.append(query)
	return "/%s/%s.json%s" % [root, path, "?" + "&".join(parts) if not parts.is_empty() else ""]


func read(path: String, shallow := false) -> Dictionary:
	return await _rest.send(HTTPClient.METHOD_GET, url(path, "shallow=true" if shallow else "")).done


## What is at path plus a tag, for write_if().
func read_tagged(path: String) -> Dictionary:
	return await _rest.send(HTTPClient.METHOD_GET, url(path), "", PackedStringArray(["X-Firebase-ETag: true"])).done


## Writes only if nobody else changed the value since read_tagged. Code 412 means they did.
func write_if(path: String, value: Variant, etag: String) -> Dictionary:
	var headers := PackedStringArray(["if-match: " + etag, "Content-Type: application/json"])
	return await _rest.send(HTTPClient.METHOD_PUT, url(path), JSON.stringify(value), headers).done


func write(path: String, value: Variant) -> Dictionary:
	return await _rest.send(HTTPClient.METHOD_PUT, url(path, "print=silent"), JSON.stringify(value)).done


## Changes several paths under one parent in a single request. A null removes.
func patch(path: String, values: Dictionary) -> Dictionary:
	return await _rest.send(HTTPClient.METHOD_PATCH, url(path, "print=silent"), JSON.stringify(values)).done


func remove(path: String) -> Dictionary:
	return await _rest.send(HTTPClient.METHOD_DELETE, url(path, "print=silent")).done


func writes_pending() -> bool:
	return _rest.pending() > 0


# --- Account --------------------------------------------------------------------

## A saved Dictionary, or null if there is none.
func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else null


func _load_account() -> void:
	var data: Variant = read_json(ACCOUNT_FILE)
	if data == null or api_key == "":
		return
	_refresh_token = data.get("refresh", "")
	uid = data.get("uid", "")
	nickname = data.get("name", "")
	_token_expires = 0.0


func _save_account() -> void:
	var f := FileAccess.open(ACCOUNT_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"refresh": _refresh_token, "uid": uid, "name": nickname}))
		f.close()


func _post(full_url: String, body: String, form := false) -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded" if form else "Content-Type: application/json"])
	if req.request(full_url, headers, HTTPClient.METHOD_POST, body) != OK:
		req.queue_free()
		return {"code": 0, "data": {}}
	var r: Array = await req.request_completed
	req.queue_free()
	var parsed: Variant = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	return {"code": r[1], "data": parsed if parsed is Dictionary else {}}


func _use_tokens(data: Dictionary) -> void:
	uid = data.get("localId", data.get("user_id", uid))
	_id_token = data.get("idToken", data.get("id_token", ""))
	_refresh_token = data.get("refreshToken", data.get("refresh_token", _refresh_token))
	_token_expires = Time.get_unix_time_from_system() + float(data.get("expiresIn", data.get("expires_in", 3600)))
	_save_account()


func _refresh() -> void:
	var r: Dictionary = await _post(token_url + api_key, "grant_type=refresh_token&refresh_token=" + _refresh_token.uri_encode(), true)
	if r["code"] == 200:
		_use_tokens(r["data"])
		if link:
			link.restart_stream()
	elif r["code"] >= 400:
		sign_out()
	else:
		_token_expires = Time.get_unix_time_from_system() + 180.0


## Waits for a usable token after a game restart.
func ready_token() -> void:
	if _refresh_token != "" and _id_token == "":
		await _refresh()


## Returns an error for the player, or "".
func sign_up(email: String, password: String) -> String:
	return await _email_auth("signUp", email, password)


func sign_in(email: String, password: String) -> String:
	return await _email_auth("signInWithPassword", email, password)


func _email_auth(method: String, email: String, password: String) -> String:
	var body := JSON.stringify({"email": email, "password": password, "returnSecureToken": true})
	var r: Dictionary = await _post(auth_url + method + "?key=" + api_key, body)
	if r["code"] != 200:
		return _auth_error(r)
	_use_tokens(r["data"])
	await _load_profile()
	return ""


func _auth_error(r: Dictionary) -> String:
	if r["code"] == 0:
		return "No connection to the server"
	var message: String = r["data"].get("error", {}).get("message", "")
	match message.get_slice(" ", 0):
		"EMAIL_EXISTS":
			return "This email already has an account"
		"INVALID_EMAIL":
			return "That email doesn't look right"
		"WEAK_PASSWORD":
			return "Password needs at least 6 characters"
		"EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS":
			return "Wrong email or password"
		"TOO_MANY_ATTEMPTS_TRY_LATER":
			return "Too many tries. Wait a little"
		"OPERATION_NOT_ALLOWED":
			return "This sign-in method is turned off"
	return "Could not sign in"


## Google's sign-in for devices without a redirect: it works the same on Windows
## and Android, without any plugin. The player approves a short code in a browser.
func sign_in_google() -> String:
	_google_cancelled = false
	var scope := "openid email profile"
	var ask: Dictionary = await _post(GOOGLE_DEVICE_URL, "client_id=%s&scope=%s" % [Config.GOOGLE_CLIENT_ID.uri_encode(), scope.uri_encode()], true)
	if ask["code"] != 200:
		return "Google sign-in is not available"
	var d: Dictionary = ask["data"]
	var page: String = d.get("verification_url", d.get("verification_uri", ""))
	google_code.emit(page, d["user_code"])
	var wait := float(d.get("interval", 5))
	var body := "client_id=%s&client_secret=%s&device_code=%s&grant_type=%s" % [Config.GOOGLE_CLIENT_ID.uri_encode(), Config.GOOGLE_CLIENT_SECRET.uri_encode(), String(d["device_code"]).uri_encode(), "urn:ietf:params:oauth:grant-type:device_code".uri_encode()]
	var deadline := Time.get_unix_time_from_system() + float(d.get("expires_in", 900))
	while Time.get_unix_time_from_system() < deadline:
		await get_tree().create_timer(wait).timeout
		if _google_cancelled:
			return "Cancelled"
		var r: Dictionary = await _post(GOOGLE_TOKEN_URL, body, true)
		if r["code"] == 200:
			return await _finish_google(r["data"].get("id_token", ""))
		match r["data"].get("error", ""):
			"authorization_pending":
				pass
			"slow_down":
				wait += 5.0
			_:
				return "Google sign-in was refused"
	return "The code has expired"


func cancel_google() -> void:
	_google_cancelled = true


func _finish_google(id_token: String) -> String:
	var body := JSON.stringify({"postBody": "id_token=%s&providerId=google.com" % id_token, "requestUri": "http://localhost", "returnSecureToken": true, "returnIdpCredential": true})
	var r: Dictionary = await _post(auth_url + "signInWithIdp?key=" + api_key, body)
	if r["code"] != 200:
		return _auth_error(r)
	_use_tokens(r["data"])
	await _load_profile()
	return ""


func _load_profile() -> void:
	var r: Dictionary = await read("users/%s/name" % uid)
	nickname = r["data"] if r["data"] is String else ""
	_save_account()
	account_changed.emit()


func sign_out() -> void:
	uid = ""
	nickname = ""
	_id_token = ""
	_refresh_token = ""
	DirAccess.remove_absolute(ACCOUNT_FILE)
	account_changed.emit()


## Nicknames are unique, and friends are found by them. Returns an error or "".
func claim_name(wanted: String) -> String:
	wanted = wanted.strip_edges()
	var key := wanted.to_lower()
	if wanted.length() < 3 or wanted.length() > NAME_MAX:
		return "A name has %d to %d characters" % [3, NAME_MAX]
	if not key.is_valid_ascii_identifier():
		return "Only letters, digits and _ please"
	var taken: Dictionary = await read_tagged("names/" + key)
	if taken["code"] == 0 or taken["code"] >= 400:
		return "No connection to the server"
	if taken["data"] != null and taken["data"] != uid:
		return "That name is taken"
	var put: Dictionary = await write_if("names/" + key, uid, taken["etag"])
	if put["code"] == 412:
		return "That name is taken"
	if put["code"] >= 300 or put["code"] == 0:
		return "Could not save the name"
	if nickname != "" and nickname.to_lower() != key:
		await remove("names/" + nickname.to_lower())
	await write("users/%s/name" % uid, wanted)
	nickname = wanted
	_save_account()
	account_changed.emit()
	return ""


# --- Friends --------------------------------------------------------------------

## Returns {friends: {uid: name}, requests: {uid: name}}.
func friends_overview() -> Dictionary:
	var friends: Variant = (await read("users/%s/friends" % uid))["data"]
	var requests: Variant = (await read("requests/" + uid))["data"]
	return {"friends": friends if friends is Dictionary else {}, "requests": requests if requests is Dictionary else {}}


func friend_where(friend: String) -> Dictionary:
	var w: Variant = (await read("where/" + friend))["data"]
	if w is Dictionary and Time.get_unix_time_from_system() - float(w.get("t", 0)) < WHERE_FRESH:
		return w
	return {}


## Returns an error for the player, or "".
func request_friend(wanted: String) -> String:
	var key := wanted.strip_edges().to_lower()
	if not key.is_valid_ascii_identifier():
		return "No gardener with that name"
	var found: Variant = (await read("names/" + key))["data"]
	if not found is String:
		return "No gardener with that name"
	if found == uid:
		return "That is you!"
	var r: Dictionary = await write("requests/%s/%s" % [found, uid], nickname)
	return "" if r["code"] < 300 and r["code"] > 0 else "Could not send the request"


func accept_friend(friend: String, friend_name: String) -> void:
	await write("users/%s/friends/%s" % [uid, friend], friend_name)
	await write("users/%s/friends/%s" % [friend, uid], nickname)
	await remove("requests/%s/%s" % [uid, friend])


func decline_friend(friend: String) -> void:
	await remove("requests/%s/%s" % [uid, friend])


func remove_friend(friend: String) -> void:
	await remove("users/%s/friends/%s" % [uid, friend])
	await remove("users/%s/friends/%s" % [friend, uid])


func set_where(kind: String, id: String) -> void:
	if kind == "":
		remove("where/" + uid)
	else:
		write("where/" + uid, {"k": kind, "id": id, "t": int(Time.get_unix_time_from_system())})


# --- Session --------------------------------------------------------------------

func start_link(new_link: GardenLink) -> void:
	await leave_link()
	link = new_link
	add_child(link)
	link.start()


func leave_link() -> void:
	if link == null:
		return
	var old := link
	link = null
	await old.leave()
	traffic_finished += old.stream_bytes()
	old.queue_free()


func _notification(what: int) -> void:
	# A phone kills a paused app without warning, so its presence just expires.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and link:
		link.say_goodbye()
