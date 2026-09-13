extends "res://enemies/monster_grandmother.gd"

enum PhotoBehavior { PATROL, STATIC_LIGHT, FLASHLIGHT, LIGHT_MEMORY, CLOSE_PLAYER, CLOSE_MEMORY, FOOTSTEP, REVEALED_PLAYER }

const LIGHT_SCAN_INTERVAL := 0.18

@export var remain_still := false
@export_group("Activación de habitación")
@export var dormant_until_door_opens := false
@export var activation_door_path: NodePath
@export_group("Comportamiento fotosensible")
@export var close_player_distance := 1.2
@export var close_player_memory_seconds := 0.85
@export var light_detection_distance := 13.0
@export var same_floor_player_tolerance := 1.35
@export var ledge_detection_distance := 7.0
@export var same_floor_light_tolerance := 4.4
@export var flashlight_memory_seconds := 2.4
@export var static_light_memory_seconds := 0.8
@export var light_wander_radius := 1.15
@export var static_light_attention_seconds := 5.0
# Debe superar el `blackout_max_duration` de flickering_light.gd (0,58 s).
@export var light_off_confirm_seconds := 0.7
@export var static_light_approach_timeout := 8.0
@export var player_pursuit_break_distance := 8.0
@export var player_hidden_memory_seconds := 1.8
@export var dark_player_pursuit_break_distance := 4.8
@export var dark_player_hidden_memory_seconds := 0.65
@export var footstep_interest_seconds := 1.6
@export var lost_player_search_seconds := 8.0
@export var search_step_seconds := 1.05
@export var search_sweep_radius := 1.45
@export_group("Revelado anti-espera")
# Evita que una partida se estanque si luces, pasos y visión no producen ninguna
# pista durante demasiado tiempo. Es un pulso breve, no seguimiento omnisciente.
@export var supernatural_player_reveal := true
@export var reveal_after_seconds := 20.0
@export var reveal_live_seconds := 1.0
@export var reveal_reset_distance := 6.0
@export var reveal_search_seconds := 12.0
@export_group("Patrulla alterna")
# Sin esto la patrulla son dos puntos pegados al spawn y la abuela se queda
# rondando la misma esquina toda la partida. Con el paseo activo elige destinos
# al azar por toda la malla, comprobando que exista ruta real hasta ellos.
@export var patrol_roams_house := true
@export_range(5.0, 120.0, 1.0) var roam_radius := 34.0
@export_range(1.0, 30.0, 0.5) var roam_minimum_distance := 6.0
@export var patrol_offset_a := Vector3(-4.2, 0.0, 0.0)
@export var patrol_offset_b := Vector3(1.8, 0.0, -4.6)
@export var patrol_wait_min := 1.4
@export var patrol_wait_max := 5.0
@export var patrol_travel_timeout := 10.0

var _photo_behavior := PhotoBehavior.PATROL
var _patrol_points: Array[Vector3] = []
var _patrol_point_index := 0
var _patrol_wait_timer := 0.0
var _patrol_travel_timer := 0.0
var _light_scan_timer := 0.0
var _light_sources: Array[Node3D] = []
var _focused_static_light: Node3D
var _light_memory_timer := 0.0
var _close_player_memory_timer := 0.0
var _flashlight_acquired := false
var _flashlight_ignition_position := Vector3.ZERO
var _last_visible_light_position := Vector3.ZERO
var _static_wander_timer := 0.0
var _static_light_attention_timer := 0.0
var _static_light_approach_timer := 0.0
var _static_light_arrived := false
var _light_on_states: Dictionary = {}
var _light_dark_seconds: Dictionary = {}
var _ignored_light_ids: Dictionary = {}
var _pending_new_light: Node3D
var _player_hunt_active := false
var _player_loss_timer := 0.0
var _footstep_interest_timer := 0.0
var _reveal_countdown := 20.0
var _reveal_live_timer := 0.0
var _reveal_search_timer := 0.0
var _activation_door: Node
var _dormant_released := false
var _dormant_monitor: Timer
var _lost_search_timer := 0.0
var _search_step_timer := 0.0
var _search_anchor := Vector3.ZERO
var _search_step_index := 0
var _search_anchor_visited := false
var _photo_sense_timer := 0.0
var _sees_personal_light := false
var _senses_close_player := false
var _sees_known_player := false
var _senses_ledge_player := false


func _ready() -> void:
	super._ready()
	_waiting_covered_eyes = false
	_player_has_moved = true
	_reveal_countdown = reveal_after_seconds
	if dormant_until_door_opens:
		call_deferred(&"_arm_dormant_monitor")


