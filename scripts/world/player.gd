extends CharacterBody2D
## The gardener. WASD or arrows to walk, or walks to a clicked spot.

const D := preload("res://scripts/core/game_data.gd")

const SPEED := 92.0
const SPRINT := 1.45

var input_enabled := true
var held_icon: Texture2D
var _sprite: Sprite2D
var _held: Sprite2D
var _dir := 0
var _flip := false
var _anim := 0.0
var _target: Variant = null
var _stuck := 0.0
var _step_frame := -1


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	shape.position = Vector2(0, -2)
	add_child(shape)
	_sprite = Art.make_sprite("player/0/0")
	add_child(_sprite)
	_held = Sprite2D.new()
	_held.position = Vector2(0, -32)
	add_child(_held)


func walk_to(pos: Vector2) -> void:
	_target = pos
	_stuck = 0.0


func stop_walking() -> void:
	_target = null


func face(pos: Vector2) -> void:
	var d := pos - global_position
	if absf(d.x) > absf(d.y):
		_dir = 2
		_flip = d.x < 0.0
	else:
		_dir = 0 if d.y > 0.0 else 1


func set_held(tex: Texture2D) -> void:
	_held.texture = tex


func _physics_process(delta: float) -> void:
	var move := Vector2.ZERO
	if input_enabled:
		move.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		move.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	if move != Vector2.ZERO:
		_target = null
	elif _target != null:
		var to: Vector2 = _target - global_position
		if to.length() < 3.0:
			_target = null
		else:
			move = to
	var speed := SPEED * (SPRINT if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	velocity = move.normalized() * speed
	var before := global_position
	move_and_slide()
	if _target != null and global_position.distance_to(before) < speed * delta * 0.2:
		_stuck += delta
		if _stuck > 0.25:
			_target = null
	if velocity.length() > 1.0:
		_anim += delta * speed * 0.09
		if absf(move.x) > absf(move.y):
			_dir = 2
			_flip = move.x < 0.0
		else:
			_dir = 0 if move.y > 0.0 else 1
		# A foot lands on every odd walking frame.
		if int(_anim) != _step_frame and int(_anim) % 2 == 1:
			Sfx.play_varied("step_stone" if D.on_path(position.x, position.y) else "step_grass", 2)
		_step_frame = int(_anim)
	else:
		_anim = 0.0
		_step_frame = -1
	var frame := int(_anim) % 4
	_sprite.texture = Art.tex("player/%d/%d" % [_dir, frame])
	_sprite.flip_h = _flip and _dir == 2
	_sprite.offset = -Art.anchor("player/0/0")
	if _sprite.flip_h:
		_sprite.offset.x = -18 + 9
