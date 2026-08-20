extends Area3D

var _picked_up := false


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node = null) -> String:
	if _player != null and _player.has_method(&"is_holding_item") and _player.is_holding_item():
		return "YA LLEVAS UN OBJETO"
	return "F  COGER LATA"


func interact(player: Node = null) -> bool:
	if _picked_up or player == null or not player.has_method(&"pick_up_item"):
		return false
	if not player.pick_up_item(&"can"):
		return false
	_picked_up = true
	monitorable = false
	monitoring = false
	$CollisionShape3D.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", position + Vector3(0.0, 0.35, 0.0), 0.16)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.16)
	tween.chain().tween_callback(queue_free)
	return true
