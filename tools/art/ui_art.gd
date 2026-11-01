extends RefCounted
## UI skin, the bitmap font and the logo.

const Painter := preload("res://tools/art/painter.gd")
const WOOD := ["#2c1a0e", "#4a2e18", "#6e4826", "#94683a", "#bb9058"]

## Classic 5x7 column font, ASCII 32..126 (bit 0 is the top row).
const FONT := [
	0x000000000000, 0x00005F000000, 0x000700070000, 0x147F147F1400, 0x242A7F2A1200, 0x231308646200, 0x364956205000, 0x000807030000,
	0x001C22410000, 0x0041221C0000, 0x2A1C7F1C2A00, 0x08083E080800, 0x008070300000, 0x080808080800, 0x000060600000, 0x201008040200,
	0x3E5149453E00, 0x00427F400000, 0x724949494600, 0x2141494D3300, 0x1814127F1000, 0x274545453900, 0x3C4A49493100, 0x412111090700,
	0x364949493600, 0x464949291E00, 0x000014000000, 0x004034000000, 0x000814224100, 0x141414141400, 0x004122140800, 0x020159090600,
	0x3E415D594E00, 0x7C1211127C00, 0x7F4949493600, 0x3E4141412200, 0x7F4141413E00, 0x7F4949494100, 0x7F0909090100, 0x3E4141517300,
	0x7F0808087F00, 0x00417F410000, 0x2040413F0100, 0x7F0814224100, 0x7F4040404000, 0x7F021C027F00, 0x7F0408107F00, 0x3E4141413E00,
	0x7F0909090600, 0x3E4151215E00, 0x7F0919294600, 0x264949493200, 0x03017F010300, 0x3F4040403F00, 0x1F2040201F00, 0x3F4038403F00,
	0x631408146300, 0x030478040300, 0x6159494D4300, 0x007F41414100, 0x020408102000, 0x004141417F00, 0x040201020400, 0x404040404000,
	0x000307080000, 0x205454784000, 0x7F2844443800, 0x384444442800, 0x384444287F00, 0x385454541800, 0x00087E090200, 0x18A4A49C7800,
	0x7F0804047800, 0x00447D400000, 0x2040403D0000, 0x7F1028440000, 0x00417F400000, 0x7C0478047800, 0x7C0804047800, 0x384444443800,
	0xFC1824241800, 0x18242418FC00, 0x7C0804040800, 0x485454542400, 0x04043F442400, 0x3C4040207C00, 0x1C2040201C00, 0x3C4030403C00,
	0x442810284400, 0x4C9090907C00, 0x446454 << 16 | 0x4C4400, 0x000836410000, 0x00007F000000, 0x004136080000, 0x020102040200,
]


static func glyph_columns(index: int) -> Array[int]:
	var v: int = FONT[index]
	var cols: Array[int] = []
	for k in 5:
		cols.append((v >> (40 - k * 8)) & 0xFF)
	return cols


