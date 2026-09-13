extends StaticBody3D

signal activated

@export var assigned_bells: Array[NodePath] = []
@export var auto_find_nearest_bell := true
@export_range(1.0, 3.0, 0.05) var interaction_distance := 1.65
@export_range(0.2, 2.0, 0.05) var reset_time := 0.55

@onready var lever_pivot: Node3D = $LeverPivot
@onready var switch_audio: AudioStreamPlayer3D = $SwitchAudio

var _busy := false
var _lever_tween: Tween


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return interaction_distance


func get_interaction_text(_player: Node = null) -> String:
	return "F  ACCIONAR CAMPANA"


func uses_switch_sound() -> bool:
	return false


func interact(_player: Node = null) -> bool:
	if _busy:
		return false
	_busy = true
	_play_lever_animation()
	switch_audio.pitch_scale = randf_range(0.96, 1.03)
	switch_audio.play()
	var bells := _get_bells()
	for bell in bells:
		bell.call(&"ring")
	activated.emit()
	return true


func _play_lever_animation() -> void:
	if _lever_tween != null:
		_lever_tween.kill()
	_lever_tween = create_tween()
	_lever_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_lever_tween.tween_property(lever_pivot, "rotation:x", deg_to_rad(-38.0), 0.14)
	_lever_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lever_tween.tween_property(lever_pivot, "rotation:x", deg_to_rad(12.0), reset_time)
	_lever_tween.tween_callback(_finish_reset)


func _finish_reset() -> void:
	_busy = false


func _get_bells() -> Array[Node]:
	var result: Array[Node] = []
	for bell_path in assigned_bells:
		var bell := get_node_or_null(bell_path)
		if is_instance_valid(bell) and bell.has_method(&"ring"):
			result.append(bell)
	if not result.is_empty() or not auto_find_nearest_bell:
		return result
	var nearest: Node3D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group(&"school_bells"):
		if candidate is Node3D and candidate.has_method(&"ring"):
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate
	if nearest != null:
		result.append(nearest)
	return result
