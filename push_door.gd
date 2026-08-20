extends AnimatableBody3D

@export_range(70.0, 110.0, 1.0) var open_angle_degrees := 90.0
@export_range(0.05, 1.0, 0.01) var transition_time := 0.18
@export var panel_half_width := 1.04

var _is_open := false
var _is_animating := false
var _open_sign := 1.0
var _active_tween: Tween


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node) -> String:
	return "F  CERRAR PUERTA" if _is_open else "F  ABRIR PUERTA"


func interact(player: Node) -> bool:
	if _is_animating:
		return true

	if not _is_open:
		_open_sign = _get_open_sign(player)
	_is_open = not _is_open
	_animate_to(_open_sign * deg_to_rad(open_angle_degrees) if _is_open else 0.0)
	return true


func _get_open_sign(player: Node) -> float:
	if not player is Node3D:
		return 1.0
	var player_3d := player as Node3D
	var panel_center := global_position + global_basis.x * panel_half_width
	var player_side := (player_3d.global_position - panel_center).dot(global_basis.z)
	if absf(player_side) < 0.01:
		return 1.0
	# Positive rotation moves the free edge toward local -Z, away from a player on local +Z.
	return signf(player_side)


func _animate_to(target_angle: float) -> void:
	_is_animating = true
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "rotation:y", target_angle, transition_time)
	_active_tween.finished.connect(func() -> void:
		rotation.y = target_angle
		_is_animating = false
	)
