class_name CompanionNPCBase
extends CharacterBody3D

## Base reutilizable para acompanantes que obedecen ordenes del jugador.
## El aspecto se desacopla en `visual_scene`, de modo que se puede sustituir
## el asset sin duplicar navegacion, interaccion ni estados.

signal command_changed(command: Command)
signal destination_reached(command: Command)
signal caught_by_monster(attacker: Node3D)
signal killed_by_monster(attacker: Node3D)

enum Command {
	WAIT,
	FOLLOW,
	STAY_CLOSE,
	ADVANCE,
	GO_THERE,
}

enum Posture {
	STANDING,
	CROUCHED,
	PRONE,
}

@export_category("Identidad")
@export var display_name := "Nico"
@export var visual_scene: PackedScene
@export var initial_command: Command = Command.WAIT
@export_range(0.6, 1.25, 0.01) var actor_scale := 1.0
@export_category("Movimiento")
@export var walk_speed := 1.15
@export var catch_up_speed := 1.8
@export var acceleration := 2.6
@export var deceleration := 3.8
@export_range(2.0, 20.0, 0.5) var steering_smoothing := 5.0
@export var arrival_slow_radius := 0.9
@export var follow_distance := 2.25
@export var close_distance := 0.95
@export var advance_distance := 5.0
@export var go_there_distance := 11.0
@export var repath_interval := 0.28
@export var target_repath_distance := 0.4
@export_range(0.05, 0.5, 0.01) var navigation_height_probe_interval := 0.18
@export var follow_start_margin := 0.5
@export var follow_stop_margin := 0.18
@export var destination_stop_radius := 0.58
@export var require_navigation := true
@export_category("Posturas")
@export var imitate_player_posture := true
@export_range(0.3, 1.0, 0.05) var crouch_speed_scale := 0.72
@export_range(0.2, 0.8, 0.05) var prone_speed_scale := 0.42
@export var crouch_capsule_height := 0.86
@export var prone_capsule_height := 0.52
@export var posture_transition_speed := 2.4
@export_category("Amenazas")
@export var is_child_target := true
@export_category("Acompanamiento")
@export_range(0.25, 1.0, 0.05) var close_player_speed_scale := 0.62
@export var command_distance := 2.8
@export_category("Puertas")
@export var can_open_doors := true
@export var door_retry_seconds := 0.7
@export var door_approach_distance := 0.38
@export var door_cross_distance := 0.9
@export var door_cross_speed := 1.15
@export var door_cross_timeout := 4.0
@export var door_blocked_timeout := 2.5
@export var attention_turn_speed := 2.8
@export_range(0.05, 0.5, 0.01) var door_scan_interval := 0.12

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual_socket: Node3D = $VisualSocket
@onready var door_ray: RayCast3D = $DoorRay
@onready var response_label: Label3D = $ResponseLabel

var current_command: Command
var _player: CharacterBody3D
var _gravity := 9.8
var _navigation_ready := false
var _navigation_probe_timer := 0.0
var _navigation_iteration := 0
var _navigation_height_probe_timer := 0.0
var _target_position := Vector3.ZERO
var _current_goal := Vector3.ZERO
var _raw_goal_cache := Vector3(100000.0, 100000.0, 100000.0)
var _reachable_goal_cache := Vector3.ZERO
var _goal_resolve_timer := 0.0
var _last_navigation_target := Vector3(100000.0, 100000.0, 100000.0)
var _repath_timer := 0.0
var _door_retry_timer := 0.0
var _door_scan_timer := 0.0
var _response_timer := 0.0
var _movement_blend := 0.0
var _movement_active := false
var _smoothed_direction := Vector3.ZERO
var _progress_origin := Vector3.ZERO
var _progress_timer := 0.0
var _stuck_cycles := 0
var _recovery_timer := 0.0
var _recovery_side := 1.0
var _door_traversal_active := false
var _door_traversal_phase := 0
var _door_traversal_door: Node
var _door_portal_center := Vector3.ZERO
var _door_cross_direction := Vector3.ZERO
var _door_entry_point := Vector3.ZERO
var _door_exit_point := Vector3.ZERO
var _door_open_wait_timer := 0.0
var _door_traversal_timer := 0.0
var _last_crossed_door_id := 0
var _door_reentry_timer := 0.0
var _visual: Node3D
var _posture := Posture.STANDING
var _posture_target := Posture.STANDING
var _posture_blend := 0.0
var _standing_capsule_height := 1.28
var _standing_door_ray_y := 0.72
var _captured_by_monster := false
var _door_blocked_timer := 0.0
var _attention_timer := 0.0
var _actual_speed := 0.0
var _turn_rate := 0.0