func _arm_dormant_monitor() -> void:
	# Dos pasos permiten que el cuerpo se apoye en el suelo antes de dormirlo.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _dormant_released or not is_inside_tree():
		return
	velocity = Vector3.ZERO
	set_physics_process(false)
	var editable_visual := get_node_or_null("EditableVisual")
	if is_instance_valid(editable_visual):
		editable_visual.set_physics_process(false)
	breathing_sound.stop()
	_dormant_monitor = Timer.new()
	_dormant_monitor.name = "DormantDoorMonitor"
	_dormant_monitor.process_callback = Timer.TIMER_PROCESS_PHYSICS
	# Respuesta inferior a dos fotogramas a 60 Hz sin mantener física/IA activa.
	_dormant_monitor.wait_time = 0.025
	_dormant_monitor.timeout.connect(_poll_dormant_door)
	add_child(_dormant_monitor)
	_dormant_monitor.start()
	_poll_dormant_door()


func _poll_dormant_door() -> void:
	_update_dormant_activation()
	if not _dormant_released:
		return
	if is_instance_valid(_dormant_monitor):
		_dormant_monitor.stop()
	if not breathing_sound.playing:
		breathing_sound.play()
	var editable_visual := get_node_or_null("EditableVisual")
	if is_instance_valid(editable_visual):
		editable_visual.set_physics_process(true)
	set_physics_process(true)


func _finish_navigation_setup() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_cache_light_sources(get_tree().current_scene)
	if is_instance_valid(_player) and _player.has_signal(&"light_switched_on"):
		var light_signal := Callable(self, &"_on_player_switched_on_light")
		if not _player.is_connected(&"light_switched_on", light_signal):
			_player.connect(&"light_switched_on", light_signal)
	if is_instance_valid(_player) and _player.has_signal(&"footstep_heard"):
		var footstep_signal := Callable(self, &"_on_player_footstep_heard")
		if not _player.is_connected(&"footstep_heard", footstep_signal):
			_player.connect(&"footstep_heard", footstep_signal)
	# Durante el horneado usamos puntos relativos transitables como intención,
	# pero no arrancamos una ruta ciega. Cuando el mapa esté listo se proyectan
	# de nuevo y se invalida cualquier camino provisional.
	_patrol_points = [_spawn_position + patrol_offset_a, _spawn_position + patrol_offset_b]
	_patrol_point_index = 0
	_patrol_target = _patrol_points[0]
	_patrol_wait_timer = randf_range(patrol_wait_min, minf(patrol_wait_max, 5.0))
	_patrol_travel_timer = patrol_travel_timeout
	var navigation_wait_frames := 0
	while NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) <= 0 and navigation_wait_frames < 600:
		navigation_wait_frames += 1
		await get_tree().physics_frame
	_navigation_available = NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0
	if not _navigation_available:
		return
	_patrol_points = [
		_snap_to_navigation(_spawn_position + patrol_offset_a),
		_snap_to_navigation(_spawn_position + patrol_offset_b),
	]
	_patrol_point_index = _closest_patrol_point_index()
	_patrol_target = _patrol_points[_patrol_point_index]
	_target_refresh_timer = 0.0


