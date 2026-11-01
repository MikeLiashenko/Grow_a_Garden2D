extends Control
## Volume slider as a row of ten pixel blocks: click or drag along it.

const BLOCKS := 10
const BLOCK := Vector2(9, 9)
const GAP := 2

var key := ""


func setup(setting_key: String) -> void:
	key = setting_key
	custom_minimum_size = Vector2(BLOCKS * (BLOCK.x + GAP) - GAP, BLOCK.y)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _draw() -> void:
	var filled: int = Settings.get_value(key) / (100 / BLOCKS)
	for i in BLOCKS:
		var at := Vector2(i * (BLOCK.x + GAP), 0)
		draw_rect(Rect2(at, BLOCK), Color("#1c120a"))
		draw_rect(Rect2(at + Vector2.ONE, BLOCK - Vector2(2, 2)), Ui.GREEN if i < filled else Color("#4a3522"))


func _gui_input(event: InputEvent) -> void:
	var press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var drag: bool = event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0
	if not press and not drag:
		return
	# Clicking left of the first block turns the sound off entirely.
	var blocks := clampi(int(ceilf((event.position.x - 1.0) / (BLOCK.x + GAP))), 0, BLOCKS)
	var value := blocks * (100 / BLOCKS)
	if value != Settings.get_value(key):
		Settings.set_value(key, value)
		queue_redraw()
		Sfx.play("ui_click")
	accept_event()
