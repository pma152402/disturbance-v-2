extends RigidBody3D

signal screw_removed(index: int)
signal all_screws_removed

const ScrewdriverScene := preload("res://house_props/flathead_screwdriver.tscn")
const SCREW_POSITIONS: Array[Vector2] = [
	Vector2(-0.31, 0.31),
	Vector2(0.31, 0.31),
	Vector2(-0.31, -0.31),
	Vector2(0.31, -0.31),
]
const SCREW_PATHS: Array[NodePath] = [
	^"Screws/TopLeft",
	^"Screws/TopRight",
	^"Screws/BottomLeft",
	^"Screws/BottomRight",
]
const REQUIRED_ROTATION := TAU * 8.75
const SCREW_EXTRACTION_DISTANCE := 0.48

var _removed: Array[bool] = [false, false, false, false]
var _active_screw := -1
var _active_player: Node
var _tool_pivot: Node3D
var _tool_visual: Node3D
var _virtual_mouse := Vector2(42.0, 0.0)
var _last_mouse_angle := 0.0
var _rotation_progress := 0.0
var _active_screw_start_position := Vector3.ZERO


func get_interaction_key() -> Key:
	return KEY_F


func uses_switch_sound() -> bool:
	return false


func get_interaction_text(player: Node = null) -> String:
	if _active_screw >= 0:
		return "HAZ CIRCULOS CON EL RATON  |  F  SOLTAR"
	var screw_index := _get_aimed_screw(player)
	if screw_index < 0:
		return ""
	if player == null or not player.has_method(&"has_tool") or not bool(player.call(&"has_tool", &"flathead_screwdriver")):
		return "NECESITAS DESTORNILLADOR PLANO"
	if player.has_method(&"is_holding_item_type") and not bool(player.call(&"is_holding_item_type", &"flathead_screwdriver")):
		return "EQUIPA DESTORNILLADOR PLANO"
	return "F  AFLOJAR TORNILLO"


func interact(player: Node = null) -> bool:
	if _active_screw >= 0:
		end_screw_manipulation()
		return true
	var screw_index := _get_aimed_screw(player)
	if screw_index < 0:
		return false
	if player == null or not player.has_method(&"has_tool") or not bool(player.call(&"has_tool", &"flathead_screwdriver")):
		return true
	if player.has_method(&"is_holding_item_type") and not bool(player.call(&"is_holding_item_type", &"flathead_screwdriver")):
		return true
	_start_screw_manipulation(player, screw_index)
	return true


func _start_screw_manipulation(player: Node, screw_index: int) -> void:
	_active_screw = screw_index
	_active_player = player
	_virtual_mouse = Vector2(42.0, 0.0)
	_last_mouse_angle = 0.0
	_rotation_progress = 0.0
	_active_screw_start_position = (get_node(SCREW_PATHS[screw_index]) as Node3D).position
	_tool_pivot = Node3D.new()
	_tool_pivot.name = "ActiveScrewdriverPivot"
	add_child(_tool_pivot)
	_tool_visual = ScrewdriverScene.instantiate() as Node3D
	_tool_pivot.add_child(_tool_visual)
	_tool_visual.collision_layer = 0
	for child in _tool_visual.get_children():
		if child is CollisionShape3D:
			child.disabled = true
	var point: Vector2 = SCREW_POSITIONS[screw_index]
	# El pivote coincide exactamente con la ranura. El origen del destornillador
	# se compensa 0.43 m para que su punta, no su centro, quede sobre el tornillo.
	# 0.012 m mas hacia dentro para que la punta quede claramente encajada.
	_tool_pivot.position = Vector3(point.x, point.y, -0.073)
	# El +90 coloca el mango delante del panel; con el signo contrario quedaba
	# oculto detrás de la chapa.
	_tool_pivot.rotation = Vector3(0.0, PI * 0.5, 0.0)
	# El modelo tiene su eje a Y=0.075. Esta compensacion coloca punta, vastago
	# y mango exactamente sobre el centro del tornillo.
	_tool_visual.position = Vector3(0.43, -0.075, 0.0)
	_tool_visual.rotation = Vector3.ZERO
	_tool_visual.scale = Vector3.ONE * 1.12
	if player.has_method(&"begin_screw_manipulation"):
		player.call(&"begin_screw_manipulation", self)
	if player.has_method(&"set_screwdriver_minigame_pose"):
		player.call(&"set_screwdriver_minigame_pose", true)


