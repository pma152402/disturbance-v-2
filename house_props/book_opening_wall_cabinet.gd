extends Node3D

@export var open_angle_degrees := 105.0
@export var opening_speed := 5.0

@onready var left_door: Node3D = $LeftDoorPivot
@onready var right_door: Node3D = $RightDoorPivot

var _is_open := false

func _process(delta: float) -> void:
	var target_angle := deg_to_rad(open_angle_degrees) if _is_open else 0.0
	left_door.rotation.y = lerp_angle(left_door.rotation.y, -target_angle, minf(delta * opening_speed, 1.0))
	right_door.rotation.y = lerp_angle(right_door.rotation.y, target_angle, minf(delta * opening_speed, 1.0))

func get_interaction_text(_player: Node = null) -> String:
	return "F  CERRAR ARMARIO" if _is_open else "F  ABRIR ARMARIO"

func get_interaction_key() -> Key:
	return KEY_F

func interact(_player: Node = null) -> bool:
	_is_open = not _is_open
	return true