func _physics_process(delta: float) -> void:
	if dormant_until_door_opens and not _dormant_released:
		_update_dormant_activation()
		if not _dormant_released:
			_stop_and_apply_gravity(delta)
			return
	if remain_still:
		_stop_and_apply_gravity(delta)
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
		if not is_instance_valid(_player):
			_stop_and_apply_gravity(delta)
			return
	if bool(get(&"_obstacle_jump_active")):
		_apply_gravity(delta)
		_update_movement(delta)
		move_and_slide()
		_update_animation(delta)
		return
	_prey_refresh_timer = maxf(0.0, _prey_refresh_timer - delta)
	_door_scan_timer = maxf(0.0, _door_scan_timer - delta)
	if _prey_refresh_timer <= 0.0 or not _is_valid_prey(_prey):
		_refresh_preferred_prey()
	# La prioridad infantil esta por encima de luces y del jugador. El modelo
	# importado conserva sus reglas fotosensibles cuando ya no quedan niños.
	if current_state == State.EAT or (is_instance_valid(_prey) and _prey != _player):
		_door_cooldown = maxf(0.0, _door_cooldown - delta)
		_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
		_target_refresh_timer = maxf(0.0, _target_refresh_timer - delta)
		_apply_gravity(delta)
		if current_state == State.EAT:
			_update_eating(delta)
		else:
			if current_state not in [State.CHASE, State.ATTACK]:
				_change_state(State.CHASE)
			_update_perception_cache(delta)
			var sees_child := _cached_sees_prey
			var hears_child := _cached_hears_prey
			_update_awareness(delta, sees_child, hears_child)
			if _door_traversal_active:
				_update_movement(delta)
			elif current_state == State.ATTACK:
				_update_attack(delta)
			else:
				_update_movement(delta)
		_update_frame_duck(delta)
		move_and_slide()
		_try_open_door()
		_update_animation(delta)
		return

	_door_cooldown = maxf(0.0, _door_cooldown - delta)
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	_target_refresh_timer = maxf(0.0, _target_refresh_timer - delta)
	_apply_gravity(delta)
	_light_scan_timer = maxf(0.0, _light_scan_timer - delta)
	if _light_scan_timer <= 0.0:
		_light_scan_timer = LIGHT_SCAN_INTERVAL
		_remove_invalid_light_sources()
		_refresh_light_activation_states(LIGHT_SCAN_INTERVAL)

	# Terminar el ataque comprometido antes de aceptar una distracción.
	if current_state == State.ATTACK:
		_update_attack(delta)
		move_and_slide()
		_update_animation(delta)
		return
	_photo_sense_timer = maxf(0.0, _photo_sense_timer - delta)
	if _photo_sense_timer <= 0.0:
		_photo_sense_timer = perception_interval
		_sees_personal_light = _can_see_flashlight()
		_senses_close_player = _is_player_close_enough()
		_sees_known_player = _player_hunt_active and _can_see_hunted_player()
		_senses_ledge_player = _is_player_on_reachable_ledge()
	var sees_flashlight := _sees_personal_light
	var player_is_close := _senses_close_player
	var position_is_revealed := _update_player_reveal(delta)

	var sees_hunted_player := _player_hunt_active and _sees_known_player

	# El jugador visible siempre manda. Una luz solo distrae cuando ya se ha roto
	# la vision directa, nunca mientras la abuela lo tiene localizado delante.
	if sees_flashlight:
		_focus_flashlight()
	elif player_is_close:
		_focus_close_player()
	elif _senses_ledge_player:
		# Subirse a un muro la sacaba del radar: todas las reglas fotosensibles
		# exigen estar en la misma altura. Ahora un jugador encaramado a su
		# alcance es un estimulo por derecho propio.
		_focus_close_player()
	elif sees_hunted_player:
		_continue_player_hunt(delta)
	elif position_is_revealed:
		_follow_revealed_player()
	elif is_instance_valid(_pending_new_light):
		var new_light := _pending_new_light
		_pending_new_light = null
		_focus_static_light(new_light)
	elif _photo_behavior == PhotoBehavior.STATIC_LIGHT and _is_focused_static_light_active():
		_update_static_light_attention(delta)
	elif _player_hunt_active:
		_continue_player_hunt(delta)
	else:
		_update_lost_stimulus(delta)

	if _door_traversal_active:
		_update_movement(delta)
	elif current_state == State.ATTACK:
		_update_attack(delta)
	else:
		_update_photo_movement(delta)
	_update_frame_duck(delta)
	move_and_slide()
	_try_open_door()
	_update_animation(delta)


func _update_dormant_activation() -> void:
	if not is_instance_valid(_activation_door):
		var scene := get_tree().current_scene
		if scene != null and not activation_door_path.is_empty():
			_activation_door = scene.get_node_or_null(activation_door_path)
	if not is_instance_valid(_activation_door):
		return
	if _activation_door.get("_is_open") == true:
		_dormant_released = true
		_reveal_countdown = reveal_after_seconds
		_return_to_patrol()


func _on_navigation_rebuilt() -> void:
	_patrol_points = [_snap_to_navigation(_spawn_position + patrol_offset_a), _snap_to_navigation(_spawn_position + patrol_offset_b)]
	if _photo_behavior == PhotoBehavior.PATROL:
		_patrol_point_index = _closest_patrol_point_index()
		_patrol_target = _patrol_points[_patrol_point_index]
		_patrol_travel_timer = patrol_travel_timeout


func _focus_flashlight() -> void:
	var live_position := _get_player_light_position()
	if not _flashlight_acquired:
		_flashlight_ignition_position = live_position
	_flashlight_acquired = true
	_last_visible_light_position = live_position
	_light_memory_timer = flashlight_memory_seconds
	_player_hunt_active = true
	_player_loss_timer = _current_player_memory_seconds()
	_photo_behavior = PhotoBehavior.FLASHLIGHT
	_last_known_player_position = _player.global_position
	if current_state != State.ATTACK:
		_set_state(State.CHASE)
		_try_begin_attack()


func _focus_static_light(source: Node3D) -> void:
	_flashlight_acquired = false
	if source != _focused_static_light or _photo_behavior != PhotoBehavior.STATIC_LIGHT:
		_focused_static_light = source
		_static_wander_timer = 0.0
		_static_light_arrived = false
		_static_light_approach_timer = 0.0
		_static_light_attention_timer = static_light_attention_seconds
	_photo_behavior = PhotoBehavior.STATIC_LIGHT
	_light_memory_timer = static_light_memory_seconds
	_set_state(State.INVESTIGATE)


func _focus_close_player() -> void:
	_flashlight_acquired = false
	_photo_behavior = PhotoBehavior.CLOSE_PLAYER
	_close_player_memory_timer = close_player_memory_seconds
	_player_hunt_active = true
	_player_loss_timer = _current_player_memory_seconds()
	_lost_search_timer = lost_player_search_seconds
	_last_known_player_position = _player.global_position
	if current_state != State.ATTACK:
		_set_state(State.CHASE)
		_try_begin_attack()


