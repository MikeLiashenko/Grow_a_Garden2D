extends Node
## Plays sound effects and the looping ambience, each on a bus with its own
## volume setting. Sound files come from tools/generate_sounds.gd.

const DIR := "res://assets/sounds/"
const SOUNDS := [
	"ui_click", "ui_hover", "panel_open", "panel_close", "slot_select",
	"plant", "harvest", "ripe", "water", "dig", "place",
	"sell_small", "sell_big", "buy", "error", "restock",
	"mutate", "golden", "rainbow", "quest", "bed_unlock", "thunder",
	"step_grass_1", "step_grass_2", "step_stone_1", "step_stone_2",
]
const LOOPS := ["amb_day", "amb_night", "amb_rain", "amb_frost", "amb_fountain"]
## Seconds a sound must wait before it may play again.
const MIN_GAP := {
	"ripe": 4.0, "error": 0.5, "thunder": 1.5, "mutate": 0.25, "golden": 0.25, "rainbow": 0.25,
	"plant": 0.06, "harvest": 0.03, "ui_hover": 0.05, "sell_small": 0.05,
}
const VOICES := 14
const AMBIENCE_FADE := 0.5
const MUSIC_DIR := "res://assets/music/"
## Tracks for each mood; they play in turn, and a lone track simply repeats.
const MUSIC := {
	"menu": ["First_Light_on_the_Ridge"],
	"day": ["Sunlight_on_the_Path", "The_Porch_at_Noon"],
	"night": ["Tides_of_Velvet_Night"],
}
const MUSIC_FADE := 2.5

## How many times each sound has played; the automated tour checks this.
var played := {}
var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played := {}
var _loops := {}
var _targets := {}
var _focused := true
var _silent := OS.has_environment("GG_TOUR")
var _hovered_at := Vector2(-1, -1)
var _mood := ""
var _mood_turn := {}
var _music_players: Array[AudioStreamPlayer] = []
var _music_levels: Array[float] = [0.0, 0.0]
var _music_now := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Sounds", "Ambience", "Music"]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	for id in SOUNDS:
		_streams[id] = load(DIR + id + ".wav")
	for i in VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = "Sounds"
		add_child(v)
		_voices.append(v)
	for id in LOOPS:
		var stream: AudioStreamWAV = load(DIR + id + ".wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = "Ambience"
		p.volume_db = -80.0
		add_child(p)
		_loops[id] = {"player": p, "level": 0.0}
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		m.finished.connect(_on_music_finished.bind(i))
		add_child(m)
		_music_players.append(m)
	Settings.changed.connect(_apply_volumes)
	_apply_volumes()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = what == NOTIFICATION_APPLICATION_FOCUS_IN
		if is_node_ready():
			_apply_volumes()


func _apply_volumes() -> void:
	_set_bus("Master", Settings.get_value("master_volume"))
	_set_bus("Sounds", Settings.get_value("sfx_volume"))
	_set_bus("Ambience", Settings.get_value("ambience_volume"))
	_set_bus("Music", Settings.get_value("music_volume"))
	# The automated tour stays silent so a test run never comes out of the speakers.
	if _silent or (not _focused and Settings.get_value("mute_unfocused")):
		AudioServer.set_bus_mute(0, true)


## percent is 0-100; squared because hearing is far from linear.
func _set_bus(bus_name: String, percent: int) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	var v := percent / 100.0
	AudioServer.set_bus_mute(i, percent <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v * v, 0.0001)))


func play(id: String, pitch := 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -100.0)) < float(MIN_GAP.get(id, 0.0)):
		return
	_last_played[id] = now
	played[id] = int(played.get(id, 0)) + 1
	var v := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	v.stream = _streams[id]
	v.pitch_scale = pitch
	v.play()


## Plays one of the numbered takes of a sound, slightly detuned so repeats blend.
func play_varied(id: String, takes: int) -> void:
	play("%s_%d" % [id, randi_range(1, takes)], randf_range(0.93, 1.07))


## A button under the cursor is often rebuilt in place when a shop refreshes,
## so hovering only sounds when the cursor reaches a new position.
func hover(b: Button) -> void:
	var at := b.get_global_rect().position
	if at != _hovered_at and not b.disabled:
		play("ui_hover")
	_hovered_at = at


## Sets how loud each ambience loop should be (0-1); anything left out fades away.
func set_ambience(levels: Dictionary) -> void:
	_targets = levels


func ambience_level(id: String) -> float:
	return _loops[id]["level"]


## Crossfades to a track for this mood; does nothing if the mood is already on.
func set_music(mood: String) -> void:
	if mood != _mood:
		_mood = mood
		_next_track()


func music_mood() -> String:
	return _mood


func is_music_playing() -> bool:
	return _music_players[_music_now].playing


func _next_track() -> void:
	var list: Array = MUSIC[_mood]
	var turn: int = _mood_turn.get(_mood, 0)
	_mood_turn[_mood] = (turn + 1) % list.size()
	_music_now = 1 - _music_now
	var p := _music_players[_music_now]
	p.stream = load(MUSIC_DIR + list[turn] + ".mp3")
	p.play()


func _on_music_finished(player: int) -> void:
	if player == _music_now:
		_next_track()


func _process(delta: float) -> void:
	for i in 2:
		var p := _music_players[i]
		var want := 1.0 if i == _music_now and _mood != "" else 0.0
		_music_levels[i] = move_toward(_music_levels[i], want, delta / MUSIC_FADE)
		p.volume_db = linear_to_db(maxf(_music_levels[i], 0.0001))
		if want == 0.0 and _music_levels[i] <= 0.0 and p.playing:
			p.stop()
	for id in _loops:
		var e: Dictionary = _loops[id]
		var p: AudioStreamPlayer = e["player"]
		var want := float(_targets.get(id, 0.0))
		if e["level"] == want and (want > 0.0) == p.playing:
			continue
		e["level"] = move_toward(e["level"], want, delta * AMBIENCE_FADE)
		p.volume_db = linear_to_db(maxf(e["level"], 0.0001))
		if e["level"] > 0.0 and not p.playing:
			p.play()
		elif e["level"] <= 0.0 and p.playing:
			p.stop()
