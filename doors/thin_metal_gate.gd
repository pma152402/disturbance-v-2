extends "res://doors/push_door.gd"

const MIX_RATE := 22050

static var _opening_stream: AudioStreamWAV
static var _closing_stream: AudioStreamWAV


func _ready() -> void:
	super()
	# Esta reja no comparte el foley largo de madera de las puertas de la casa.
	door_sound.stream = _make_gate_stream(true)


func _play_door_sound(opening: bool) -> void:
	door_sound.stream = _make_gate_stream(opening)
	door_sound.volume_db = volumen_apertura_db if opening else volumen_cierre_db
	door_sound.pitch_scale = randf_range(0.97, 1.03)
	door_sound.play()


static func _make_gate_stream(opening: bool) -> AudioStreamWAV:
	if opening and _opening_stream != null:
		return _opening_stream
	if not opening and _closing_stream != null:
		return _closing_stream

	var duration := 0.82 if opening else 0.68
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91337 if opening else 91381
	var scrape := 0.0
	var bounce_times := PackedFloat32Array([0.54, 0.625, 0.705]) if opening else PackedFloat32Array([0.43, 0.515, 0.59])

	for index in sample_count:
		var time := float(index) / MIX_RATE
		# Friccion de bisagra y flexion irregular de una hoja de metal ligera.
		var motion_envelope := sin(PI * minf(time / (duration * 0.82), 1.0))
		if time > duration * 0.82:
			motion_envelope = 0.0
		scrape = lerpf(scrape, rng.randf_range(-1.0, 1.0), 0.075)
		var wobble := sin(TAU * (8.0 + sin(time * 17.0) * 2.2) * time)
		var hinge := sin(TAU * (265.0 + wobble * 48.0) * time) * motion_envelope * 0.16
		var metal_flex := (
			sin(TAU * 515.0 * time) * 0.10
			+ sin(TAU * 1035.0 * time) * 0.055
		) * motion_envelope * (0.65 + wobble * 0.25)
		var texture := scrape * motion_envelope * 0.13

		# Al llegar al marco, la hoja transmite tres rebotes cada vez mas debiles
		# a la malla metalica circundante.
		var fence_rattle := 0.0
		for bounce_index in bounce_times.size():
			var bounce_time := time - bounce_times[bounce_index]
			if bounce_time < 0.0:
				continue
			var strength := (0.52 if opening else 0.72) * pow(0.48, bounce_index)
			var decay := exp(-bounce_time * (31.0 + bounce_index * 7.0))
			fence_rattle += strength * decay * (
				sin(TAU * 690.0 * bounce_time)
				+ sin(TAU * 1170.0 * bounce_time) * 0.58
				+ sin(TAU * 1840.0 * bounce_time) * 0.28
			)

		var attack := minf(time / 0.004, 1.0)
		var end_fade := minf((duration - time) / 0.035, 1.0)
		samples[index] = clampf((hinge + metal_flex + texture + fence_rattle) * attack * end_fade, -1.0, 1.0)

	var stream := _stream_from_samples(samples)
	if opening:
		_opening_stream = stream
	else:
		_closing_stream = stream
	return stream


static func _stream_from_samples(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		var encoded := int(clampf(samples[index], -1.0, 1.0) * 32767.0)
		bytes[index * 2] = encoded & 0xff
		bytes[index * 2 + 1] = (encoded >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
