class_name GameplaySoundFactory
extends RefCounted

const MIX_RATE := 22050


static func make_switch_click() -> AudioStreamWAV:
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
	return _stream_from_samples(samples)


static func make_footstep() -> AudioStreamWAV:
	var duration := 0.16
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90217
	var smoothed_noise := 0.0
	for index in sample_count:
		var time := float(index) / MIX_RATE
		smoothed_noise = lerpf(smoothed_noise, rng.randf_range(-1.0, 1.0), 0.16)
		var heel := sin(TAU * (92.0 - time * 170.0) * time) * exp(-time * 29.0)
		var sole_time := maxf(time - 0.045, 0.0)
		var sole := sin(TAU * 58.0 * sole_time) * exp(-sole_time * 34.0)
		if time < 0.045:
			sole = 0.0
		var texture := smoothed_noise * exp(-time * 18.0)
		samples[index] = clampf(heel * 0.42 + sole * 0.22 + texture * 0.28, -1.0, 1.0)
	return _stream_from_samples(samples)


static func make_can_impact() -> AudioStreamWAV:
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
	return _stream_from_samples(samples)


static func make_glass_break() -> AudioStreamWAV:
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
	return _stream_from_samples(samples)


static func make_door_open() -> AudioStreamWAV:
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
	return _stream_from_samples(samples)


static func make_door_close() -> AudioStreamWAV:
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
	return _stream_from_samples(samples)


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
