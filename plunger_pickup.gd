extends StaticBody3D

var _picked_up := false


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if player != null and player.has_method(&"is_holding_item") and player.is_holding_item():
		return "YA LLEVAS UN OBJETO"
	return "F  COGER DESATASCADOR"


func interact(player: Node = null) -> bool:
	if _picked_up or player == null or not player.has_method(&"pick_up_plunger"):
		return false
	if not player.pick_up_plunger():
		return false
	_picked_up = true
	queue_free()
	return true
