extends CharacterBody3D

const PassageProbe := preload("res://systems/npc_passage_probe.gd")

signal state_changed(previous_state: State, new_state: State)
signal prey_changed(previous_prey: Node3D, new_prey: Node3D)
signal child_caught(child: Node3D)
signal finished_eating_child(child: Node3D)

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, ATTACK, EAT }
enum StairCommitment { NONE, ASCENDING, DESCENDING }

const STAIR_LOWER_ANCHOR := Vector3(-1.328, 0.12, 3.0)
const STAIR_UPPER_ANCHOR := Vector3(-1.328, 4.18, -2.18)
@export var patrol_speed := 0.88
@export var investigate_speed := 1.28
@export var chase_speed := 2.75
@export var vision_distance := 15.0
@export_range(10.0, 160.0, 1.0) var vision_angle_degrees := 78.0
@export var hearing_distance := 7.5
@export_group("Espera inicial")
@export var starts_waiting_covered_eyes := true
@export_range(1.5, 8.0, 0.1) var wake_distance := 3.6
@export var chase_memory_seconds := 12.0
@export var search_seconds := 8.0
@export var attack_distance := 1.05
@export var attack_cooldown := 1.65
@export var attack_windup_seconds := 0.24
@export var attack_hit_seconds := 0.43
@export var attack_animation_seconds := 0.98
@export var attack_vertical_tolerance := 1.35
@export var target_refresh_seconds := 0.16
@export_group("Objetivos inalcanzables")
# Cuando la presa se sube a un muro, a una repisa o a cualquier sitio que el
# navmesh no cubre, la ruta termina en el punto transitable más cercano. Sin
# estos controles la abuela se quedaba parada ahí para siempre.
@export var unreachable_tolerance := 1.1
@export_range(1.0, 30.0, 0.5) var stalk_seconds := 5.0
@export_range(1.0, 20.0, 0.5) var floor_change_grace_seconds := 6.0
# Un muro no la detiene: se planta debajo y sacude hacia arriba. El empujón sale
# del mismo `receive_monster_attack` que el resto de golpes, así que también te
# tira del saliente.
@export_range(1.0, 5.0, 0.1) var ledge_reach_height := 3.2
@export_range(0.5, 3.0, 0.1) var ledge_reach_radius := 1.5
@export_group("Suavizado de movimiento")
@export_range(2.0, 20.0, 0.1) var acceleration := 6.2
@export_range(2.0, 30.0, 0.1) var braking := 10.5
@export_range(60.0, 720.0, 5.0) var max_turn_speed_degrees := 235.0
@export_range(1.0, 20.0, 0.5) var heading_smoothing := 5.0
@export_range(0.3, 1.6, 0.02) var stride_length := 0.72
@export_group("Navegación y recuperación")
@export var obstacle_probe_distance := 0.85
@export var stuck_check_seconds := 0.65
@export var stuck_minimum_progress := 0.12
@export var recovery_duration := 0.7
@export var chase_prediction_seconds := 0.22
@export var chase_slowdown_distance := 2.1
@export var chase_stop_distance := 0.68
@export_group("Prioridad de presas")
@export var prioritize_children := true
@export_range(0.05, 1.0, 0.05) var prey_refresh_seconds := 0.2
@export_range(1.0, 60.0, 0.5) var child_eating_seconds := 20.0
@export_range(0.05, 0.5, 0.01) var perception_interval := 0.1
@export_range(0.45, 1.2, 0.05) var eating_distance := 0.72
@export_range(0.3, 1.5, 0.05) var eating_approach_speed := 0.8
@export_range(0.5, 4.0, 0.1) var eating_approach_timeout := 2.0
@export_group("Cruce de puertas")
@export var door_approach_distance := 0.38
@export var door_cross_distance := 1.15
@export var door_cross_speed := 1.55
@export var door_open_wait_seconds := 0.12
@export var door_cross_timeout := 2.8
@export var door_blocked_timeout := 2.5
@export var door_center_tolerance := 0.20
@export_range(0.05, 0.5, 0.01) var door_scan_interval := 0.12
@export_range(0.05, 0.5, 0.01) var clearance_probe_interval := 0.1
@export_group("Recorrido de escaleras")
@export_range(0.6, 2.0, 0.05) var stair_corridor_radius := 1.05
@export_range(0.6, 2.0, 0.05) var stair_landing_radius := 0.82
@export_range(0.6, 2.0, 0.05) var stair_close_prey_distance := 1.25

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var door_ray: RayCast3D = $DoorRay
@onready var clearance_sensor: Node3D = $ClearanceSensor
@onready var head_forward_ray: RayCast3D = $ClearanceSensor/HeadForward
@onready var body_forward_ray: RayCast3D = $ClearanceSensor/BodyForward
@onready var overhead_ray: RayCast3D = $ClearanceSensor/Overhead
@onready var model: Node3D = $Model
@onready var torso: Node3D = $Model/TorsoRig
@onready var head_rig: Node3D = $Model/TorsoRig/HeadRig
@onready var left_eye: Node3D = $Model/TorsoRig/HeadRig/LeftEye
@onready var right_eye: Node3D = $Model/TorsoRig/HeadRig/RightEye
@onready var mouth: MeshInstance3D = get_node_or_null("Model/TorsoRig/HeadRig/Mouth") as MeshInstance3D
@onready var left_arm: Node3D = $Model/TorsoRig/LeftArmPivot
@onready var right_arm: Node3D = $Model/TorsoRig/RightArmPivot
@onready var left_elbow: Node3D = $Model/TorsoRig/LeftArmPivot/LeftElbow
@onready var right_elbow: Node3D = $Model/TorsoRig/RightArmPivot/RightElbow
@onready var left_leg: Node3D = $Model/LeftLegPivot
@onready var right_leg: Node3D = $Model/RightLegPivot
@onready var left_knee: Node3D = $Model/LeftLegPivot/LeftKnee
@onready var right_knee: Node3D = $Model/RightLegPivot/RightKnee
@onready var breathing_sound: AudioStreamPlayer3D = $BreathingSound
@onready var footstep_sound: AudioStreamPlayer3D = $FootstepSound
@onready var voice_sound: AudioStreamPlayer3D = $VoiceSound

var current_state := State.PATROL
var _door_blocked_timer := 0.0
var _navigation_revision := -1
var _player: CharacterBody3D
var _prey: CharacterBody3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _spawn_position := Vector3.ZERO
var _last_known_player_position := Vector3.ZERO
var _patrol_target := Vector3.ZERO
var _state_timer := 0.0
var _memory_timer := 0.0
var _target_refresh_timer := 0.0
var _door_cooldown := 0.0
var _attack_timer := 0.0
var _attack_applied := false
var _attack_cooldown_timer := 0.0
var _motion_phase := 0.0
var _last_step_beat := -1
var _navigation_available := false
var _player_has_moved := false
var _player_start_position := Vector2.ZERO
var _player_start_position_set := false
var _smoothed_move_direction := Vector3.ZERO
var _duck_amount := 0.0
var _duck_hold_timer := 0.0
var _force_stair_steering := false
var _stair_commitment := StairCommitment.NONE
var _stair_close_prey_override := false
var _waiting_covered_eyes := false
var _mouth_close_amount := 0.0
var _mouth_rest_scale := Vector3.ONE
var teeth: Array[MeshInstance3D] = []
var _teeth_rest_positions: Array[Vector3] = []
var _teeth_rest_scales: Array[Vector3] = []
var _last_motion_sample_position := Vector3.ZERO
var _motion_sample_timer := 0.0
var _was_trying_to_move := false
var _recovery_timer := 0.0
var _recovery_direction := Vector3.ZERO
var _recovery_side := 1.0
var _door_traversal_active := false
var _door_traversal_phase := 0
var _door_traversal_door: Node
var _door_portal_center := Vector3.ZERO
var _door_portal_normal := Vector3.ZERO
var _door_entry_point := Vector3.ZERO
var _door_exit_point := Vector3.ZERO
var _door_traversal_timer := 0.0
var _door_open_wait_timer := 0.0
var _last_crossed_door_id := 0
var _door_reentry_timer := 0.0
var _prey_refresh_timer := 0.0
var _perception_timer := 0.0
var _cached_sees_prey := false
var _cached_hears_prey := false
var _door_scan_timer := 0.0
var _clearance_probe_timer := 0.0
var _cached_doorway_header_ahead := false
var _cached_low_ceiling_above := false
var _eating_target: CharacterBody3D
var _eating_timer := 0.0
var _eating_elapsed := 0.0
var _eating_approach_timer := 0.0
var _eating_started := false
var _eating_pose_amount := 0.0
var _stalk_timer := 0.0
var _ledge_attack_active := false
var _floor_change_grace := 0.0
var _closest_floor_change_distance := INF


