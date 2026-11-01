extends Node2D
## Standing in a neighbour's garden in the Open Village: walk around and look.

const D := preload("res://scripts/core/game_data.gd")
const GardenWorld := preload("res://scripts/world/garden_world.gd")
const RemoteCrowd := preload("res://scripts/world/remote_crowd.gd")

var world: Node2D
var _link: VillageLink


func _ready() -> void:
	_link = Net.link as VillageLink
	if _link == null or _link.visit_sim == null:
		Session.go_to("res://scenes/garden.tscn")
		return
	world = GardenWorld.new()
	add_child(world)
	world.setup(_link.visit_sim, true)
	world.player.position = D.SPAWN
	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(D.WORLD_PX.x)
	camera.limit_bottom = int(D.WORLD_PX.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	world.player.add_child(camera)
	camera.make_current()
	var crowd := RemoteCrowd.new()
	add_child(crowd)
	crowd.setup(_link, world)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var bar := Ui.hbox(6)
	bar.position = Vector2(4, 4)
	layer.add_child(bar)
	var plate := Ui.panel()
	plate.add_child(Ui.label("Visiting %s's garden" % _link.peer_name(_link.visiting), Ui.GOLD))
	bar.add_child(plate)
	var home := Ui.button("GO HOME", "green")
	home.pressed.connect(_go_home)
	bar.add_child(home)
	_link.peers_changed.connect(_check_owner)


func _process(_delta: float) -> void:
	if world and _link and Net.link == _link:
		_link.send_move(world.player.position, world.player.velocity)


func _check_owner() -> void:
	if not _link.peers().has(_link.visiting):
		_go_home()


func _go_home() -> void:
	_link.go_home()
	Session.go_to("res://scenes/garden.tscn")


func _click_walk(pos: Vector2) -> void:
	world.player.walk_to(pos)


func _unhandled_input(event: InputEvent) -> void:
	if world and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_click_walk(world.get_global_mouse_position())


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		_go_home()
