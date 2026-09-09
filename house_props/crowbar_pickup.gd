extends RigidBody3D

@export var tool_id: StringName = &"crowbar"
@export var tool_name := "PALANCA"

var _collected := false


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node = null) -> String:
	if _player != null and _player.has_method(&"can_store_inventory_item") and not _player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  COGER %s" % tool_name.to_upper()


func interact(player: Node = null) -> bool:
	if _collected or player == null or not player.has_method(&"pick_up_crowbar"):
		return false
	if not player.pick_up_crowbar():
		return false
	_collected = true
	freeze = true
	collision_layer = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", position + Vector3.UP * 0.42, 0.24)
	tween.tween_property(self, "rotation", rotation + Vector3(0.25, 1.4, -0.35), 0.24)
	# Keep the transform invertible until the node is freed; a literal zero scale
	# produces noisy Basis inversion errors in Godot's 3D update.
	tween.tween_property(self, "scale", Vector3.ONE * 0.03, 0.24)
	tween.chain().tween_callback(queue_free)
	return true


func set_dropped(inherited_velocity := Vector3.ZERO) -> void:
	_collected = false
	collision_layer = 2
	collision_mask = 1
	freeze = false
	sleeping = false
	linear_velocity = inherited_velocity + Vector3.UP * 0.08
	angular_velocity = Vector3(
		randf_range(-1.8, 1.8),
		randf_range(-1.2, 1.2),
		randf_range(-2.2, 2.2)
	)
