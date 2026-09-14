extends StaticBody3D

const PROGRAMS_DIRECTORY := "res://assets/tv_videos"
const GRID_COLUMNS := 3
const GRID_ROWS := 3
const FRAME_COUNT := GRID_COLUMNS * GRID_ROWS
const SCREEN_LIGHT_ENERGY := 0.65
const GameplaySounds := preload("res://sounds/gameplay_sound_factory.gd")
const CRT_POWER_ON_SOUND := preload("res://sounds/objects/tv_crt_power_on.wav")
const CRT_POWER_OFF_SOUND := preload("res://sounds/objects/tv_crt_power_off.wav")
const CHANNEL_ROTARY_SOUND := preload("res://sounds/objects/tv_channel_rotary_real.mp3")
const VOLUME_ROTARY_SOUND := preload("res://sounds/objects/tv_volume_rotary_real.mp3")

@export_range(0.2, 5.0, 0.05, "suffix:s") var frame_duration := 1.5

@onready var screen: MeshInstance3D = $SquareGreyScreen
@onready var screen_light: OmniLight3D = $ScreenLight
@onready var channel_indicator: Node3D = $ChannelControl/Visual/IndicatorPivot
@onready var volume_indicator: Node3D = $VolumeControl/Visual/IndicatorPivot
@onready var power_button: Node3D = $PowerControl/Visual

var _programs: Array[Texture2D] = []
var _screen_material: ShaderMaterial
var _is_on := false
var _channel := 0
var _frame := 0
var _frame_time := 0.0
var _volume_level := 5
var _volume_direction := 1
var _power_audio: AudioStreamPlayer3D
var _control_audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"televisions")
	_prepare_power_audio()
	_load_programs()
	_prepare_screen_material()
	_show_powered_off_screen()
	_update_control_positions()


func _process(delta: float) -> void:
	if not _is_on or _programs.is_empty():
		return
	_frame_time += delta
	while _frame_time >= frame_duration:
		_frame_time -= frame_duration
		_frame = (_frame + 1) % FRAME_COUNT
		_update_frame_uv()


func get_control_prompt(action: String) -> String:
	match action:
		"power": return "F  %s TELE" % ("APAGAR" if _is_on else "ENCENDER")
		"channel":
			if not _is_on:
				return "TELE APAGADA"
			return "F  CAMBIAR CANAL  [%d/%d]" % [_channel + 1, _programs.size()]
		"volume":
			if not _is_on:
				return "TELE APAGADA"
			var shown_direction := _volume_direction
			if _volume_level >= 10:
				shown_direction = -1
			elif _volume_level <= 0:
				shown_direction = 1
			return "F  %s VOLUMEN  [%d/10]" % [
				"SUBIR" if shown_direction > 0 else "BAJAR",
				_volume_level,
			]
	return ""


func activate_control(action: String) -> bool:
	match action:
		"power": return toggle_power()
		"channel": return next_channel()
		"volume": return step_volume()
	return false


func toggle_power() -> bool:
	if _programs.is_empty():
		return false
	_is_on = not _is_on
	_frame = 0
	_frame_time = 0.0
	if _is_on:
		_show_current_program()
	else:
		_show_powered_off_screen()
	_play_power_sound(_is_on)
	_update_control_positions()
	return true


func next_channel(from_remote: bool = false) -> bool:
	if not _is_on or _programs.is_empty():
		return false
	_channel = (_channel + 1) % _programs.size()
	_frame = 0
	_frame_time = 0.0
	_show_current_program()
	if from_remote:
		_play_control_sound(GameplaySounds.make_crt_remote_channel_response(), 0.99, 1.01)
	else:
		_play_control_sound(CHANNEL_ROTARY_SOUND, 0.99, 1.01)
	_update_control_positions()
	return true


func step_volume() -> bool:
	if not _is_on:
		return false
	if _volume_level >= 10:
		_volume_direction = -1
	elif _volume_level <= 0:
		_volume_direction = 1
	return adjust_volume(_volume_direction)


