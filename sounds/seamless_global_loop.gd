class_name SeamlessGlobalLoop
extends Node

## Bucle no espacial para ruido perteneciente a la propia cámara. Al usar
## AudioStreamPlayer no intervienen distancia, unit_size, max_db ni paneo 3D.

@export var stream: AudioStream
@export_range(-80.0, 0.0, 0.1) var volume_db := -40.0
@export_range(-80.0, 0.0, 0.1) var volume_ceiling_db := -40.0
@export_range(0.1, 3.0, 0.05) var crossfade_seconds := 0.8
@export_range(0.05, 2.0, 0.05) var activation_fade_seconds := 0.35
@export_range(0.0, 10.0, 0.01) var start_offset_seconds := 0.0
@export var autoplay := false
@export var bus: StringName = &"Master"

var _players: Array[AudioStreamPlayer] = []
var _current_player := 0
var _active_requested := false
var _master_gain := 0.0
var _crossfading := false
var _crossfade_elapsed := 0.0
var _mix_accumulator := 0.0
var _stream_length := 0.0
var _last_voice_db := PackedFloat32Array([999.0, 999.0])


func _ready() -> void:
	_stream_length = stream.get_length() if stream != null else 0.0
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "LoopVoice%d" % (index + 1)
		player.stream = stream
		player.bus = bus
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
		_start_current_voice()
	set_process(true)


func is_active() -> bool:
	return _active_requested


func _process(delta: float) -> void:
	if _players.is_empty() or stream == null:
		set_process(false)
		return
	_mix_accumulator += delta
	if _mix_accumulator < 0.033:
		return
	var mix_delta := _mix_accumulator
	_mix_accumulator = 0.0
	_master_gain = move_toward(
		_master_gain,
		1.0 if _active_requested else 0.0,
		mix_delta / maxf(activation_fade_seconds, 0.01)
	)
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
		_players[next_index].play(start_offset_seconds)
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


func _start_current_voice() -> void:
	if not _players.is_empty() and stream != null:
		_players[_current_player].play(start_offset_seconds)


func _set_voice_gain(index: int, gain: float) -> void:
	var target_db := minf(volume_db + linear_to_db(maxf(gain, 0.0001)), volume_ceiling_db)
	if absf(_last_voice_db[index] - target_db) < 0.05:
		return
	_last_voice_db[index] = target_db
	_players[index].volume_db = target_db


func _stop_all() -> void:
	for index in _players.size():
		_players[index].stop()
		_players[index].volume_db = -80.0
		_last_voice_db[index] = -80.0
	_crossfading = false
	_crossfade_elapsed = 0.0