func _ready() -> void:
	add_to_group(&"companion_npc")
	if is_child_target:
		add_to_group(&"child_target")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	current_command = initial_command
	navigation_agent.path_desired_distance = 0.3
	navigation_agent.target_desired_distance = destination_stop_radius
	# Igual que en el mecanismo del video: el agente sigue el siguiente punto de
	# una ruta NavMesh limpia. El funnel elimina los zigzags y bucles que puede
	# introducir EDGE_CENTERED en pasillos y marcos de puerta estrechos.
	navigation_agent.path_postprocessing = NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	navigation_agent.avoidance_enabled = false
	door_ray.enabled = false
	_apply_actor_scale()
	_prepare_posture_collision()
	_spawn_visual()
	response_label.text = ""
	_progress_origin = global_position
	call_deferred(&"_finish_navigation_setup")


func _apply_actor_scale() -> void:
	var uniform_scale := Vector3.ONE * actor_scale
	visual_socket.scale = uniform_scale
	$Collision.scale = uniform_scale
	$Collision.position.y *= actor_scale
	navigation_agent.height *= actor_scale
	navigation_agent.radius *= actor_scale
	door_ray.position.y *= actor_scale
	response_label.position.y *= actor_scale


func _prepare_posture_collision() -> void:
	var collision := $Collision as CollisionShape3D
	if collision.shape != null:
		collision.shape = collision.shape.duplicate()
	var capsule := collision.shape as CapsuleShape3D
	if capsule != null:
		_standing_capsule_height = capsule.height
	_standing_door_ray_y = door_ray.position.y


func _spawn_visual() -> void:
	if visual_scene == null:
		return
	_visual = visual_scene.instantiate() as Node3D
	if _visual != null:
		visual_socket.add_child(_visual)


func _finish_navigation_setup() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_try_enable_navigation()


func _try_enable_navigation() -> void:
	var navigation_map := get_world_3d().navigation_map
	var map_iteration := NavigationServer3D.map_get_iteration_id(navigation_map)
	if map_iteration <= 0 or NavigationServer3D.map_get_regions(navigation_map).is_empty():
		_navigation_ready = false
		return
	var map_was_rebaked := map_iteration != _navigation_iteration
	_navigation_ready = true
	_navigation_iteration = map_iteration
	navigation_agent.set_navigation_map(navigation_map)
	if map_was_rebaked:
		# La casa construye regiones provisionales antes del bake definitivo.
		# Cada revision invalida cualquier ruta corta o inalcanzable anterior.
		_last_navigation_target = Vector3(100000.0, 100000.0, 100000.0)
		_raw_goal_cache = Vector3(100000.0, 100000.0, 100000.0)
		_goal_resolve_timer = 0.0
		_repath_timer = 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	_update_response(delta)
	if _captured_by_monster:
		# La cápsula se desactiva al morir: seguir aplicando gravedad haría
		# atravesar el suelo al cuerpo durante la animación de alimentación.
		velocity = Vector3.ZERO
		_actual_speed = 0.0
		_turn_rate = 0.0
		_update_visual(delta, 0.0)
		return
	_repath_timer = maxf(0.0, _repath_timer - delta)
	_goal_resolve_timer = maxf(0.0, _goal_resolve_timer - delta)
	_door_retry_timer = maxf(0.0, _door_retry_timer - delta)
	_door_scan_timer = maxf(0.0, _door_scan_timer - delta)
	_door_reentry_timer = maxf(0.0, _door_reentry_timer - delta)
	_navigation_probe_timer -= delta
	if _navigation_probe_timer <= 0.0:
		_navigation_probe_timer = 0.25
		_try_enable_navigation()
	_navigation_height_probe_timer = maxf(0.0, _navigation_height_probe_timer - delta)
	if _navigation_height_probe_timer <= 0.0:
		_navigation_height_probe_timer = navigation_height_probe_interval
		_update_navigation_height_offset()
	_update_posture(delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.15

	var desired_velocity := Vector3.ZERO
	_attention_timer = maxf(0.0, _attention_timer - delta)
	if _door_traversal_active:
		desired_velocity = _calculate_door_traversal_velocity(delta)
	else:
		_current_goal = _resolve_goal()
		_update_movement_state(_current_goal)
		if _movement_active:
			desired_velocity = _calculate_desired_velocity(_current_goal, delta)
	var velocity_change := acceleration if desired_velocity.length_squared() > 0.001 else deceleration
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, velocity_change * delta)
	if desired_velocity.is_zero_approx() and horizontal_velocity.length() < 0.025:
		horizontal_velocity = Vector3.ZERO
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	var previous_position := global_position
	var previous_yaw := rotation.y
	move_and_slide()
	if not _door_traversal_active:
		_update_stuck_recovery(delta, desired_velocity)

	var planar_speed := _planar_distance(previous_position, global_position) / maxf(delta, 0.001)
	_actual_speed = planar_speed
	var target_movement_blend := clampf(planar_speed / maxf(walk_speed, 0.01), 0.0, 1.15)
	var blend_response := 3.2 if target_movement_blend > _movement_blend else 4.6
	_movement_blend = lerpf(_movement_blend, target_movement_blend, 1.0 - exp(-blend_response * delta))
	if planar_speed > 0.08:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), 1.0 - exp(-4.2 * delta))
	elif _attention_timer > 0.0 and is_instance_valid(_player) and not _captured_by_monster:
		var attention := _player.global_position - global_position
		if Vector2(attention.x, attention.z).length_squared() > 0.04:
			rotation.y = rotate_toward(rotation.y, atan2(attention.x, attention.z), attention_turn_speed * delta)
	_turn_rate = wrapf(rotation.y - previous_yaw, -PI, PI) / maxf(delta, 0.001)
	_try_open_door()
	_update_visual(delta, _movement_blend)
	_check_arrival()