func _ready() -> void:
	_spawn_position = global_position
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if is_instance_valid(_player):
		_player_start_position = Vector2(_player.global_position.x, _player.global_position.z)
		_player_start_position_set = true
	navigation_agent.path_height_offset = 0.0
	navigation_agent.path_desired_distance = 0.42
	navigation_agent.target_desired_distance = 0.65
	# Mecanismo base del video: objetivo mundial vivo + siguiente punto del
	# NavigationAgent. CORRIDORFUNNEL evita los bucles que EDGE_CENTERED producia
	# en pasillos; los portales explicitos se encargan de centrar las puertas.
	navigation_agent.path_postprocessing = NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	# Con celdas finas el funnel devuelve muchos puntos casi colineales y el
	# cuerpo corrige el rumbo en cada uno, produciendo un zigzag visible. La
	# simplificación deja sólo los vértices que cambian la dirección de verdad.
	navigation_agent.simplify_path = true
	navigation_agent.simplify_epsilon = 0.18
	navigation_agent.avoidance_enabled = false
	door_ray.enabled = false
	head_forward_ray.enabled = false
	body_forward_ray.enabled = false
	overhead_ray.enabled = false
	_last_motion_sample_position = global_position
	breathing_sound.stream = _make_breathing_sound()
	footstep_sound.stream = _make_footstep_sound()
	voice_sound.stream = _make_chase_voice()
	# _ready() también se ejecuta con PROCESS_MODE_DISABLED. No dejar una
	# respiración permanente activa en enemigos colocados como inactivos.
	if process_mode != Node.PROCESS_MODE_DISABLED:
		breathing_sound.play()
	else:
		breathing_sound.stop()
	_waiting_covered_eyes = starts_waiting_covered_eyes
	_refresh_preferred_prey(true)
	if is_instance_valid(mouth):
		_mouth_rest_scale = mouth.scale
	for tooth_number in range(1, 9):
		var tooth_path := "Model/TorsoRig/HeadRig/Tooth%02d" % tooth_number
		var tooth := get_node_or_null(tooth_path) as MeshInstance3D
		if is_instance_valid(tooth):
			teeth.append(tooth)
			_teeth_rest_positions.append(tooth.position)
			_teeth_rest_scales.append(tooth.scale)
	call_deferred(&"_finish_navigation_setup")


func _finish_navigation_setup() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_navigation_available = NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0
	_choose_patrol_target()


func _refresh_preferred_prey(force := false) -> void:
	_prey_refresh_timer = prey_refresh_seconds
	var selected: CharacterBody3D
	var closest_distance := INF
	if prioritize_children:
		for candidate in get_tree().get_nodes_in_group(&"child_target"):
			var child := candidate as CharacterBody3D
			if not _is_valid_child_prey(child):
				continue
			var distance := global_position.distance_squared_to(child.global_position)
			if distance < closest_distance:
				closest_distance = distance
				selected = child
	if selected == null and is_instance_valid(_player):
		selected = _player
	if not force and selected == _prey:
		return
	var previous := _prey
	_prey = selected
	# La percepción almacenada pertenece a la presa anterior.
	_perception_timer = 0.0
	_cached_sees_prey = false
	_cached_hears_prey = false
	_target_refresh_timer = 0.0
	_smoothed_move_direction = Vector3.ZERO
	if is_instance_valid(_prey):
		_last_known_player_position = _prey.global_position
		if _prey != _player and not _waiting_covered_eyes and current_state != State.EAT:
			_player_has_moved = true
			_change_state(State.CHASE)
		elif current_state == State.ATTACK:
			_change_state(State.CHASE)
	prey_changed.emit(previous, _prey)


func _is_valid_child_prey(child: CharacterBody3D) -> bool:
	if not is_instance_valid(child) or not child.is_inside_tree():
		return false
	if child.has_method(&"can_be_targeted_by_monster"):
		return bool(child.call(&"can_be_targeted_by_monster"))
	return true


