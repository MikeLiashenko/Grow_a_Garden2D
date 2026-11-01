extends RefCounted
## Sound synthesiser built on materials instead of raw waveforms: struck wood and
## metal (damped resonant modes), plucked strings, grains of soil, water drops.
## Sounds are float buffers mixed additively; events placed with wrap = true run
## past the end back to the start, for loops.

const RATE := 44100

## Resonant modes of struck objects: [frequency ratio, loudness, decay seconds].
## The ratios are not whole numbers, which is what makes them sound like objects.
const WOOD := [[1.0, 1.0, 0.035], [2.41, 0.6, 0.02], [3.93, 0.35, 0.012], [5.6, 0.15, 0.007]]
const MARIMBA := [[1.0, 1.0, 0.3], [3.93, 0.35, 0.09], [9.2, 0.1, 0.025]]
const KALIMBA := [[1.0, 1.0, 0.5], [6.27, 0.22, 0.06], [2.0, 0.08, 0.2]]
const COIN := [[1.0, 1.0, 0.22], [1.47, 0.7, 0.16], [2.09, 0.55, 0.12], [2.56, 0.35, 0.09], [3.22, 0.25, 0.06]]
const BELL := [[0.5, 0.35, 1.1], [1.0, 1.0, 0.8], [1.19, 0.55, 0.6], [1.5, 0.35, 0.45], [2.0, 0.4, 0.35], [2.67, 0.2, 0.25], [4.0, 0.1, 0.15]]
const GLASS := [[1.0, 1.0, 0.5], [2.76, 0.5, 0.25], [5.4, 0.2, 0.1]]
const THUD := [[1.0, 1.0, 0.07], [1.8, 0.4, 0.04]]
const STONE := [[1.0, 1.0, 0.012], [2.3, 0.5, 0.008], [4.1, 0.25, 0.005]]


static func buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	b.fill(0.0)
	return b


## Strikes an object: every mode rings and dies away at its own rate.
static func strike(b: PackedFloat32Array, t0: float, f: float, modes: Array, vol: float) -> void:
	var start := int(t0 * RATE)
	for m: Array in modes:
		var step: float = TAU * f * m[0] / RATE
		if step >= PI:
			continue
		var seconds: float = m[2]
		var fall := exp(-1.0 / (seconds * RATE))
		var amp: float = vol * m[1]
		var phase := 0.0
		for i in mini(int(seconds * 7.0 * RATE), b.size() - start):
			b[start + i] += sin(phase) * amp
			phase += step
			amp *= fall


## A plucked string (Karplus-Strong): a burst of noise circulating in a short delay.
static func pluck(b: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, f: float, vol: float, dur: float, bright := 0.997) -> void:
	var n := maxi(int(RATE / f), 2)
	var line := PackedFloat32Array()
	line.resize(n)
	var soft := 0.0
	for i in n:
		soft += (rng.randf_range(-1.0, 1.0) - soft) * 0.6
		line[i] = soft
	var start := int(t0 * RATE)
	var total := int(dur * RATE)
	var at := 0
	for i in mini(total, b.size() - start):
		var next := (at + 1) % n
		var out := line[at]
		b[start + i] += out * vol * minf((total - i) / (RATE * 0.01), 1.0)
		line[at] = (out + line[next]) * 0.5 * bright
		at = next


## A sine that glides and may wobble (vib_hz, vib_depth as a fraction of the pitch).
## Used for bird syllables, water drops and the low end of a pop.
static func glide(b: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, vol: float, decay := 4.0, attack := 0.02, wrap := false, vib_hz := 0.0, vib_depth := 0.0) -> void:
	var start := int(t0 * RATE)
	var n := int(dur * RATE)
	var size := b.size()
	var phase := 0.0
	for i in n:
		var u := float(i) / n
		var f := lerpf(f0, f1, u)
		if vib_hz > 0.0:
			f *= 1.0 + sin(TAU * vib_hz * i / RATE) * vib_depth
		phase += TAU * f / RATE
		var at := start + i
		if wrap:
			at = posmod(at, size)
		elif at >= size:
			break
		b[at] += sin(phase) * vol * _env(u, attack, decay)


## Attack, then an exponential fall reaching silence at the end of the note.
static func _env(u: float, attack: float, decay: float) -> float:
	var hit := minf(u / maxf(attack, 0.0001), 1.0)
	return hit * exp(-decay * u) * minf((1.0 - u) * 12.0, 1.0)