func _resolve_goal() -> Vector3:
	if current_command == Command.WAIT:
		return global_position
	var raw_goal := _target_position
	if current_command in [Command.FOLLOW, Command.STAY_CLOSE] and is_instance_valid(_player):
		# Seguir a una persona no significa perseguir un punto exacto detras de
		# su espalda. El objetivo es su posicion y la banda de distancia decide
		# cuando parar; girar la camara ya no obliga al nino a dar vueltas.
		raw_goal = _get_player_ground_position()
	if not _navigation_ready:
		return raw_goal
	if (
		_goal_resolve_timer > 0.0
		and _raw_goal_cache.distance_squared_to(raw_goal) <= target_repath_distance * target_repath_distance
	):
		return _reachable_goal_cache
	_raw_goal_cache = raw_goal
	_goal_resolve_timer = repath_interval
	_reachable_goal_cache = _select_reachable_goal(raw_goal)
	return _reachable_goal_cache


func _update_navigation_height_offset() -> void:
	if not _navigation_ready or not is_on_floor():
		return
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid():
		return
	var nav_surface := NavigationServer3D.map_get_closest_point(navigation_map, global_position)
	# RuntimeHouseNavigation hornea sus poligonos en el centro de la celda
	# vertical. Restar esta diferencia hace que el primer waypoint coincida con
	# los pies fisicos y permite que NavigationAgent avance al siguiente punto.
	navigation_agent.path_height_offset = nav_surface.y - global_position.y


func _select_reachable_goal(raw_goal: Vector3) -> Vector3:
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid():
		return raw_goal
	var projected_goal := NavigationServer3D.map_get_closest_point(navigation_map, raw_goal)
	if current_command in [Command.FOLLOW, Command.STAY_CLOSE] and is_instance_valid(_player):
		# Primero intentamos el hueco ideal. Si cae tras una pared, priorizamos
		# la isla del propio jugador; nunca aceptamos un punto intermedio que se
		# haya proyectado al lado equivocado del muro.
		var ideal_path := NavigationServer3D.map_get_path(
			navigation_map, global_position, projected_goal, true
		)
		var ideal_projection_error := _planar_distance(projected_goal, raw_goal)
		if ideal_projection_error <= 0.7 and _path_reaches(ideal_path, projected_goal):
			return projected_goal
		# raw_goal ya es la posición del jugador: reutilizar la consulta.
		var player_goal := projected_goal
		var player_path := ideal_path
		if _path_reaches(player_path, player_goal):
			return player_goal
		# Una ruta parcial aun sirve para aproximarse a la puerta o al limite
		# accesible, donde el sensor de puertas puede continuar el recorrido.
		return player_path[-1] if not player_path.is_empty() else global_position
	var destination_path := NavigationServer3D.map_get_path(
		navigation_map, global_position, projected_goal, true
	)
	if _path_reaches(destination_path, projected_goal):
		return projected_goal
	# AVANZA/VE ALLI terminan en el ultimo punto realmente accesible.
	return destination_path[-1] if not destination_path.is_empty() else global_position