func _is_valid_prey(candidate: CharacterBody3D) -> bool:
	if not is_instance_valid(candidate) or not candidate.is_inside_tree():
		return false
	if candidate == _player:
		return true
	return _is_valid_child_prey(candidate)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
		if not is_instance_valid(_player):
			return
		_player_start_position = Vector2(_player.global_position.x, _player.global_position.z)
		_player_start_position_set = true
	_prey_refresh_timer = maxf(0.0, _prey_refresh_timer - delta)
	if _prey_refresh_timer <= 0.0 or not _is_valid_prey(_prey):
		_refresh_preferred_prey()

	_door_cooldown = maxf(0.0, _door_cooldown - delta)
	_door_scan_timer = maxf(0.0, _door_scan_timer - delta)
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	_target_refresh_timer = maxf(0.0, _target_refresh_timer - delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.2

	if not _player_has_moved:
		var player_position_2d := Vector2(_player.global_position.x, _player.global_position.z)
		var player_speed_2d := Vector2(_player.velocity.x, _player.velocity.z).length()
		var prey_speed_2d := Vector2(_prey.velocity.x, _prey.velocity.z).length() if is_instance_valid(_prey) else 0.0
		if not _player_start_position_set:
			_player_start_position = player_position_2d
			_player_start_position_set = true
		_player_has_moved = player_position_2d.distance_to(_player_start_position) > 0.035 or player_speed_2d > 0.12 or prey_speed_2d > 0.12
		if not _player_has_moved:
			_brake_planar(12.0, delta)
			move_and_slide()
			_update_animation(delta)
			return

	var sees_prey := false
	var hears_prey := false
	if current_state != State.EAT:
		_update_perception_cache(delta)
		sees_prey = _cached_sees_prey
		hears_prey = _cached_hears_prey
		_update_awareness(delta, sees_prey, hears_prey)

	var distress_active := _update_distress(delta)
	if distress_active:
		_brake_planar(10.0, delta)
	elif current_state == State.EAT:
		_update_eating(delta)
	elif _door_traversal_active:
		_update_movement(delta)
	elif current_state == State.ATTACK:
		_update_attack(delta)
	else:
		_update_movement(delta)
	_update_frame_duck(delta)

	move_and_slide()
	_try_open_door()
	_update_animation(delta)


func _update_distress(delta: float) -> bool:
	if not _waiting_covered_eyes:
		return false
	var wake_target := _prey if is_instance_valid(_prey) else _player
	var wake_distance_to_target := global_position.distance_to(wake_target.global_position)
	if is_instance_valid(_player):
		wake_distance_to_target = minf(wake_distance_to_target, global_position.distance_to(_player.global_position))
	if wake_distance_to_target <= wake_distance:
		_waiting_covered_eyes = false
		_player_has_moved = true
		_last_known_player_position = wake_target.global_position
		_change_state(State.CHASE)
		return false
	var to_target := wake_target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		_turn_toward(atan2(to_target.x, to_target.z), delta, 8.0)
	return true


func _update_awareness(delta: float, sees_prey: bool, hears_prey: bool) -> void:
	if not is_instance_valid(_prey):
		return
	if sees_prey:
		_last_known_player_position = _prey.global_position
		_memory_timer = chase_memory_seconds
		if current_state != State.CHASE and current_state != State.ATTACK:
			_change_state(State.CHASE)
	elif hears_prey and current_state in [State.PATROL, State.SEARCH]:
		_last_known_player_position = _prey.global_position
		_change_state(State.INVESTIGATE)

	match current_state:
		State.PATROL:
			if global_position.distance_to(_patrol_target) < 0.85:
				_state_timer -= delta
				if _state_timer <= 0.0:
					_choose_patrol_target()
		State.INVESTIGATE:
			if sees_prey:
				_change_state(State.CHASE)
			elif global_position.distance_to(_last_known_player_position) < 0.9:
				_change_state(State.SEARCH)
		State.CHASE:
			var changing_floor := absf(_prey.global_position.y - global_position.y) > 1.15
			var keeps_memory := sees_prey
			if sees_prey:
				# El suelo y la losa de la escalera cortan la visión un momento; durante
				# esa transición debe seguir el objetivo vivo en vez de olvidarlo.
				_floor_change_grace = floor_change_grace_seconds
				_closest_floor_change_distance = global_position.distance_to(_prey.global_position)
			elif changing_floor:
				# Antes esta rama refrescaba la memoria sin límite, así que una presa
				# subida a un muro la dejaba en persecución eterna contra un objetivo
				# al que no hay ruta. Ahora sólo insiste mientras gane terreno: si deja
				# de acercarse, la cuenta atrás corre y acaba rindiéndose.
				var prey_distance := global_position.distance_to(_prey.global_position)
				if prey_distance < _closest_floor_change_distance - 0.25:
					_closest_floor_change_distance = prey_distance
					_floor_change_grace = floor_change_grace_seconds
				_floor_change_grace = maxf(0.0, _floor_change_grace - delta)
				keeps_memory = _floor_change_grace > 0.0
			if keeps_memory:
				_last_known_player_position = _prey.global_position
				_memory_timer = chase_memory_seconds
			else:
				_memory_timer -= delta
				if _memory_timer <= 0.0:
					_change_state(State.SEARCH)
			if _has_attack_contact(attack_distance) and sees_prey and can_begin_attack():
				_change_state(State.ATTACK)
		State.SEARCH:
			_state_timer -= delta
			if sees_prey:
				_change_state(State.CHASE)
			elif hears_prey:
				_last_known_player_position = _prey.global_position
				_change_state(State.INVESTIGATE)
			elif _state_timer <= 0.0:
				_choose_patrol_target()
				_change_state(State.PATROL)


func _update_movement(delta: float) -> void:
	_door_reentry_timer = maxf(0.0, _door_reentry_timer - delta)
	if _door_traversal_active:
		_update_door_traversal(delta)
		return
	_update_stuck_recovery(delta)
	var target := _patrol_target
	var speed := patrol_speed
	_force_stair_steering = false
	_stair_close_prey_override = false
	match current_state:
		State.INVESTIGATE:
			target = _last_known_player_position
			speed = investigate_speed
		State.CHASE:
			target = _predicted_prey_position()
			speed = chase_speed
		State.SEARCH:
			target = _last_known_player_position
			speed = patrol_speed * 0.72
	# El estado de percepción puede cambiar al perderla de vista bajo la losa.
	# El recorrido comprometido debe sobrevivir a CHASE/INVESTIGATE/SEARCH.
	if _stair_commitment != StairCommitment.NONE or current_state in [State.CHASE, State.INVESTIGATE, State.SEARCH]:
		target = _get_floor_transition_target(target)

	# El destino real se guarda antes de redirigir: es contra él contra el que se
	# decide si hay que acechar, sacudir o rendirse.
	var requested_target := target
	target = _redirect_unreachable_target(target)

	# El zarpazo al saliente se comprueba aquí y no en la rama de "sin dirección
	# de avance": a medio metro del muro todavía le queda rumbo hacia el punto de
	# debajo, así que aquella rama no llegaba a ejecutarse nunca.
	if current_state in [State.CHASE, State.INVESTIGATE, State.SEARCH] and _try_ledge_attack():
		return

	if _target_refresh_timer <= 0.0:
		_target_refresh_timer = target_refresh_seconds
		_refresh_navigation_state()
		if _navigation_available:
			navigation_agent.target_position = target

	var next_point := global_position
	var has_navigation_path := false
	if not _force_stair_steering and _navigation_available and not navigation_agent.is_navigation_finished():
		# El agente calcula/avanza la ruta al solicitar el siguiente punto.
		# Consultar primero el array deja una ruta recién asignada sin calcular.
		next_point = navigation_agent.get_next_path_position()
		has_navigation_path = navigation_agent.get_current_navigation_path().size() >= 2
	if has_navigation_path:
		next_point = _get_next_useful_path_point(next_point)
	elif _force_stair_steering:
		next_point = target
	elif _can_walk_directly_to(target):
		# Sólo usamos línea recta si no hay geometría entre ambos puntos. Una ruta
		# vacía ya no convierte una pared en el siguiente waypoint.
		next_point = target
	var flat_direction := next_point - global_position
	flat_direction.y = 0.0
	if flat_direction.length_squared() > 0.015:
		flat_direction = flat_direction.normalized()
		var planar_prey_distance := INF
		var close_visible_prey := false
		if current_state == State.CHASE and is_instance_valid(_prey):
			planar_prey_distance = _prey_planar_distance()
			close_visible_prey = (
				planar_prey_distance <= chase_slowdown_distance
				and absf(_prey.global_position.y - global_position.y) <= attack_vertical_tolerance
				and _has_clear_line_to_prey_body()
				and (_stair_commitment == StairCommitment.NONE or _stair_close_prey_override)
			)
			if close_visible_prey and planar_prey_distance <= chase_slowdown_distance:
				var direct_prey_direction := _prey.global_position - global_position
				direct_prey_direction.y = 0.0
				if direct_prey_direction.length_squared() > 0.01:
					flat_direction = direct_prey_direction.normalized()
				var approach_scale := clampf(
					(planar_prey_distance - chase_stop_distance) /
					maxf(chase_slowdown_distance - chase_stop_distance, 0.01),
					0.0,
					1.0
				)
				speed *= approach_scale
				if approach_scale <= 0.01:
					_recovery_timer = 0.0
					_recovery_direction = Vector3.ZERO
		if _stair_commitment == StairCommitment.NONE and _recovery_timer > 0.0 and _recovery_direction.length_squared() > 0.01:
			flat_direction = _recovery_direction
		if not close_visible_prey and _stair_commitment == StairCommitment.NONE:
			flat_direction = _steer_around_nearby_obstacle(flat_direction)
		if _smoothed_move_direction.length_squared() < 0.01:
			_smoothed_move_direction = flat_direction
		else:
			var heading := lerp_angle(atan2(_smoothed_move_direction.x, _smoothed_move_direction.z), atan2(flat_direction.x, flat_direction.z), 1.0 - exp(-heading_smoothing * delta))
			_smoothed_move_direction = Vector3(sin(heading), 0.0, cos(heading))
		speed *= lerpf(0.35, 1.0, smoothstep(-0.3, 0.8, global_basis.z.dot(flat_direction)))
		_accelerate_planar(_smoothed_move_direction, speed, delta)
		var movement_yaw := atan2(_smoothed_move_direction.x, _smoothed_move_direction.z)
		clearance_sensor.rotation.y = wrapf(movement_yaw - rotation.y, -PI, PI)
		door_ray.rotation.y = clearance_sensor.rotation.y
		var facing_direction := _smoothed_move_direction
		if current_state == State.CHASE and is_instance_valid(_prey) and close_visible_prey:
			facing_direction = _prey.global_position - global_position
			facing_direction.y = 0.0
		if facing_direction.length_squared() > 0.01:
			_turn_toward(atan2(facing_direction.x, facing_direction.z), delta, 7.5)
		_was_trying_to_move = speed > 0.05
		_stalk_timer = 0.0
	else:
		_brake_planar(braking * 0.6, delta)
		_smoothed_move_direction = _smoothed_move_direction.move_toward(Vector3.ZERO, delta * 4.0)
		_was_trying_to_move = false
		_update_unreachable_target(delta, requested_target)


# Un único move_toward sobre el plano. Aplicarlo por eje aceleraba hasta 1,41x
# más rápido en diagonal y hacía que la respuesta dependiera del rumbo: en un
# pasillo norte-sur arrancaba distinto que en una diagonal del salón.
func _accelerate_planar(direction: Vector3, speed: float, delta: float) -> void:
	var current := Vector2(velocity.x, velocity.z)
	var desired := Vector2(direction.x, direction.z) * speed
	var rate := acceleration if desired.length_squared() >= current.length_squared() else braking
	current = current.move_toward(desired, rate * delta)
	velocity.x = current.x
	velocity.z = current.y


func _brake_planar(rate: float, delta: float) -> void:
	var current := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, rate * delta)
	velocity.x = current.x
	velocity.z = current.y


# Suavizado exponencial (mismo giro a 30 y a 144 FPS) limitado por una velocidad
# angular máxima. Sin el tope el cuerpo encaraba de golpe cada esquina nueva de
# la ruta; es el salto que hacía que la abuela pareciese teledirigida.
func _turn_toward(target_yaw: float, delta: float, responsiveness: float) -> void:
	var eased := lerp_angle(rotation.y, target_yaw, 1.0 - exp(-responsiveness * delta))
	var max_step := deg_to_rad(max_turn_speed_degrees) * delta
	rotation.y = rotation.y + clampf(wrapf(eased - rotation.y, -PI, PI), -max_step, max_step)


# Sin dirección de avance hay dos casos muy distintos: o ha llegado, o el
# objetivo está donde ella no puede pisar. El segundo la dejaba congelada de
# espaldas, porque además `_was_trying_to_move` se ponía en falso y desactivaba
# la recuperación de atascos justo cuando hacía falta.
# Si el destino no está sobre la malla (presa subida a un muro), apuntar a él
# deja una ruta degenerada y la abuela no se mueve. Redirigirla al punto
# transitable más cercano la lleva hasta debajo del saliente, que es desde donde
# puede hacer algo.
func _redirect_unreachable_target(target: Vector3) -> Vector3:
	if not _navigation_available:
		return target
	var closest := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, target)
	if closest.distance_to(target) <= unreachable_tolerance:
		return target
	return closest


