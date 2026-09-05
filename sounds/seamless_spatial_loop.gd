class_name SeamlessSpatialLoop
extends Node3D

@export var stream: AudioStream
@export_range(-40.0, 18.0, 0.1) var volume_db := -12.0
@export_range(-80.0, 18.0, 0.1) var volume_ceiling_db := 18.0
@export_range(0.1, 3.0, 0.05) var crossfade_seconds := 0.8
@export_range(0.05, 2.0, 0.05) var activation_fade_seconds := 0.35
@export_range(0.0, 10.0, 0.01) var start_offset_seconds := 0.0
@export var autoplay := false
@export var random_start := false
@export var bus: StringName = &"Master"
@export_enum("Inversa", "Inversa cuadrada", "Logarítmica", "Sin atenuación") var attenuation_model: int = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
@export_range(0.1, 50.0, 0.1) var unit_size := 2.0
@export_range(1.0, 80.0, 0.5) var max_distance := 14.0
@export_group("Rendimiento")
@export var distance_culling := true
@export_range(0.05, 1.0, 0.01) var audibility_check_seconds := 0.2
@export_range(0.016, 0.1, 0.001) var mix_update_seconds := 0.033
@export_range(0.0, 10.0, 0.25) var cull_margin := 2.0

var _players: Array[AudioStreamPlayer3D] = []
var _current_player := 0
var _active_requested := false
var _master_gain := 0.0
var _crossfading := false
var _crossfade_elapsed := 0.0
var _audible := true
var _audibility_accumulator := 0.0
var _mix_accumulator := 0.0
var _last_voice_db := PackedFloat32Array([999.0, 999.0])
var _stream_length := 0.0


func _ready() -> void:
	_stream_length = stream.get_length() if stream != null else 0.0
	for index in 2:
		var player := AudioStreamPlayer3D.new()
		player.name = "LoopVoice%d" % (index + 1)
		player.stream = stream
		player.bus = bus
		player.unit_size = unit_size
		player.max_distance = max_distance
		player.attenuation_model = attenuation_model
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	set_process(false)
	if autoplay:
		call_deferred(&"set_active", true)


func set_active(active: bool) -> void:
	if _active_requested == active:
		return
	_active_requested = active
	if active:
		_update_audibility()
		if _audible:
			_start_current_voice()
		set_process(true)
	elif not _players.is_empty():
		set_process(true)


func is_active() -> bool:
	return _active_requested


func set_pitch_scale(value: float) -> void:
	for player in _players:
		player.pitch_scale = clampf(value, 0.25, 4.0)


func set_spatial_range(source_unit_size: float, audible_max_distance: float) -> void:
	unit_size = maxf(source_unit_size, 0.1)
	max_distance = maxf(audible_max_distance, 1.0)
	for player in _players:
		player.unit_size = unit_size
		player.max_distance = max_distance
	_update_audibility()


func _process(delta: float) -> void:
	if _players.is_empty() or stream == null:
		set_process(false)
		return
	_audibility_accumulator += delta
	if _audibility_accumulator >= audibility_check_seconds:
		_audibility_accumulator = 0.0
		_update_audibility()
	if not _audible:
		if _players[0].playing or _players[1].playing:
			_stop_all()
		if not _active_requested:
			_master_gain = 0.0
			set_process(false)
		return
	_mix_accumulator += delta
	if _mix_accumulator < mix_update_seconds:
		return
	var mix_delta := _mix_accumulator
	_mix_accumulator = 0.0
	var fade_speed := 1.0 / maxf(activation_fade_seconds, 0.01)
	_master_gain = move_toward(_master_gain, 1.0 if _active_requested else 0.0, mix_delta * fade_speed)
	if not _active_requested and _master_gain <= 0.001:
		_stop_all()
		set_process(false)
		return

	var current := _players[_current_player]
	if _active_requested and not current.playing and not _crossfading:
		_start_current_voice()
	if (
		_active_requested
		and not _crossfading
		and _stream_length > crossfade_seconds * 1.25
		and current.get_playback_position() >= _stream_length - crossfade_seconds
	):
		var next_index := 1 - _current_player
		_players[next_index].play(_get_start_position(false))
		_crossfading = true
		_crossfade_elapsed = 0.0

	if _crossfading:
		_crossfade_elapsed += mix_delta
		var blend := smoothstep(0.0, 1.0, clampf(_crossfade_elapsed / crossfade_seconds, 0.0, 1.0))
		_set_voice_gain(_current_player, _master_gain * (1.0 - blend))
		_set_voice_gain(1 - _current_player, _master_gain * blend)
		if blend >= 1.0:
			_players[_current_player].stop()
			_current_player = 1 - _current_player
			_crossfading = false
	else:
		_set_voice_gain(_current_player, _master_gain)
		_set_voice_gain(1 - _current_player, 0.0)


func _update_audibility() -> void:
	if not distance_culling:
		_set_audible(true)
		return
	var listener := get_viewport().get_camera_3d()
	if listener == null:
		_set_audible(true)
		return
	var audible_distance := max_distance + cull_margin
	_set_audible(global_position.distance_squared_to(listener.global_position) <= audible_distance * audible_distance)


func _set_audible(value: bool) -> void:
	if _audible == value:
		return
	_audible = value
	if not _audible:
		_stop_all()
	elif _active_requested:
		_start_current_voice()


func _start_current_voice() -> void:
	if _players.is_empty() or stream == null:
		return
	_players[_current_player].play(_get_start_position(random_start))


func _get_start_position(randomized: bool) -> float:
	var latest_start := maxf(0.0, _stream_length - crossfade_seconds * 1.5)
	var earliest_start := minf(start_offset_seconds, latest_start)
	if randomized and latest_start > earliest_start:
		return randf_range(earliest_start, latest_start)
	return earliest_start


func _set_voice_gain(index: int, gain: float) -> void:
	var target_db := minf(volume_db + linear_to_db(maxf(gain, 0.0001)), volume_ceiling_db)
	if absf(_last_voice_db[index] - target_db) < 0.05:
		return
	_last_voice_db[index] = target_db
	_players[index].volume_db = target_db


func _stop_all() -> void:
	for index in _players.size():
		var player := _players[index]
		if player.playing:
			player.stop()
		if not is_equal_approx(_last_voice_db[index], -80.0):
			player.volume_db = -80.0
			_last_voice_db[index] = -80.0
	_crossfading = false
	_crossfade_elapsed = 0.0
