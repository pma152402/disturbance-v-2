extends StaticBody3D

@export var rocking_amplitude_degrees := 16.0
@export var rocking_speed := 2.875

var _base_rotation_x := 0.0
var _rocking_time := 0.0


func _ready() -> void:
	_base_rotation_x = rotation.x
	_rocking_time = global_position.x * 0.37 + global_position.z * 0.19


func _process(delta: float) -> void:
	_rocking_time += delta * rocking_speed
	rotation.x = _base_rotation_x + sin(_rocking_time) * deg_to_rad(rocking_amplitude_degrees)