func _try_ledge_attack() -> bool:
	if not is_instance_valid(_prey) or not can_begin_attack():
		return false
	var height := _prey.global_position.y - global_position.y
	if height <= attack_vertical_tolerance or height > ledge_reach_height:
		return false
	if _prey_planar_distance() > ledge_reach_radius:
		return false
	_ledge_attack_active = true
	_stalk_timer = 0.0
	_change_state(State.ATTACK)
	return true


func _update_unreachable_target(delta: float, target: Vector3) -> void:
	# Se mide contra el final real de la ruta, no contra su posición: cuando el
	# destino cae en una isla de navegación desconectada el servidor devuelve una
	# ruta degenerada de dos puntos sobre ella misma, y entonces no llega a
	# moverse en ningún momento. Comparar "posición contra objetivo" no distingue
	# ese caso de haber llegado.
	# Distancia en 3D a propósito: una presa justo encima de su cabeza tiene
	# distancia horizontal casi nula y parecería alcanzada.
	var reachable_end := global_position
	if _navigation_available:
		reachable_end = navigation_agent.get_final_position()
	if reachable_end.distance_to(target) <= navigation_agent.target_desired_distance + unreachable_tolerance:
		_stalk_timer = 0.0
		return
	# Ya está debajo: sacude hacia arriba. Mientras la presa siga al alcance no se
	# rinde, así que quedarse en el muro deja de ser un refugio seguro.
	if _try_ledge_attack():
		return
	# Acecha: la encara desde el punto transitable más cercano en vez de quedarse
	# mirando a una pared. Es lo que se ve desde arriba de un muro.
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		_turn_toward(atan2(to_target.x, to_target.z), delta, 4.0)
	_stalk_timer += delta
	if _stalk_timer < stalk_seconds:
		return
	_stalk_timer = 0.0
	_give_up_unreachable_target()


func _give_up_unreachable_target() -> void:
	_memory_timer = 0.0
	_floor_change_grace = 0.0
	_closest_floor_change_distance = INF
	if current_state != State.SEARCH:
		_change_state(State.SEARCH)


func _update_stuck_recovery(delta: float) -> void:
	_recovery_timer = maxf(0.0, _recovery_timer - delta)
	_motion_sample_timer += delta
	if _motion_sample_timer < stuck_check_seconds:
		return
	var progress := Vector2(
		global_position.x - _last_motion_sample_position.x,
		global_position.z - _last_motion_sample_position.z
	).length()
	if _was_trying_to_move and progress < stuck_minimum_progress:
		var basis_direction := _smoothed_move_direction
		if basis_direction.length_squared() < 0.01:
			basis_direction = global_basis.z
		_recovery_side *= -1.0
		_recovery_direction = Vector3(
			-basis_direction.z * _recovery_side,
			0.0,
			basis_direction.x * _recovery_side
		).normalized()
		_recovery_timer = recovery_duration
		_target_refresh_timer = 0.0
		navigation_agent.target_position = navigation_agent.target_position
	elif progress >= stuck_minimum_progress:
		_recovery_direction = Vector3.ZERO
	_motion_sample_timer = 0.0
	_last_motion_sample_position = global_position


func _refresh_navigation_state() -> void:
	var map := get_world_3d().navigation_map
	var revision := NavigationServer3D.map_get_iteration_id(map)
	_navigation_available = revision > 0 and NavigationServer3D.map_get_closest_point_owner(map, global_position).is_valid()
	if not _navigation_available:
		return
	if is_on_floor():
		var surface := NavigationServer3D.map_get_closest_point(map, global_position)
		navigation_agent.path_height_offset = clampf(surface.y - global_position.y, -1.0, 1.0)
	if revision != _navigation_revision:
		_navigation_revision = revision
		_on_navigation_rebuilt()


func _on_navigation_rebuilt() -> void:
	pass


func _steer_around_nearby_obstacle(direction: Vector3) -> Vector3:
	var origin := global_position + Vector3.UP * 0.72
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * obstacle_probe_distance, collision_mask)
	query.exclude = _movement_probe_exclusions()
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return direction
	var collider := hit.collider as Node
	if _find_npc_door(collider) != null:
		return direction
	# Prueba un pequeño abanico antes de pegarse a la tangente. Esto permite
	# bordear patas de muebles y esquinas sin oscilar contra el mismo punto.
	var best_direction := Vector3.ZERO
	var best_score := -INF
	for angle_degrees in [32.0, -32.0, 58.0, -58.0, 82.0, -82.0]:
		var candidate := direction.rotated(Vector3.UP, deg_to_rad(angle_degrees)).normalized()
		var candidate_query := PhysicsRayQueryParameters3D.create(origin, origin + candidate * obstacle_probe_distance, collision_mask)
		candidate_query.exclude = _movement_probe_exclusions()
		candidate_query.collide_with_areas = false
		if not get_world_3d().direct_space_state.intersect_ray(candidate_query).is_empty():
			continue
		var score := candidate.dot(direction)
		if signf(angle_degrees) == _recovery_side:
			score += 0.04
		if score > best_score:
			best_score = score
			best_direction = candidate
	if best_direction.length_squared() > 0.01:
		return best_direction
	var normal: Vector3 = hit.normal
	normal.y = 0.0
	if normal.length_squared() < 0.01:
		return direction
	var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
	if (-tangent).dot(direction) > tangent.dot(direction):
		tangent = -tangent
	return (direction * 0.28 + tangent * 0.72).normalized()


func _can_walk_directly_to(target: Vector3) -> bool:
	if absf(target.y - global_position.y) > 0.8:
		return false
	var origin := global_position + Vector3.UP * 0.72
	var destination := Vector3(target.x, origin.y, target.z)
	var query := PhysicsRayQueryParameters3D.create(origin, destination, collision_mask)
	query.exclude = _movement_probe_exclusions()
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _movement_probe_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [get_rid()]
	# El objetivo de una persecución no es un obstáculo de navegación. Incluirlo
	# aquí hacía que el abanico local eligiese izquierda/derecha y orbitase.
	if is_instance_valid(_player):
		exclusions.append(_player.get_rid())
	if is_instance_valid(_prey) and _prey != _player:
		exclusions.append(_prey.get_rid())
	return exclusions


func _prey_planar_distance() -> float:
	if not is_instance_valid(_prey):
		return INF
	return Vector2(
		_prey.global_position.x - global_position.x,
		_prey.global_position.z - global_position.z
	).length()


# Compatibilidad con las variantes fotosensibles que aun miden reglas
# especificas del jugador, aunque el objetivo de ataque compartido sea la presa.
func _player_planar_distance() -> float:
	if not is_instance_valid(_player):
		return INF
	return Vector2(
		_player.global_position.x - global_position.x,
		_player.global_position.z - global_position.z
	).length()


func _has_attack_contact(distance: float = attack_distance) -> bool:
	if not is_instance_valid(_prey):
		return false
	# Sacudir hacia un saliente llega mucho más alto que un golpe normal, y a esa
	# distancia no necesita ver: está pegada al muro palpando por encima del
	# borde. Exigir línea de visión aquí haría que el propio muro anulase el
	# golpe justo cuando ya lo está tocando.
	if _ledge_attack_active:
		var height := _prey.global_position.y - global_position.y
		return (
			height > 0.0
			and height <= ledge_reach_height
			and _prey_planar_distance() <= maxf(distance, ledge_reach_radius)
		)
	return (
		absf(_prey.global_position.y - global_position.y) <= attack_vertical_tolerance
		and _prey_planar_distance() <= distance
		and _has_clear_line_to_prey_body()
	)


func can_begin_attack() -> bool:
	return _attack_cooldown_timer <= 0.0 and current_state != State.ATTACK


func _predicted_prey_position() -> Vector3:
	if not is_instance_valid(_prey):
		return global_position
	var prediction := clampf(_prey_planar_distance() / 8.0, 0.0, 1.0) * chase_prediction_seconds
	var predicted := _prey.global_position + Vector3(_prey.velocity.x, 0.0, _prey.velocity.z) * prediction
	return predicted


func _has_clear_line_to_prey_body() -> bool:
	if not is_instance_valid(_prey):
		return false
	var origin := global_position + Vector3.UP * 0.85
	var target := _get_prey_aim_position()
	var query := PhysicsRayQueryParameters3D.create(origin, target, collision_mask)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == _prey


func _get_prey_aim_position() -> Vector3:
	if not is_instance_valid(_prey):
		return global_position
	var collision := _prey.get_node_or_null("Collision") as CollisionShape3D
	if collision == null:
		collision = _prey.get_node_or_null("CollisionShape3D") as CollisionShape3D
	return collision.global_position if collision != null else _prey.global_position + Vector3.UP * 0.65


