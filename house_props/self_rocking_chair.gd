extends StaticBody3D

@export var rocking_amplitude_degrees := 16.0
@export var rocking_speed := 2.875
@export_range(0.0, 30.0, 0.05) var creak_start_seconds := 0.0
@export_group("Habitacion superior")
@export var room_min_x := 6.4
@export var room_max_x := 12.8
@export var room_min_z := 4.15
@export var room_max_z := 10.8
@export var room_min_y := 3.4
@export var room_max_y := 7.0
@export_category("Audio")
@export_range(-40.0, 18.0, 0.5) var volumen_dentro_db := 2.0

var _base_rotation_x := 0.0
var _rocking_time := 0.0
var _previous_direction := 1.0
var _player: Node3D
var _player_inside_room := false

@onready var rocking_sound: AudioStreamPlayer3D = $RockingSound


func _ready() -> void:
	_base_rotation_x = rotation.x
	_rocking_time = global_position.x * 0.37 + global_position.z * 0.19
	_previous_direction = signf(cos(_rocking_time))
	rocking_sound.stop()
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_player_inside_room = _player != null and _is_player_in_room()
	rocking_sound.volume_db = volumen_dentro_db
	if _player_inside_room:
		_play_creak()


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	var is_inside := _player != null and _is_player_in_room()
	if is_inside != _player_inside_room:
		_player_inside_room = is_inside
		if _player_inside_room:
			_play_creak()
		else:
			rocking_sound.stop()

	_rocking_time += delta * rocking_speed
	rotation.x = _base_rotation_x + sin(_rocking_time) * deg_to_rad(rocking_amplitude_degrees)
	var direction := signf(cos(_rocking_time))
	if direction != 0.0 and direction != _previous_direction:
		_previous_direction = direction
		if _player_inside_room:
			_play_creak()


func _play_creak() -> void:
	rocking_sound.volume_db = volumen_dentro_db
	rocking_sound.pitch_scale = randf_range(0.96, 1.04)
	rocking_sound.play(creak_start_seconds)


func _is_player_in_room() -> bool:
	var position := _player.global_position
	return position.x > room_min_x and position.x < room_max_x \
		and position.z > room_min_z and position.z < room_max_z \
		and position.y > room_min_y and position.y < room_max_y
