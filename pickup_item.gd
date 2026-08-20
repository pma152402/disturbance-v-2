extends Area3D

@export var item_name := "OBJETO"
@export var item_type: StringName = &"bottle"

var _picked_up := false


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node = null) -> String:
	if _player != null and _player.has_method(&"is_holding_item") and _player.is_holding_item():
		return "YA LLEVAS UN OBJETO"
	return "F  COGER %s" % item_name.to_upper()


func interact(_player: Node = null) -> bool:
	if _picked_up or _player == null or not _player.has_method(&"pick_up_item"):
		return false
	if not _player.pick_up_item(item_type):
		return false
	_picked_up = true
	monitorable = false
	monitoring = false
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", position + Vector3(0.0, 0.55, 0.0), 0.28)
	tween.tween_property(self, "rotation", rotation + Vector3(0.4, 1.8, -0.3), 0.28)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.28)
	tween.chain().tween_callback(queue_free)
	return true
