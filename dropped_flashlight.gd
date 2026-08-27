extends RigidBody3D

@onready var light: SpotLight3D = $SpotLight3D
var _being_picked_up := false


func set_light_enabled(enabled: bool) -> void:
	light.visible = enabled


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if player != null and player.has_method(&"is_holding_item") and player.is_holding_item():
		return "TIENES LAS MANOS OCUPADAS"
	return "F  COGER LINTERNA"


func interact(player: Node = null) -> bool:
	if _being_picked_up or player == null or not player.has_method(&"recover_flashlight"):
		return false
	if not player.recover_flashlight(light.visible):
		return false
	_being_picked_up = true
	queue_free()
	return true
