class_name GameplaySoundFactory
extends RefCounted

const MIX_RATE := 22050

static var _switch_click_cache: AudioStreamWAV
static var _can_impact_cache: AudioStreamWAV
static var _glass_break_cache: AudioStreamWAV
static var _door_open_cache: AudioStreamWAV
static var _door_close_cache: AudioStreamWAV
static var _crt_power_on_cache: AudioStreamWAV
static var _crt_power_off_cache: AudioStreamWAV
static var _crt_channel_change_cache: AudioStreamWAV
static var _crt_volume_detent_cache: AudioStreamWAV
static var _crt_remote_channel_response_cache: AudioStreamWAV
static var _tv_remote_button_cache: Dictionary = {}
static var _surface_footstep_cache: Dictionary = {}

const FOOTSTEP_VARIANTS := 4

# Perfil físico de cada superficie. Un paso son tres capas: el golpe sordo del
# talón (thump), la resonancia del material (ring) y la textura del contacto
# (noise). Lo que distingue una tarima de una baldosa no es el volumen, es el
# reparto entre esas tres y la velocidad a la que se apagan.
#
#   thump_hz/decay/gain : cuerpo grave del pisotón
#   ring_hz/decay/gain  : resonancia tonal (hueca en madera, aguda en cerámica)
#   noise_lp            : 0..1, cuanto mayor más brillante es el ruido de roce
#   noise_decay/gain    : cola de textura (grava, tierra, moqueta)
#   toe_gain            : segundo apoyo, la punta del pie tras el talón
#   duration            : el ruido corto es lo que hace que una baldosa suene dura
#   gain_db             : compensación de sonoridad; la moqueta apaga de verdad
const SURFACE_PROFILES := {
	&"wood": {
		"thump_hz": 96.0, "thump_decay": 26.0, "thump_gain": 0.62,
		"ring_hz": 316.0, "ring_decay": 30.0, "ring_gain": 0.30,
		"noise_lp": 0.16, "noise_decay": 46.0, "noise_gain": 0.20,
		"toe_gain": 0.26, "duration": 0.20, "gain_db": 0.0,
	},
	&"carpet": {
		"thump_hz": 74.0, "thump_decay": 34.0, "thump_gain": 0.44,
		"ring_hz": 0.0, "ring_decay": 1.0, "ring_gain": 0.0,
		"noise_lp": 0.030, "noise_decay": 26.0, "noise_gain": 0.26,
		"toe_gain": 0.10, "duration": 0.20, "gain_db": -7.5,
	},
	&"tile": {
		"thump_hz": 132.0, "thump_decay": 44.0, "thump_gain": 0.40,
		"ring_hz": 1980.0, "ring_decay": 62.0, "ring_gain": 0.30,
		"noise_lp": 0.62, "noise_decay": 96.0, "noise_gain": 0.26,
		"toe_gain": 0.34, "duration": 0.13, "gain_db": +1.0,
	},
	&"stone": {
		"thump_hz": 108.0, "thump_decay": 34.0, "thump_gain": 0.52,
		"ring_hz": 640.0, "ring_decay": 58.0, "ring_gain": 0.14,
		"noise_lp": 0.40, "noise_decay": 58.0, "noise_gain": 0.34,
		"toe_gain": 0.30, "duration": 0.17, "gain_db": +0.5,
	},
	&"metal": {
		"thump_hz": 120.0, "thump_decay": 30.0, "thump_gain": 0.34,
		"ring_hz": 1420.0, "ring_decay": 11.0, "ring_gain": 0.42,
		"noise_lp": 0.55, "noise_decay": 72.0, "noise_gain": 0.16,
		"toe_gain": 0.24, "duration": 0.30, "gain_db": +0.5,
	},
	&"dirt": {
		"thump_hz": 82.0, "thump_decay": 28.0, "thump_gain": 0.44,
		"ring_hz": 0.0, "ring_decay": 1.0, "ring_gain": 0.0,
		"noise_lp": 0.11, "noise_decay": 20.0, "noise_gain": 0.60,
		"toe_gain": 0.30, "duration": 0.26, "gain_db": -1.0,
	},
	&"gravel": {
		"thump_hz": 78.0, "thump_decay": 24.0, "thump_gain": 0.40,
		"ring_hz": 0.0, "ring_decay": 1.0, "ring_gain": 0.0,
		"noise_lp": 0.30, "noise_decay": 15.0, "noise_gain": 0.74,
		"toe_gain": 0.36, "duration": 0.30, "gain_db": 0.0,
	},
}