func _path_reaches(path: PackedVector3Array, goal: Vector3) -> bool:
	if path.size() < 2:
		return _planar_distance(global_position, goal) <= destination_stop_radius
	return _planar_distance(path[-1], goal) <= destination_stop_radius + 0.12


func _update_movement_state(goal: Vector3) -> void:
	if current_command == Command.WAIT or not is_instance_valid(_player):
		_movement_active = false
		_smoothed_direction = Vector3.ZERO
		return
	var distance_to_goal := _planar_distance(global_position, goal)
	if current_command in [Command.FOLLOW, Command.STAY_CLOSE]:
		var desired_distance := close_distance if current_command == Command.STAY_CLOSE else follow_distance
		var start_distance := desired_distance + follow_start_margin
		var stop_distance := maxf(0.35, desired_distance - follow_stop_margin)
		var player_distance := _planar_distance(global_position, _player.global_position)
		# La zona muerta entre ambos radios evita microcorrecciones. Mientras el
		# jugador permanezca dentro de ella, Nico conserva quietud completa.
		if _movement_active:
			_movement_active = player_distance > stop_distance
		else:
			_movement_active = player_distance > start_distance
	else:
		_movement_active = distance_to_goal > destination_stop_radius
	if not _movement_active:
		_smoothed_direction = Vector3.ZERO


func _calculate_desired_velocity(goal: Vector3, delta: float) -> Vector3:
	var speed := walk_speed
	if current_command in [Command.FOLLOW, Command.STAY_CLOSE] and is_instance_valid(_player):
		var distance_to_player := _planar_distance(global_position, _player.global_position)
		var desired_distance := close_distance if current_command == Command.STAY_CLOSE else follow_distance
		var stop_distance := maxf(0.35, desired_distance - follow_stop_margin)
		var arrival_ratio := clampf((distance_to_player - stop_distance) / arrival_slow_radius, 0.0, 1.0)
		var eased_arrival := arrival_ratio * arrival_ratio * (3.0 - 2.0 * arrival_ratio)
		speed *= lerpf(0.34, 1.0, eased_arrival)
		speed = lerpf(speed, catch_up_speed, smoothstep(4.0, 7.0, distance_to_player))
	else:
		var goal_distance := _planar_distance(global_position, goal)
		var arrival_ratio := clampf((goal_distance - destination_stop_radius) / 1.2, 0.0, 1.0)
		var eased_arrival := arrival_ratio * arrival_ratio * (3.0 - 2.0 * arrival_ratio)
		speed *= lerpf(0.3, 1.0, eased_arrival)

	speed *= _get_posture_speed_multiplier()
	var raw_direction := Vector3.ZERO
	if _navigation_ready:
		if _repath_timer <= 0.0 and (
			_last_navigation_target.distance_squared_to(goal) > target_repath_distance * target_repath_distance
			or navigation_agent.is_navigation_finished()
			or not navigation_agent.is_target_reachable()
		):
			navigation_agent.target_position = goal
			_last_navigation_target = goal
			_repath_timer = repath_interval
		if not navigation_agent.is_navigation_finished():
			var next_position := navigation_agent.get_next_path_position()
			raw_direction = next_position - global_position
	elif not require_navigation:
		raw_direction = goal - global_position
	raw_direction.y = 0.0
	if raw_direction.length_squared() < 0.0064:
		return Vector3.ZERO
	raw_direction = raw_direction.normalized()
	if _recovery_timer > 0.0:
		var lateral := Vector3(raw_direction.z, 0.0, -raw_direction.x) * _recovery_side
		raw_direction = (raw_direction + lateral * 0.55).normalized()
	var steering_weight := 1.0 - exp(-steering_smoothing * delta)
	# Un giro de 180 grados necesita una rotación, no interpolar dos vectores
	# opuestos (que conserva la dirección antigua o pasa por cero).
	if _smoothed_direction.length_squared() < 0.01:
		_smoothed_direction = raw_direction
	else:
		var heading := lerp_angle(atan2(_smoothed_direction.x, _smoothed_direction.z), atan2(raw_direction.x, raw_direction.z), steering_weight)
		_smoothed_direction = Vector3(sin(heading), 0.0, cos(heading))
	var facing_alignment := global_basis.z.dot(raw_direction)
	speed *= lerpf(0.28, 1.0, smoothstep(-0.4, 0.85, facing_alignment))
	return _smoothed_direction * speed


