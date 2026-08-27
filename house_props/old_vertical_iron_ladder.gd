extends StaticBody3D

@export_category("Escalada")
@export var climb_speed := 1.55
@export var climb_min_y := 0.12
@export var climb_max_y := 5.75
@export var attach_distance := 0.58
@export var exit_distance := 0.92

var _climber: CharacterBody3D
var _approach_side := 1.0

func get_interaction_key() -> Key:
	return KEY_F

func get_interaction_text(player: Node = null) -> String:
	if is_instance_valid(_climber):
		return "F  SOLTAR ESCALERA"
	if player != null and player.has_method(&"is_holding_item") and player.is_holding_item():
		return "TIENES LAS MANOS OCUPADAS"
	return "F  SUBIR ESCALERA"

func interact(player: Node = null) -> bool:
	if is_instance_valid(_climber):
		stop_climbing(false)
		return true
	if not player is CharacterBody3D or not player.has_method(&"begin_climbing_ladder"):
		return false
	var local_player := to_local(player.global_position)
	_approach_side = 1.0 if local_player.z >= 0.0 else -1.0
	if not player.begin_climbing_ladder(self):
		return false
	_climber = player as CharacterBody3D
	add_collision_exception_with(_climber)
	local_player.x = 0.0
	local_player.y = clampf(local_player.y, climb_min_y, climb_max_y)
	local_player.z = _approach_side * attach_distance
	_sync_climber(local_player)
	return true

func drive_from_player(input_vector: Vector2, delta: float) -> void:
	if not is_instance_valid(_climber):
		_climber = null
		return
	var climb_input := -input_vector.y
	var local_player := to_local(_climber.global_position)
	local_player.x = move_toward(local_player.x, 0.0, delta * 4.0)
	local_player.z = move_toward(local_player.z, _approach_side * attach_distance, delta * 4.0)
	local_player.y += climb_input * climb_speed * delta
	if climb_input > 0.0 and local_player.y >= climb_max_y:
		# El origen del jugador queda casi un metro por encima de sus pies.
		# Terminamos bien sobre el tejado para que la capsula completa libre el borde.
		local_player.y = climb_max_y
		local_player.z = -_approach_side * exit_distance
		_finish_climbing(local_player, Vector3.ZERO)
		return
	if climb_input < 0.0 and local_player.y <= climb_min_y:
		local_player.y = climb_min_y
		local_player.z = _approach_side * exit_distance
		_finish_climbing(local_player, Vector3.ZERO)
		return
	local_player.y = clampf(local_player.y, climb_min_y, climb_max_y)
	_sync_climber(local_player)

func stop_climbing(jump_away := false) -> void:
	if not is_instance_valid(_climber):
		_climber = null
		return
	var local_player := to_local(_climber.global_position)
	local_player.z = _approach_side * (exit_distance + (0.25 if jump_away else 0.0))
	var away := (global_basis.z.normalized() * _approach_side * 1.4 + Vector3.UP * 1.2) if jump_away else Vector3.ZERO
	_finish_climbing(local_player, away)

func _sync_climber(local_position: Vector3) -> void:
	if not is_instance_valid(_climber):
		return
	var toward_ladder := -global_basis.z.normalized() * _approach_side
	var facing_yaw := atan2(-toward_ladder.x, -toward_ladder.z)
	_climber.call(&"sync_to_ladder", to_global(local_position), facing_yaw)

func _finish_climbing(local_position: Vector3, launch_velocity: Vector3) -> void:
	var player := _climber
	_sync_climber(local_position)
	remove_collision_exception_with(player)
	_climber = null
	player.call(&"end_climbing_ladder", self, launch_velocity)
