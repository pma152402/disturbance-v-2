class_name GameplaySoundFactory
extends RefCounted

const MIX_RATE := 22050

static var _switch_click_cache: AudioStreamWAV
static var _footstep_normal_cache: AudioStreamWAV
static var _footstep_wood_cache: AudioStreamWAV
static var _footstep_outdoor_cache: AudioStreamWAV
static var _can_impact_cache: AudioStreamWAV
static var _glass_break_cache: AudioStreamWAV
static var _door_open_cache: AudioStreamWAV
static var _door_close_cache: AudioStreamWAV


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
	return make_footstep_normal()


static func make_footstep_normal() -> AudioStreamWAV:
	if _footstep_normal_cache != null:
		return _footstep_normal_cache
	var duration := 0.19
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90217
	var smoothed_noise := 0.0
	for index in sample_count:
		var time := float(index) / MIX_RATE
		smoothed_noise = lerpf(smoothed_noise, rng.randf_range(-1.0, 1.0), 0.16)
		var heel := sin(TAU * (104.0 - time * 170.0) * time) * exp(-time * 25.0)
		var sole_time := maxf(time - 0.045, 0.0)
		var sole := sin(TAU * 64.0 * sole_time) * exp(-sole_time * 30.0)
		if time < 0.045:
			sole = 0.0
		var texture := smoothed_noise * exp(-time * 18.0)
		samples[index] = clampf(heel * 0.62 + sole * 0.32 + texture * 0.34, -1.0, 1.0)
	_footstep_normal_cache = _stream_from_samples(samples)
	return _footstep_normal_cache


static func make_footstep_wood() -> AudioStreamWAV:
	if _footstep_wood_cache != null:
		return _footstep_wood_cache
	var duration := 0.24
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73103
	var smoothed_noise := 0.0
	for index in sample_count:
		var time := float(index) / MIX_RATE
		smoothed_noise = lerpf(smoothed_noise, rng.randf_range(-1.0, 1.0), 0.11)
		var knock := sin(TAU * (185.0 - time * 210.0) * time) * exp(-time * 23.0)
		var board := sin(TAU * 345.0 * time + 0.25) * exp(-time * 17.0)
		var creak := sin(TAU * (92.0 + sin(time * 31.0) * 18.0) * time) * exp(-time * 11.0)
		var grain := smoothed_noise * exp(-time * 22.0)
		samples[index] = clampf(knock * 0.62 + board * 0.27 + creak * 0.18 + grain * 0.2, -1.0, 1.0)
	_footstep_wood_cache = _stream_from_samples(samples)
	return _footstep_wood_cache


static func make_footstep_outdoor() -> AudioStreamWAV:
	if _footstep_outdoor_cache != null:
		return _footstep_outdoor_cache
	var duration := 0.23
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61847
	var coarse_noise := 0.0
	var fine_noise := 0.0
	for index in sample_count:
		var time := float(index) / MIX_RATE
		coarse_noise = lerpf(coarse_noise, rng.randf_range(-1.0, 1.0), 0.09)
		fine_noise = lerpf(fine_noise, rng.randf_range(-1.0, 1.0), 0.32)
		var thump := sin(TAU * (78.0 - time * 95.0) * time) * exp(-time * 24.0)
		var crunch := (coarse_noise * 0.72 + fine_noise * 0.28) * exp(-time * 15.0)
		var second_crunch_time := maxf(time - 0.055, 0.0)
		var second_crunch := fine_noise * exp(-second_crunch_time * 24.0)
		if time < 0.055:
			second_crunch = 0.0
		samples[index] = clampf(thump * 0.45 + crunch * 0.62 + second_crunch * 0.22, -1.0, 1.0)
	_footstep_outdoor_cache = _stream_from_samples(samples)
	return _footstep_outdoor_cache


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