func _update_stuck_recovery(delta: float, desired_velocity: Vector3) -> void:
	_recovery_timer = maxf(0.0, _recovery_timer - delta)
	if desired_velocity.length_squared() < 0.04:
		_progress_timer = 0.0
		_progress_origin = global_position
		_stuck_cycles = 0
		return
	_progress_timer += delta
	if _progress_timer < 0.65:
		return
	var progress := _planar_distance(_progress_origin, global_position)
	if progress < 0.055:
		_stuck_cycles += 1
		_repath_timer = 0.0
		_last_navigation_target = Vector3(100000.0, 100000.0, 100000.0)
		if _stuck_cycles >= 2:
			_recovery_side *= -1.0
			_recovery_timer = 0.5
	else:
		_stuck_cycles = 0
	_progress_origin = global_position
	_progress_timer = 0.0


func _planar_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))


func _get_player_ground_position() -> Vector3:
	if not is_instance_valid(_player):
		return global_position
	var player_collision := _player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if player_collision == null or player_collision.shape == null:
		return _player.global_position
	var half_height := 0.0
	if player_collision.shape is CapsuleShape3D:
		half_height = (player_collision.shape as CapsuleShape3D).height * 0.5
	elif player_collision.shape is CylinderShape3D:
		half_height = (player_collision.shape as CylinderShape3D).height * 0.5
	elif player_collision.shape is BoxShape3D:
		half_height = (player_collision.shape as BoxShape3D).size.y * 0.5
	else:
		return _player.global_position
	var local_foot_y := player_collision.position.y - half_height
	return _player.global_position + _player.global_basis.y.normalized() * local_foot_y


func _update_posture(delta: float) -> void:
	var requested: Posture = Posture.STANDING
	if not _captured_by_monster and imitate_player_posture and is_instance_valid(_player):
		if _player.has_method(&"get_companion_stance"):
			requested = clampi(int(_player.call(&"get_companion_stance")), Posture.STANDING, Posture.PRONE) as Posture
		elif _player.has_method(&"is_crouched") and bool(_player.call(&"is_crouched")):
			requested = Posture.CROUCHED
	if requested != _posture_target:
		# Encogerse siempre es seguro. Para crecer comprobamos el espacio que
		# ocupa Nico, que puede ser distinto del espacio sobre el jugador.
		if requested >= _posture_target or _posture_fits(requested):
			_posture_target = requested
			if _visual != null and _visual.has_method(&"set_companion_posture"):
				_visual.call(&"set_companion_posture", requested)
	var previous_blend := _posture_blend
	_posture_blend = move_toward(_posture_blend, float(_posture_target), posture_transition_speed * delta)
	if not is_equal_approx(previous_blend, _posture_blend):
		_apply_posture_collision()
	if is_equal_approx(_posture_blend, float(_posture_target)):
		_posture = _posture_target


func _posture_fits(target: Posture) -> bool:
	var collision := $Collision as CollisionShape3D
	var current_capsule := collision.shape as CapsuleShape3D
	if current_capsule == null:
		return true
	var test_capsule := CapsuleShape3D.new()
	# La forma real esta escalada por actor_scale; las consultas fisicas no
	# heredan la escala del nodo y necesitan dimensiones ya convertidas.
	test_capsule.radius = current_capsule.radius * actor_scale
	test_capsule.height = _get_posture_capsule_height(float(target)) * actor_scale
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = test_capsule
	var target_y := test_capsule.height * 0.5
	query.transform = Transform3D(global_basis, global_position + Vector3.UP * (target_y + 0.045))
	query.margin = 0.001
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _apply_posture_collision() -> void:
	var capsule := ($Collision as CollisionShape3D).shape as CapsuleShape3D
	if capsule == null:
		return
	var posture_height := _get_posture_capsule_height(_posture_blend)
	capsule.height = posture_height
	var effective_height := posture_height * actor_scale
	$Collision.position.y = effective_height * 0.5
	navigation_agent.height = effective_height
	door_ray.position.y = minf(_standing_door_ray_y, effective_height * 0.62)
	response_label.position.y = effective_height + 0.42 * actor_scale