func _get_floor_transition_target(player_target: Vector3) -> Vector3:
	# Una vez que mete el cuerpo en la escalera, conserva el sentido hasta el
	# descansillo. Antes esta decisión se rehacía cada frame y cualquier cambio
	# de altura/objetivo la hacía darse la vuelta en medio de la rampa.
	if _stair_commitment != StairCommitment.NONE:
		if _has_completed_stair_commitment():
			_stair_commitment = StairCommitment.NONE
			_smoothed_move_direction = Vector3.ZERO
		else:
			_force_stair_steering = true
			_recovery_timer = 0.0
			_recovery_direction = Vector3.ZERO
			if _is_prey_right_beside_on_stairs():
				_stair_close_prey_override = true
				return player_target
			return _stair_commitment_destination()

	var player_is_upstairs := player_target.y > 2.65
	var player_is_downstairs := player_target.y < 1.65
	if player_is_upstairs and global_position.y < 3.72:
		var lower_distance := Vector2(
			global_position.x - STAIR_LOWER_ANCHOR.x,
			global_position.z - STAIR_LOWER_ANCHOR.z
		).length()
		if global_position.y < 0.8 and lower_distance > 0.72:
			return STAIR_LOWER_ANCHOR
		_stair_commitment = StairCommitment.ASCENDING
		_force_stair_steering = true
		return STAIR_UPPER_ANCHOR
	if player_is_downstairs and global_position.y > 0.62:
		var upper_distance := Vector2(
			global_position.x - STAIR_UPPER_ANCHOR.x,
			global_position.z - STAIR_UPPER_ANCHOR.z
		).length()
		if global_position.y > 3.55 and upper_distance > 0.72:
			return STAIR_UPPER_ANCHOR
		_stair_commitment = StairCommitment.DESCENDING
		_force_stair_steering = true
		return STAIR_LOWER_ANCHOR
	return player_target


func _stair_commitment_destination() -> Vector3:
	return STAIR_UPPER_ANCHOR if _stair_commitment == StairCommitment.ASCENDING else STAIR_LOWER_ANCHOR


func _has_completed_stair_commitment() -> bool:
	var destination := _stair_commitment_destination()
	var planar_distance := Vector2(global_position.x - destination.x, global_position.z - destination.z).length()
	if planar_distance <= stair_landing_radius:
		return true
	if _stair_commitment == StairCommitment.ASCENDING:
		return global_position.y >= STAIR_UPPER_ANCHOR.y - 0.28
	return global_position.y <= STAIR_LOWER_ANCHOR.y + 0.28


