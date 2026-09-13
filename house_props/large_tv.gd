extends StaticBody3D

const PROGRAMS_DIRECTORY := "res://assets/tv_videos"
const GRID_COLUMNS := 3
const GRID_ROWS := 3
const FRAME_COUNT := GRID_COLUMNS * GRID_ROWS
const SCREEN_LIGHT_ENERGY := 0.65

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


func _ready() -> void:
	add_to_group(&"televisions")
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
	_update_control_positions()
	return true


func next_channel() -> bool:
	if not _is_on or _programs.is_empty():
		return false
	_channel = (_channel + 1) % _programs.size()
	_frame = 0
	_frame_time = 0.0
	_show_current_program()
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


func adjust_volume(amount: int) -> bool:
	if not _is_on or amount == 0:
		return false
	_volume_level = clampi(_volume_level + signi(amount), 0, 10)
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
