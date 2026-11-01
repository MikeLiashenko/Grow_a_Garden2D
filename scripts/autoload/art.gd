extends Node
## Looks up generated sprites by name and recolors fruit for mutations on demand.

const Manifest := preload("res://assets/sprites/manifest.gd")
const D := preload("res://scripts/core/game_data.gd")

const SHEETS := {
	"fruits": preload("res://assets/sprites/fruits.png"),
	"plants": preload("res://assets/sprites/plants.png"),
	"items": preload("res://assets/sprites/items.png"),
	"characters": preload("res://assets/sprites/characters.png"),
	"props": preload("res://assets/sprites/props.png"),
	"ui": preload("res://assets/sprites/ui.png"),
}
const GROUND := preload("res://assets/world/ground.png")
const LOCKED_BED := preload("res://assets/world/locked_bed.png")
const LOGO := preload("res://assets/world/logo.png")

var _atlas := {}
var _tinted := {}
var _images := {}
var _glow: Texture2D


func has_sprite(sprite_name: String) -> bool:
	return Manifest.SPRITES.has(sprite_name)


func tex(sprite_name: String) -> Texture2D:
	if _atlas.has(sprite_name):
		return _atlas[sprite_name]
	var e: Array = Manifest.SPRITES[sprite_name]
	var a := AtlasTexture.new()
	a.atlas = SHEETS[e[0]]
	a.region = Rect2(e[1], e[2], e[3], e[4])
	_atlas[sprite_name] = a
	return a


func anchor(sprite_name: String) -> Vector2:
	var e: Array = Manifest.SPRITES[sprite_name]
	return Vector2(e[5], e[6])


## A Sprite2D whose origin is the sprite's anchor, ready for y-sorting.
func make_sprite(sprite_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(sprite_name)
	s.centered = false
	s.offset = -anchor(sprite_name)
	return s


func draw(ci: CanvasItem, sprite_name: String, pos: Vector2, color := Color.WHITE) -> void:
	ci.draw_texture(tex(sprite_name), (pos - anchor(sprite_name)).round(), color)


## Lights can't use atlas textures, so the glow gets its own texture.
func glow() -> Texture2D:
	if _glow == null:
		_glow = ImageTexture.create_from_image(_crop("ui/glow"))
	return _glow


func item_icon(key: String) -> Texture2D:
	var parts := key.split(":")
	return tex("item/%s/%s" % [parts[0], parts[1]])


func fruit_icon(seed_id: String, tint := "") -> Texture2D:
	return fruit_tex(seed_id, 16, tint)


func fruit_size(def: Dictionary, f: Dictionary) -> int:
	var fs: int = def["fs"]
	var t: float = f["t"]
	if t < 0.33:
		return maxi(roundi(fs * 0.45), 3)
	if t < 0.66:
		return maxi(roundi(fs * 0.7), 3)
	var ratio: float = f["w"] / def["kg"]
	if ratio < 0.85:
		return fs - 1
	if ratio < 1.2:
		return fs
	if ratio < 1.6:
		return fs + 1
	return fs + 2


func fruit_tint(f: Dictionary) -> String:
	for m in D.TINT_ORDER:
		if m in f["m"]:
			return m
	return "unripe" if f["t"] < 1.0 else ""


func fruit_tex(seed_id: String, size: int, tint := "", frame := 0) -> Texture2D:
	var sprite_name := "fruit/%s/%d" % [seed_id, size]
	if tint == "":
		return tex(sprite_name)
	var key := "%s|%s|%d" % [sprite_name, tint, frame]
	if _tinted.has(key):
		return _tinted[key]
	var img := _crop(sprite_name)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, _recolor(c, tint, x, y, frame))
	var t := ImageTexture.create_from_image(img)
	_tinted[key] = t
	return t


func _crop(sprite_name: String) -> Image:
	var e: Array = Manifest.SPRITES[sprite_name]
	if not _images.has(e[0]):
		var sheet: Image = SHEETS[e[0]].get_image()
		if sheet.is_compressed():
			sheet.decompress()
		sheet.convert(Image.FORMAT_RGBA8)
		_images[e[0]] = sheet
	return _images[e[0]].get_region(Rect2i(e[1], e[2], e[3], e[4]))


func _recolor(c: Color, tint: String, x: int, y: int, frame: int) -> Color:
	var luma := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	match tint:
		"unripe":
			return c.lerp(Color("#7aa848"), 0.45)
		"golden":
			var ramp := [Color("#7a4a10"), Color("#c08a20"), Color("#ffc832"), Color("#ffe880"), Color("#fffbe0")]
			return ramp[clampi(int(luma * 6.0), 0, 4)]
		"rainbow":
			var hue := fmod((x + y) * 0.07 + frame / 8.0, 1.0)
			return Color.from_hsv(hue, 0.72, clampf(luma * 1.25 + 0.3, 0.0, 1.0))
		"frozen":
			return c.lerp(Color("#a8ecff"), 0.6)
		"chilled":
			return c.lerp(Color("#cdf2ff"), 0.32)
		"shocked":
			return c.lerp(Color("#fff36b"), 0.4)
		"moonlit":
			return c.lerp(Color("#9c88ff"), 0.45)
		"white":
			return Color.WHITE
	return c
