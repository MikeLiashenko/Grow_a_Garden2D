extends Node
## Shared theme and widget helpers, so every screen has the same wooden look.

const CREAM := Color("#fff4d0")
const MUTED := Color("#c8b48c")
const GOLD := Color("#ffd23f")
const GREEN := Color("#8ee05a")
const RED := Color("#ff7a60")
const INK := Color("#3a2414")

var font: Font
var theme: Theme


func _ready() -> void:
	font = load("res://assets/fonts/pixel.fnt")
	if font is FontFile:
		font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	theme = _build_theme()
	# Merged into the default theme: a theme set on the window stops at CanvasLayers.
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 8
	var base := ThemeDB.get_default_theme()
	base.default_font = font
	base.default_font_size = 8
	base.merge_with(theme)
	if DisplayServer.get_name() != "headless":
		update_cursor(get_node("/root/Settings").current_scale())


func update_cursor(scale_factor: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img: Image = Art.tex("ui/cursor").get_image()
	img.resize(img.get_width() * scale_factor, img.get_height() * scale_factor, Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img))


func style(sprite_name: String, margin := 8, content := Vector4(8, 6, 8, 6)) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = Art.tex(sprite_name)
	s.texture_margin_left = margin
	s.texture_margin_top = margin
	s.texture_margin_right = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = content.x
	s.content_margin_top = content.y
	s.content_margin_right = content.z
	s.content_margin_bottom = content.w
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return s


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 8
	var btn := Vector4(6, 3, 6, 5)
	t.set_stylebox("normal", "Button", style("ui/btn", 4, btn))
	t.set_stylebox("hover", "Button", style("ui/btn_hover", 4, btn))
	t.set_stylebox("pressed", "Button", style("ui/btn_pressed", 4, Vector4(6, 5, 6, 3)))
	t.set_stylebox("disabled", "Button", style("ui/btn_disabled", 4, btn))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color("#a09888"))
	t.set_constant("h_separation", "Button", 3)
	t.set_stylebox("panel", "PanelContainer", style("ui/panel_dark", 8, Vector4(9, 8, 9, 8)))
	t.set_stylebox("panel", "Panel", style("ui/panel_dark", 8))
	t.set_color("font_color", "Label", CREAM)
	t.set_constant("line_spacing", "Label", 1)
	t.set_color("font_color", "RichTextLabel", CREAM)
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_constant("separation", "HBoxContainer", 3)
	# Scrollbar: slim brass grabber on a dark track.
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#22140a")
	track.content_margin_left = 3
	track.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("#bb9058")
	var grab_hi := StyleBoxFlat.new()
	grab_hi.bg_color = Color("#ffe080")
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	return t


func label(text: String, color := CREAM, size := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if size != 8:
		l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## kind: "", "green", "red", "blue" or "gold".
func button(text: String, kind := "", size := 8) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(Sfx.play.bind("ui_click"))
	b.mouse_entered.connect(Sfx.hover.bind(b))
	if size != 8:
		b.add_theme_font_size_override("font_size", size)
	if kind != "":
		var margin := Vector4(6, 3, 6, 5)
		b.add_theme_stylebox_override("normal", style("ui/btn_" + kind, 4, margin))
		b.add_theme_stylebox_override("pressed", style("ui/btn_%s_pressed" % kind, 4, Vector4(6, 5, 6, 3)))
		var hover := style("ui/btn_" + kind, 4, margin)
		hover.modulate_color = Color(1.18, 1.18, 1.18)
		b.add_theme_stylebox_override("hover", hover)
		if kind == "gold":
			for key in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(key, INK)
	return b


func line_edit(placeholder: String, secret := false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(150, 16)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#22140a")
	box.border_color = Color("#bb9058")
	box.set_border_width_all(1)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	e.add_theme_stylebox_override("normal", box)
	e.add_theme_stylebox_override("focus", box)
	e.add_theme_color_override("font_color", CREAM)
	e.add_theme_color_override("font_placeholder_color", MUTED)
	e.add_theme_color_override("caret_color", GOLD)
	return e


## Puts text on the clipboard and says so on the button for a moment.
func copy_button(text: String) -> Button:
	var b := button("COPY", "blue")
	b.pressed.connect(func():
		DisplayServer.clipboard_set(text)
		b.text = "COPIED!"
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(b):
			b.text = "COPY"
	)
	return b


func icon(texture: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.custom_minimum_size = texture.get_size()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func panel(dark := true) -> PanelContainer:
	var p := PanelContainer.new()
	if not dark:
		p.add_theme_stylebox_override("panel", style("ui/panel", 8, Vector4(12, 10, 12, 10)))
	return p


func hbox(sep := 3) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


func vbox(sep := 3) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func money(n: float) -> String:
	return "$" + number(n)


func number(n: float) -> String:
	var short: bool = Settings.get_value("short_numbers")
	if short and absf(n) >= 100000.0:
		for pair: Array in [[1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"]]:
			if absf(n) >= pair[0]:
				var v: float = n / pair[0]
				return ("%.0f" % v if v >= 100.0 else "%.1f" % v) + pair[1]
	var s := str(int(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func time_text(sec: float) -> String:
	var t := int(ceilf(maxf(sec, 0.0)))
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t / 60) % 60]
	return "%d:%02d" % [t / 60, t % 60]


## One line about a saved garden, from Session.garden_list().
func garden_summary(g: Dictionary) -> String:
	return "%s   %d plants   Day %d" % [money(g["money"]), g["plants"], g["day"]]


## Crisp outlined text for anything drawn directly in the world.
func draw_outlined(ci: CanvasItem, pos: Vector2, text: String, color: Color, outline := Color("#1c120a"), size := 8) -> void:
	for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		ci.draw_string(font, pos + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