func _update_lost_stimulus(delta: float) -> void:
	match _photo_behavior:
		PhotoBehavior.FLASHLIGHT:
			_photo_behavior = PhotoBehavior.LIGHT_MEMORY
			var flashlight_is_on := bool(_player.call(&"is_flashlight_on"))
			_last_known_player_position = (
				_last_visible_light_position if flashlight_is_on else _flashlight_ignition_position
			)
			_set_state(State.INVESTIGATE)
		PhotoBehavior.STATIC_LIGHT:
			_photo_behavior = PhotoBehavior.LIGHT_MEMORY
			_light_memory_timer = static_light_memory_seconds
			if is_instance_valid(_focused_static_light):
				_last_known_player_position = _light_ground_position(_focused_static_light)
			_set_state(State.INVESTIGATE)
		PhotoBehavior.LIGHT_MEMORY:
			_light_memory_timer -= delta
			if _light_memory_timer <= 0.0 or global_position.distance_to(_last_known_player_position) < 0.8:
				_return_to_patrol()
		PhotoBehavior.CLOSE_PLAYER:
			_photo_behavior = PhotoBehavior.CLOSE_MEMORY
			_set_state(State.INVESTIGATE)
		PhotoBehavior.CLOSE_MEMORY:
			_update_lost_player_search(delta)
		PhotoBehavior.FOOTSTEP:
			_footstep_interest_timer = maxf(0.0, _footstep_interest_timer - delta)
			if _footstep_interest_timer <= 0.0 or global_position.distance_to(_last_known_player_position) < 0.75:
				_begin_lost_player_search()
		PhotoBehavior.REVEALED_PLAYER:
			_reveal_search_timer = maxf(0.0, _reveal_search_timer - delta)
			_set_state(State.INVESTIGATE)
			if _reveal_search_timer <= 0.0 or global_position.distance_to(_last_known_player_position) < 0.8:
				_return_to_patrol()
		PhotoBehavior.PATROL:
			if _patrol_wait_timer > 0.0:
				_update_patrol_wait(delta)
			else:
				_patrol_travel_timer = maxf(0.0, _patrol_travel_timer - delta)
				if _patrol_travel_timer <= 0.0:
					_begin_patrol_wait()


func _update_photo_movement(delta: float) -> void:
	match _photo_behavior:
		PhotoBehavior.PATROL:
			if _patrol_wait_timer > 0.0:
				_brake_planar(8.0, delta)
				return
			_set_state(State.PATROL)
			_update_movement(delta)
			if global_position.distance_to(_patrol_target) < 0.75:
				_begin_patrol_wait()
		PhotoBehavior.STATIC_LIGHT:
			_update_static_light_wander(delta)
			_last_known_player_position = _patrol_target
			_set_state(State.INVESTIGATE)
			_update_movement(delta)
		PhotoBehavior.FLASHLIGHT:
			_last_known_player_position = _player.global_position
			_set_state(State.CHASE)
			_update_movement(delta)
		PhotoBehavior.LIGHT_MEMORY, PhotoBehavior.CLOSE_MEMORY, PhotoBehavior.FOOTSTEP:
			_set_state(State.SEARCH if _photo_behavior == PhotoBehavior.CLOSE_MEMORY else State.INVESTIGATE)
			_update_movement(delta)
		PhotoBehavior.REVEALED_PLAYER:
			_set_state(State.CHASE if _reveal_live_timer > 0.0 else State.INVESTIGATE)
			_update_movement(delta)
		PhotoBehavior.CLOSE_PLAYER:
			_set_state(State.CHASE)
			_update_movement(delta)


func _update_patrol_wait(delta: float) -> void:
	if _patrol_wait_timer <= 0.0:
		return
	_patrol_wait_timer = maxf(0.0, _patrol_wait_timer - delta)
	if _patrol_wait_timer > 0.0:
		return
	if patrol_roams_house and _choose_roaming_target():
		return
	if not _patrol_points.is_empty():
		_patrol_point_index = (_patrol_point_index + 1) % _patrol_points.size()
		_patrol_target = _patrol_points[_patrol_point_index]
		_patrol_travel_timer = patrol_travel_timeout
		_target_refresh_timer = 0.0


