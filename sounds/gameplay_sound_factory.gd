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
