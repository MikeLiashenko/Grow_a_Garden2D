class_name FbRest
extends RefCounted
## Reads and writes over one reused connection, one request at a time. Firebase
## counts encryption overhead as traffic, so a new connection per write is costly.


class Job:
	extends RefCounted
	signal done(result: Dictionary)
	var method: int
	var url: String
	var body: String
	var headers: PackedStringArray


const IDLE_CLOSE := 20.0

var bytes_in := 0

var _http := HTTPClient.new()
var _host := ""
var _port := 443
var _tls := true
var _queue: Array[Job] = []
var _job: Job
var _response := PackedByteArray()
var _idle := 0.0
var _sent := false
var _tries := 0


func _init(host: String, port: int, tls: bool) -> void:
	_host = host
	_port = port
	_tls = tls


func send(method: int, url: String, body := "", headers := PackedStringArray()) -> Job:
	var job := Job.new()
	job.method = method
	job.url = url
	job.body = body
	job.headers = headers
	_queue.append(job)
	return job


func pending() -> int:
	return _queue.size() + (1 if _job != null else 0)


func poll(delta: float) -> void:
	if _job == null:
		if _queue.is_empty():
			_idle += delta
			if _idle > IDLE_CLOSE and _http.get_status() != HTTPClient.STATUS_DISCONNECTED:
				_http.close()
			return
		_job = _queue.pop_front()
		_response.clear()
		_sent = false
		_tries = 0
		_idle = 0.0
	_http.poll()
	match _http.get_status():
		HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_reconnect()
		HTTPClient.STATUS_CONNECTED:
			if _sent:
				_finish()
			elif _http.request(_job.method, _job.url, _job.headers, _job.body) == OK:
				_sent = true
			else:
				_reconnect()
		HTTPClient.STATUS_BODY:
			var chunk := _http.read_response_body_chunk()
			bytes_in += chunk.size()
			_response.append_array(chunk)


## A kept connection can die between requests, so a failure gets a few new tries.
func _reconnect() -> void:
	_http.close()
	_sent = false
	_response.clear()
	_tries += 1
	if _tries > 3:
		_complete({"code": 0, "data": null, "etag": ""})
	elif _http.connect_to_host(_host, _port, TLSOptions.client() if _tls else null) != OK:
		_complete({"code": 0, "data": null, "etag": ""})


func _finish() -> void:
	var code := _http.get_response_code()
	var headers := _http.get_response_headers_as_dictionary()
	if code == 307:
		_host = String(headers.get("Location", headers.get("location", ""))).trim_prefix("https://").get_slice("/", 0)
		_reconnect()
		return
	var text := _response.get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else null
	_complete({"code": code, "data": data, "etag": String(headers.get("ETag", headers.get("etag", "")))})


func _complete(result: Dictionary) -> void:
	var job := _job
	_job = null
	job.done.emit(result)
