class_name GameplaySoundFactory
extends RefCounted

const MIX_RATE := 22050

static var _switch_click_cache: AudioStreamWAV
static var _can_impact_cache: AudioStreamWAV
static var _glass_break_cache: AudioStreamWAV
static var _door_open_cache: AudioStreamWAV
static var _door_close_cache: AudioStreamWAV
static var _outdoor_footstep_cache: Dictionary = {}


static func prewarm_footsteps() -> void:
	# Se hace una sola vez al cargar al jugador. Así el primer paso sobre un
	# material nuevo no tiene que sintetizar audio durante un fotograma de juego.
	for variant in 4:
		make_outdoor_footstep(variant)


static func make_switch_click() -> AudioStreamWAV:
	if _switch_click_cache != null:
		return _switch_click_cache
	var duration := 0.105
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 48151
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var first_snap := exp(-time * 72.0) * sin(TAU * 1180.0 * time)
		var second_time := maxf(time - 0.038, 0.0)
		var second_snap := 0.48 * exp(-second_time * 95.0) * sin(TAU * 720.0 * second_time)
		if time < 0.038:
			second_snap = 0.0
		var body := 0.34 * exp(-time * 38.0) * sin(TAU * 165.0 * time)
		var grit := rng.randf_range(-1.0, 1.0) * exp(-time * 85.0) * 0.14
		samples[index] = clampf((first_snap * 0.48 + second_snap + body + grit) * 0.72, -1.0, 1.0)
	_switch_click_cache = _stream_from_samples(samples)
	return _switch_click_cache


static func make_footstep() -> AudioStreamWAV:
	return make_outdoor_footstep(0)


static func make_outdoor_footstep(variant: int = 0) -> AudioStreamWAV:
	var safe_variant := posmod(variant, 4)
	if _outdoor_footstep_cache.has(safe_variant):
		return _outdoor_footstep_cache[safe_variant] as AudioStreamWAV
	var duration := 0.25
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 115079 + safe_variant * 7919
	var tuning := rng.randf_range(0.92, 1.08)
	var toe_delay := rng.randf_range(0.035, 0.052)
	var coarse_noise := 0.0
	var soft_noise := 0.0
	for index in sample_count:
		var time := float(index) / MIX_RATE
		coarse_noise = lerpf(coarse_noise, rng.randf_range(-1.0, 1.0), 0.10)
		soft_noise = lerpf(soft_noise, rng.randf_range(-1.0, 1.0), 0.035)
		var toe_time := maxf(time - toe_delay, 0.0)
		var toe_gate := 0.0 if toe_time <= 0.0 else 1.0
		var thump := sin(TAU * (74.0 * tuning - time * 65.0) * time) * exp(-time * 24.0)
		var crunch := (coarse_noise * 0.72 + soft_noise * 0.28) * exp(-time * 14.0)
		var second_crunch := coarse_noise * exp(-toe_time * 21.0) * toe_gate
		var sample := thump * 0.48 + crunch * 0.65 + second_crunch * 0.22
		samples[index] = clampf(sample * 0.88, -1.0, 1.0)
	var stream := _stream_from_samples(samples)
	_outdoor_footstep_cache[safe_variant] = stream
	return stream


static func make_can_impact() -> AudioStreamWAV:
	if _can_impact_cache != null:
		return _can_impact_cache
	var duration := 0.24
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73129
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var strike := sin(TAU * 780.0 * time) * exp(-time * 24.0)
		var ring := sin(TAU * 1260.0 * time + 0.4) * exp(-time * 15.0)
		var body := sin(TAU * 185.0 * time) * exp(-time * 31.0)
		var rattle := rng.randf_range(-1.0, 1.0) * exp(-time * 38.0)
		samples[index] = clampf(strike * 0.35 + ring * 0.2 + body * 0.28 + rattle * 0.12, -1.0, 1.0)
	_can_impact_cache = _stream_from_samples(samples)
	return _can_impact_cache


static func make_glass_break() -> AudioStreamWAV:
	if _glass_break_cache != null:
		return _glass_break_cache
	var duration := 0.42
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19477
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var initial_crack := noise * exp(-time * 42.0)
		var chime_a := sin(TAU * 2150.0 * time) * exp(-time * 13.0)
		var chime_b := sin(TAU * 3370.0 * time + 0.7) * exp(-time * 17.0)
		var scatter_time := maxf(time - 0.075, 0.0)
		var scatter := rng.randf_range(-1.0, 1.0) * exp(-scatter_time * 11.0)
		if time < 0.075:
			scatter = 0.0
		samples[index] = clampf(initial_crack * 0.5 + chime_a * 0.18 + chime_b * 0.12 + scatter * 0.18, -1.0, 1.0)
	_glass_break_cache = _stream_from_samples(samples)
	return _glass_break_cache


static func make_door_open() -> AudioStreamWAV:
	if _door_open_cache != null:
		return _door_open_cache
	var duration := 0.38
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61043
	var smoothed_noise := 0.0
	for index in sample_count:
		var time := float(index) / MIX_RATE
		smoothed_noise = lerpf(smoothed_noise, rng.randf_range(-1.0, 1.0), 0.055)
		var sweep_frequency := 118.0 + sin(time * 17.0) * 42.0 + time * 95.0
		var creak := sin(TAU * sweep_frequency * time) * sin(PI * clampf(time / duration, 0.0, 1.0))
		var hinge_grit := smoothed_noise * sin(PI * clampf(time / duration, 0.0, 1.0))
		var latch := sin(TAU * 640.0 * time) * exp(-time * 70.0)
		samples[index] = clampf(creak * 0.38 + hinge_grit * 0.24 + latch * 0.18, -1.0, 1.0)
	_door_open_cache = _stream_from_samples(samples)
	return _door_open_cache


static func make_door_close() -> AudioStreamWAV:
	if _door_close_cache != null:
		return _door_close_cache
	var duration := 0.26
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 84731
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var wood_thud := sin(TAU * (92.0 - time * 80.0) * time) * exp(-time * 24.0)
		var frame_hit := rng.randf_range(-1.0, 1.0) * exp(-time * 58.0)
		var latch_time := maxf(time - 0.055, 0.0)
		var latch := sin(TAU * 920.0 * latch_time) * exp(-latch_time * 75.0)
		if time < 0.055:
			latch = 0.0
		samples[index] = clampf(wood_thud * 0.52 + frame_hit * 0.24 + latch * 0.3, -1.0, 1.0)
	_door_close_cache = _stream_from_samples(samples)
	return _door_close_cache


static func _stream_from_samples(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		var encoded := int(clampf(samples[index], -1.0, 1.0) * 32767.0)
		if encoded < 0:
			encoded += 65536
		bytes[index * 2] = encoded & 0xff
		bytes[index * 2 + 1] = (encoded >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