static func prewarm_footsteps() -> void:
	# Se hace una sola vez al cargar al jugador. Así el primer paso sobre un
	# material nuevo no tiene que sintetizar audio durante un fotograma de juego.
	for surface in SURFACE_PROFILES:
		for variant in FOOTSTEP_VARIANTS:
			make_surface_footstep(surface, variant)


static func footstep_gain_db(surface: StringName) -> float:
	var profile: Dictionary = SURFACE_PROFILES.get(surface, SURFACE_PROFILES[&"wood"])
	return float(profile["gain_db"])


static func make_surface_footstep(surface: StringName, variant: int = 0) -> AudioStreamWAV:
	var profile: Dictionary = SURFACE_PROFILES.get(surface, SURFACE_PROFILES[&"wood"])
	var key := "%s:%d" % [surface, posmod(variant, FOOTSTEP_VARIANTS)]
	if _surface_footstep_cache.has(key):
		return _surface_footstep_cache[key] as AudioStreamWAV

	var duration := float(profile["duration"])
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	# Semilla fija por superficie y variante: el mismo paso suena igual entre
	# partidas, pero cuatro variantes evitan el bucle metronómico.
	rng.seed = hash(key)
	var tuning := rng.randf_range(0.93, 1.07)
	var toe_delay := rng.randf_range(0.030, 0.050)
	var noise_lp := float(profile["noise_lp"])
	var ring_hz := float(profile["ring_hz"])
	var texture := 0.0
	for index in sample_count:
		var time := float(index) / MIX_RATE
		texture = lerpf(texture, rng.randf_range(-1.0, 1.0), noise_lp)
		# El talón baja de tono al hundirse: es lo que da la sensación de peso.
		var thump_hz := float(profile["thump_hz"]) * tuning - time * 58.0
		var thump := sin(TAU * maxf(thump_hz, 12.0) * time) * exp(-time * float(profile["thump_decay"]))
		var ring := 0.0
		if ring_hz > 0.0:
			ring = sin(TAU * ring_hz * tuning * time) * exp(-time * float(profile["ring_decay"]))
		var noise := texture * exp(-time * float(profile["noise_decay"]))
		# Segundo apoyo: la punta del pie cae unos milisegundos después.
		var toe_time := maxf(time - toe_delay, 0.0)
		var toe := 0.0
		if toe_time > 0.0:
			toe = texture * exp(-toe_time * float(profile["noise_decay"]) * 1.35)
		var sample := (
			thump * float(profile["thump_gain"])
			+ ring * float(profile["ring_gain"])
			+ noise * float(profile["noise_gain"])
			+ toe * float(profile["toe_gain"])
		)
		# Ataque de 1,5 ms: sin él el primer sample es un chasquido digital.
		samples[index] = clampf(sample * minf(time / 0.0015, 1.0) * 0.9, -1.0, 1.0)
	var stream := _stream_from_samples(samples)
	_surface_footstep_cache[key] = stream
	return stream


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
	return make_surface_footstep(&"wood", 0)


# El "paso exterior" es ahora el perfil de tierra mojada del patio.
static func make_outdoor_footstep(variant: int = 0) -> AudioStreamWAV:
	return make_surface_footstep(&"dirt", variant)


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


