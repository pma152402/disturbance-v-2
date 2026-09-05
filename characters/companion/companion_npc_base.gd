class_name CompanionNPCBase
extends CharacterBody3D

## Base reutilizable para acompanantes que obedecen ordenes del jugador.
## El aspecto se desacopla en `visual_scene`, de modo que se puede sustituir
## el asset sin duplicar navegacion, interaccion ni estados.

signal command_changed(command: Command)
signal destination_reached(command: Command)

enum Command {
	WAIT,
	FOLLOW,
	STAY_CLOSE,
	ADVANCE,
	GO_THERE,
}

@export_category("Identidad")
@export var display_name := "Nico"
@export var visual_scene: PackedScene
@export var initial_command: Command = Command.WAIT
@export_category("Movimiento")
@export var walk_speed := 1.45
@export var catch_up_speed := 2.35
@export var acceleration := 7.5
@export var follow_distance := 2.25
@export var close_distance := 0.95
@export var advance_distance := 5.0
@export var go_there_distance := 11.0
@export var repath_interval := 0.18
@export_category("Acompanamiento")
@export_range(0.25, 1.0, 0.05) var close_player_speed_scale := 0.62
@export var command_distance := 2.8
@export_category("Puertas")
@export var can_open_doors := true
@export var door_retry_seconds := 0.7

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual_socket: Node3D = $VisualSocket
@onready var door_ray: RayCast3D = $DoorRay
@onready var response_label: Label3D = $ResponseLabel

var current_command: Command
var _player: CharacterBody3D
var _gravity := 9.8
var _navigation_ready := false
var _target_position := Vector3.ZERO
var _repath_timer := 0.0
var _door_retry_timer := 0.0
var _response_timer := 0.0
var _movement_blend := 0.0
var _visual: Node3D


func _ready() -> void:
	add_to_group(&"companion_npc")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	current_command = initial_command
	navigation_agent.path_desired_distance = 0.3
	navigation_agent.target_desired_distance = 0.55
	navigation_agent.path_postprocessing = NavigationPathQueryParameters3D.PATH_POSTPROCESSING_EDGECENTERED
	navigation_agent.avoidance_enabled = false
	_spawn_visual()
	response_label.text = ""
	call_deferred(&"_finish_navigation_setup")


func _spawn_visual() -> void:
	if visual_scene == null:
		return
	_visual = visual_scene.instantiate() as Node3D
	if _visual != null:
		visual_socket.add_child(_visual)


func _finish_navigation_setup() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_navigation_ready = NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	_update_response(delta)
	_repath_timer = maxf(0.0, _repath_timer - delta)
	_door_retry_timer = maxf(0.0, _door_retry_timer - delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.15

	var desired_velocity := Vector3.ZERO
	if _should_move():
		desired_velocity = _calculate_desired_velocity()
	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	move_and_slide()

	var planar_speed := Vector2(velocity.x, velocity.z).length()
	_movement_blend = move_toward(_movement_blend, clampf(planar_speed / maxf(walk_speed, 0.01), 0.0, 1.35), delta * 5.0)
	if desired_velocity.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(desired_velocity.x, desired_velocity.z), minf(delta * 8.0, 1.0))
	_try_open_door()
	_update_visual(delta, _movement_blend)
	_check_arrival()


func _should_move() -> bool:
	if not is_instance_valid(_player):
		return false
	match current_command:
		Command.WAIT:
			return false
		Command.FOLLOW:
			return global_position.distance_to(_player.global_position) > follow_distance
		Command.STAY_CLOSE:
			return global_position.distance_to(_player.global_position) > close_distance
		Command.ADVANCE, Command.GO_THERE:
			return global_position.distance_to(_target_position) > navigation_agent.target_desired_distance
	return false


func _calculate_desired_velocity() -> Vector3:
	var goal := _target_position
	var speed := walk_speed
	if current_command in [Command.FOLLOW, Command.STAY_CLOSE]:
		var distance_to_player := global_position.distance_to(_player.global_position)
		var desired_distance := close_distance if current_command == Command.STAY_CLOSE else follow_distance
		var player_forward := -_player.global_basis.z
		player_forward.y = 0.0
		goal = _player.global_position - player_forward.normalized() * desired_distance
		if distance_to_player > 5.0:
			speed = catch_up_speed

	if _navigation_ready:
		if _repath_timer <= 0.0:
			navigation_agent.target_position = goal
			_repath_timer = repath_interval
		if not navigation_agent.is_navigation_finished():
			var next_position := navigation_agent.get_next_path_position()
			var direction := next_position - global_position
			direction.y = 0.0
			if direction.length_squared() > 0.0025:
				return direction.normalized() * speed

	var direct := goal - global_position
	direct.y = 0.0
	return direct.normalized() * speed if direct.length_squared() > 0.0025 else Vector3.ZERO


