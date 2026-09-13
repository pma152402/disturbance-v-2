extends StaticBody3D

@export var key_id: StringName = &"old_house_key"
@export var key_name := "LLAVE ANTIGUA"
@export var starts_hidden_until_revealed := false
@export var requires_crouch := false
@export_range(0.5, 2.35, 0.05, "suffix:m") var interaction_distance := 1.55

var _collected := false
var _revealing := false


func _ready() -> void:
	add_to_group(&"collectible_keys")
	if starts_hidden_until_revealed:
		visible = false
		_set_interaction_enabled(false)


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return interaction_distance


func get_interaction_priority() -> int:
	return 100


func get_interaction_text(player: Node = null) -> String:
	if not _player_meets_stance_requirement(player):
		return ""
	return "F  COGER %s" % preload("res://systems/key_display_text.gd").clean(key_name).to_upper()


func interact(player: Node = null) -> bool:
	if (
		_collected
		or _revealing
		or not visible
		or not _player_meets_stance_requirement(player)
		or player == null
		or not player.has_method(&"add_key")
	):
		return false
	if not player.add_key(key_id, key_name):
		return false
	_collected = true
	_set_interaction_enabled(false)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", position + Vector3(0.0, 0.35, 0.0), 0.22)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.22)
	tween.chain().tween_callback(queue_free)
	return true


func _player_meets_stance_requirement(player: Node) -> bool:
	if not requires_crouch:
		return true
	return player != null and player.has_method(&"is_crouched") and bool(player.call(&"is_crouched"))


func reveal_from_toilet(start_global_position: Vector3, landing_global_position: Vector3) -> void:
	if _collected or _revealing:
		return
	_revealing = true
	visible = true
	global_position = start_global_position + Vector3.UP * 0.06
	_set_interaction_enabled(false)
	var original_rotation := rotation
	var rise_position := global_position + Vector3.UP * 1.25
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", rise_position, 1.35)
	tween.parallel().tween_property(self, "rotation", original_rotation + Vector3(0.7, TAU * 1.5, 0.45), 1.35)
	tween.tween_property(self, "global_position", landing_global_position, 1.7)
	tween.parallel().tween_property(self, "rotation", original_rotation + Vector3(1.2, TAU * 3.0, 1.1), 1.7)
	tween.tween_callback(func() -> void:
		_revealing = false
		_set_interaction_enabled(true)
	)


func _set_interaction_enabled(enabled: bool) -> void:
	collision_layer = 2 if enabled else 0
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).set_deferred("disabled", not enabled)
	var interaction_area := get_node_or_null("InteractionArea") as Area3D
	if interaction_area != null:
		interaction_area.collision_layer = 2 if enabled else 0