static func make_crt_power_on() -> AudioStreamWAV:
	if _crt_power_on_cache != null:
		return _crt_power_on_cache
	var duration := 0.92
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19840317
	var filtered_noise := 0.0
	for index: int in sample_count:
		var time := float(index) / MIX_RATE
		filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.34)
		# Interruptor mecanico, seguido por el golpe grave de la bobina de
		# desmagnetizacion y el siseo que aparece al calentarse el tubo.
		var click := sin(TAU * 1120.0 * time) * exp(-time * 115.0)
		var degauss_time := maxf(time - 0.018, 0.0)
		var degauss_phase := TAU * (69.0 * degauss_time - 23.0 * degauss_time * degauss_time)
		var degauss := sin(degauss_phase) * exp(-degauss_time * 7.4)
		var warmup := 1.0 - exp(-time * 9.0)
		var static_noise := filtered_noise * warmup * exp(-time * 3.8)
		# El silbido real de linea queda por encima del limite de 22 kHz de la
		# fabrica. Esta componente mas baja conserva su lectura sin ser molesta.
		var flyback := sin(TAU * 7600.0 * time) * warmup * exp(-time * 2.5)
		var mains_hum := sin(TAU * 50.0 * time) * warmup * exp(-time * 2.2)
		var sample := click * 0.23 + degauss * 0.54 + static_noise * 0.23 + flyback * 0.045 + mains_hum * 0.08
		samples[index] = clampf(sample * minf(time / 0.001, 1.0), -1.0, 1.0)
	_crt_power_on_cache = _stream_from_samples(samples)
	return _crt_power_on_cache


static func make_crt_power_off() -> AudioStreamWAV:
	if _crt_power_off_cache != null:
		return _crt_power_off_cache
	var duration := 0.58
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19840318
	var filtered_noise := 0.0
	for index: int in sample_count:
		var time := float(index) / MIX_RATE
		filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.28)
		var click := sin(TAU * 860.0 * time) * exp(-time * 105.0)
		var collapse_time := maxf(time - 0.012, 0.0)
		var collapse_phase := TAU * (170.0 * collapse_time - 125.0 * collapse_time * collapse_time)
		var collapse := sin(collapse_phase) * exp(-collapse_time * 10.0)
		var discharge := filtered_noise * exp(-time * 8.0)
		var flyback_frequency := maxf(7600.0 - time * 10500.0, 620.0)
		var flyback := sin(TAU * flyback_frequency * time) * exp(-time * 8.5)
		var tail_time := maxf(time - 0.19, 0.0)
		var cabinet_tick := sin(TAU * 1450.0 * tail_time) * exp(-tail_time * 75.0)
		if time < 0.19:
			cabinet_tick = 0.0
		var sample := click * 0.28 + collapse * 0.43 + discharge * 0.2 + flyback * 0.055 + cabinet_tick * 0.12
		samples[index] = clampf(sample * minf(time / 0.001, 1.0), -1.0, 1.0)
	_crt_power_off_cache = _stream_from_samples(samples)
	return _crt_power_off_cache


static func make_crt_channel_change() -> AudioStreamWAV:
	if _crt_channel_change_cache != null:
		return _crt_channel_change_cache
	var duration := 0.31
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19840319
	var filtered_noise := 0.0
	for index: int in sample_count:
		var time := float(index) / MIX_RATE
		filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.42)
		# El selector rotativo mueve un contacto grande: golpe de baquelita,
		# rebote metalico y una rafaga muy corta al perder la sintonia.
		var clunk := sin(TAU * (205.0 - time * 160.0) * time) * exp(-time * 31.0)
		var contact := sin(TAU * 1320.0 * time) * exp(-time * 92.0)
		var rebound_time := maxf(time - 0.048, 0.0)
		var rebound := sin(TAU * 720.0 * rebound_time) * exp(-rebound_time * 75.0)
		if time < 0.048:
			rebound = 0.0
		var tuning_burst := filtered_noise * exp(-time * 15.0)
		var electrical_tick := sin(TAU * 5200.0 * time) * exp(-time * 48.0)
		var sample := clunk * 0.48 + contact * 0.25 + rebound * 0.18 + tuning_burst * 0.22 + electrical_tick * 0.045
		samples[index] = clampf(sample * minf(time / 0.001, 1.0), -1.0, 1.0)
	_crt_channel_change_cache = _stream_from_samples(samples)
	return _crt_channel_change_cache


