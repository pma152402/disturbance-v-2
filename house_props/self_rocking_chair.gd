extends StaticBody3D

@export var rocking_amplitude_degrees := 16.0
@export var rocking_speed := 2.875
@export_range(0.0, 30.0, 0.05) var creak_start_seconds := 0.0
@export_group("Room acoustics")
@export var room_min_x := 6.4
@export var room_max_x := 12.8
@export var room_min_z := 4.15
@export var room_max_z := 10.8
@export var room_min_y := 3.4
@export var inside_volume_db := 2.0
@export var outside_volume_db := -12.0
@export var acoustic_transition_speed := 5.0

var _base_rotation_x := 0.0
var _rocking_time := 0.0
var _previous_direction := 1.0
var _player: Node3D
var _room_volume_blend := 0.0

@onready var rocking_sound: AudioStreamPlayer3D = $RockingSound


func _ready() -> void:
	_base_rotation_x = rotation.x
	_rocking_time = global_position.x * 0.37 + global_position.z * 0.19
	_previous_direction = signf(cos(_rocking_time))
	rocking_sound.stop()
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if _player != null and _is_player_in_room():
		_room_volume_blend = 1.0
	_apply_room_volume()


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	var room_target := 1.0 if _player != null and _is_player_in_room() else 0.0
	_room_volume_blend = move_toward(_room_volume_blend, room_target, acoustic_transition_speed * delta)
	_apply_room_volume()

	_rocking_time += delta * rocking_speed
	rotation.x = _base_rotation_x + sin(_rocking_time) * deg_to_rad(rocking_amplitude_degrees)
	var direction := signf(cos(_rocking_time))
	if direction != 0.0 and direction != _previous_direction:
		_previous_direction = direction
		rocking_sound.pitch_scale = randf_range(0.96, 1.04)
		rocking_sound.play(creak_start_seconds)


func _is_player_in_room() -> bool:
	var position := _player.global_position
	return position.x > room_min_x and position.x < room_max_x \
		and position.z > room_min_z and position.z < room_max_z \
		and position.y > room_min_y


func _apply_room_volume() -> void:
	rocking_sound.volume_db = lerpf(
		outside_volume_db,
		inside_volume_db,
		smoothstep(0.0, 1.0, _room_volume_blend)
	)
