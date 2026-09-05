extends StaticBody3D

@export_range(30.0, 125.0, 1.0) var open_angle_degrees := 92.0
@export_range(1.0, 12.0, 0.1) var opening_speed := 6.0

@onready var left_door: Node3D = $LeftDoorPivot
@onready var right_door: Node3D = $RightDoorPivot

var _is_open := false

func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	var target_angle := deg_to_rad(open_angle_degrees) if _is_open else 0.0
	left_door.rotation.y = lerp_angle(left_door.rotation.y, target_angle, minf(delta * opening_speed, 1.0))
	right_door.rotation.y = lerp_angle(right_door.rotation.y, -target_angle, minf(delta * opening_speed, 1.0))
	if absf(angle_difference(left_door.rotation.y,target_angle)) < 0.002 and absf(angle_difference(right_door.rotation.y,-target_angle)) < 0.002:
		left_door.rotation.y = target_angle
		right_door.rotation.y = -target_angle
		set_process(false)


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node = null) -> String:
	return "F  CERRAR ARMARIO" if _is_open else "F  ABRIR ARMARIO"


func interact(_player: Node = null) -> bool:
	_is_open = not _is_open
	set_process(true)
	return true
