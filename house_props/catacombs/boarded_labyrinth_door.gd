extends CharacterBody3D

const MinigameScene := preload("res://boarded_door_minigame.tscn")
const CrowbarVisual := preload("res://player/held_items/crowbar.tscn")

@export var required_tool_id: StringName = &"crowbar"
@export var required_tool_name := "PALANCA"
@export_node_path("Node3D") var deferred_content_path: NodePath

@onready var collision_shape: CollisionShape3D = $Collision
@onready var boards_root: Node3D = $Boards

var _removed := false
var _minigame_active := false
var _active_player: Node
var _active_layer: CanvasLayer
var _player_was_processing_input := true
var _player_was_processing_physics := true
var _nails: Array[MeshInstance3D] = []
var _nail_rest_positions: Array[Vector3] = []
var _nail_rest_rotations: Array[Vector3] = []
var _nail_removed_flags: Array[bool] = []
var _boards: Array[Node3D] = []
var _board_removed_flags: Array[bool] = []
var _pry_pivot: Node3D
var _pry_tween: Tween


func _ready() -> void:
	for board in boards_root.get_children():
		if board is not Node3D:
			continue
		_boards.append(board as Node3D)
		_board_removed_flags.append(false)
		for nail_name in [^"NailLeft", ^"NailRight"]:
			var nail := board.get_node(nail_name) as MeshInstance3D
			_nails.append(nail)
			_nail_rest_positions.append(nail.position)
			_nail_rest_rotations.append(nail.rotation)
			_nail_removed_flags.append(false)


func _exit_tree() -> void:
	if _minigame_active:
		_restore_player()


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if _removed or _minigame_active:
		return ""
	if player != null and player.has_method(&"has_tool") and player.has_tool(required_tool_id):
		if player.has_method(&"is_holding_item_type") and not player.is_holding_item_type(required_tool_id):
			return "EQUIPA %s" % required_tool_name.to_upper()
		return "F  QUITAR TABLONES"
	return "NECESITAS %s" % required_tool_name.to_upper()


func interact(player: Node = null) -> bool:
	if _removed or _minigame_active:
		return true
	if player == null or not player.has_method(&"has_tool") or not player.has_tool(required_tool_id):
		return true
	if player.has_method(&"is_holding_item_type") and not player.is_holding_item_type(required_tool_id):
		return true
	_start_minigame(player)
	return true


func _start_minigame(player: Node) -> void:
	if not deferred_content_path.is_empty():
		var content := get_node_or_null(deferred_content_path)
		if content == null or not content.has_method(&"ensure_church_catacombs"):
			push_error("Falta el controlador del laberinto de la iglesia")
			return
		if not bool(content.call(&"ensure_church_catacombs")):
			return
	_minigame_active = true
	_active_player = player
	_active_layer = MinigameScene.instantiate() as CanvasLayer
	get_tree().current_scene.add_child(_active_layer)
	var minigame := _active_layer.get_node("BoardedDoorMinigame")
	minigame.call(&"setup", _nail_removed_flags)
	minigame.call(&"bind_world", get_viewport().get_camera_3d(), _nails)
	minigame.completed.connect(_on_minigame_completed)
	minigame.cancelled.connect(_on_minigame_cancelled)
	minigame.nail_selected.connect(_on_nail_selected)
	minigame.pry_motion.connect(_on_pry_motion)
	minigame.nail_removed.connect(_on_nail_removed)
	_lock_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _lock_player() -> void:
	if not is_instance_valid(_active_player):
		return
	_player_was_processing_input = _active_player.is_processing_input()
	_player_was_processing_physics = _active_player.is_physics_processing()
	if _active_player.has_method(&"set_skill_check_active"):
		_active_player.call(&"set_skill_check_active", true)
	if _active_player.has_method(&"set_crowbar_minigame_pose"):
		_active_player.call(&"set_crowbar_minigame_pose", true)
	if _active_player is CharacterBody3D:
		(_active_player as CharacterBody3D).velocity = Vector3.ZERO
	_active_player.set_process_input(false)
	_active_player.set_physics_process(false)