# Elige un destino al azar de toda la malla y comprueba que haya camino hasta el.
# El mapa contiene islas sin conexion con la casa (catacumbas, escuela, tejados):
# sin la comprobacion de ruta se pasaria el temporizador entero caminando contra
# una pared hacia un sitio al que no puede llegar.
func _choose_roaming_target() -> bool:
	if not _navigation_available:
		return false
	var map := get_world_3d().navigation_map
	for _attempt in 12:
		var candidate := NavigationServer3D.map_get_random_point(map, navigation_agent.navigation_layers, false)
		if candidate.distance_to(_spawn_position) > roam_radius:
			continue
		var travel := global_position.distance_to(candidate)
		if travel < roam_minimum_distance:
			continue
		var path := NavigationServer3D.map_get_path(map, global_position, candidate, true)
		if path.size() < 2:
			continue
		# Las puertas cerradas no se hornean, asi que cada habitacion es una isla
		# de navegacion propia y casi ningun destino "se alcanza" segun el mapa.
		# Exigirlo la dejaba encerrada donde apareciera. Basta con que la ruta
		# avance de verdad: el borde de la isla es justo donde esta la puerta, y
		# alli el sistema de travesia la abre y continua al otro lado.
		var reaches_candidate := path[-1].distance_to(candidate) <= 1.0
		if not reaches_candidate and global_position.distance_to(path[-1]) < roam_minimum_distance:
			continue
		_patrol_target = candidate
		# El limite fijo de 10 s solo daba para 8,8 m a velocidad de patrulla, asi
		# que cualquier destino lejano se abortaba a mitad de camino.
		_patrol_travel_timer = clampf(travel / maxf(patrol_speed, 0.1) * 1.8 + 4.0, patrol_travel_timeout, 60.0)
		_target_refresh_timer = 0.0
		return true
	return false


func _begin_patrol_wait() -> void:
	_patrol_wait_timer = randf_range(patrol_wait_min, minf(patrol_wait_max, 5.0))
	_patrol_travel_timer = patrol_travel_timeout


func _return_to_patrol() -> void:
	_photo_behavior = PhotoBehavior.PATROL
	_focused_static_light = null
	_flashlight_acquired = false
	_close_player_memory_timer = 0.0
	_light_memory_timer = 0.0
	_set_state(State.PATROL)
	if patrol_roams_house and _choose_roaming_target():
		pass
	elif _patrol_points.is_empty():
		_patrol_target = _spawn_position
	else:
		_patrol_point_index = _closest_patrol_point_index()
		_patrol_target = _patrol_points[_patrol_point_index]
	_patrol_wait_timer = randf_range(0.25, 1.0)
	_patrol_travel_timer = patrol_travel_timeout
	_target_refresh_timer = 0.0
	_lost_search_timer = 0.0
	_search_step_timer = 0.0


func _update_player_reveal(delta: float) -> bool:
	if not supernatural_player_reveal:
		_reveal_live_timer = 0.0
		return false
	var player_distance := global_position.distance_to(_player.global_position)
	if player_distance <= reveal_reset_distance:
		_reveal_countdown = reveal_after_seconds
		_reveal_live_timer = 0.0
		return false

	if _reveal_live_timer > 0.0:
		_reveal_live_timer = maxf(0.0, _reveal_live_timer - delta)
		_last_known_player_position = _snap_to_navigation(_player.global_position)
		_reveal_search_timer = reveal_search_seconds
		return true

	_reveal_countdown = maxf(0.0, _reveal_countdown - delta)
	if _reveal_countdown > 0.0:
		return false
	_reveal_countdown = reveal_after_seconds
	_reveal_live_timer = reveal_live_seconds
	_reveal_search_timer = reveal_search_seconds
	_last_known_player_position = _snap_to_navigation(_player.global_position)
	_player_hunt_active = false
	_focused_static_light = null
	_photo_behavior = PhotoBehavior.REVEALED_PLAYER
	return true


func _follow_revealed_player() -> void:
	_last_known_player_position = _snap_to_navigation(_player.global_position)
	_reveal_search_timer = reveal_search_seconds
	_photo_behavior = PhotoBehavior.REVEALED_PLAYER
	_set_state(State.CHASE)


func _continue_player_hunt(delta: float) -> void:
	var player_distance := _player_planar_distance()
	var same_floor := absf(_player.global_position.y - global_position.y) <= same_floor_player_tolerance
	var break_distance := (
		player_pursuit_break_distance if _is_player_illuminated()
		else dark_player_pursuit_break_distance
	)
	if not same_floor:
		_begin_lost_player_search()
		return
	if player_distance > break_distance:
		_begin_lost_player_search()
		return

	if _sees_known_player:
		_player_loss_timer = _current_player_memory_seconds()
		_lost_search_timer = lost_player_search_seconds
		_last_known_player_position = _player.global_position
		_photo_behavior = PhotoBehavior.CLOSE_PLAYER
		_set_state(State.CHASE)
		_try_begin_attack()
		return

	_player_loss_timer = maxf(0.0, _player_loss_timer - delta)
	_photo_behavior = PhotoBehavior.CLOSE_MEMORY
	_set_state(State.INVESTIGATE)
	if _player_loss_timer <= 0.0:
		_begin_lost_player_search()


