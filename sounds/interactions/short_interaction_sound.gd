extends AudioStreamPlayer

@export_range(0.0, 10.0, 0.01) var clip_start := 0.0
@export_range(0.02, 2.0, 0.01) var clip_duration := 0.42

var _remaining := 0.0


func play_clip() -> void:
	play(clip_start)
	_remaining = clip_duration
	set_process(true)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		stop()
		set_process(false)