func _get_posture_capsule_height(blend: float) -> float:
	if blend <= 1.0:
		return lerpf(_standing_capsule_height, crouch_capsule_height, blend)
	return lerpf(crouch_capsule_height, prone_capsule_height, blend - 1.0)


func _get_posture_speed_multiplier() -> float:
	if _posture_blend <= 1.0:
		return lerpf(1.0, crouch_speed_scale, _posture_blend)
	return lerpf(crouch_speed_scale, prone_speed_scale, _posture_blend - 1.0)


func _check_arrival() -> void:
	if _door_traversal_active:
		return
	if current_command not in [Command.ADVANCE, Command.GO_THERE]:
		return
	if _planar_distance(global_position, _current_goal) <= destination_stop_radius:
		var completed_command := current_command
		var requested_point_was_blocked := _planar_distance(_target_position, _current_goal) > 1.0
		current_command = Command.WAIT
		_show_response("No puedo llegar hasta alli." if requested_point_was_blocked else "Ya estoy aqui.")
		command_changed.emit(current_command)
		destination_reached.emit(completed_command)


func issue_command(command: Command, world_target := Vector3.ZERO) -> void:
	if _captured_by_monster:
		return
	if _door_traversal_active:
		_end_door_traversal(false)
	_attention_timer = 0.9
	current_command = command
	_movement_active = false
	_smoothed_direction = Vector3.ZERO
	_last_navigation_target = Vector3(100000.0, 100000.0, 100000.0)
	_raw_goal_cache = Vector3(100000.0, 100000.0, 100000.0)
	_goal_resolve_timer = 0.0
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


func can_be_targeted_by_monster() -> bool:
	return is_child_target and not _captured_by_monster and is_inside_tree() and visible


func is_dead() -> bool:
	return _captured_by_monster


func receive_monster_attack(attacker: Node3D) -> void:
	if _captured_by_monster:
		return
	_captured_by_monster = true
	if _door_traversal_active:
		_end_door_traversal(false)
	current_command = Command.WAIT
	_target_position = global_position
	_movement_active = false
	_smoothed_direction = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	($Collision as CollisionShape3D).set_deferred("disabled", true)
	if _visual != null and _visual.has_method(&"set_companion_dead"):
		_visual.call(&"set_companion_dead", true)
	_show_response("")
	command_changed.emit(current_command)
	caught_by_monster.emit(attacker)
	killed_by_monster.emit(attacker)


func release_after_monster_capture(world_position := Vector3.INF) -> void:
	_captured_by_monster = false
	($Collision as CollisionShape3D).set_deferred("disabled", false)
	if _visual != null and _visual.has_method(&"set_companion_dead"):
		_visual.call(&"set_companion_dead", false)
	if world_position.is_finite():
		global_position = world_position
	issue_command(Command.WAIT)


func _get_advance_target() -> Vector3:
	if not is_instance_valid(_player):
		return global_position
	var forward := -_player.global_basis.z
	forward.y = 0.0
	return _get_player_ground_position() + forward.normalized() * advance_distance


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
	if _captured_by_monster:
		return "%s HA MUERTO" % display_name.to_upper()
	return "F  HABLAR CON %s  [%s]" % [display_name.to_upper(), _command_label(current_command)]


func interact(interactor: Node) -> bool:
	if _captured_by_monster:
		return false
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
	_attention_timer = 2.0


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
	if is_instance_valid(_visual) and _visual.has_method(&"set_motion_context"):
		var gaze := global_position + global_basis.z * 2.0 + Vector3.UP * 1.4
		if _door_traversal_active:
			gaze = _door_exit_point + Vector3.UP * 1.1
		elif is_instance_valid(_player) and (_actual_speed < 0.15 or _attention_timer > 0.0):
			gaze = _player.global_position + Vector3.UP * 1.1
		_visual.call(&"set_motion_context", _actual_speed / maxf(actor_scale, 0.01), _turn_rate, gaze, _door_traversal_active)
	if _visual != null and _visual.has_method(&"update_companion_animation"):
		_visual.call(&"update_companion_animation", delta, movement, current_command == Command.WAIT)


