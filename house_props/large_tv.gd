extends StaticBody3D

const PROGRAMS_DIRECTORY := "res://assets/tv_videos"
const GRID_COLUMNS := 3
const GRID_ROWS := 3
const FRAME_COUNT := GRID_COLUMNS * GRID_ROWS
const SCREEN_LIGHT_ENERGY := 0.65

@export_range(0.2, 5.0, 0.05, "suffix:s") var frame_duration := 1.5
@export_range(0.5, 2.35, 0.05, "suffix:m") var interaction_distance := 2.0

@onready var screen: MeshInstance3D = $SquareGreyScreen
@onready var screen_light: OmniLight3D = $ScreenLight

var _programs: Array[Texture2D] = []
var _screen_material: ShaderMaterial
var _is_on := false
var _channel := 0
var _frame := 0
var _frame_time := 0.0


func _ready() -> void:
	_load_programs()
	_prepare_screen_material()
	_show_powered_off_screen()


func _process(delta: float) -> void:
	if not _is_on or _programs.is_empty():
		return
	_frame_time += delta
	while _frame_time >= frame_duration:
		_frame_time -= frame_duration
		_frame = (_frame + 1) % FRAME_COUNT
		_update_frame_uv()


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return interaction_distance


func get_interaction_text(_player: Node = null) -> String:
	if _programs.is_empty():
		return "TELE SIN SENAL"
	if not _is_on:
		return "F  ENCENDER TELE"
	if _channel == _programs.size() - 1:
		return "F  APAGAR TELE  [%d/%d]" % [_channel + 1, _programs.size()]
	return "F  CAMBIAR CANAL  [%d/%d]" % [_channel + 1, _programs.size()]


func interact(_player: Node = null) -> bool:
	if _programs.is_empty():
		return false
	if not _is_on:
		_is_on = true
		_channel = 0
	elif _channel == _programs.size() - 1:
		_is_on = false
		_frame = 0
		_frame_time = 0.0
		_show_powered_off_screen()
		return true
	else:
		_channel += 1
	_frame = 0
	_frame_time = 0.0
	_show_current_program()
	return true


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