func _begin_lost_player_search() -> void:
	_player_hunt_active = false
	_photo_behavior = PhotoBehavior.CLOSE_MEMORY
	_search_anchor = _snap_to_navigation(_last_known_player_position)
	_lost_search_timer = lost_player_search_seconds
	_search_step_timer = 0.0
	_search_step_index = 0
	_search_anchor_visited = false
	_search_step_timer = 3.0
	_last_known_player_position = _search_anchor
	_set_state(State.SEARCH)
	_target_refresh_timer = 0.0


func _update_lost_player_search(delta: float) -> void:
	_lost_search_timer = maxf(0.0, _lost_search_timer - delta)
	_search_step_timer = maxf(0.0, _search_step_timer - delta)
	if _lost_search_timer <= 0.0:
		_return_to_patrol()
		return
	var arrived := global_position.distance_to(_last_known_player_position) < 0.72
	# Primero llegar al último lugar observado; después detenerse a escuchar.
	if not _search_anchor_visited:
		if not arrived and _search_step_timer > 0.0:
			return
		_search_anchor_visited = true
		_search_step_timer = 0.65
		return
	if _search_step_timer > 0.0:
		return
	var search_angles := [0.0, 2.35, -2.35, 1.15, -1.15, PI]
	var angle: float = search_angles[_search_step_index % search_angles.size()]
	var radius := search_sweep_radius * (0.62 + 0.38 * float((_search_step_index % 3) + 1) / 3.0)
	var candidate := _snap_to_navigation(_search_anchor + Vector3(cos(angle), 0.0, sin(angle)) * radius)
	if _navigation_available:
		var path := NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, candidate, true)
		if path.is_empty() or path[-1].distance_to(candidate) > 0.75 or absf(candidate.y - _search_anchor.y) > 1.0:
			_search_step_index += 1
			_search_step_timer = 0.2
			return
	_last_known_player_position = candidate
	_search_step_index += 1
	_search_step_timer = search_step_seconds
	_target_refresh_timer = 0.0


func _give_up_unreachable_target() -> void:
	# La capa fotosensible vuelve a fijar el mismo estímulo en cuanto la base se
	# rinde, así que aquí hay que consumirlo: una luz a la que no hay ruta pasa a
	# la lista de ignoradas y un jugador inalcanzable se convierte en búsqueda.
	if _photo_behavior == PhotoBehavior.STATIC_LIGHT and is_instance_valid(_focused_static_light):
		_ignored_light_ids[_focused_static_light.get_instance_id()] = true
		_focused_static_light = null
		_return_to_patrol()
		return
	if _player_hunt_active or _photo_behavior in [
		PhotoBehavior.FLASHLIGHT, PhotoBehavior.CLOSE_PLAYER, PhotoBehavior.REVEALED_PLAYER
	]:
		_begin_lost_player_search()
		return
	_return_to_patrol()


func _update_static_light_attention(delta: float) -> void:
	if not is_instance_valid(_focused_static_light):
		_return_to_patrol()
		return
	# Son cinco segundos totales desde que la luz capta su atencion. No depende
	# de alcanzar el punto, evitando que mobiliario o navegacion la bloqueen.
	_static_light_attention_timer = maxf(0.0, _static_light_attention_timer - delta)
	if _static_light_attention_timer > 0.0:
		return
	_ignored_light_ids[_focused_static_light.get_instance_id()] = true
	_focused_static_light = null
	_return_to_patrol()


func _on_player_switched_on_light(source: Node3D) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(source):
		return
	if absf(_player.global_position.y - global_position.y) > same_floor_player_tolerance:
		return
	if global_position.distance_to(_player.global_position) > light_detection_distance:
		return
	if not _has_clear_line_to(_player.global_position + Vector3.UP, _player):
		return
	# Si ha visto al jugador accionar el interruptor, el jugador es el estímulo;
	# esa luz queda consumida hasta que vuelva a apagarse y encenderse.
	var source_id := source.get_instance_id()
	_ignored_light_ids[source_id] = true
	_light_on_states[source_id] = true
	_pending_new_light = null
	_focus_close_player()


func _on_player_footstep_heard(step_position: Vector3, hearing_radius: float) -> void:
	if current_state in [State.ATTACK, State.EAT]:
		return
	if _player_hunt_active or _photo_behavior in [PhotoBehavior.STATIC_LIGHT, PhotoBehavior.FLASHLIGHT]:
		return
	if absf(step_position.y - global_position.y) > same_floor_player_tolerance:
		return
	var sound_distance := global_position.distance_to(step_position)
	if sound_distance > hearing_radius:
		return
	# Las paredes amortiguan los pasos, pero no convierten la casa en silencio.
	if sound_distance > hearing_radius * 0.55 and not _has_clear_line_between(global_position + Vector3.UP, step_position + Vector3.UP, _player):
		return
	_last_known_player_position = _snap_to_navigation(step_position)
	_footstep_interest_timer = clampf(sound_distance / maxf(investigate_speed, 0.1) + 0.8, footstep_interest_seconds, 6.0)
	_target_refresh_timer = 0.0
	_photo_behavior = PhotoBehavior.FOOTSTEP
	_set_state(State.INVESTIGATE)