func _is_point_on_stair_corridor(point: Vector3) -> bool:
	var stair_segment := STAIR_UPPER_ANCHOR - STAIR_LOWER_ANCHOR
	var segment_length_squared := stair_segment.length_squared()
	if segment_length_squared <= 0.001:
		return false
	var progress := clampf((point - STAIR_LOWER_ANCHOR).dot(stair_segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := STAIR_LOWER_ANCHOR + stair_segment * progress
	return point.distance_to(closest_point) <= stair_corridor_radius


func _is_prey_right_beside_on_stairs() -> bool:
	if not is_instance_valid(_prey):
		return false
	if not _is_point_on_stair_corridor(global_position) or not _is_point_on_stair_corridor(_prey.global_position):
		return false
	return global_position.distance_to(_prey.global_position) <= stair_close_prey_distance


func _get_next_useful_path_point(first_point: Vector3) -> Vector3:
	# On a floor change NavigationAgent can return a waypoint almost directly
	# above/below the body. Horizontal steering would then become zero forever.
	var first_flat := Vector2(first_point.x - global_position.x, first_point.z - global_position.z)
	var path := navigation_agent.get_current_navigation_path()
	var start_index := navigation_agent.get_current_navigation_path_index()
	# Si el primer punto quedó detrás de una esquina tras deslizar el cuerpo,
	# avanzamos hasta el waypoint visible más lejano. El agente deja así de
	# intentar volver indefinidamente a una marca que ya no necesita tocar.
	var lookahead_end := mini(start_index + 3, path.size() - 1)
	for path_index in range(lookahead_end, start_index, -1):
		var visible_candidate := path[path_index]
		if _can_walk_directly_to(visible_candidate):
			return visible_candidate
	if first_flat.length_squared() > 0.015:
		return first_point
	for path_index in range(start_index + 1, path.size()):
		var candidate := path[path_index]
		var candidate_flat := Vector2(candidate.x - global_position.x, candidate.z - global_position.z)
		if candidate_flat.length_squared() > 0.015:
			return candidate
	return first_point


func _update_frame_duck(delta: float) -> void:
	_clearance_probe_timer = maxf(0.0, _clearance_probe_timer - delta)
	if _clearance_probe_timer <= 0.0:
		_clearance_probe_timer = clearance_probe_interval
		head_forward_ray.force_raycast_update()
		body_forward_ray.force_raycast_update()
		overhead_ray.force_raycast_update()
		_cached_doorway_header_ahead = head_forward_ray.is_colliding() and not body_forward_ray.is_colliding()
		_cached_low_ceiling_above = overhead_ray.is_colliding()
	if _cached_doorway_header_ahead or _cached_low_ceiling_above:
		_duck_hold_timer = 0.72
	else:
		_duck_hold_timer = maxf(0.0, _duck_hold_timer - delta)
	var target_duck := 1.0 if _duck_hold_timer > 0.0 else 0.0
	var duck_speed := 4.6 if target_duck > _duck_amount else 2.8
	_duck_amount = move_toward(_duck_amount, target_duck, delta * duck_speed)


func _update_attack(delta: float) -> void:
	if not is_instance_valid(_prey):
		_change_state(State.CHASE)
		return
	_attack_timer += delta
	var to_prey := _prey.global_position - global_position
	to_prey.y = 0.0
	if to_prey.length_squared() > 0.01:
		# El ataque es el único momento en que puede girar sobre sí misma sin tope:
		# es un movimiento intencionado, no una corrección de ruta.
		rotation.y = lerp_angle(rotation.y, atan2(to_prey.x, to_prey.z), 1.0 - exp(-10.0 * delta))
	var lunging := _attack_timer >= attack_windup_seconds and _attack_timer <= attack_hit_seconds
	if lunging and to_prey.length_squared() > 0.01 and _prey_planar_distance() > 0.48:
		var current_lunge := Vector2(velocity.x, velocity.z).move_toward(
			Vector2(to_prey.normalized().x, to_prey.normalized().z) * 1.35, delta * 10.0
		)
		velocity.x = current_lunge.x
		velocity.z = current_lunge.y
	else:
		_brake_planar(14.0, delta)
	if _attack_timer >= attack_hit_seconds and not _attack_applied:
		_attack_applied = true
		if _has_attack_contact(attack_distance + 0.7):
			var struck_prey := _prey
			if struck_prey.has_method(&"receive_monster_attack"):
				struck_prey.call(&"receive_monster_attack", self)
			if struck_prey != _player and struck_prey.is_in_group(&"child_target"):
				_begin_eating_child(struck_prey)
				return
	if _attack_timer >= attack_animation_seconds:
		_change_state(State.CHASE)


func _begin_eating_child(child: CharacterBody3D) -> void:
	if _door_traversal_active:
		_end_door_traversal(false)
	_eating_target = child
	_eating_timer = child_eating_seconds
	_eating_elapsed = 0.0
	_eating_approach_timer = eating_approach_timeout
	_eating_started = false
	velocity.x = 0.0
	velocity.z = 0.0
	_recovery_timer = 0.0
	_recovery_direction = Vector3.ZERO
	child_caught.emit(child)
	_change_state(State.EAT)


func _update_eating(delta: float) -> void:
	_duck_hold_timer = 0.5
	if is_instance_valid(_eating_target):
		var to_body := _eating_target.global_position - global_position
		to_body.y = 0.0
		if to_body.length_squared() > 0.01:
			_turn_toward(atan2(to_body.x, to_body.z), delta, 5.5)
		var body_distance := to_body.length()
		if not _eating_started and body_distance > eating_distance and _eating_approach_timer > 0.0:
			_eating_approach_timer = maxf(0.0, _eating_approach_timer - delta)
			var approach := Vector2(velocity.x, velocity.z).move_toward(
				Vector2(to_body.normalized().x, to_body.normalized().z) * eating_approach_speed, delta * 5.0
			)
			velocity.x = approach.x
			velocity.z = approach.y
			return
	_eating_started = true
	_brake_planar(14.0, delta)
	_eating_elapsed += delta
	_eating_timer = maxf(0.0, _eating_timer - delta)
	if _eating_timer > 0.0:
		return
	var finished_child := _eating_target
	_eating_target = null
	_eating_started = false
	if is_instance_valid(finished_child):
		finished_eating_child.emit(finished_child)
	_refresh_preferred_prey(true)
	if is_instance_valid(_prey):
		_last_known_player_position = _prey.global_position
		_memory_timer = chase_memory_seconds
		_change_state(State.CHASE)
	else:
		_change_state(State.SEARCH)


func _change_state(new_state: State) -> void:
	if new_state in [State.ATTACK, State.EAT] and _door_traversal_active:
		_end_door_traversal(false)
	if new_state == current_state:
		return
	var previous := current_state
	current_state = new_state
	if new_state != State.ATTACK:
		_ledge_attack_active = false
	_state_timer = search_seconds if new_state == State.SEARCH else randf_range(0.8, 2.0)
	if new_state == State.ATTACK:
		_attack_timer = 0.0
		_attack_applied = false
		_attack_cooldown_timer = attack_cooldown
	elif new_state == State.CHASE and not voice_sound.playing:
		voice_sound.pitch_scale = randf_range(0.9, 1.06)
		voice_sound.play()
	emit_signal(&"state_changed", previous, new_state)


func _update_perception_cache(delta: float) -> void:
	_perception_timer = maxf(0.0, _perception_timer - delta)
	if _perception_timer > 0.0:
		return
	_perception_timer = perception_interval
	_cached_sees_prey = _can_see_prey()
	_cached_hears_prey = _can_hear_prey()


func _can_see_prey() -> bool:
	if not is_instance_valid(_prey):
		return false
	var eye_position := global_position + Vector3.UP * 2.65
	var target_position := _get_prey_aim_position()
	var to_target := target_position - eye_position
	if to_target.length() > vision_distance:
		return false
	var forward := global_basis.z.normalized()
	if rad_to_deg(forward.angle_to(to_target.normalized())) > vision_angle_degrees * 0.5:
		return false
	var vision_mask := collision_mask | _prey.collision_layer
	var query := PhysicsRayQueryParameters3D.create(eye_position, target_position, vision_mask)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == _prey


func _can_hear_prey() -> bool:
	if not is_instance_valid(_prey):
		return false
	var prey_speed := Vector2(_prey.velocity.x, _prey.velocity.z).length()
	if prey_speed < 0.35:
		return false
	var effective_distance := hearing_distance * clampf(prey_speed / 1.4, 0.65, 1.8)
	return global_position.distance_to(_prey.global_position) <= effective_distance


func _choose_patrol_target() -> void:
	_state_timer = randf_range(1.2, 3.0)
	var candidate := _spawn_position + Vector3(randf_range(-6.5, 6.5), 0.0, randf_range(-6.5, 6.5))
	if _navigation_available:
		candidate = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, candidate)
	_patrol_target = candidate


func _try_open_door() -> void:
	if _door_traversal_active or _door_cooldown > 0.0 or current_state == State.EAT or _door_scan_timer > 0.0:
		return
	_door_scan_timer = door_scan_interval
	var door := _find_nearby_door_portal()
	if door == null and velocity.length_squared() >= 0.12:
		door = _find_door_ahead()
	if door != null:
		if _door_reentry_timer > 0.0 and door.get_instance_id() == _last_crossed_door_id:
			return
		_door_cooldown = 1.0
		door.call(&"ensure_open_for_npc", self)
		# Las puertas con llave pueden consumir la interacción sin abrirse. Sólo
		# comprometemos el cruce cuando la hoja confirma que el hueco está libre.
		if door.get("_is_open") == true:
			_begin_door_traversal(door)


func _find_nearby_door_portal() -> Node:
	var requested_target := _patrol_target
	if current_state == State.CHASE and is_instance_valid(_prey):
		requested_target = _prey.global_position
	elif current_state in [State.INVESTIGATE, State.SEARCH]:
		requested_target = _last_known_player_position
	var closest: Node
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
		if distance > 1.65:
			continue
		var actor_side := offset.dot(normal)
		var target_side := (requested_target - center).dot(normal)
		var lateral_offset := (offset - normal * actor_side).length()
		if lateral_offset > 1.25 or actor_side * target_side >= -0.04:
			continue
		var entry := center + normal * signf(actor_side) * maxf(door_approach_distance, 0.6)
		entry.y = global_position.y
		if PassageProbe.is_blocked(self, entry - global_position):
			continue
		if distance < closest_distance:
			closest_distance = distance
			closest = door
	return closest


func _find_door_ahead() -> Node:
	door_ray.force_raycast_update()
	if door_ray.is_colliding():
		var center_door := _find_npc_door(door_ray.get_collider() as Node)
		if center_door != null:
			return center_door
	# Las puertas dobles tienen una junta justo en el centro. Dos rayos laterales
	# evitan que esa ranura invisible anule la detección de ambas hojas.
	var ray_origin := door_ray.global_position
	var ray_end := door_ray.to_global(door_ray.target_position)
	var side_axis := global_basis.x.normalized()
	for side_offset: float in [-0.32, 0.32]:
		var offset: Vector3 = side_axis * side_offset
		var query := PhysicsRayQueryParameters3D.create(ray_origin + offset, ray_end + offset, door_ray.collision_mask)
		query.exclude = [get_rid()]
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			continue
		var side_door := _find_npc_door(result.collider as Node)
		if side_door != null:
			return side_door
	return null


func _begin_door_traversal(door: Node) -> void:
	if not is_instance_valid(door):
		return
	var portal_data: Dictionary = {}
	if door.has_method(&"get_npc_traversal_portal"):
		portal_data = door.call(&"get_npc_traversal_portal") as Dictionary
	var portal_root := door.get_parent() as Node3D
	if portal_data.has("center"):
		_door_portal_center = portal_data["center"] as Vector3
	elif is_instance_valid(portal_root):
		_door_portal_center = portal_root.global_position
	elif door is Node3D:
		_door_portal_center = (door as Node3D).global_position
	else:
		return
	if portal_data.has("normal"):
		_door_portal_normal = portal_data["normal"] as Vector3
	elif is_instance_valid(portal_root):
		_door_portal_normal = portal_root.global_basis.z
	else:
		_door_portal_normal = (door as Node3D).global_basis.z
	_door_portal_normal.y = 0.0
	if _door_portal_normal.length_squared() < 0.01:
		return
	_door_portal_normal = _door_portal_normal.normalized()
	var side := signf((global_position - _door_portal_center).dot(_door_portal_normal))
	if is_zero_approx(side):
		side = -signf(velocity.dot(_door_portal_normal))
	if is_zero_approx(side):
		side = 1.0
	_door_entry_point = _door_portal_center + _door_portal_normal * side * maxf(door_approach_distance, 0.6)
	_door_exit_point = _door_portal_center - _door_portal_normal * side * door_cross_distance
	_door_traversal_door = door
	_door_traversal_active = true
	var crossing := -_door_portal_normal * side
	_door_traversal_phase = 1 if (global_position - _door_entry_point).dot(crossing) >= 0.0 else 0
	_door_traversal_timer = maxf(door_cross_timeout, 4.5)
	_door_blocked_timer = 0.0
	_door_open_wait_timer = maxf(door_open_wait_seconds, float(portal_data.get("open_wait", 0.0)))
	_recovery_timer = 0.0
	_recovery_direction = Vector3.ZERO
	_smoothed_move_direction = Vector3.ZERO


func _update_door_traversal(delta: float) -> void:
	_door_traversal_timer -= delta
	if _door_traversal_timer <= 0.0 or not is_instance_valid(_door_traversal_door):
		_end_door_traversal(false)
		return
	_door_open_wait_timer = maxf(0.0, _door_open_wait_timer - delta)
	var ready := _door_open_wait_timer <= 0.0
	if _door_traversal_door.has_method(&"is_npc_passage_ready"):
		ready = bool(_door_traversal_door.call(&"is_npc_passage_ready"))
	var target := _door_entry_point if _door_traversal_phase == 0 else _door_exit_point
	if _door_traversal_phase == 0 and _planar_distance_to(target) <= door_center_tolerance:
		_door_traversal_phase = 1
	if _door_traversal_phase == 1:
		if not ready:
			_brake_at_door(delta)
			return
		_door_traversal_phase = 2
	if _door_traversal_phase == 2:
		target = _door_exit_point
		if not ready:
			if _door_cooldown <= 0.0:
				_door_traversal_door.call(&"ensure_open_for_npc", self)
				_door_cooldown = 0.7
			_brake_at_door(delta)
			return
		var crossing := (_door_exit_point - _door_portal_center).normalized()
		if (global_position - _door_portal_center).dot(crossing) >= door_cross_distance * 0.8:
			_end_door_traversal(true)
			return

	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() <= door_center_tolerance * door_center_tolerance:
		if _door_traversal_phase == 0:
			_door_traversal_phase = 1
		else:
			_end_door_traversal(true)
		return
	direction = direction.normalized()
	if PassageProbe.is_blocked(self, direction * 0.3):
		_door_blocked_timer += delta
		_brake_at_door(delta)
		# Un objetivo al alcance no puede bloquear indefinidamente la puerta.
		if _has_attack_contact() and can_begin_attack():
			_end_door_traversal(false)
			_change_state(State.ATTACK)
		elif _door_blocked_timer >= door_blocked_timeout:
			_end_door_traversal(false)
		return
	_door_blocked_timer = 0.0
	_smoothed_move_direction = direction
	var crossing_velocity := Vector2(velocity.x, velocity.z).move_toward(
		Vector2(direction.x, direction.z) * door_cross_speed, delta * 12.0
	)
	velocity.x = crossing_velocity.x
	velocity.z = crossing_velocity.y
	_turn_toward(atan2(direction.x, direction.z), delta, 11.0)
	clearance_sensor.rotation.y = wrapf(atan2(direction.x, direction.z) - rotation.y, -PI, PI)
	door_ray.rotation.y = clearance_sensor.rotation.y
	_was_trying_to_move = true


func _brake_at_door(delta: float) -> void:
	_brake_planar(14.0, delta)
	_was_trying_to_move = false


func _end_door_traversal(completed: bool) -> void:
	if is_instance_valid(_door_traversal_door):
		_last_crossed_door_id = _door_traversal_door.get_instance_id()
	_door_reentry_timer = 1.15 if completed else 1.5
	_door_traversal_active = false
	_door_traversal_phase = 0
	_door_traversal_door = null
	_target_refresh_timer = 0.0
	_motion_sample_timer = 0.0
	_last_motion_sample_position = global_position


func _planar_distance_to(point: Vector3) -> float:
	return Vector2(global_position.x - point.x, global_position.z - point.z).length()


func is_crossing_door() -> bool:
	return _door_traversal_active


func get_attention_position() -> Vector3:
	if _door_traversal_active:
		return _door_exit_point + Vector3.UP
	if current_state in [State.CHASE, State.INVESTIGATE, State.SEARCH, State.ATTACK]:
		return _last_known_player_position + Vector3.UP
	return _patrol_target + Vector3.UP


func _find_npc_door(node: Node) -> Node:
	var candidate := node
	for _level in 4:
		if candidate == null:
			return null
		if candidate.has_method(&"ensure_open_for_npc"):
			return candidate
		candidate = candidate.get_parent()
	return null


func _update_animation(delta: float) -> void:
	var actual_velocity := get_real_velocity()
	var horizontal_speed := Vector2(actual_velocity.x, actual_velocity.z).length()
	var moving_amount := clampf(horizontal_speed / maxf(chase_speed, 0.01), 0.0, 1.0)
	# Una zancada cada `stride_length` metros recorridos en lugar de una rampa
	# fija por estado. Los pasos (que se disparan cada PI de fase), el balanceo de
	# piernas y el bob del rig importado quedan atados a la velocidad real, así
	# que dejan de patinar al acelerar, frenar o rozar una pared.
	var stride_cadence := PI * horizontal_speed / maxf(stride_length, 0.05)
	_motion_phase += delta * maxf(stride_cadence, 1.6)
	var leg_swing := sin(_motion_phase) * lerpf(0.18, 0.72, moving_amount)
	var arm_swing := sin(_motion_phase) * lerpf(0.08, 0.46, moving_amount)
	var chase_amount := 1.0 if current_state == State.CHASE else 0.0
	var distress_active := _waiting_covered_eyes
	var prey_distance := global_position.distance_to(_prey.global_position) if is_instance_valid(_prey) else INF
	var reach_active := (
		current_state == State.CHASE
		and prey_distance >= 2.35
		and prey_distance <= 7.2
		and is_instance_valid(_prey)
		and absf(_prey.global_position.y - global_position.y) < 1.7
	)
	_update_mouth_pose(delta, distress_active)
	var eating_active := current_state == State.EAT and _eating_started
	_eating_pose_amount = move_toward(
		_eating_pose_amount,
		1.0 if eating_active else 0.0,
		delta * (2.2 if eating_active else 3.4)
	)

	if distress_active:
		left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, minf(delta * 9.0, 1.0))
		right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, minf(delta * 9.0, 1.0))
		left_knee.rotation.x = lerpf(left_knee.rotation.x, 0.22, minf(delta * 9.0, 1.0))
		right_knee.rotation.x = lerpf(right_knee.rotation.x, 0.22, minf(delta * 9.0, 1.0))
		_pose_hand_over_eye(left_arm, left_elbow, left_eye, -1.0, delta)
		_pose_hand_over_eye(right_arm, right_elbow, right_eye, 1.0, delta)
		torso.rotation.x = lerpf(torso.rotation.x, -0.2, minf(delta * 8.0, 1.0))
	elif eating_active:
		var chew_cycle := sin(_motion_phase * 1.65)
		var eat_pulse := chew_cycle * 0.14 * _eating_pose_amount
		left_leg.rotation.x = lerpf(left_leg.rotation.x, -0.82, minf(delta * 8.0, 1.0))
		right_leg.rotation.x = lerpf(right_leg.rotation.x, -0.82, minf(delta * 8.0, 1.0))
		left_knee.rotation.x = lerpf(left_knee.rotation.x, 1.12, minf(delta * 9.0, 1.0))
		right_knee.rotation.x = lerpf(right_knee.rotation.x, 1.12, minf(delta * 9.0, 1.0))
		if is_instance_valid(_eating_target):
			var body_center := _eating_target.global_position + Vector3.UP * 0.16
			var side := global_basis.x.normalized()
			var mouth_target := mouth.global_position + global_basis.z.normalized() * 0.08 if is_instance_valid(mouth) else body_center + Vector3.UP * 0.55
			var left_transfer := smoothstep(-0.2, 0.85, chew_cycle)
			var right_transfer := smoothstep(-0.2, 0.85, -chew_cycle)
			var left_grab := body_center - side * 0.14
			var right_grab := body_center + side * 0.14
			_pose_arm_toward_position(left_arm, left_elbow, left_grab.lerp(mouth_target - side * 0.08, left_transfer), -1.0, delta)
			_pose_arm_toward_position(right_arm, right_elbow, right_grab.lerp(mouth_target + side * 0.08, right_transfer), 1.0, delta)
		torso.rotation.x = lerpf(torso.rotation.x, -0.66 + absf(eat_pulse) * 0.22, minf(delta * 8.0, 1.0))
		if is_instance_valid(mouth):
			var bite := smoothstep(-0.15, 0.7, -chew_cycle)
			mouth.scale.y = _mouth_rest_scale.y * lerpf(1.18, 0.24, bite)
	elif current_state == State.ATTACK:
		var attack_progress := clampf(_attack_timer / 0.72, 0.0, 1.0)
		var thrust := sin(attack_progress * PI)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 1.38 * thrust, minf(delta * 16.0, 1.0))
		right_arm.rotation.x = lerpf(right_arm.rotation.x, 1.38 * thrust, minf(delta * 16.0, 1.0))
		left_elbow.rotation.x = lerpf(left_elbow.rotation.x, 0.55, minf(delta * 12.0, 1.0))
		right_elbow.rotation.x = lerpf(right_elbow.rotation.x, 0.55, minf(delta * 12.0, 1.0))
		torso.rotation.x = lerpf(torso.rotation.x, -0.34 * thrust - _duck_amount * 0.18, minf(delta * 14.0, 1.0))
	else:
		left_leg.rotation.x = lerpf(left_leg.rotation.x, leg_swing, minf(delta * 12.0, 1.0))
		right_leg.rotation.x = lerpf(right_leg.rotation.x, -leg_swing, minf(delta * 12.0, 1.0))
		left_knee.rotation.x = lerpf(left_knee.rotation.x, maxf(0.0, -leg_swing) * 0.62 + _duck_amount * 0.52, minf(delta * 13.0, 1.0))
		right_knee.rotation.x = lerpf(right_knee.rotation.x, maxf(0.0, leg_swing) * 0.62 + _duck_amount * 0.52, minf(delta * 13.0, 1.0))
		if reach_active:
			var prey_right := _prey.global_basis.x.normalized()
			var reach_center := _prey.global_position + Vector3.UP * (0.72 if _prey.is_in_group(&"child_target") else 1.05)
			_pose_arm_toward_position(left_arm, left_elbow, reach_center + prey_right * 0.2, -1.0, delta)
			_pose_arm_toward_position(right_arm, right_elbow, reach_center - prey_right * 0.2, 1.0, delta)
		else:
			left_arm.rotation.x = lerpf(left_arm.rotation.x, -arm_swing + chase_amount * 0.35, minf(delta * 10.0, 1.0))
			right_arm.rotation.x = lerpf(right_arm.rotation.x, arm_swing + chase_amount * 0.35, minf(delta * 10.0, 1.0))
			left_elbow.rotation.x = lerpf(left_elbow.rotation.x, 0.16 + chase_amount * 0.52, minf(delta * 10.0, 1.0))
			right_elbow.rotation.x = lerpf(right_elbow.rotation.x, 0.16 + chase_amount * 0.52, minf(delta * 10.0, 1.0))
		torso.rotation.x = lerpf(torso.rotation.x, -0.07 - chase_amount * (0.26 if reach_active else 0.18) - _duck_amount * 0.16, minf(delta * 8.0, 1.0))
	if not distress_active and not reach_active and not eating_active:
		left_arm.rotation.y = lerp_angle(left_arm.rotation.y, 0.0, minf(delta * 7.0, 1.0))
		right_arm.rotation.y = lerp_angle(right_arm.rotation.y, 0.0, minf(delta * 7.0, 1.0))
		left_arm.rotation.z = lerp_angle(left_arm.rotation.z, -0.11, minf(delta * 7.0, 1.0))
		right_arm.rotation.z = lerp_angle(right_arm.rotation.z, 0.11, minf(delta * 7.0, 1.0))
		left_elbow.rotation.y = lerp_angle(left_elbow.rotation.y, 0.0, minf(delta * 7.0, 1.0))
		right_elbow.rotation.y = lerp_angle(right_elbow.rotation.y, 0.0, minf(delta * 7.0, 1.0))
		left_elbow.rotation.z = lerp_angle(left_elbow.rotation.z, 0.0, minf(delta * 7.0, 1.0))
		right_elbow.rotation.z = lerp_angle(right_elbow.rotation.z, 0.0, minf(delta * 7.0, 1.0))
	torso.position.y = lerpf(torso.position.y, 1.9 - _duck_amount * 0.62, minf(delta * 7.0, 1.0))
	torso.rotation.y = lerp_angle(torso.rotation.y, 0.0, minf(delta * 11.0, 1.0))
	torso.rotation.z = lerp_angle(torso.rotation.z, 0.0, minf(delta * 11.0, 1.0))

	var search_scan := sin(_motion_phase * 0.42) * 0.62 if current_state == State.SEARCH else 0.0
	var eating_head_pitch := 0.46 + absf(sin(_motion_phase * 1.65)) * 0.12 if eating_active else 0.0
	head_rig.rotation.x = lerp_angle(head_rig.rotation.x, eating_head_pitch, minf(delta * (7.0 if eating_active else 15.0), 1.0))
	head_rig.rotation.y = lerp_angle(head_rig.rotation.y, 0.04 * sin(_motion_phase * 0.8) if eating_active else search_scan, minf(delta * 4.0, 1.0))
	head_rig.rotation.z = lerp_angle(head_rig.rotation.z, sin(_motion_phase * 0.23) * 0.045, minf(delta * 6.0, 1.0))
	model.position.y = (absf(sin(_motion_phase)) - 0.5) * 0.055 * moving_amount + sin(Time.get_ticks_msec() * 0.0018) * 0.012

	if horizontal_speed > 0.25 and is_on_floor():
		var beat := floori(_motion_phase / PI)
		if beat != _last_step_beat:
			_last_step_beat = beat
			footstep_sound.pitch_scale = randf_range(0.82, 1.02) + moving_amount * 0.08
			footstep_sound.play()