func _try_open_door() -> void:
	if current_command == Command.WAIT or _captured_by_monster or _door_traversal_active or not can_open_doors or _door_retry_timer > 0.0 or _door_scan_timer > 0.0:
		return
	_door_scan_timer = door_scan_interval
	# Una puerta abierta deja de estar delante del rayo al girar su hoja. Se
	# detecta primero el portal fijo y solo se usan rayos como respaldo para una
	# puerta cerrada. Asi el NPC puede seguir la misma ruta NavMesh del jugador.
	var target := _find_nearby_door_portal()
	if target == null and Vector2(velocity.x, velocity.z).length() >= 0.12:
		door_ray.force_raycast_update()
		target = _find_npc_door(door_ray.get_collider() as Node) if door_ray.is_colliding() else null
		if target == null:
			target = _find_door_with_side_rays()
	if target != null and _door_reentry_timer > 0.0 and target.get_instance_id() == _last_crossed_door_id:
		return
	if target != null and target.has_method(&"ensure_open_for_npc"):
		target.call(&"ensure_open_for_npc", self)
		_door_retry_timer = door_retry_seconds
		if target.get("_is_open") == true:
			_begin_door_traversal(target)
	elif target != null and target.has_method(&"interact"):
		target.call(&"interact", self)
		_door_retry_timer = door_retry_seconds


func _find_nearby_door_portal() -> Node:
	if current_command == Command.WAIT:
		return null
	var requested_goal := _target_position
	if current_command in [Command.FOLLOW, Command.STAY_CLOSE] and is_instance_valid(_player):
		requested_goal = _get_player_ground_position()
	var closest_door: Node
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group(&"npc_door"):
		var door := candidate as Node
		if not is_instance_valid(door) or not door.has_method(&"get_npc_traversal_portal"):
			continue
		if _door_reentry_timer > 0.0 and door.get_instance_id() == _last_crossed_door_id:
			continue
		var portal := door.call(&"get_npc_traversal_portal") as Dictionary
		var center: Vector3 = portal.get("center", (door as Node3D).global_position)
		var normal: Vector3 = portal.get("normal", (door as Node3D).global_basis.z)
		normal.y = 0.0
		if normal.length_squared() < 0.01:
			continue
		normal = normal.normalized()
		var offset := global_position - center
		if absf(offset.y) > 1.0:
			continue
		offset.y = 0.0
		var distance := offset.length()
		if distance > 1.45:
			continue
		# Solo usamos el portal si la orden actual termina al otro lado de su
		# plano. Evita abrir puertas cercanas que no forman parte del recorrido.
		var actor_side := offset.dot(normal)
		var goal_side := (requested_goal - center).dot(normal)
		var lateral_offset := (offset - normal * actor_side).length()
		if lateral_offset > 1.15 or actor_side * goal_side >= -0.035:
			continue
		# No elegir un portal vecino a través de una pared.
		var entry := center + normal * signf(actor_side) * maxf(door_approach_distance, 0.55)
		entry.y = global_position.y
		if test_move(global_transform, entry - global_position):
			continue
		if distance < closest_distance:
			closest_distance = distance
			closest_door = door
	return closest_door


func _find_door_with_side_rays() -> Node:
	var ray_origin := door_ray.global_position
	var ray_end := door_ray.to_global(door_ray.target_position)
	for side_offset: float in [-0.2, 0.2]:
		var offset := global_basis.x.normalized() * side_offset
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin + offset, ray_end + offset, door_ray.collision_mask
		)
		query.exclude = [get_rid()]
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			var door := _find_npc_door(result.collider as Node)
			if door != null:
				return door
	return null


func _find_npc_door(node: Node) -> Node:
	var candidate := node
	for _level in range(5):
		if candidate == null:
			return null
		if candidate.has_method(&"ensure_open_for_npc"):
			return candidate
		candidate = candidate.get_parent()
	return null