func _update_static_light_wander(delta: float) -> void:
	if not is_instance_valid(_focused_static_light):
		return
	_static_wander_timer = maxf(0.0, _static_wander_timer - delta)
	if _static_wander_timer > 0.0 and global_position.distance_to(_patrol_target) > 0.7:
		return
	_static_wander_timer = randf_range(1.2, 3.4)
	var center := _light_ground_position(_focused_static_light)
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.25, light_wander_radius)
	_patrol_target = _snap_to_navigation(center + offset)
	_target_refresh_timer = 0.0


func _try_begin_attack() -> void:
	if _has_attack_contact(attack_distance + 0.18) and can_begin_attack():
		_set_state(State.ATTACK)


func _set_state(state: State) -> void:
	if current_state != state:
		_change_state(state)


func _is_player_close_enough() -> bool:
	return (
		absf(_player.global_position.y - global_position.y) <= same_floor_player_tolerance
		and _player_planar_distance() <= close_player_distance
		and _has_clear_line_to(_player.global_position + Vector3.UP * 0.85, _player)
	)


# Un jugador encaramado esta fuera de `same_floor_player_tolerance`, pero si lo
# tiene justo encima y a su alcance no deberia ignorarlo: se planta debajo y
# sacude. El radio es generoso para que llegue a acercarse desde media sala.
func _is_player_on_reachable_ledge() -> bool:
	if not is_instance_valid(_player):
		return false
	var height := _player.global_position.y - global_position.y
	if height <= same_floor_player_tolerance or height > ledge_reach_height:
		return false
	if _player_planar_distance() > ledge_detection_distance:
		return false
	return _has_clear_line_to(_player.global_position + Vector3.UP * 0.5, _player)


func _can_see_hunted_player() -> bool:
	if not is_instance_valid(_player):
		return false
	if absf(_player.global_position.y - global_position.y) > same_floor_player_tolerance:
		return false
	var break_distance := (
		player_pursuit_break_distance if _is_player_illuminated()
		else dark_player_pursuit_break_distance
	)
	if global_position.distance_to(_player.global_position) > break_distance:
		return false
	return _has_clear_line_to(_player.global_position + Vector3.UP, _player)


func _current_player_memory_seconds() -> float:
	return player_hidden_memory_seconds if _is_player_illuminated() else dark_player_hidden_memory_seconds


func _is_player_illuminated() -> bool:
	if _player.has_method(&"is_personal_light_on") and bool(_player.call(&"is_personal_light_on")):
		return true
	if _player.has_method(&"is_flashlight_on") and bool(_player.call(&"is_flashlight_on")):
		return true
	var player_light_position := _player.global_position + Vector3.UP
	for source in _light_sources:
		if not is_instance_valid(source) or not bool(source.get("is_on")):
			continue
		var emission := _find_visible_emission(source)
		if emission == null:
			continue
		var effective_range := 0.0
		if emission is OmniLight3D:
			effective_range = (emission as OmniLight3D).omni_range
		elif emission is SpotLight3D:
			effective_range = (emission as SpotLight3D).spot_range
		if effective_range <= 0.0 or emission.global_position.distance_to(player_light_position) > effective_range:
			continue
		if _has_clear_line_between(player_light_position, emission.global_position, source):
			return true
	return false


func _can_see_flashlight() -> bool:
	var has_personal_light := (
		_player.has_method(&"is_personal_light_on")
		and bool(_player.call(&"is_personal_light_on"))
	)
	if not has_personal_light and (not _player.has_method(&"is_flashlight_on") or not bool(_player.call(&"is_flashlight_on"))):
		return false
	var light_position := _get_player_light_position()
	if absf(_player.global_position.y - global_position.y) > same_floor_player_tolerance:
		return false
	if global_position.distance_to(light_position) > light_detection_distance:
		return false
	return _has_clear_line_to(light_position, _player)


func _get_player_light_position() -> Vector3:
	if _player.has_method(&"get_personal_light_world_position"):
		return _player.call(&"get_personal_light_world_position") as Vector3
	if _player.has_method(&"get_flashlight_world_position"):
		return _player.call(&"get_flashlight_world_position") as Vector3
	return _player.global_position + Vector3.UP


func _find_best_visible_static_light() -> Node3D:
	var best_source: Node3D
	var best_distance := INF
	for source in _light_sources:
		if not is_instance_valid(source) or not bool(source.get("is_on")):
			continue
		var emission := _find_visible_emission(source)
		if emission == null:
			continue
		var source_position := emission.global_position
		var distance := global_position.distance_to(source_position)
		if distance > light_detection_distance or distance >= best_distance:
			continue
		if absf(source_position.y - global_position.y) > same_floor_light_tolerance:
			continue
		if not _has_clear_line_to(source_position, source):
			continue
		best_source = source
		best_distance = distance
	return best_source