func _update_mouth_pose(delta: float, distress_active: bool) -> void:
	if not is_instance_valid(mouth):
		return
	var target_amount := 1.0 if distress_active else 0.0
	var transition_speed := 5.5 if distress_active else 3.5
	_mouth_close_amount = move_toward(_mouth_close_amount, target_amount, delta * transition_speed)

	mouth.scale = _mouth_rest_scale
	mouth.scale.y = lerpf(_mouth_rest_scale.y, _mouth_rest_scale.y * 0.18, _mouth_close_amount)

	var closed_y := mouth.position.y
	for i in teeth.size():
		var tooth := teeth[i]
		if not is_instance_valid(tooth):
			continue
		var rest_position := _teeth_rest_positions[i]
		var rest_scale := _teeth_rest_scales[i]
		var closed_position := rest_position
		closed_position.y = closed_y + (-0.012 if i < 4 else 0.012)
		tooth.position = rest_position.lerp(closed_position, _mouth_close_amount)
		tooth.scale = rest_scale
		tooth.scale.y = lerpf(rest_scale.y, rest_scale.y * 0.25, _mouth_close_amount)


const UPPER_ARM_LENGTH := 0.88
const FOREARM_TO_HAND_LENGTH := 0.94


# Solver de dos huesos compartido por las dos poses de brazo. Estaba copiado
# entero en ambas y solo cambiaban la holgura de alcance y la velocidad de
# interpolacion, que ahora son parametros.
#
# El codo tiene dos soluciones posibles sobre la circunferencia de flexion; se
# elige siempre la exterior para que cada brazo trabaje en su lado sin cruzarse
# con el otro.
func _pose_two_bone_arm(
	arm: Node3D,
	elbow: Node3D,
	target: Vector3,
	outward_side: float,
	delta: float,
	reach_slack: float,
	pose_speed: float
) -> void:
	var shoulder := arm.global_position
	var shoulder_to_target := target - shoulder
	var target_distance := shoulder_to_target.length()
	if target_distance < 0.001:
		return
	var target_direction := shoulder_to_target / target_distance
	var reach_min := absf(UPPER_ARM_LENGTH - FOREARM_TO_HAND_LENGTH) + 0.01
	var reach_max := UPPER_ARM_LENGTH + FOREARM_TO_HAND_LENGTH - reach_slack
	var solved_distance := clampf(target_distance, reach_min, reach_max)
	var solved_target := shoulder + target_direction * solved_distance
	var along_distance := (
		UPPER_ARM_LENGTH * UPPER_ARM_LENGTH
		- FOREARM_TO_HAND_LENGTH * FOREARM_TO_HAND_LENGTH
		+ solved_distance * solved_distance
	) / (2.0 * solved_distance)
	var bend_height := sqrt(maxf(0.0, UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - along_distance * along_distance))
	var arm_parent := arm.get_parent() as Node3D
	var parent_basis := arm_parent.global_basis.orthonormalized()
	var outward := parent_basis.x.normalized() * outward_side
	var bend_direction := outward - target_direction * outward.dot(target_direction)
	if bend_direction.length_squared() < 0.001:
		bend_direction = parent_basis.y.cross(target_direction)
	bend_direction = bend_direction.normalized()
	var elbow_target := shoulder + target_direction * along_distance + bend_direction * bend_height
	var upper_direction_local := (parent_basis.inverse() * (elbow_target - shoulder).normalized()).normalized()
	var desired_arm_quaternion := Quaternion(Vector3.DOWN, upper_direction_local)
	var desired_arm_global_basis := parent_basis * Basis(desired_arm_quaternion)
	var lower_direction_local := (desired_arm_global_basis.inverse() * (solved_target - elbow_target).normalized()).normalized()
	var desired_elbow_quaternion := Quaternion(Vector3.DOWN, lower_direction_local)
	var pose_weight := minf(delta * pose_speed, 1.0)
	arm.quaternion = arm.quaternion.slerp(desired_arm_quaternion, pose_weight)
	elbow.quaternion = elbow.quaternion.slerp(desired_elbow_quaternion, pose_weight)


