extends RigidBody3D

var _picked_up := false


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return 2.35


func get_interaction_priority() -> int:
	return 100


func get_interaction_text(player: Node = null) -> String:
	if player != null and player.has_method(&"can_store_inventory_item") and not player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  COGER MANDO DE TELE"


func interact(player: Node = null) -> bool:
	if _picked_up or player == null or not player.has_method(&"pick_up_tv_remote"):
		return false
	if not bool(player.call(&"pick_up_tv_remote")):
		return false
	_picked_up = true
	collision_layer = 0
	queue_free()
	return true


func set_dropped(initial_velocity := Vector3.ZERO) -> void:
	freeze = false
	sleeping = false
	linear_velocity = initial_velocity
	angular_velocity = Vector3(
		randf_range(-0.7, 0.7),
		randf_range(-0.45, 0.45),
		randf_range(-0.7, 0.7)
	)