## Writes pixel.png and pixel.fnt (BMFont text format).
static func write_font(dir: String) -> void:
	var img := Image.create_empty(128, 96, false, Image.FORMAT_RGBA8)
	var lines: Array[String] = []
	var count := 0
	var chars: Array[String] = []
	for i in FONT.size():
		var code := 32 + i
		var cols := glyph_columns(i)
		var first := 0
		var last := 4
		while first < 5 and cols[first] == 0:
			first += 1
		while last >= 0 and cols[last] == 0:
			last -= 1
		var x := (i % 16) * 8
		var y := (i / 16) * 10
		var width := last - first + 1
		if code == 32:
			chars.append("char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=4 page=0 chnl=15")
			count += 1
			continue
		for c in width:
			for r in 8:
				if cols[first + c] & (1 << r):
					img.set_pixel(x + c, y + r, Color.WHITE)
		chars.append("char id=%d x=%d y=%d width=%d height=8 xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15" % [code, x, y, width, width + 1])
		count += 1
	img.save_png(dir + "/pixel_font.png")
	lines.append('info face="GardenPixel" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1')
	lines.append("common lineHeight=10 base=7 scaleW=128 scaleH=96 pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4")
	lines.append('page id=0 file="pixel_font.png"')
	lines.append("chars count=%d" % count)
	lines.append_array(chars)
	var f := FileAccess.open(dir + "/pixel.fnt", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()


## Wooden frame. The theme uses these as 9-slice textures with an 8px margin.
static func panel(fill: Array, frame: Array = WOOD) -> RefCounted:
	var s := 32
	var p: RefCounted = Painter.new(s, s)
	p.rect(0, 0, s, s, frame[0])
	p.rect(1, 1, s - 2, s - 2, frame[3])
	p.rect(1, 1, s - 2, 1, frame[4])
	p.rect(1, 1, 1, s - 2, frame[4])
	p.rect(s - 2, 1, 1, s - 2, frame[2])
	p.rect(1, s - 2, s - 2, 1, frame[1])
	p.rect(4, 4, s - 8, s - 8, frame[0])
	for y in range(5, s - 5):
		for x in range(5, s - 5):
			var i := (x * 3 + y * 7) % 4
			p.px(x, y, fill[1] if i == 0 else fill[0])
	p.rect(5, 5, s - 10, 1, fill[2])
	p.rect(5, 5, 1, s - 10, fill[2])
	# Cut the corners so the frame looks chamfered.
	for c: Vector2i in [Vector2i(0, 0), Vector2i(s - 1, 0), Vector2i(0, s - 1), Vector2i(s - 1, s - 1)]:
		p.img.set_pixel(c.x, c.y, Color(0, 0, 0, 0))
	# Brass rivets.
	for c: Vector2i in [Vector2i(2, 2), Vector2i(s - 3, 2), Vector2i(2, s - 3), Vector2i(s - 3, s - 3)]:
		p.px(c.x, c.y, "#ffe080")
	return p


static func button(base: Array, offset := 0) -> RefCounted:
	var w := 24
	var h := 24
	var p: RefCounted = Painter.new(w, h)
	var bottom := 2 - offset
	p.rect(0, offset, w, h - offset, "#1c120a")
	p.rect(1, offset + 1, w - 2, h - offset - 2 - bottom, base[2])
	p.rect(1, offset + 1, w - 2, 1, base[3])
	p.rect(1, offset + 1, 1, h - offset - 2 - bottom, base[3])
	p.rect(w - 2, offset + 1, 1, h - offset - 2 - bottom, base[1])
	p.rect(1, h - 1 - bottom, w - 2, bottom, base[0])
	for c: Vector2i in [Vector2i(0, offset), Vector2i(w - 1, offset), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		p.img.set_pixel(c.x, c.y, Color(0, 0, 0, 0))
	return p


static func slot(selected: bool) -> RefCounted:
	var s := 24
	var p: RefCounted = Painter.new(s, s)
	if selected:
		p.rect(0, 0, s, s, "#ffe080")
		p.rect(1, 1, s - 2, s - 2, "#b8841c")
	else:
		p.rect(0, 0, s, s, "#1c120a")
		p.rect(1, 1, s - 2, s - 2, WOOD[3])
	p.rect(2, 2, s - 4, s - 4, "#1c120a")
	p.rect(3, 3, s - 6, s - 6, "#5a3a20" if selected else "#3a2414")
	p.rect(3, 3, s - 6, 1, "#2a1a0e")
	p.rect(3, 3, 1, s - 6, "#2a1a0e")
	for c: Vector2i in [Vector2i(0, 0), Vector2i(s - 1, 0), Vector2i(0, s - 1), Vector2i(s - 1, s - 1)]:
		p.img.set_pixel(c.x, c.y, Color(0, 0, 0, 0))
	return p


## Title drawn with the bitmap font at 4x, with a leafy gradient.
static func logo() -> RefCounted:
	var line1 := "GROW A GARDEN"
	var scale := 4
	var w := 0
	for ch in line1:
		w += _glyph_width(ch) + 1
	w = w * scale + 40
	var h := 44 + 34
	var p: RefCounted = Painter.new(w, h)
	var ramp := ["#2c8a34", "#3ca83a", "#5cc844", "#8ee05a", "#c8f47a", "#f4ffb0"]
	var mask: RefCounted = Painter.new(w, h)
	var x := 20
	for ch in line1:
		x = _stamp_glyph(mask, ch, x, 6, scale, ramp, 4)
	var two := "2D"
	var width2 := 0
	for ch in two:
		width2 += _glyph_width(ch) + 1
	var x2 := (w - width2 * 5) / 2
	var gold := ["#b86a10", "#e89a20", "#ffc030", "#ffe060", "#fff4a0", "#ffffff"]
	for ch in two:
		x2 = _stamp_glyph(mask, ch, x2, 42, 5, gold, 5)
	# Thick outline, then a drop shadow behind everything.
	var dark: RefCounted = Painter.new(w, h)
	dark.stamp(mask, 0, 0)
	dark.outline("#12301a", true)
	dark.outline("#12301a", false)
	for yy in h:
		for xx in w:
			if dark.solid(xx, yy):
				p.px(xx + 2, yy + 3, Color(0, 0, 0, 0.45))
	p.stamp(dark, 0, 0)
	return p


static func _glyph_width(ch: String) -> int:
	var code := ch.unicode_at(0)
	if code == 32:
		return 3
	var cols := glyph_columns(code - 32)
	var first := 0
	var last := 4
	while first < 5 and cols[first] == 0:
		first += 1
	while last >= 0 and cols[last] == 0:
		last -= 1
	return last - first + 1


static func _stamp_glyph(p: RefCounted, ch: String, x: int, y: int, scale: int, ramp: Array, _shade_h: int) -> int:
	var code := ch.unicode_at(0)
	if code == 32:
		return x + 3 * scale + scale
	var cols := glyph_columns(code - 32)
	var first := 0
	while first < 5 and cols[first] == 0:
		first += 1
	var width := _glyph_width(ch)
	for c in width:
		for r in 7:
			if cols[first + c] & (1 << r):
				for sy in scale:
					for sx in scale:
						var t := float(r * scale + sy) / (7.0 * scale)
						var idx := clampi(ramp.size() - 1 - int(t * ramp.size()), 0, ramp.size() - 1)
						if sx == 0 and sy == 0:
							idx = ramp.size() - 1
						p.px(x + c * scale + sx, y + r * scale + sy, ramp[idx])
	return x + (width + 1) * scale


## Soft-free lamp glow: concentric hard rings keep it looking pixelated.
static func glow(size: int) -> RefCounted:
	var p: RefCounted = Painter.new(size, size)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			if d <= 1.0:
				var band := ceilf((1.0 - d) * 6.0) / 6.0
				p.img.set_pixel(x, y, Color(1, 1, 1, band))
	return p


static func cursor() -> RefCounted:
	const ROWS := [
		"X..........",
		"XX.........",
		"XOX........",
		"XOOX.......",
		"XOOOX......",
		"XOOOOX.....",
		"XOOOOOX....",
		"XOOOOOOX...",
		"XOOOOOOOX..",
		"XOOOOXXXXX.",
		"XOOXOX.....",
		"XOX.XOX....",
		"XX..XOX....",
		"X....XOX...",
		".....XXX...",
	]
	var p: RefCounted = Painter.new(11, 15)
	for y in ROWS.size():
		var row: String = ROWS[y]
		for x in row.length():
			if row[x] == "X":
				p.px(x, y, "#2a1a0e")
			elif row[x] == "O":
				p.px(x, y, "#fff4c8" if x < 3 else "#f0c860")
	return p
