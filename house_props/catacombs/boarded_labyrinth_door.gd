extends CharacterBody3D

const MinigameScene := preload("res://minigames/boarded_door_minigame.tscn")
const CrowbarVisual := preload("res://player/held_items/crowbar.tscn")

@export var required_tool_id: StringName = &"crowbar"
@export var required_tool_name := "PALANCA"
@export var requires_two_hands := true
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
var _pry_visual: Node3D
var _minigame: Control
var _work_position := Vector3.ZERO
var _work_normal := Vector3.FORWARD
var _alignment_time := 0.0
var _grip_settle_time := 0.0
var _pry_rest_basis := Basis.IDENTITY
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED


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
	_close_minigame_layer()


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if _removed or _minigame_active:
		return ""
	if player != null and player.has_method(&"has_tool") and player.has_tool(required_tool_id):
		if player.has_method(&"is_holding_item_type") and not player.is_holding_item_type(required_tool_id):
			return "EQUIPA %s" % required_tool_name.to_upper()
		if requires_two_hands and (not player.has_method(&"is_camera_on_ground") or not player.is_camera_on_ground()):
			return "O  DEJA LA CAMARA  |  NECESITAS DOS MANOS"
		return "F  QUITAR TABLONES CON DOS MANOS"
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
	if requires_two_hands and (not player.has_method(&"can_begin_two_hand_interaction") or not player.can_begin_two_hand_interaction(required_tool_id)):
		return
	if not deferred_content_path.is_empty():
		var content := get_node_or_null(deferred_content_path)
		if content == null or not content.has_method(&"ensure_church_catacombs"):
			push_error("Falta el controlador del laberinto de la iglesia")
			return
		if not bool(content.call(&"ensure_church_catacombs")):
			return
	if requires_two_hands:
		if not player.has_method(&"begin_two_hand_interaction") or not player.begin_two_hand_interaction(self, required_tool_id):
			return
	_minigame_active = true
	_active_player = player
	_active_layer = MinigameScene.instantiate() as CanvasLayer
	get_tree().current_scene.add_child(_active_layer)
	var minigame := _active_layer.get_node("BoardedDoorMinigame")
	_minigame = minigame
	minigame.call(&"setup", _nail_removed_flags)
	minigame.call(&"bind_world", get_viewport().get_camera_3d(), _nails)
	minigame.completed.connect(_on_minigame_completed)
	minigame.cancelled.connect(_on_minigame_cancelled)
	minigame.nail_selected.connect(_on_nail_selected)
	minigame.pry_motion.connect(_on_pry_motion)
	minigame.nail_removed.connect(_on_nail_removed)
	_lock_player()
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
		var dying := bool(_active_player.get("_monster_restart_pending"))
		_active_player.set_process_input(_player_was_processing_input and not dying)
		_active_player.set_physics_process(_player_was_processing_physics and not dying)
		if _active_player.has_method(&"set_skill_check_active"):
			_active_player.call(&"set_skill_check_active", false)
		if _active_player.has_method(&"set_crowbar_minigame_pose"):
			_active_player.call(&"set_crowbar_minigame_pose", false)
		if _active_player.has_method(&"end_two_hand_interaction"):
			_active_player.call(&"end_two_hand_interaction", self)
		if _active_player is CharacterBody3D:
			_active_player.velocity = Vector3.ZERO
	_active_player = null
	Input.mouse_mode = _previous_mouse_mode