func _restore_player() -> void:
	if is_instance_valid(_active_player):
		_active_player.set_process_input(_player_was_processing_input)
		_active_player.set_physics_process(_player_was_processing_physics)
		if _active_player.has_method(&"set_skill_check_active"):
			_active_player.call(&"set_skill_check_active", false)
		if _active_player.has_method(&"set_crowbar_minigame_pose"):
			_active_player.call(&"set_crowbar_minigame_pose", false)
	_active_player = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_nail_selected(nail_index: int) -> void:
	if nail_index < 0 or nail_index >= _nails.size() or not is_instance_valid(_nails[nail_index]):
		return
	var nail := _nails[nail_index]
	if is_instance_valid(_pry_pivot):
		_pry_pivot.free()
	_pry_pivot = Node3D.new()
	add_child(_pry_pivot)
	_pry_pivot.global_transform = (nail.get_parent() as Node3D).global_transform
	_pry_pivot.global_position = nail.global_position - _pry_pivot.global_basis.z.normalized() * 0.07
	var visual := CrowbarVisual.instantiate() as Node3D
	_pry_pivot.add_child(visual)
	visual.scale = Vector3.ONE * 0.42
	var inserted := -Vector3(0.41, 1.45, 0) * 0.42
	visual.position = inserted + Vector3(0, -0.2, -0.3)
	visual.create_tween().tween_property(visual, "position", inserted, 0.3)
	var tween := nail.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(nail, "scale", Vector3.ONE * 1.24, 0.12)
	tween.tween_property(nail, "scale", Vector3.ONE, 0.16)


func _on_pry_motion(nail_index: int, progress: float, handle_value: float) -> void:
	if nail_index < 0 or nail_index >= _nails.size() or not is_instance_valid(_nails[nail_index]):
		return
	var nail := _nails[nail_index]
	nail.position = _nail_rest_positions[nail_index] + Vector3(0.0, 0.0, -progress * 0.17)
	nail.rotation = _nail_rest_rotations[nail_index] + Vector3(handle_value * 0.035, progress * 0.12, handle_value * 0.025)
	if is_instance_valid(_pry_pivot):
		if _pry_tween != null and _pry_tween.is_valid():
			_pry_tween.kill()
		_pry_tween = _pry_pivot.create_tween()
		_pry_tween.tween_property(_pry_pivot, "rotation:x", handle_value * 0.22, 0.1)


func _on_nail_removed(nail_index: int) -> void:
	if nail_index < 0 or nail_index >= _nails.size() or _nail_removed_flags[nail_index]:
		return
	_nail_removed_flags[nail_index] = true
	var nail := _nails[nail_index]
	if is_instance_valid(nail):
		var tween := nail.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(nail, "position", nail.position + Vector3(0.0, -0.08, -0.22), 0.22)
		tween.parallel().tween_property(nail, "scale", Vector3.ONE * 0.05, 0.22)
		tween.tween_callback(func() -> void: nail.visible = false)
	var board_index := nail_index / 2
	if _nail_removed_flags[board_index * 2] and _nail_removed_flags[board_index * 2 + 1]:
		_remove_board(board_index)


func _remove_board(board_index: int) -> void:
	if board_index < 0 or board_index >= _boards.size() or _board_removed_flags[board_index]:
		return
	_board_removed_flags[board_index] = true
	var board := _boards[board_index]
	if not is_instance_valid(board):
		return
	var direction := -1.0 if board_index % 2 == 0 else 1.0
	var start_position := board.position
	var tween := board.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(board, "position", start_position + Vector3(direction * 0.42, -0.12, 0.5), 0.34)
	tween.parallel().tween_property(board, "rotation", board.rotation + Vector3(0.22 * direction, 0.14 * direction, 0.38 * direction), 0.34)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(board, "position", start_position + Vector3(direction * 0.64, -1.35, 0.82), 0.48)
	tween.tween_callback(board.queue_free)


func _on_minigame_completed() -> void:
	_removed = true
	_minigame_active = false
	collision_layer = 0
	collision_shape.set_deferred("disabled", true)
	_restore_player()
	_close_minigame_layer()


func _on_minigame_cancelled() -> void:
	_minigame_active = false
	for nail_index in _nails.size():
		if _nail_removed_flags[nail_index] or not is_instance_valid(_nails[nail_index]):
			continue
		_nails[nail_index].position = _nail_rest_positions[nail_index]
		_nails[nail_index].rotation = _nail_rest_rotations[nail_index]
		_nails[nail_index].scale = Vector3.ONE
	_restore_player()
	_close_minigame_layer()


func _close_minigame_layer() -> void:
	if is_instance_valid(_pry_pivot):
		_pry_pivot.queue_free()
	_pry_pivot = null
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null
