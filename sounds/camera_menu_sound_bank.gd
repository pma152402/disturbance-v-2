extends RefCounted

## Sonidos diegeticos del menu de la videocamara. Se sintetizan una sola vez
## para mantenerlos libres de dependencias externas y con una textura coherente.

const MIX_RATE := 22050

static var _cache: Dictionary = {}


static func make(sound_kind: StringName) -> AudioStreamWAV:
	if _cache.has(sound_kind):
		return _cache[sound_kind] as AudioStreamWAV
	var stream := _synthesize(sound_kind)
	_cache[sound_kind] = stream
	return stream


static func _synthesize(sound_kind: StringName) -> AudioStreamWAV:
	var duration := _duration_for(sound_kind)
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("camera_menu:%s" % sound_kind)
	var filtered_noise := 0.0
	var motor_phase := 0.0
	for index: int in sample_count:
		var time := float(index) / MIX_RATE
		filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.19)
		var sample := 0.0
		match sound_kind:
			&"power_on":
				# Relé, motor del tambor cogiendo velocidad y breve siseo de cinta.
				var relay := _impact(time, 0.0, 920.0, 105.0, 0.38)
				var motor_env := (1.0 - exp(-time * 13.0)) * exp(-time * 2.8)
				motor_phase += TAU * lerpf(72.0, 148.0, clampf(time / duration, 0.0, 1.0)) / MIX_RATE
				var motor := sin(motor_phase) * motor_env * 0.25
				var head_lock := _impact(time, 0.265, 1380.0, 72.0, 0.24)
				var tape_hiss := filtered_noise * motor_env * 0.14
				sample = relay + motor + head_lock + tape_hiss
			&"power_off":
				# Freno del tambor y liberacion mecanica del cabezal.
				var brake_phase := TAU * (152.0 * time - 118.0 * time * time)
				var brake := sin(brake_phase) * exp(-time * 8.5) * 0.3
				var release := _impact(time, 0.105, 690.0, 72.0, 0.34)
				var latch := _impact(time, 0.205, 1250.0, 92.0, 0.2)
				sample = brake + release + latch + filtered_noise * exp(-time * 13.0) * 0.1
			&"mode":
				# El cabezal busca la siguiente seccion del OSD.
				var clunk := _impact(time, 0.0, 510.0, 48.0, 0.34)
				var seek_env := sin(PI * clampf(time / duration, 0.0, 1.0))
				motor_phase += TAU * (190.0 + sin(time * 38.0) * 26.0) / MIX_RATE
				var seek := sin(motor_phase) * seek_env * 0.2
				var lock := _impact(time, 0.16, 1320.0, 95.0, 0.27)
				sample = clunk + seek + lock + filtered_noise * seek_env * 0.08
			&"cursor":
				# Pulsador pequeño de goma con su retorno.
				sample = (
					_impact(time, 0.0, 1720.0, 145.0, 0.34)
					+ _impact(time, 0.026, 1080.0, 165.0, 0.22)
					+ _impact(time, 0.0, 285.0, 85.0, 0.15)
				)
			&"adjust":
				# Diente de rueda y pequeño rebote metalico.
				sample = (
					_impact(time, 0.0, 1380.0, 108.0, 0.34)
					+ _impact(time, 0.032, 820.0, 120.0, 0.25)
					+ filtered_noise * exp(-time * 105.0) * 0.08
				)
			&"confirm":
				# Boton grande: golpe de plastico y contacto electrico.
				sample = (
					_impact(time, 0.0, 620.0, 58.0, 0.42)
					+ _impact(time, 0.044, 1450.0, 105.0, 0.26)
					+ _impact(time, 0.0, 185.0, 42.0, 0.2)
				)
			&"timer_arm":
				# Pestillo del autodisparador y tono breve del circuito de cuenta atras.
				sample = (
					_impact(time, 0.0, 540.0, 58.0, 0.34)
					+ sin(TAU * 1040.0 * time) * exp(-time * 18.0) * 0.22
					+ filtered_noise * exp(-time * 70.0) * 0.06
				)
			&"timer_tick":
				# Pitido seco y ligeramente inestable de una camara domestica antigua.
				var tone := sin(TAU * (930.0 + sin(time * 44.0) * 9.0) * time) * exp(-time * 24.0)
				sample = tone * 0.3 + _impact(time, 0.0, 1680.0, 125.0, 0.12)
			&"record_start":
				# Pulsador REC, rele y tambor empezando a arrastrar la cinta.
				var rec_button := _impact(time, 0.0, 490.0, 48.0, 0.42)
				var rec_relay := _impact(time, 0.048, 1320.0, 92.0, 0.26)
				var rec_motor_env := (1.0 - exp(-time * 18.0)) * exp(-time * 3.2)
				motor_phase += TAU * lerpf(76.0, 158.0, minf(time / 0.22, 1.0)) / MIX_RATE
				var rec_tone_time := maxf(time - 0.11, 0.0)
				var rec_tone := sin(TAU * 1180.0 * rec_tone_time) * exp(-rec_tone_time * 22.0) * 0.16
				if time < 0.11:
					rec_tone = 0.0
				sample = rec_button + rec_relay + sin(motor_phase) * rec_motor_env * 0.25 + rec_tone
			&"record_stop":
				# Boton STOP, frenado del tambor y liberacion del transporte.
				var stop_button := _impact(time, 0.0, 430.0, 50.0, 0.4)
				var rec_brake_phase := TAU * (154.0 * time - 178.0 * time * time)
				var rec_brake := sin(rec_brake_phase) * exp(-time * 10.0) * 0.27
				var rec_release := _impact(time, 0.12, 860.0, 78.0, 0.3)
				sample = stop_button + rec_brake + rec_release
			&"transport_play":
				var engage := _impact(time, 0.0, 470.0, 50.0, 0.38)
				var motor_env := (1.0 - exp(-time * 19.0)) * exp(-time * 3.8)
				motor_phase += TAU * lerpf(88.0, 164.0, minf(time / 0.18, 1.0)) / MIX_RATE
				sample = engage + sin(motor_phase) * motor_env * 0.26 + filtered_noise * motor_env * 0.1
			&"transport_pause":
				var stop_phase := TAU * (145.0 * time - 165.0 * time * time)
				sample = sin(stop_phase) * exp(-time * 13.0) * 0.27 + _impact(time, 0.075, 540.0, 70.0, 0.38)
			&"tape_seek":
				var seek_env := sin(PI * clampf(time / duration, 0.0, 1.0))
				motor_phase += TAU * (225.0 + sin(time * 52.0) * 34.0) / MIX_RATE
				sample = (
					_impact(time, 0.0, 530.0, 62.0, 0.28)
					+ sin(motor_phase) * seek_env * 0.23
					+ filtered_noise * seek_env * 0.11
				)
			&"tape_lock":
				sample = _impact(time, 0.0, 760.0, 62.0, 0.38) + _impact(time, 0.055, 1280.0, 105.0, 0.28)
			&"delete":
				var erase_noise := filtered_noise * exp(-time * 9.0) * 0.18
				sample = _impact(time, 0.0, 350.0, 38.0, 0.46) + erase_noise + _impact(time, 0.15, 980.0, 80.0, 0.28)
			&"error":
				var first := sin(TAU * 185.0 * time) * exp(-time * 24.0) * 0.3
				var second_time := maxf(time - 0.095, 0.0)
				var second := sin(TAU * 165.0 * second_time) * exp(-second_time * 25.0) * 0.3
				if time < 0.095:
					second = 0.0
				sample = first + second
			_:
				sample = 0.0
		var fade_out := clampf((duration - time) / 0.012, 0.0, 1.0)
		samples[index] = clampf(sample * minf(time / 0.0008, 1.0) * fade_out * 0.82, -1.0, 1.0)
	return _stream_from_samples(samples)


static func _duration_for(sound_kind: StringName) -> float:
	match sound_kind:
		&"power_on": return 0.52
		&"power_off": return 0.34
		&"mode": return 0.28
		&"cursor": return 0.075
		&"adjust": return 0.11
		&"confirm": return 0.16
		&"timer_arm": return 0.2
		&"timer_tick": return 0.14
		&"record_start": return 0.42
		&"record_stop": return 0.28
		&"transport_play": return 0.32
		&"transport_pause": return 0.18
		&"tape_seek": return 0.42
		&"tape_lock": return 0.13
		&"delete": return 0.29
		&"error": return 0.22
		_: return 0.05


static func _impact(time: float, delay: float, frequency: float, decay: float, gain: float) -> float:
	if time < delay:
		return 0.0
	var local_time := time - delay
	return sin(TAU * frequency * local_time) * exp(-local_time * decay) * gain


static func _stream_from_samples(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index: int in samples.size():
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
