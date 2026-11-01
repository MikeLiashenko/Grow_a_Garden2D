extends SceneTree
## Turns the recordings in tools/audio/recorded into game sounds in assets/sounds,
## at matching levels, and writes a listening reel to build/sound_preview.wav.
## Sources and licences are in assets/sounds/CREDITS.md. Needs ffmpeg on the PATH.
## Run, then re-import:
##   godot --headless --path . --script tools/import_sounds.gd
##   godot --headless --path . --import

const S := preload("res://tools/audio/synth.gd")
const SRC := "res://tools/audio/recorded/"
const OUT := "res://assets/sounds/"
const PREVIEW := "res://build/sound_preview"
const TEMP := "user://sound_import.raw"
const PREVIEW_GAP := 0.45
const PREVIEW_LOOP_SEC := 6.0
const LOOP_BLEND := 0.25

## Game sound: [source file, peak level].
const ONE_SHOTS := {
	"ui_click": ["wood_blocks.ogg", 0.34],
	"ui_hover": ["wood_click.ogg", 0.08],
	"panel_open": ["page_turn.ogg", 0.30],
	"panel_close": ["book_close.ogg", 0.28],
	"slot_select": ["wood_knock.ogg", 0.22],
	"dig": ["shovel_dirt.ogg", 0.50],
	"place": ["mug_on_wood.ogg", 0.50],
	"bed_unlock": ["key_unlock.ogg", 0.46],
	"harvest": ["pull_plant.ogg", 0.50],
	"ripe": ["leaves_rustle.ogg", 0.25],
	"sell_small": ["coin.1.ogg", 0.34],
	"sell_big": ["handleCoins.ogg", 0.42],
	"buy": ["handleCoins2.ogg", 0.32],
	"restock": ["shop_bell.ogg", 0.30],
	"step_grass_1": ["step_grass_a.ogg", 0.15],
	"step_grass_2": ["step_grass_c.ogg", 0.15],
	"step_stone_1": ["step_stone_a.ogg", 0.16],
	"step_stone_2": ["step_stone_b.ogg", 0.16],
}
## The useful part of a longer recording: [file, peak, start second, seconds].
const CUTS := {
	"water": ["watering_can.ogg", 0.42, 1.5, 1.6],
	"plant": ["shovel_calm.ogg", 0.46, 5.2, 0.8],
	"error": ["knock_wood.ogg", 0.34, 0.8, 0.7],
	"mutate": ["wind_chimes.ogg", 0.28, 0.0, 2.0],
	"golden": ["ding.ogg", 0.42, 0.44, 0.95],
	"rainbow": ["harp_glissando.ogg", 0.46, 0.0, 1.6],
	"quest": ["hand_bell.ogg", 0.42, 10.15, 0.85],
	"thunder": ["thunder.ogg", 0.62, 0.45, 3.7],
}
const CUT_FADE_IN := 0.005
const LOOPS := {
	"amb_day": ["birds-isaiah658_0.ogg", 0.30],
	"amb_night": ["crickets_1.mp3", 0.20],
	"amb_rain": ["rain_1.ogg", 0.42],
	"amb_frost": ["cold_wind.ogg", 0.34],
	"amb_fountain": ["loop_water_02.ogg", 0.36],
}
const REEL := [
	"ui_click", "ui_hover", "panel_open", "panel_close", "slot_select", "plant", "harvest",
	"ripe", "water", "dig", "place", "sell_small", "sell_big", "buy", "error", "restock",
	"mutate", "golden", "rainbow", "quest", "bed_unlock", "thunder", "step_grass_1",
	"step_stone_1", "step_grass_2", "step_stone_2", "amb_day", "amb_night", "amb_rain",
	"amb_frost", "amb_fountain",
]


func _init() -> void:
	for id: String in ONE_SHOTS:
		var clip := _trimmed(_decode(ONE_SHOTS[id][0]))
		var out := S.normalized(clip, ONE_SHOTS[id][1])
		S.fade_end(out, 0.01)
		S.save_wav(OUT + id + ".wav", out)
	for id: String in CUTS:
		var from := int(float(CUTS[id][2]) * S.RATE)
		var clip := _decode(CUTS[id][0]).slice(from, from + int(float(CUTS[id][3]) * S.RATE))
		var out := S.normalized(clip, CUTS[id][1])
		for i in int(CUT_FADE_IN * S.RATE):
			out[i] *= float(i) / (CUT_FADE_IN * S.RATE)
		S.fade_end(out, 0.25)
		S.save_wav(OUT + id + ".wav", out)
	for id: String in LOOPS:
		S.save_wav(OUT + id + ".wav", S.normalized(S.fold(_decode(LOOPS[id][0]), LOOP_BLEND), LOOPS[id][1]))
	_write_reel()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	quit()


func _decode(file_name: String) -> PackedFloat32Array:
	var temp := ProjectSettings.globalize_path(TEMP)
	var args := ["-y", "-v", "error", "-i", ProjectSettings.globalize_path(SRC + file_name), "-ac", "1", "-ar", str(S.RATE), "-f", "f32le", temp]
	var code := OS.execute("ffmpeg", args)
	assert(code == 0, "ffmpeg failed on " + file_name)
	return FileAccess.get_file_as_bytes(TEMP).to_float32_array()


## Cuts the silence off both ends, so a sound starts the moment it is triggered.
func _trimmed(b: PackedFloat32Array) -> PackedFloat32Array:
	var top := 0.0
	for v in b:
		top = maxf(top, absf(v))
	var limit := top * 0.01
	var start := 0
	while start < b.size() - 1 and absf(b[start]) <= limit:
		start += 1
	var end := b.size()
	while end > start + 1 and absf(b[end - 1]) <= limit:
		end -= 1
	return b.slice(start, end)


func _read_wav(path: String) -> PackedFloat32Array:
	var bytes := FileAccess.get_file_as_bytes(path).slice(44)
	var out := PackedFloat32Array()
	out.resize(bytes.size() / 2)
	for i in out.size():
		out[i] = bytes.decode_s16(i * 2) / 32767.0
	return out


func _write_reel() -> void:
	var reel := PackedFloat32Array()
	var timeline: Array[String] = []
	for id: String in REEL:
		var s := _read_wav(OUT + id + ".wav")
		var at := float(reel.size()) / S.RATE
		timeline.append("%d:%04.1f  %s  (%.2fs)" % [int(at) / 60, fmod(at, 60.0), id, float(s.size()) / S.RATE])
		reel.append_array(s.slice(0, int(PREVIEW_LOOP_SEC * S.RATE)) if id.begins_with("amb_") else s)
		reel.append_array(S.buf(PREVIEW_GAP))
	S.save_wav(PREVIEW + ".wav", reel)
	var f := FileAccess.open(PREVIEW + ".txt", FileAccess.WRITE)
	f.store_string("\n".join(timeline) + "\n")
	f.close()
	print("\n".join(timeline))