func _refresh_light_activation_states(elapsed: float) -> void:
	var best_new_light: Node3D
	var best_distance := INF
	for source in _light_sources:
		if not is_instance_valid(source):
			continue
		var source_id := source.get_instance_id()
		# Un parpadeo no es un interruptor, y la lámpara ya distingue ambos: el
		# interruptor vive en `is_on`, el apagón de flickering_light.gd sólo pone
		# la emisión a cero. Accionar el interruptor cuenta al instante; una
		# bombilla que titila con el interruptor puesto sigue contando como
		# encendida hasta `light_off_confirm_seconds`. Sin esta distinción cada
		# apagón se leía como lámpara nueva y le reiniciaba la atención, dejándola
		# clavada delante de una luz parpadeante para siempre.
		var switch_on := bool(source.get("is_on"))
		var is_emitting := switch_on and _find_visible_emission(source) != null
		if is_emitting or not switch_on:
			_light_dark_seconds[source_id] = 0.0
		else:
			_light_dark_seconds[source_id] = float(_light_dark_seconds.get(source_id, 0.0)) + elapsed
		var is_on := is_emitting or (
			switch_on and float(_light_dark_seconds[source_id]) < light_off_confirm_seconds
		)
		var was_on := bool(_light_on_states.get(source_id, false))
		_light_on_states[source_id] = is_on
		if not is_on:
			_ignored_light_ids.erase(source_id)
			continue
		if not is_emitting:
			continue
		if was_on or _ignored_light_ids.has(source_id) or not _is_static_source_visible(source):
			continue
		var distance := global_position.distance_to(source.global_position)
		if distance < best_distance:
			best_distance = distance
			best_new_light = source
	if is_instance_valid(best_new_light):
		_pending_new_light = best_new_light


func _is_static_source_visible(source: Node3D) -> bool:
	var emission := _find_visible_emission(source)
	if emission == null:
		return false
	var source_position := emission.global_position
	if global_position.distance_to(source_position) > light_detection_distance:
		return false
	if absf(source_position.y - global_position.y) > same_floor_light_tolerance:
		return false
	return _has_clear_line_to(source_position, source)


func _is_focused_static_light_active() -> bool:
	# Se apoya en el estado antirrebote, no en la emisión instantánea: si no, un
	# apagón de parpadeo la mandaba a LIGHT_MEMORY y al volver la luz reentraba
	# por la rama de luz nueva.
	return (
		is_instance_valid(_focused_static_light)
		and bool(_focused_static_light.get("is_on"))
		and bool(_light_on_states.get(_focused_static_light.get_instance_id(), false))
	)


func _find_visible_emission(node: Node) -> Light3D:
	if node is Light3D:
		var light := node as Light3D
		if light.visible and light.light_energy > 0.01:
			return light
	for child in node.get_children():
		var found := _find_visible_emission(child)
		if found != null:
			return found
	return null


func _has_clear_line_to(target_position: Vector3, target_node: Node) -> bool:
	var eye_position := global_position + Vector3.UP * 2.2
	return _has_clear_line_between(eye_position, target_position, target_node)


func _has_clear_line_between(from_position: Vector3, target_position: Vector3, target_node: Node) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from_position, target_position, 1)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider := result.get("collider") as Node
	return (
		collider != null
		and (collider == target_node or (target_node != null and target_node.is_ancestor_of(collider)))
	)


func _cache_light_sources(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is Node3D and node.has_method(&"set_lamp_enabled"):
		_light_sources.append(node as Node3D)
	for child in node.get_children():
		_cache_light_sources(child)


func _remove_invalid_light_sources() -> void:
	for index in range(_light_sources.size() - 1, -1, -1):
		if not is_instance_valid(_light_sources[index]):
			_light_sources.remove_at(index)


func _light_ground_position(source: Node3D) -> Vector3:
	var attraction_point := source.get_node_or_null("GrandmotherAttractionPoint") as Node3D
	var reference := attraction_point.global_position if attraction_point != null else source.global_position
	return _snap_to_navigation(Vector3(reference.x, global_position.y, reference.z))


func _snap_to_navigation(point: Vector3) -> Vector3:
	if not _navigation_available:
		return point
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)


func _closest_patrol_point_index() -> int:
	var closest_index := 0
	var closest_distance := INF
	for index in _patrol_points.size():
		var distance := global_position.distance_squared_to(_patrol_points[index])
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.2


func _stop_and_apply_gravity(delta: float) -> void:
	_apply_gravity(delta)
	_brake_planar(12.0, delta)
	move_and_slide()
	_update_animation(delta)


func _update_frame_duck(_delta: float) -> void:
	_duck_amount = 0.0
	_duck_hold_timer = 0.0
