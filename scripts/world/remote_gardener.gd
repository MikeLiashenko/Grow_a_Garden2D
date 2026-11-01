extends Node2D
## Another player's gardener. Positions arrive rarely, so it keeps walking the way
## it was last told to, and eases into each correction.

const MAX_COAST := 3.5
const SNAP_DISTANCE := 90.0
const TINTS := ["#ffffff", "#ffc8c8", "#c8e0ff", "#d0ffc8", "#ffe8a8", "#e8c8ff"]

var display_name := ""
var _sprite: Sprite2D
var _velocity := Vector2.ZERO
var _target := Vector2.ZERO
var _coast := 0.0
var _anim := 0.0
var _dir := 0
var _flip := false


func setup(id: String, shown_name: String, pos: Vector2) -> void:
	display_name = shown_name
	position = pos
	_target = pos
	modulate = Color(TINTS[id.hash() % TINTS.size()])


func _ready() -> void:
	_sprite = Art.make_sprite("player/0/0")
	add_child(_sprite)


func told(pos: Vector2, velocity: Vector2) -> void:
	_velocity = velocity
	_target = pos
	_coast = MAX_COAST if velocity.length() > 1.0 else 0.0
	if position.distance_to(pos) > SNAP_DISTANCE:
		position = pos


func _process(delta: float) -> void:
	_coast -= delta
	var walking := _coast > 0.0
	if walking:
		_target += _velocity * delta
	else:
		_velocity = Vector2.ZERO
	position = position.lerp(_target, minf(delta * 8.0, 1.0))
	var moving := walking or position.distance_to(_target) > 2.0
	if moving:
		var heading := _velocity if walking else _target - position
		_anim += delta * 8.0
		if absf(heading.x) > absf(heading.y):
			_dir = 2
			_flip = heading.x < 0.0
		else:
			_dir = 0 if heading.y > 0.0 else 1
	else:
		_anim = 0.0
	_sprite.texture = Art.tex("player/%d/%d" % [_dir, int(_anim) % 4])
	_sprite.flip_h = _flip and _dir == 2
	_sprite.offset = -Art.anchor("player/0/0")
	if _sprite.flip_h:
		_sprite.offset.x = -18 + 9
	queue_redraw()


func _draw() -> void:
	var width := Ui.font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	Ui.draw_outlined(self, Vector2(-width * 0.5, -36), display_name, Ui.CREAM)
