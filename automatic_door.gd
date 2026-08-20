extends AnimatableBody3D

@export var detection_distance := 2.7
@export var slide_distance := 2.25
@export var movement_speed := 7.0

var _closed_position: Vector3
var _player: Node3D


func _ready() -> void:
	_closed_position = position
	_player = get_tree().get_first_node_in_group(&"player") as Node3D


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		return

	var should_open := global_position.distance_to(_player.global_position) <= detection_distance
	var slide_offset := transform.basis * Vector3(slide_distance, 0, 0)
	var target_position := _closed_position + (slide_offset if should_open else Vector3.ZERO)
	position = position.lerp(target_position, minf(delta * movement_speed, 1.0))