func _check_arrival() -> void:
	if current_command not in [Command.ADVANCE, Command.GO_THERE]:
		return
	if global_position.distance_to(_target_position) <= 0.7:
		var completed_command := current_command
		current_command = Command.WAIT
		_show_response("Ya estoy aqui.")
		command_changed.emit(current_command)
		destination_reached.emit(completed_command)


func issue_command(command: Command, world_target := Vector3.ZERO) -> void:
	current_command = command
	match command:
		Command.WAIT:
			_target_position = global_position
			_show_response("Me quedo aqui.")
		Command.FOLLOW:
			_show_response("Voy contigo.")
		Command.STAY_CLOSE:
			_show_response("No me separo.")
		Command.ADVANCE:
			_target_position = _get_advance_target()
			_show_response("Voy delante.")
		Command.GO_THERE:
			_target_position = world_target
			_show_response("Voy alli.")
	_repath_timer = 0.0
	command_changed.emit(current_command)


func _get_advance_target() -> Vector3:
	if not is_instance_valid(_player):
		return global_position
	var forward := -_player.global_basis.z
	forward.y = 0.0
	return _player.global_position + forward.normalized() * advance_distance


func get_player_speed_scale() -> float:
	if current_command != Command.STAY_CLOSE or not is_instance_valid(_player):
		return 1.0
	# La penalizacion solo se aplica cuando el nino esta realmente cerca;
	# una orden no debe frenar al jugador desde la otra punta de la casa.
	return close_player_speed_scale if global_position.distance_to(_player.global_position) < 3.2 else 1.0


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return command_distance


func get_interaction_text(_interactor: Node) -> String:
	return "F  HABLAR CON %s  [%s]" % [display_name.to_upper(), _command_label(current_command)]


func interact(interactor: Node) -> bool:
	if interactor != null and interactor.has_method(&"begin_companion_command"):
		interactor.call(&"begin_companion_command", self)
		look_at_player()
		return true
	return false


func get_command_menu_text() -> String:
	return "%s  |  1 QUIETO  2 SIGUEME  3 CERCA  4 AVANZA  5 VE ALLI  |  ESC CANCELAR" % display_name.to_upper()


func receive_menu_command(index: int, world_target := Vector3.ZERO) -> bool:
	match index:
		1: issue_command(Command.WAIT)
		2: issue_command(Command.FOLLOW)
		3: issue_command(Command.STAY_CLOSE)
		4: issue_command(Command.ADVANCE)
		5: issue_command(Command.GO_THERE, world_target)
		_: return false
	return true


func look_at_player() -> void:
	if not is_instance_valid(_player):
		return
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		rotation.y = atan2(direction.x, direction.z)


func _command_label(command: Command) -> String:
	match command:
		Command.WAIT: return "QUIETO"
		Command.FOLLOW: return "SIGUIENDO"
		Command.STAY_CLOSE: return "CERCA"
		Command.ADVANCE: return "AVANZANDO"
		Command.GO_THERE: return "YENDO ALLI"
	return ""


func _show_response(text: String) -> void:
	response_label.text = text
	response_label.modulate.a = 1.0
	_response_timer = 2.2


func _update_response(delta: float) -> void:
	if _response_timer <= 0.0:
		response_label.text = ""
		return
	_response_timer = maxf(0.0, _response_timer - delta)
	if _response_timer < 0.35:
		response_label.modulate.a = _response_timer / 0.35


func _update_visual(delta: float, movement: float) -> void:
	if _visual != null and _visual.has_method(&"update_companion_animation"):
		_visual.call(&"update_companion_animation", delta, movement, current_command == Command.WAIT)


func _try_open_door() -> void:
	if not can_open_doors or _door_retry_timer > 0.0 or Vector2(velocity.x, velocity.z).length() < 0.2:
		return
	door_ray.force_raycast_update()
	if not door_ray.is_colliding():
		return
	var target := door_ray.get_collider() as Node
	if target != null and target.has_method(&"ensure_open_for_npc"):
		target.call(&"ensure_open_for_npc", self)
		_door_retry_timer = door_retry_seconds
	elif target != null and target.has_method(&"interact"):
		target.call(&"interact", self)
		_door_retry_timer = door_retry_seconds