static func make_crt_volume_detent() -> AudioStreamWAV:
	if _crt_volume_detent_cache != null:
		return _crt_volume_detent_cache
	var duration := 0.14
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19840320
	for index: int in sample_count:
		var time := float(index) / MIX_RATE
		# Clic pequeno y seco del dentado de la rueda, sin la rafaga electrica
		# reservada al selector de canal.
		var detent := sin(TAU * 1540.0 * time) * exp(-time * 105.0)
		var knob_body := sin(TAU * 310.0 * time) * exp(-time * 55.0)
		var spring_time := maxf(time - 0.022, 0.0)
		var spring := sin(TAU * 980.0 * spring_time) * exp(-spring_time * 110.0)
		if time < 0.022:
			spring = 0.0
		var grit := rng.randf_range(-1.0, 1.0) * exp(-time * 125.0)
		var sample := detent * 0.44 + knob_body * 0.27 + spring * 0.24 + grit * 0.09
		samples[index] = clampf(sample * minf(time / 0.0008, 1.0), -1.0, 1.0)
	_crt_volume_detent_cache = _stream_from_samples(samples)
	return _crt_volume_detent_cache


static func make_crt_remote_channel_response() -> AudioStreamWAV:
	if _crt_remote_channel_response_cache != null:
		return _crt_remote_channel_response_cache
	var duration := 0.19
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19840321
	var filtered_noise := 0.0
	for index: int in sample_count:
		var time := float(index) / MIX_RATE
		filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.48)
		# Al usar infrarrojos no gira el selector de la carcasa: solo se oye
		# el corte electronico de sintonia y la entrada del canal nuevo.
		var tuning_burst := filtered_noise * exp(-time * 21.0)
		var lock_tone := sin(TAU * 4200.0 * time) * exp(-time * 45.0)
		var relay_body := sin(TAU * 185.0 * time) * exp(-time * 54.0)
		var sample := tuning_burst * 0.31 + lock_tone * 0.055 + relay_body * 0.16
		samples[index] = clampf(sample * minf(time / 0.0008, 1.0), -1.0, 1.0)
	_crt_remote_channel_response_cache = _stream_from_samples(samples)
	return _crt_remote_channel_response_cache


static func make_tv_remote_button(button_kind: StringName) -> AudioStreamWAV:
	if _tv_remote_button_cache.has(button_kind):
		return _tv_remote_button_cache[button_kind] as AudioStreamWAV
	var duration := 0.10
	var impact_hz := 1280.0
	var body_hz := 270.0
	var return_delay := 0.031
	var gain := 0.72
	match button_kind:
		&"power":
			duration = 0.13
			impact_hz = 920.0
			body_hz = 220.0
			return_delay = 0.041
			gain = 0.82
		&"volume":
			duration = 0.085
			impact_hz = 1580.0
			body_hz = 340.0
			return_delay = 0.024
			gain = 0.62
	var sample_count := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("tv_remote:%s" % button_kind)
	for index: int in sample_count:
		var time := float(index) / MIX_RATE
		# Dos impactos apagados de una membrana de goma: fondo de carrera y
		# retorno. El cuerpo de plastico aporta el golpe grave cercano.
		var press := sin(TAU * impact_hz * time) * exp(-time * 115.0)
		var body := sin(TAU * body_hz * time) * exp(-time * 62.0)
		var release_time := maxf(time - return_delay, 0.0)
		var release := sin(TAU * impact_hz * 0.78 * release_time) * exp(-release_time * 135.0)
		if time < return_delay:
			release = 0.0
		var plastic := rng.randf_range(-1.0, 1.0) * exp(-time * 145.0)
		var sample := press * 0.38 + body * 0.28 + release * 0.24 + plastic * 0.07
		samples[index] = clampf(sample * gain * minf(time / 0.0007, 1.0), -1.0, 1.0)
	var stream := _stream_from_samples(samples)
	_tv_remote_button_cache[button_kind] = stream
	return stream


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
