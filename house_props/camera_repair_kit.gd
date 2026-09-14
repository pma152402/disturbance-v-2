extends RigidBody3D

var _picked_up := false

func get_interaction_key() -> Key:
	return KEY_F

func get_interaction_text(player: Node = null) -> String:
	if player != null and not player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  COGER KIT DE REPARACION"

func interact(player: Node = null) -> bool:
	if _picked_up or player == null or not player.pick_up_item(&"repair_kit"):
		return false
	_picked_up = true
	hide()
	queue_free()
	return true

func set_dropped(initial_velocity := Vector3.ZERO) -> void:
	freeze = false
	linear_velocity = initial_velocity
	sleeping = false
