extends StaticBody3D

@export_range(0, 3) var slot_index := 0


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return 1.65


func get_interaction_text(player: Node = null) -> String:
	var panel := _panel()
	if panel == null or bool(panel.call(&"has_fuse", slot_index)):
		return ""
	if player != null and player.has_method(&"has_selected_panel_fuse") and bool(player.call(&"has_selected_panel_fuse")):
		return "F  COLOCAR FUSIBLE"
	return "EQUIPA UN FUSIBLE"


func interact(player: Node = null) -> bool:
	var panel := _panel()
	return panel != null and bool(panel.call(&"insert_selected_fuse", slot_index, player))


func _panel() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method(&"insert_selected_fuse"):
			return current
		current = current.get_parent()
	return null
