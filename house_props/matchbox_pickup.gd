extends Area3D

@export_range(0, 20, 1) var matches_remaining := 20

var _picked_up := false


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if player != null and player.has_method(&"can_store_inventory_item") and not player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  COGER CAJA DE CERILLAS (%d)" % matches_remaining


func interact(player: Node = null) -> bool:
	if _picked_up or player == null or not player.has_method(&"pick_up_matchbox"):
		return false
	if not bool(player.call(&"pick_up_matchbox", matches_remaining)):
		return false
	_picked_up = true
	monitoring = false
	monitorable = false
	queue_free()
	return true


func configure_matchbox(data: Dictionary) -> void:
	matches_remaining = clampi(int(data.get("matches_remaining", 20)), 0, 20)
