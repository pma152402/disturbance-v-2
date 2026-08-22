extends AudioStreamPlayer3D

@export_range(0.0, 16.0, 0.05) var clip_start := 1.15
@export_range(0.05, 1.5, 0.05) var clip_duration := 0.55

var _remaining := 0.0


func _ready() -> void:
	set_process(false)


func play_flicker() -> void:
	pitch_scale = randf_range(0.97, 1.03)
	play(clip_start)
	_remaining = clip_duration
	set_process(true)


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		stop_flicker()


func stop_flicker() -> void:
	stop()
	set_process(false)
	_remaining = 0.0