func adjust_volume(amount: int, from_remote: bool = false) -> bool:
	if not _is_on or amount == 0:
		return false
	_volume_level = clampi(_volume_level + signi(amount), 0, 10)
	if not from_remote:
		_play_control_sound(VOLUME_ROTARY_SOUND, 0.985, 1.015)
	_update_control_positions()
	return true


func get_remote_status() -> String:
	if not _is_on:
		return "TELE APAGADA"
	return "CANAL %d/%d    VOLUMEN %d/10" % [_channel + 1, _programs.size(), _volume_level]


func get_camera_observation_state() -> Dictionary:
	return {
		"id": &"television",
		"label": "TELE ENCENDIDA" if _is_on else "TELE APAGADA",
		"state": &"on" if _is_on else &"off",
	}


func _load_programs() -> void:
	var file_names := DirAccess.get_files_at(PROGRAMS_DIRECTORY)
	file_names.sort()
	for file_name: String in file_names:
		if file_name.get_extension().to_lower() != "png":
			continue
		var texture := load(PROGRAMS_DIRECTORY.path_join(file_name)) as Texture2D
		if texture == null:
			push_warning("No se pudo cargar el programa de TV: %s" % file_name)
			continue
		_programs.append(texture)


func _prepare_screen_material() -> void:
	_screen_material = screen.material_override.duplicate() as ShaderMaterial
	screen.material_override = _screen_material
	_screen_material.set_shader_parameter(&"powered_on", false)


func _prepare_power_audio() -> void:
	_power_audio = AudioStreamPlayer3D.new()
	_power_audio.name = "PowerAudio"
	_power_audio.max_distance = 14.0
	_power_audio.unit_size = 2.2
	_power_audio.volume_db = -3.5
	add_child(_power_audio)
	_control_audio = AudioStreamPlayer3D.new()
	_control_audio.name = "ControlAudio"
	_control_audio.max_distance = 10.0
	_control_audio.unit_size = 1.8
	_control_audio.volume_db = -5.0
	add_child(_control_audio)


func _play_power_sound(powered_on: bool) -> void:
	_power_audio.stream = (
		CRT_POWER_ON_SOUND
		if powered_on
		else CRT_POWER_OFF_SOUND
	)
	_power_audio.pitch_scale = randf_range(0.985, 1.015)
	_power_audio.play()


func _play_control_sound(stream: AudioStream, minimum_pitch: float, maximum_pitch: float) -> void:
	_control_audio.stream = stream
	_control_audio.pitch_scale = randf_range(minimum_pitch, maximum_pitch)
	_control_audio.play()


func _show_powered_off_screen() -> void:
	_screen_material.set_shader_parameter(&"powered_on", false)
	screen_light.light_energy = 0.0
	screen_light.visible = false


func _show_current_program() -> void:
	var texture := _programs[_channel]
	_screen_material.set_shader_parameter(&"program_texture", texture)
	_screen_material.set_shader_parameter(
		&"sheet_size",
		Vector2(texture.get_width(), texture.get_height())
	)
	_screen_material.set_shader_parameter(&"powered_on", true)
	screen_light.light_energy = SCREEN_LIGHT_ENERGY
	screen_light.visible = true
	_update_frame_uv()


func _update_frame_uv() -> void:
	_screen_material.set_shader_parameter(&"frame_index", _frame)


func _update_control_positions() -> void:
	# Las ruedas permanecen fijas: solo gira el pivote de la marca blanca sobre
	# el eje perpendicular a la cara del mando, como la aguja de un reloj.
	channel_indicator.rotation.y = -float(_channel) * TAU / maxf(float(_programs.size()), 1.0)
	volume_indicator.rotation.y = lerpf(-2.2, 2.2, float(_volume_level) / 10.0)
	# Encendida queda fisicamente enclavada dentro de la carcasa; apagada vuelve
	# a sobresalir. El eje +Z apunta hacia el interior de esta tele.
	power_button.position.z = 0.022 if _is_on else 0.0
