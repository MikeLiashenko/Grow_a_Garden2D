class_name FbStream
extends RefCounted
## One live subscription to a database path, over Server-Sent Events. A player
## keeps only one open: the free plan allows 100 connections at a time.

signal received(path: String, data: Variant, merge: bool)
signal token_expired

enum { IDLE, CONNECTING, REQUESTING, STREAMING, WAITING }

const RETRY_MIN := 2.0
const RETRY_MAX := 30.0

var bytes_in := 0
var connected := false

var _http := HTTPClient.new()
var _host := ""
var _port := 443
var _tls := true
var _url := ""
var _state := IDLE
var _buffer := PackedByteArray()
var _retry := RETRY_MIN
var _retry_left := 0.0


func open(host: String, port: int, tls: bool, url: String) -> void:
	_host = host
	_port = port
	_tls = tls
	_url = url
	_connect()


func close() -> void:
	_http.close()
	_state = IDLE
	connected = false


func _connect() -> void:
	_http.close()
	_buffer.clear()
	if _http.connect_to_host(_host, _port, TLSOptions.client() if _tls else null) != OK:
		_fail()
		return
	_state = CONNECTING


func _fail() -> void:
	_http.close()
	connected = false
	_state = WAITING
	_retry_left = _retry
	_retry = minf(_retry * 2.0, RETRY_MAX)


func poll(delta: float) -> void:
	match _state:
		IDLE:
			return
		WAITING:
			_retry_left -= delta
			if _retry_left <= 0.0:
				_connect()
			return
	_http.poll()
	var status := _http.get_status()
	match _state:
		CONNECTING:
			if status == HTTPClient.STATUS_CONNECTED:
				var headers := PackedStringArray(["Accept: text/event-stream"])
				if _http.request(HTTPClient.METHOD_GET, _url, headers) != OK:
					_fail()
					return
				_state = REQUESTING
			elif status != HTTPClient.STATUS_RESOLVING and status != HTTPClient.STATUS_CONNECTING:
				_fail()
		REQUESTING:
			if status == HTTPClient.STATUS_BODY or status == HTTPClient.STATUS_CONNECTED:
				_on_response()
			elif status != HTTPClient.STATUS_REQUESTING:
				_fail()
		STREAMING:
			if status != HTTPClient.STATUS_BODY:
				_fail()
				return
			var chunk := _http.read_response_body_chunk()
			if not chunk.is_empty():
				bytes_in += chunk.size()
				_buffer.append_array(chunk)
				_parse()


func _on_response() -> void:
	var code := _http.get_response_code()
	if code == 307 or code == 302:
		var headers := _http.get_response_headers_as_dictionary()
		_host = String(headers.get("Location", headers.get("location", ""))).trim_prefix("https://").get_slice("/", 0)
		_connect()
	elif code == 200:
		connected = true
		_retry = RETRY_MIN
		_state = STREAMING
	elif code == 401:
		_fail()
		token_expired.emit()
	else:
		_fail()


## Events end with a blank line; a part of one stays in the buffer for later.
func _parse() -> void:
	var start := 0
	var i := 0
	while i < _buffer.size() - 1:
		if _buffer[i] == 10 and _buffer[i + 1] == 10:
			_on_event(_buffer.slice(start, i).get_string_from_utf8())
			start = i + 2
			i = start
		else:
			i += 1
	if start > 0:
		_buffer = _buffer.slice(start)


func _on_event(text: String) -> void:
	var kind := ""
	var body := ""
	for line: String in text.split("\n"):
		if line.begins_with("event:"):
			kind = line.substr(6).strip_edges()
		elif line.begins_with("data:"):
			body = line.substr(5).strip_edges()
	match kind:
		"put", "patch":
			var parsed: Variant = JSON.parse_string(body)
			if parsed is Dictionary:
				received.emit(parsed.get("path", "/"), parsed.get("data"), kind == "patch")
		"auth_revoked", "cancel":
			_fail()
			token_expired.emit()