func _on_nail_selected(nail_index: int) -> void:
	if nail_index < 0 or nail_index >= _nails.size() or not is_instance_valid(_nails[nail_index]):
		return
	var nail := _nails[nail_index]
	if _pry_tween != null and _pry_tween.is_valid():
		_pry_tween.kill()
	if is_instance_valid(_pry_pivot):
		_pry_pivot.free()
	_pry_pivot = Node3D.new()
	add_child(_pry_pivot)
	_pry_pivot.global_transform = (nail.get_parent() as Node3D).global_transform
	_work_normal = -global_basis.z.normalized()
	if (_active_player.global_position - global_position).dot(_work_normal) < 0:
		_work_normal = -_work_normal
	_pry_pivot.global_position = nail.global_position + _work_normal * 0.045
	# El mango apunta hacia el cuerpo: arriba en clavos bajos, abajo en altos.
	var low_nail: bool = nail.global_position.y < _active_player.global_position.y - 0.05
	var waist_nail: bool = nail.global_position.y < _active_player.global_position.y + 0.5
	var left_side := to_local(nail.global_position).x < 0.0
	var working_angle := PI if low_nail else ((-PI * 0.5 if left_side else PI * 0.5) if waist_nail else 0.0)
	_pry_pivot.global_basis = global_basis.orthonormalized() * Basis(Vector3.FORWARD, working_angle)
	if (low_nail and not left_side) or (not waist_nail and left_side):
		_pry_pivot.global_basis *= Basis(Vector3.UP, PI)
	_pry_rest_basis = _pry_pivot.basis
	var visual := CrowbarVisual.instantiate() as Node3D
	_pry_visual = visual
	_pry_pivot.add_child(visual)
	visual.scale = Vector3.ONE * 0.72
	# Deslizar las manos por el mango permite llegar a clavos altos sin alargar brazos.
	var high_nail: bool = nail.global_position.y > _active_player.global_position.y + 1.0
	visual.get_node("SupportGrip").position.y = 0.30 if high_nail else 0.78
	visual.get_node("PowerGrip").position.y = 0.16 if high_nail else 0.48
	var inserted: Vector3 = -visual.get_node("HookContact").position * 0.72
	visual.position = inserted
	var grip: Vector3 = (visual.get_node("SupportGrip").global_position + visual.get_node("PowerGrip").global_position) * 0.5
	_work_position = grip + _work_normal * 0.46
	_work_position.y = _active_player.global_position.y
	_alignment_time = 0.0
	_grip_settle_time = 0.0
	_minigame.work_ready = false
	visual.visible = false
	_active_player.call(&"set_two_hand_tool", null)
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
		_pry_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# El mango oscila desde reposo hacia el jugador, sin atravesar los tablones.
		var side := -1.0 if _work_normal.dot(global_basis * _pry_rest_basis.z) > 0.0 else 1.0
		var target_basis := _pry_rest_basis * Basis(Vector3.RIGHT, side * (0.03 + (handle_value + 1.0) * 0.07))
		_pry_tween.tween_property(_pry_pivot, "basis", target_basis, 0.14)
		_pry_tween.parallel().tween_property(_pry_pivot, "global_position", nail.global_position + _work_normal * 0.045, 0.14)


func _physics_process(delta: float) -> void:
	if not _minigame_active or not is_instance_valid(_active_player) or not is_instance_valid(_pry_visual):
		return
	if _active_player.get("_monster_restart_pending"):
		_on_minigame_cancelled()
		return
	var actor := _active_player as CharacterBody3D
	var offset := _work_position - actor.global_position
	offset.y = 0
	var motion := offset.limit_length(1.35 * delta)
	actor.move_and_collide(motion)
	actor.velocity = motion / maxf(delta, 0.001) if offset.length() > 0.03 else Vector3.ZERO
	var facing := -_work_normal
	actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-facing.x, -facing.z), minf(delta * 8, 1))
	_alignment_time += delta
	if offset.length() < 0.04:
		_grip_settle_time += delta
		if not _pry_visual.visible:
			_pry_visual.visible = true
			_active_player.call(&"set_two_hand_tool", _pry_visual)
			var inserted := _pry_visual.position
			_pry_visual.position += _pry_pivot.global_basis.inverse() * _work_normal * 0.12
			_pry_visual.create_tween().tween_property(_pry_visual, "position", inserted, 0.28)
		_minigame.work_ready = _grip_settle_time > 0.4
	elif _alignment_time > 4.0:
		# Un obstáculo real cancela el acercamiento; nunca atravesamos colisiones.
		_on_minigame_cancelled()


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
