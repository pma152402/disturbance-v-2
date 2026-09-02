extends RigidBody3D

@onready var visual: Node3D = $CandleVisual

var _picked_up := false


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if bool(visual.get("lit")):
		if player != null and player.has_method(&"can_store_inventory_item") and not player.can_store_inventory_item():
			return "INVENTARIO LLENO"
		return "F  COGER VELA ENCENDIDA"
	if not _player_has_flame_in_hand(player):
		return "NECESITAS UNA CERILLA O VELA ENCENDIDA"
	if player != null and player.has_method(&"can_store_inventory_item") and not player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  EQUIPAR VELA ENCENDIDA"


func interact(player: Node = null) -> bool:
	if _picked_up or player == null or not player.has_method(&"pick_up_candle"):
		return false
	var already_lit := bool(visual.get("lit"))
	if not already_lit and not _player_has_flame_in_hand(player):
		return false
	if not bool(player.call(&"pick_up_candle", visual.call(&"get_candle_data"), not already_lit)):
		return false
	_picked_up = true
	collision_layer = 0
	collision_mask = 0
	queue_free()
	return true


func _player_has_flame_in_hand(player: Node) -> bool:
	if player == null:
		return false
	var has_match_flame := player.has_method(&"has_lit_match_in_hand") and bool(player.call(&"has_lit_match_in_hand"))
	var has_candle_flame := player.has_method(&"has_lit_candle_in_hand") and bool(player.call(&"has_lit_candle_in_hand"))
	return has_match_flame or has_candle_flame


func configure_candle(data: Dictionary) -> void:
	visual.call(&"configure_candle", data)


func set_placed() -> void:
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	rotation.x = 0.0
	rotation.z = 0.0


func set_dropped(initial_velocity := Vector3.ZERO) -> void:
	freeze = false
	linear_velocity = initial_velocity
	angular_velocity = Vector3.ZERO
	rotation.x = 0.0
	rotation.z = 0.0