func handle_screwdriver_mouse(relative_motion: Vector2) -> void:
	if _active_screw < 0 or relative_motion.is_zero_approx():
		return
	_virtual_mouse += relative_motion
	if _virtual_mouse.length() > 95.0:
		_virtual_mouse = _virtual_mouse.normalized() * 95.0
	if _virtual_mouse.length() < 18.0:
		return
	var current_angle := _virtual_mouse.angle()
	var angle_delta := wrapf(current_angle - _last_mouse_angle, -PI, PI)
	_last_mouse_angle = current_angle
	# Se exige trayectoria circular; los cambios bruscos y lineales no cuentan.
	if absf(angle_delta) > 0.65:
		return
	_rotation_progress += absf(angle_delta)
	var ratio := clampf(_rotation_progress / REQUIRED_ROTATION, 0.0, 1.0)
	var screw := get_node(SCREW_PATHS[_active_screw]) as Node3D
	# Parte siempre de su posicion real, sin el salto inicial que provocaba
	# recalcular Z desde cero. Al girar sale progresivamente y deja ver el vastago.
	screw.position = _active_screw_start_position + Vector3(0.0, 0.0, -SCREW_EXTRACTION_DISTANCE * ratio)
	screw.rotation.z = -_rotation_progress
	# Solo rota sobre el eje longitudinal; el pivote nunca cambia de posición.
	_tool_pivot.rotation.x = _rotation_progress
	if ratio >= 1.0:
		_finish_active_screw()


func _finish_active_screw() -> void:
	var finished_index := _active_screw
	_removed[finished_index] = true
	var screw := get_node(SCREW_PATHS[finished_index]) as Node3D
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(screw, "position", screw.position + Vector3(0.0, -0.18, -0.12), 0.28)
	tween.tween_property(screw, "rotation:z", screw.rotation.z - 1.8, 0.28)
	tween.tween_property(screw, "scale", Vector3.ONE * 0.05, 0.28)
	tween.chain().tween_callback(func() -> void: screw.visible = false)
	end_screw_manipulation()
	screw_removed.emit(finished_index)
	if not false in _removed:
		all_screws_removed.emit()
		call_deferred(&"_drop_panel")


func end_screw_manipulation() -> void:
	if is_instance_valid(_tool_pivot):
		_tool_pivot.queue_free()
	_tool_pivot = null
	_tool_visual = null
	_active_screw = -1
	_rotation_progress = 0.0
	if is_instance_valid(_active_player) and _active_player.has_method(&"end_screw_manipulation"):
		_active_player.call(&"end_screw_manipulation", self)
	if is_instance_valid(_active_player) and _active_player.has_method(&"set_screwdriver_minigame_pose"):
		_active_player.call(&"set_screwdriver_minigame_pose", false)
	_active_player = null


func _drop_panel() -> void:
	await get_tree().create_timer(0.3).timeout
	var panel_collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if panel_collision != null:
		panel_collision.set_deferred(&"disabled", true)
	collision_layer = 0
	collision_mask = 0
	freeze = true

	# Sin collider, calculamos el suelo y animamos solo la trampilla visible para
	# que no atraviese el piso ni deje una barrera invisible en el conducto.
	var forward: Vector3 = -global_basis.z.normalized()
	var target_position := global_position + forward * 0.42 + Vector3.DOWN * 1.25
	var world := get_world_3d()
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(
			global_position + forward * 0.22,
			global_position + forward * 0.42 + Vector3.DOWN * 4.0,
			1,
			[get_rid()]
		)
		query.collide_with_areas = false
		var floor_hit := world.direct_space_state.intersect_ray(query)
		if not floor_hit.is_empty():
			target_position = floor_hit.position + Vector3.UP * 0.025

	var target_rotation := rotation + Vector3(-PI * 0.5, 0.0, 0.08)
	var fall_tween := create_tween().set_parallel(true)
	fall_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(self, "global_position", target_position, 0.72)
	fall_tween.tween_property(self, "rotation", target_rotation, 0.72)


func _get_aimed_screw(player: Node) -> int:
	if player == null or not "interaction_ray" in player:
		return -1
	var ray := player.get("interaction_ray") as RayCast3D
	if ray == null or not ray.is_colliding() or ray.get_collider() != self:
		return -1
	var local_hit := to_local(ray.get_collision_point())
	var closest := -1
	# Margen generoso para poder seleccionar los tornillos también desde la
	# cámara baja al arrastrarse con X, sin exigir precisión de píxel.
	var closest_distance := 0.18
	for index in SCREW_POSITIONS.size():
		if _removed[index]:
			continue
		var distance := Vector2(local_hit.x, local_hit.y).distance_to(SCREW_POSITIONS[index])
		if distance < closest_distance:
			closest_distance = distance
			closest = index
	return closest