## Filtered noise. The low-pass cutoff sweeps from lp0 to lp1 Hz; hp removes rumble.
static func noise(b: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, vol: float, lp0: float, lp1: float, decay := 4.0, attack := 0.02, hp := 0.0, wrap := false) -> void:
	var start := int(t0 * RATE)
	var n := int(dur * RATE)
	var size := b.size()
	var low := 0.0
	var slow := 0.0
	var hp_k := 1.0 - exp(-TAU * hp / RATE)
	for i in n:
		var u := float(i) / n
		var k := 1.0 - exp(-TAU * lerpf(lp0, lp1, u) / RATE)
		low += (rng.randf_range(-1.0, 1.0) - low) * k
		slow += (low - slow) * hp_k
		var at := start + i
		if wrap:
			at = posmod(at, size)
		elif at >= size:
			break
		b[at] += (low - slow) * vol * _env(u, attack, decay)


## Many tiny bursts of noise: soil, gravel, rustling leaves, paper.
static func grains(b: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, count: int, vol: float, lp: float, hp: float, wrap := false) -> void:
	for i in count:
		var fade := 1.0 - float(i) / count * 0.6
		noise(b, rng, t0 + rng.randf() * dur, rng.randf_range(0.003, 0.012), vol * fade * rng.randf_range(0.5, 1.0), lp, lp * 0.7, 3.0, 0.1, hp, wrap)


## Endless noise bed for a loop; cutoff and level drift with whole cycles of a
## slow sine so the end meets the start. Call fold() afterwards to hide the seam.
static func bed(b: PackedFloat32Array, rng: RandomNumberGenerator, vol: float, lp: float, lp_drift: float, vol_drift: float, cycles: int, hp := 0.0) -> void:
	var low := 0.0
	var slow := 0.0
	var hp_k := 1.0 - exp(-TAU * hp / RATE)
	for i in b.size():
		var s := sin(float(i) / b.size() * TAU * cycles)
		var k := 1.0 - exp(-TAU * maxf(lp + lp_drift * s, 20.0) / RATE)
		low += (rng.randf_range(-1.0, 1.0) - low) * k
		slow += (low - slow) * hp_k
		b[i] += (low - slow) * vol * (1.0 + vol_drift * s)


## Blends the last sec seconds over the start and cuts them off: a seamless loop.
static func fold(b: PackedFloat32Array, sec: float) -> PackedFloat32Array:
	var x := int(sec * RATE)
	var keep := b.size() - x
	var out := b.slice(0, keep)
	for i in x:
		var u := float(i) / x
		out[i] = b[i] * sqrt(u) + b[keep + i] * sqrt(1.0 - u)
	return out


## Puts a sound in a small outdoor space (Schroeder reverb) and adds the tail.
static func room(dry: PackedFloat32Array, wet: float, feedback := 0.72, tail := 0.5) -> PackedFloat32Array:
	var b := buf(float(dry.size()) / RATE + tail)
	for i in dry.size():
		b[i] = dry[i]
	var out := b.duplicate()
	out.fill(0.0)
	for ms: float in [29.7, 37.1, 41.1, 43.7]:
		var line := buf(ms * 0.001)
		var at := 0
		var soft := 0.0
		for i in b.size():
			var d := line[at]
			soft += (d - soft) * 0.45
			line[at] = b[i] + soft * feedback
			out[i] += d
			at = (at + 1) % line.size()
	for ms: float in [5.0, 1.7]:
		var line := buf(ms * 0.001)
		var at := 0
		for i in out.size():
			var d := line[at]
			var v := out[i] + d * 0.6
			line[at] = v
			out[i] = d - v * 0.6
			at = (at + 1) % line.size()
	for i in b.size():
		b[i] += out[i] * wet * 0.25
	return b


static func normalized(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0001
	for v in b:
		top = maxf(top, absf(v))
	var out := b.duplicate()
	for i in out.size():
		out[i] = b[i] / top * peak
	return out


## Fades the last moments so a sound never ends in a click.
static func fade_end(b: PackedFloat32Array, sec := 0.02) -> void:
	var n := mini(int(sec * RATE), b.size())
	for i in n:
		b[b.size() - 1 - i] *= float(i) / n


static func save_wav(path: String, b: PackedFloat32Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	var bytes := b.size() * 2
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + bytes)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1) # PCM
	f.store_16(1) # mono
	f.store_32(RATE)
	f.store_32(RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(bytes)
	for v in b:
		f.store_16(int(clampf(v, -1.0, 1.0) * 32767.0) & 0xffff)
	f.close()
