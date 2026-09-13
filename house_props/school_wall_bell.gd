extends StaticBody3D

signal rung

@export_range(-24.0, 6.0, 0.5) var ring_volume_db := -3.0
@export_range(0.5, 4.0, 0.1) var ring_duration := 1.8
@export_range(0.1, 3.0, 0.05) var retrigger_delay := 0.45

@onready var bell_pivot: Node3D = $BellPivot
@onready var striker_pivot: Node3D = $StrikerPivot
@onready var ring_audio: AudioStreamPlayer3D = $RingAudio

var _ring_stream: AudioStreamWAV
var _last_ring_msec := -100000
var _bell_tween: Tween
var _striker_tween: Tween


func _ready() -> void:
	add_to_group(&"school_bells")
	ring_audio.volume_db = ring_volume_db
	_ring_stream = _build_metallic_ring()
	ring_audio.stream = _ring_stream


func ring() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_ring_msec < int(retrigger_delay * 1000.0):
		return false
	_last_ring_msec = now
	ring_audio.pitch_scale = randf_range(0.985, 1.015)
	ring_audio.play()
	_animate_mechanism()
	rung.emit()
	return true


func _animate_mechanism() -> void:
	if _bell_tween != null:
		_bell_tween.kill()
	if _striker_tween != null:
		_striker_tween.kill()
	bell_pivot.rotation = Vector3.ZERO
	striker_pivot.rotation = Vector3.ZERO
	_bell_tween = create_tween()
	for index in 10:
		var strength := 1.0 - float(index) / 10.0
		var angle := deg_to_rad(2.3 * strength) * (-1.0 if index % 2 == 0 else 1.0)
		_bell_tween.tween_property(bell_pivot, "rotation:z", angle, 0.045)
	_bell_tween.tween_property(bell_pivot, "rotation:z", 0.0, 0.07)
	_striker_tween = create_tween()
	for index in 8:
		var angle := deg_to_rad(7.0) * (-1.0 if index % 2 == 0 else 1.0)
		_striker_tween.tween_property(striker_pivot, "rotation:z", angle, 0.055)
	_striker_tween.tween_property(striker_pivot, "rotation:z", 0.0, 0.06)


func _build_metallic_ring() -> AudioStreamWAV:
	var mix_rate := 44100
	var frame_count := maxi(1, int(ring_duration * float(mix_rate)))
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	for frame in frame_count:
		var time := float(frame) / float(mix_rate)
		var strike_phase := fmod(time, 0.19)
		var strike_index := floori(time / 0.19)
		var strike_gain := exp(-float(strike_index) * 0.34)
		var attack := clampf(strike_phase * 180.0, 0.0, 1.0)
		var local_decay := exp(-strike_phase * 13.0)
		var body_decay := exp(-time * 2.15)
		var shimmer := (
			sin(TAU * 742.0 * time)
			+ 0.53 * sin(TAU * 1117.0 * time + 0.7)
			+ 0.31 * sin(TAU * 1493.0 * time + 1.4)
			+ 0.16 * sin(TAU * 2241.0 * time + 0.2)
		)
		var hammer := sin(TAU * 318.0 * strike_phase) + 0.35 * sin(TAU * 2710.0 * strike_phase)
		var sample := shimmer * body_decay * 0.24
		sample += hammer * attack * local_decay * strike_gain * 0.30
		sample = clampf(sample, -0.92, 0.92)
		pcm.encode_s16(frame * 2, roundi(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = pcm
	return stream
