extends Control

@onready var recording_label: Label = $Recording
@onready var timestamp_label: Label = $Timestamp
@onready var fps_label: Label = $FPS

var _refresh_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_timestamp()


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.2
		_update_timestamp()
		_update_fps()
	recording_label.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.68 else 0.28


func _update_timestamp() -> void:
	var datetime := Time.get_datetime_dict_from_system()
	timestamp_label.text = "%02d/%02d/%04d  %02d:%02d:%02d" % [
		datetime.day, datetime.month, datetime.year,
		datetime.hour, datetime.minute, datetime.second
	]


func _update_fps() -> void:
	var fps := Engine.get_frames_per_second()
	fps_label.text = "%d FPS" % fps
	if fps < 30:
		fps_label.modulate = Color(1.0, 0.28, 0.22, 0.96)
	elif fps < 50:
		fps_label.modulate = Color(1.0, 0.72, 0.2, 0.96)
	else:
		fps_label.modulate = Color(0.86, 0.9, 0.83, 0.86)
