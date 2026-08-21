extends AudioStreamPlayer

@export_range(0.5, 10.0, 0.1) var fragment_duration := 4.2
@export_range(-40.0, 6.0, 0.5) var thunder_volume_db := -5.0

var _fragment_time_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	volume_db = thunder_volume_db
	set_process(false)


func play_lightning_fragment() -> void:
	if stream == null:
		return
	var audio_length := stream.get_length()
	var maximum_start := maxf(0.0, audio_length - fragment_duration - 0.1)
	var fragment_start := _rng.randf_range(0.0, maximum_start) if maximum_start > 0.0 else 0.0
	play(fragment_start)
	_fragment_time_left = minf(fragment_duration, maxf(audio_length - fragment_start, 0.1))
	set_process(true)


func _process(delta: float) -> void:
	_fragment_time_left -= delta
	if _fragment_time_left <= 0.0:
		stop()
		set_process(false)
