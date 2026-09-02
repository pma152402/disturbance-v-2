extends StaticBody3D

@export_enum("Bueno", "Roto") var fuse_condition := 0
var panel: Node = null
var slot_index := -1


func configure_panel_slot(owner_panel: Node, index: int, condition: int) -> void:
	panel = owner_panel
	slot_index = index
	fuse_condition = condition


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return 1.65


func get_interaction_text(player: Node = null) -> String:
	if player != null and player.has_method(&"can_store_inventory_item") and not player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  SACAR FUSIBLE BUENO" if fuse_condition == 0 else "F  SACAR FUSIBLE ROTO"


func interact(player: Node = null) -> bool:
	if player == null or not player.has_method(&"pick_up_panel_fuse"):
		return false
	if not bool(player.call(&"pick_up_panel_fuse", fuse_condition)):
		return false
	if panel != null and panel.has_method(&"remove_fuse"):
		panel.call(&"remove_fuse", slot_index, self)
	else:
		queue_free()
	return true
