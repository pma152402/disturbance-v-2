extends AnimatableBody3D

@export var open_angle_degrees := 96.0
@export var open_sign := 1.0
@export var transition_time := 0.65
@export var panel_direction := 1.0
@export var panel_width := 1.19

@onready var panel_collision: CollisionShape3D = $PanelCollision

var _is_open := false
var _is_animating := false
var _active_tween: Tween
var _last_interactor: Node3D
var _restore_token := 0


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node) -> String:
	return "F  CERRAR PUERTA" if _is_open else "F  ABRIR PUERTA"


func interact(player: Node) -> bool:
	for leaf in get_parent().get_children():
		if leaf.get_script() == get_script() and leaf._is_animating:
			return true
	var opening := not _is_open
	for leaf in get_parent().get_children():
		if leaf.get_script() == get_script():
			leaf._set_open(opening, player)
	return true


func ensure_open_for_npc(actor: Node) -> bool:
	return true if _is_open else interact(actor)


func get_npc_traversal_portal() -> Dictionary:
	var portal_root := get_parent() as Node3D
	if not is_instance_valid(portal_root):
		return {"center": global_position, "normal": global_basis.z.normalized(), "open_wait": transition_time * 0.25}
	return {
		"center": portal_root.global_position,
		"normal": portal_root.global_basis.z.normalized(),
		"open_wait": transition_time * 0.25,
	}


func _set_open(opening: bool, player: Node) -> void:
	_is_open = opening
	_is_animating = true
	_last_interactor = player as Node3D
	_restore_token += 1
	panel_collision.set_deferred("disabled", true)
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	var target := deg_to_rad(open_angle_degrees) * open_sign if _is_open else 0.0
	_active_tween.tween_property(self, "rotation:y", target, transition_time)
	_active_tween.finished.connect(func() -> void:
		rotation.y = target
		_is_animating = false
		_restore_collision(_restore_token)
	)


func _restore_collision(token: int) -> void:
	while token == _restore_token and _actor_in_panel():
		await get_tree().physics_frame
	if token == _restore_token:
		panel_collision.set_deferred("disabled", false)


func _actor_in_panel() -> bool:
	if not is_instance_valid(_last_interactor):
		return false
	var p := to_local(_last_interactor.global_position)
	return p.x * panel_direction > -0.45 and p.x * panel_direction < panel_width + 0.45 and absf(p.z) < 0.55 and p.y > -0.4 and p.y < 3.0
