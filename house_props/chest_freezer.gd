extends StaticBody3D

@export_range(0.5, 2.0, 0.05, "suffix:m") var interaction_distance := 1.5
@export var hiding_position := Vector3(0.0, 0.48, 0.0)
@export var exit_position := Vector3(0.0, 0.08, -0.72)
@export_range(60.0, 125.0, 1.0, "suffix:deg") var open_angle_degrees := 105.0

@onready var lid_hinge: Node3D = $LidHinge

var _occupant: Node3D
var _transitioning := false
var _lid_tween: Tween


func _ready() -> void:
	_set_hiding_visuals(false)


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return interaction_distance


func get_interaction_text(_player: Node = null) -> String:
	return "" if _transitioning or is_instance_valid(_occupant) else "F  ESCONDERSE EN CONGELADOR"


func interact(player: Node = null) -> bool:
	if _transitioning or is_instance_valid(_occupant):
		return true
	if player == null or not player.has_method(&"prepare_chest_freezer_entry") or not player.has_method(&"enter_chest_freezer"):
		return false
	if not bool(player.call(&"prepare_chest_freezer_entry", self)):
		return false
	_transitioning = true
	_animate_lid(deg_to_rad(open_angle_degrees), 0.28, func() -> void:
		var forward := -global_basis.z.normalized()
		if bool(player.call(&"enter_chest_freezer", self, to_global(hiding_position), forward)):
			_occupant = player
			_set_hiding_visuals(true)
		_animate_lid(0.0, 0.36, func() -> void:
			_transitioning = false
		)
	)
	return true


func request_exit(player: Node) -> void:
	if _transitioning or player != _occupant:
		return
	_transitioning = true
	_animate_lid(deg_to_rad(open_angle_degrees), 0.3, func() -> void:
		var forward := -global_basis.z.normalized()
		player.call(&"leave_chest_freezer", to_global(exit_position), forward)
		_occupant = null
		_set_hiding_visuals(false)
		_animate_lid(0.0, 0.38, func() -> void:
			_transitioning = false
		)
	)


func is_player_hidden(player: Node) -> bool:
	return is_instance_valid(_occupant) and _occupant == player


func _animate_lid(target_angle: float, duration: float, finished: Callable) -> void:
	if is_instance_valid(_lid_tween):
		_lid_tween.kill()
	_lid_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_lid_tween.tween_property(lid_hinge, "rotation:x", target_angle, duration)
	_lid_tween.tween_callback(finished)


func _set_hiding_visuals(active: bool) -> void:
	var original_body := get_node_or_null("Body") as MeshInstance3D
	if original_body != null:
		original_body.visible = not active
	for path: NodePath in [
		^"OuterBottom", ^"OuterBack", ^"OuterFront", ^"OuterFrontUpper", ^"OuterLeft", ^"OuterRight",
		^"InteriorBottom", ^"InteriorBack", ^"InteriorFront", ^"InteriorFrontUpper", ^"InteriorLeft", ^"InteriorRight",
	]:
		var part := get_node_or_null(path) as MeshInstance3D
		if part != null:
			part.visible = active
