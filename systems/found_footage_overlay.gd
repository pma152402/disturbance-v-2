extends Control

@onready var recording_label: Label = $Recording
@onready var timestamp_label: Label = $Timestamp
@onready var fps_label: Label = $FPS

var _recording_bright := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_timestamp()
	_update_fps()
	set_process(false)
	var refresh := Timer.new()
	refresh.name = "OverlayRefreshTimer"
	refresh.wait_time = 0.2
	refresh.timeout.connect(_refresh_readouts)
	add_child(refresh)
	refresh.start()
	_schedule_recording_blink()


func _refresh_readouts() -> void:
	_update_timestamp()
	_update_fps()


func _schedule_recording_blink() -> void:
	var delay := 0.68 if _recording_bright else 0.32
	get_tree().create_timer(delay).timeout.connect(_toggle_recording, CONNECT_ONE_SHOT)


func _toggle_recording() -> void:
	_recording_bright = not _recording_bright
	recording_label.modulate.a = 1.0 if _recording_bright else 0.28
	_schedule_recording_blink()


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
