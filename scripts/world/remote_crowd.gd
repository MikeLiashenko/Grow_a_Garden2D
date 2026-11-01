extends Node
## Keeps a gardener on screen for each other player in the garden being shown.

const RemoteGardener := preload("res://scripts/world/remote_gardener.gd")

var link: GardenLink
var world: Node2D
var _gardeners := {}


func setup(garden_link: GardenLink, garden_world: Node2D) -> void:
	link = garden_link
	world = garden_world
	link.peers_changed.connect(_refresh)
	link.peer_moved.connect(_on_moved)
	_refresh()


func _refresh() -> void:
	var wanted := link.visible_peers()
	for id: String in _gardeners.keys():
		if id not in wanted:
			_gardeners[id].queue_free()
			_gardeners.erase(id)
	for id: String in wanted:
		if not _gardeners.has(id):
			var g: Node2D = RemoteGardener.new()
			g.setup(id, link.peer_name(id), _last_seen(id))
			world.entities.add_child(g)
			_gardeners[id] = g


func _last_seen(id: String) -> Vector2:
	var m: Variant = link.last_moves().get(id)
	if m is String:
		var v: PackedFloat64Array = m.split_floats(",")
		if v.size() == 4:
			return Vector2(v[0], v[1])
	return world.D.SPAWN


func _on_moved(id: String, pos: Vector2, velocity: Vector2) -> void:
	if _gardeners.has(id):
		_gardeners[id].told(pos, velocity)
