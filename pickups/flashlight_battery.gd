extends StaticBody3D

@export var item_id: StringName = &"flashlight_battery"
@export var item_name := "PILA"

var _collected := false


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node = null) -> String:
	return "F  COGER %s" % item_name.to_upper()


func interact(player: Node = null) -> bool:
	if _collected or player == null or not player.has_method(&"add_tool"):
		return false
	var installed := player.has_method(&"install_flashlight_battery") and bool(player.call(&"install_flashlight_battery"))
	if not installed and not player.add_tool(item_id):
		return false
	if player.has_method(&"play_pickup_sound"):
		player.call(&"play_pickup_sound", item_id)
	_collected = true
	collision_layer = 0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", position + Vector3.UP * 0.2, 0.2)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
	tween.chain().tween_callback(queue_free)
	return true
