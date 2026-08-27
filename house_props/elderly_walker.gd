extends CharacterBody3D

@export var push_speed := 1.05
@export var reverse_speed := 0.62
@export var turn_speed := 1.25
@export var driver_distance := 0.93

var _driver: CharacterBody3D


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if is_instance_valid(_driver):
		return "F  SOLTAR ANDADOR"
	if player != null and player.has_method(&"is_holding_item") and player.is_holding_item():
		return "TIENES LAS MANOS OCUPADAS"
	return "F  MOVER ANDADOR"


func interact(player: Node = null) -> bool:
	if is_instance_valid(_driver):
		stop_moving()
		return true
	if not player is CharacterBody3D or not player.has_method(&"begin_moving_walker"):
		return false
	if not player.begin_moving_walker(self):
		return false
	_driver = player as CharacterBody3D
	add_collision_exception_with(_driver)
	_sync_driver_pose()
	return true


func drive_from_player(input_vector: Vector2, delta: float) -> void:
	if not is_instance_valid(_driver):
		velocity = Vector3.ZERO
		return
	var forward_amount := -input_vector.y
	var turn_amount := input_vector.x
	if absf(turn_amount) > 0.01:
		var direction_sign := 1.0 if absf(forward_amount) < 0.01 else signf(forward_amount)
		rotate_y(-turn_amount * turn_speed * direction_sign * delta)
	var selected_speed := push_speed if forward_amount >= 0.0 else reverse_speed
	velocity = -global_basis.z * forward_amount * selected_speed
	velocity.y = 0.0
	move_and_slide()
	_sync_driver_pose()


func stop_moving() -> void:
	if not is_instance_valid(_driver):
		return
	var previous_driver := _driver
	remove_collision_exception_with(previous_driver)
	_driver = null
	velocity = Vector3.ZERO
	if previous_driver.has_method(&"end_moving_walker"):
		previous_driver.end_moving_walker(self)


func _sync_driver_pose() -> void:
	if not is_instance_valid(_driver):
		return
	var standing_position := global_position + global_basis.z.normalized() * driver_distance
	standing_position.y = global_position.y
	_driver.sync_to_walker(standing_position, rotation.y)