func _begin_door_traversal(door: Node) -> void:
	if _door_traversal_active or not is_instance_valid(door):
		return
	var portal_data: Dictionary = {}
	if door.has_method(&"get_npc_traversal_portal"):
		portal_data = door.call(&"get_npc_traversal_portal") as Dictionary
	var portal_center := (door as Node3D).global_position
	var portal_normal := (door as Node3D).global_basis.z
	if portal_data.has("center"):
		portal_center = portal_data["center"] as Vector3
	if portal_data.has("normal"):
		portal_normal = portal_data["normal"] as Vector3
	portal_normal.y = 0.0
	if portal_normal.length_squared() < 0.01:
		return
	portal_normal = portal_normal.normalized()
	var side := signf((global_position - portal_center).dot(portal_normal))
	if is_zero_approx(side):
		side = 1.0
	_door_portal_center = portal_center
	# Se fija una direccion de cruce al comenzar. No se recalcula dentro del
	# umbral, donde el signo cambia y antes podia hacer que el NPC se diese la vuelta.
	_door_cross_direction = -portal_normal * side
	_door_entry_point = portal_center - _door_cross_direction * maxf(door_approach_distance, 0.55)
	_door_exit_point = portal_center + _door_cross_direction * door_cross_distance
	_door_traversal_door = door
	_door_traversal_active = true
	# Si el sensor ya esta dentro del umbral, no le hacemos retroceder para
	# tocar un punto de entrada que ha dejado atras.
	var entry_progress := (global_position - _door_entry_point).dot(_door_cross_direction)
	_door_traversal_phase = 1 if entry_progress >= 0.0 else 0
	_door_traversal_timer = maxf(door_cross_timeout, 3.0 / maxf(door_cross_speed * _get_posture_speed_multiplier(), 0.1))
	_door_blocked_timer = 0.0
	var door_transition := float(door.get("transition_time")) if door.get("transition_time") != null else 0.4
	_door_open_wait_timer = maxf(maxf(0.32, door_transition * 0.7), float(portal_data.get("open_wait", 0.0)))
	_smoothed_direction = Vector3.ZERO


func _calculate_door_traversal_velocity(delta: float) -> Vector3:
	_door_traversal_timer -= delta
	if _door_traversal_timer <= 0.0 or not is_instance_valid(_door_traversal_door):
		_end_door_traversal(false)
		return Vector3.ZERO
	_door_open_wait_timer = maxf(0.0, _door_open_wait_timer - delta)
	var passage_ready := _door_open_wait_timer <= 0.0
	if _door_traversal_door.has_method(&"is_npc_passage_ready"):
		passage_ready = bool(_door_traversal_door.call(&"is_npc_passage_ready"))
	var target := _door_entry_point if _door_traversal_phase == 0 else _door_exit_point
	if _door_traversal_phase == 0 and _planar_distance(global_position, target) <= 0.18:
		_door_traversal_phase = 1
	if _door_traversal_phase == 1:
		if not passage_ready:
			return Vector3.ZERO
		_door_traversal_phase = 2
	if _door_traversal_phase == 2:
		target = _door_exit_point
		var cross_progress := (global_position - _door_portal_center).dot(_door_cross_direction)
		if cross_progress >= door_cross_distance * 0.72:
			_end_door_traversal(true)
			_current_goal = _resolve_goal()
			_update_movement_state(_current_goal)
			return _calculate_desired_velocity(_current_goal, delta) if _movement_active else Vector3.ZERO
		if not passage_ready:
			if _door_retry_timer <= 0.0:
				_door_traversal_door.call(&"ensure_open_for_npc", self)
				_door_retry_timer = door_retry_seconds
			return Vector3.ZERO
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.04:
		if _door_traversal_phase == 0:
			_door_traversal_phase = 1
		else:
			_end_door_traversal(true)
		return Vector3.ZERO
	# Barrido de la cápsula real: esperar a la hoja o a otro actor, sin
	# empujar continuamente ni activar recuperaciones laterales en el marco.
	var probe_distance := minf(direction.length(), 0.3)
	if test_move(global_transform, direction.normalized() * probe_distance):
		_door_blocked_timer += delta
		if _door_blocked_timer >= door_blocked_timeout:
			_show_response("No puedo pasar. ¿Me dejas sitio?")
			_end_door_traversal(false)
		return Vector3.ZERO
	_door_blocked_timer = 0.0
	var speed := door_cross_speed * _get_posture_speed_multiplier()
	if _door_traversal_phase == 0 and not passage_ready:
		speed = minf(speed, sqrt(2.0 * deceleration * maxf(direction.length() - 0.12, 0.0)))
	return direction.normalized() * speed


func _end_door_traversal(completed: bool) -> void:
	if is_instance_valid(_door_traversal_door):
		_last_crossed_door_id = _door_traversal_door.get_instance_id()
	_door_reentry_timer = 1.6 if completed else 1.0
	_door_traversal_active = false
	_door_traversal_phase = 0
	_door_traversal_door = null
	_door_cross_direction = Vector3.ZERO
	_last_navigation_target = Vector3(100000.0, 100000.0, 100000.0)
	_raw_goal_cache = Vector3(100000.0, 100000.0, 100000.0)
	_repath_timer = 0.0
	_goal_resolve_timer = 0.0