func _pose_hand_over_eye(arm: Node3D, elbow: Node3D, eye: Node3D, outward_side: float, delta: float) -> void:
	# La palma se apoya justo delante del ojo de su mismo lado.
	var face_forward := -head_rig.global_basis.z.normalized()
	_pose_two_bone_arm(arm, elbow, eye.global_position + face_forward * 0.055, outward_side, delta, 0.01, 8.0)


func _pose_arm_toward_position(arm: Node3D, elbow: Node3D, target_position: Vector3, outward_side: float, delta: float) -> void:
	_pose_two_bone_arm(arm, elbow, target_position, outward_side, delta, 0.025, 10.0)


func _make_breathing_sound() -> AudioStreamWAV:
	return _make_tonal_stream(1.8, 58.0, 0.16, true, 0.34)


func _make_footstep_sound() -> AudioStreamWAV:
	return _make_tonal_stream(0.18, 43.0, 0.52, false, 0.0)


func _make_chase_voice() -> AudioStreamWAV:
	return _make_tonal_stream(0.92, 82.0, 0.28, false, 0.58)


func _make_tonal_stream(duration: float, frequency: float, volume: float, looped: bool, noise_amount: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(duration * mix_rate)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(frequency * 193.0 + duration * 1000.0)
	for sample_index in sample_count:
		var time := float(sample_index) / float(mix_rate)
		var envelope := sin(PI * clampf(time / duration, 0.0, 1.0))
		if looped:
			envelope = 0.62 + sin(time * TAU / duration) * 0.28
		var tone := sin(time * TAU * frequency) * 0.72 + sin(time * TAU * frequency * 0.48) * 0.28
		var noise := rng.randf_range(-1.0, 1.0) * noise_amount
		var value := clampf((tone + noise) * envelope * volume, -1.0, 1.0)
		pcm.encode_s16(sample_index * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = pcm
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream
