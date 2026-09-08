extends CharacterBody3D

enum Behavior {
	FLEE_PLAYER,
	WANDER,
	STAY_STILL,
}

@export_category("Comportamiento")
@export var behavior: Behavior = Behavior.FLEE_PLAYER
@export_range(1.0, 12.0, 0.1) var run_speed := 4.3
@export_range(0.5, 20.0, 0.5) var player_detection_distance := 9.0
@export_range(0.2, 4.0, 0.1) var direction_min_time := 0.32
@export_range(0.2, 5.0, 0.1) var direction_max_time := 0.95
@export_range(0.5, 6.0, 0.1) var obstacle_probe_distance := 1.25
@export_flags_3d_physics var world_collision_mask := 1
@export_category("Reaccion a luces recien encendidas")
@export_range(1.0, 20.0, 0.5) var new_light_reaction_distance := 8.0
@export_range(0.1, 5.0, 0.1) var new_light_reaction_seconds := 2.0
@export_category("Referencias opcionales")
@export_node_path("Node3D") var player_path: NodePath
@export_node_path("Node3D") var escape_target_path: NodePath
@export var escape_waypoint_paths: Array[NodePath] = []
@export_range(0.0, 3.0, 0.05) var escape_delay := 0.85
@export_category("Audio")
@export_range(-40.0, 6.0, 0.5) var volumen_susto_db := -1.5
@export_range(-40.0, 6.0, 0.5) var volumen_normal_min_db := -12.0
@export_range(-40.0, 6.0, 0.5) var volumen_normal_max_db := -9.0

@onready var visual: Node3D = $Visual
@onready var tail: Node3D = $Visual/Tail
@onready var rat_sound: AudioStreamPlayer3D = $RatSound

var _player: Node3D
var _travel_direction := Vector3.ZERO
var _decision_timer := 0.0
var _obstacle_check_timer := 0.0
var _recent_light_position := Vector3.ZERO
var _recent_light_timer := 0.0
var _motion_time := 0.0
var _gravity := 9.8
var _scripted_escape := false
var _escape_triggered := false
var _escape_waypoint_index := 0
var _escape_detour_timer := 0.0
var _last_motion_position := Vector3.ZERO
var _stuck_time := 0.0
var _sound_timer := 0.0
var _scare_sound_pending := false
var _waiting_for_scripted_reveal := false


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_find_player()
	_choose_direction()
	_last_motion_position = global_position
	_waiting_for_scripted_reveal = behavior == Behavior.STAY_STILL and not escape_target_path.is_empty()
	_sound_timer = randf_range(5.0, 14.0)
	if _waiting_for_scripted_reveal:
		# La rata de la trampilla no necesita física, sensores, animación ni audio
		# mientras espera una señal que puede recibirse aunque el proceso esté parado.
		velocity = Vector3.ZERO
		rat_sound.stop()
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	_find_player()
	_update_rat_sound(delta)
	_recent_light_timer = maxf(0.0, _recent_light_timer - delta)

	if _scripted_escape:
		_update_scripted_escape(delta)
	elif behavior == Behavior.STAY_STILL:
		velocity.x = move_toward(velocity.x, 0.0, run_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, run_speed * 8.0 * delta)
	else:
		_decision_timer -= delta
		_obstacle_check_timer -= delta
		var obstacle_check_due := _obstacle_check_timer <= 0.0
		var path_is_blocked := false
		if obstacle_check_due:
			_obstacle_check_timer = 0.1
			path_is_blocked = _path_blocked(_travel_direction)
		if _decision_timer <= 0.0 or _travel_direction.is_zero_approx() or path_is_blocked:
			_choose_direction()
		velocity.x = _travel_direction.x * run_speed
		velocity.z = _travel_direction.z * run_speed

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.15
	move_and_slide()
	_update_stuck_recovery(delta)
	if _hit_wall_this_frame():
		if _scripted_escape:
			_escape_detour_timer = 0.0
		else:
			# Reacciona al impacto inmediatamente; no pasa otro frame empujando
			# contra el mueble o la pared.
			_travel_direction = _choose_emergency_direction()
			_decision_timer = randf_range(0.3, 0.52)
	_animate_rat(delta)


func _update_stuck_recovery(delta: float) -> void:
	var horizontal_travel := Vector2(
		global_position.x - _last_motion_position.x,
		global_position.z - _last_motion_position.z
	).length()
	_last_motion_position = global_position
	var trying_to_move := Vector2(velocity.x, velocity.z).length() > run_speed * 0.35
	if trying_to_move and horizontal_travel < run_speed * delta * 0.16:
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.5)
	var recovery_time := 0.12 if _player_is_close() else 0.24
	if _stuck_time < recovery_time:
		return
	_stuck_time = 0.0
	# Busca una salida comprobada en vez de girar a ciegas hacia otra pared.
	_travel_direction = _choose_emergency_direction()
	if _scripted_escape:
		_escape_detour_timer = 0.65
	else:
		_decision_timer = randf_range(0.22, 0.48)


func set_behavior(new_behavior: Behavior) -> void:
	behavior = new_behavior
	_decision_timer = 0.0


func set_fleeing_enabled(enabled: bool) -> void:
	behavior = Behavior.FLEE_PLAYER if enabled else Behavior.WANDER
	_decision_timer = 0.0


func _on_escape_triggered() -> void:
	if _escape_triggered:
		return
	_escape_triggered = true
	behavior = Behavior.STAY_STILL
	await get_tree().create_timer(escape_delay).timeout
	if not is_inside_tree():
		return
	_escape_waypoint_index = 0
	_scripted_escape = true
	_waiting_for_scripted_reveal = false
	set_physics_process(true)
	_scare_sound_pending = true
	_sound_timer = 1.0


func _update_rat_sound(delta: float) -> void:
	if _waiting_for_scripted_reveal or rat_sound.stream == null:
		return
	_sound_timer -= delta
	if _sound_timer > 0.0:
		return
	if _scare_sound_pending:
		_scare_sound_pending = false
		rat_sound.volume_db = volumen_susto_db
		rat_sound.pitch_scale = 1.03
	else:
		rat_sound.volume_db = randf_range(
			minf(volumen_normal_min_db, volumen_normal_max_db),
			maxf(volumen_normal_min_db, volumen_normal_max_db)
		)
		rat_sound.pitch_scale = randf_range(0.94, 1.06)
	rat_sound.play()
	# El clip ya dura unos 13 s. Dejamos una pausa amplia después para que la
	# rata siga teniendo presencia sin convertirse en una alarma repetitiva.
	_sound_timer = rat_sound.stream.get_length() + randf_range(14.0, 28.0)


func _update_scripted_escape(delta: float) -> void:
	var target: Node3D
	if _escape_waypoint_index < escape_waypoint_paths.size():
		target = get_node_or_null(escape_waypoint_paths[_escape_waypoint_index]) as Node3D
	else:
		target = get_node_or_null(escape_target_path) as Node3D
	if target == null:
		_scripted_escape = false
		behavior = Behavior.WANDER
		_decision_timer = 0.0
		return
	var toward_target := target.global_position - global_position
	toward_target.y = 0.0
	if toward_target.length() <= 0.3:
		if _escape_waypoint_index < escape_waypoint_paths.size():
			_escape_waypoint_index += 1
			return
		_scripted_escape = false
		behavior = Behavior.WANDER
		_decision_timer = 0.0
		_choose_direction()
		return
	var desired_direction := toward_target.normalized()
	_escape_detour_timer = maxf(0.0, _escape_detour_timer - delta)
	if _escape_detour_timer <= 0.0 or _path_blocked(_travel_direction):
		if _direction_clearance(desired_direction) < 0.52:
			# Si un objeto ocupa exactamente un punto intermedio, no insistimos en
			# alcanzar su centro: lo damos por rodeado cuando ya estamos cerca.
			if toward_target.length() < 1.15 and _escape_waypoint_index < escape_waypoint_paths.size():
				_escape_waypoint_index += 1
				return
			_travel_direction = _choose_escape_detour(desired_direction)
			_escape_detour_timer = 0.58
		else:
			_travel_direction = desired_direction
	velocity.x = _travel_direction.x * run_speed
	velocity.z = _travel_direction.z * run_speed


func _choose_escape_detour(desired_direction: Vector3) -> Vector3:
	var best_direction := -desired_direction
	var best_score := -INF
	# Prueba ambos lados del obstáculo. La puntuación prioriza espacio libre,
	# suelo válido y seguir avanzando hacia el siguiente punto de la ruta.
	for angle_degrees in [38.0, -38.0, 62.0, -62.0, 88.0, -88.0, 118.0, -118.0]:
		var candidate := desired_direction.rotated(Vector3.UP, deg_to_rad(angle_degrees)).normalized()
		var clearance := _direction_clearance(candidate)
		if clearance < 0.14 or not _has_floor_ahead(candidate):
			continue
		var score := clearance * 4.0 + candidate.dot(desired_direction) * 1.4
		if score > best_score:
			best_score = score
			best_direction = candidate
	return best_direction.normalized()


func _hit_wall_this_frame() -> bool:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		# El suelo también aparece como colisión de deslizamiento; solo las
		# normales casi horizontales representan muebles o paredes.
		if absf(collision.get_normal().dot(Vector3.UP)) < 0.65:
			return true
	return false


func _find_player() -> void:
	if is_instance_valid(_player):
		_connect_player_signals()
		return
	if not player_path.is_empty():
		_player = get_node_or_null(player_path) as Node3D
	if _player == null and get_tree().current_scene != null:
		_player = get_tree().current_scene.find_child("Player", true, false) as Node3D
	if _player is PhysicsBody3D:
		add_collision_exception_with(_player as PhysicsBody3D)
	_connect_player_signals()


func _connect_player_signals() -> void:
	if not is_instance_valid(_player) or not _player.has_signal(&"light_switched_on"):
		return
	var callback := Callable(self, &"_on_light_switched_on")
	if not _player.is_connected(&"light_switched_on", callback):
		_player.connect(&"light_switched_on", callback)


func _on_light_switched_on(source: Node3D) -> void:
	if not is_instance_valid(source):
		return
	var offset := global_position - source.global_position
	offset.y = 0.0
	if offset.length() > new_light_reaction_distance:
		return
	_recent_light_position = source.global_position
	_recent_light_timer = new_light_reaction_seconds
	_decision_timer = 0.0


func _choose_direction() -> void:
	_decision_timer = randf_range(direction_min_time, maxf(direction_min_time, direction_max_time))
	var base_angle := randf_range(-PI, PI)
	var player_is_close := false
	if behavior == Behavior.FLEE_PLAYER and is_instance_valid(_player):
		var away := global_position - _player.global_position
		away.y = 0.0
		player_is_close = away.length() <= player_detection_distance
		if player_is_close and away.length_squared() > 0.001:
			base_angle = atan2(away.x, away.z) + randf_range(-0.72, 0.72)

	var best_direction := Vector3.ZERO
	var best_score := -INF
	for index in 10:
		var offset := (float(index) / 10.0) * TAU
		var angle := base_angle + offset
		var candidate := Vector3(sin(angle), 0.0, cos(angle)).normalized()
		var clearance := _direction_clearance(candidate)
		var required_clearance := 0.48 if player_is_close else 0.2
		if clearance <= required_clearance or not _has_floor_ahead(candidate):
			continue
		var score := clearance * (6.5 if player_is_close else 2.8)
		if player_is_close:
			var away_direction := global_position - _player.global_position
			away_direction.y = 0.0
			score += candidate.dot(away_direction.normalized()) * 7.2
			score += randf_range(-1.6, 1.6)
		else:
			score += randf_range(-1.8, 1.8)
		if _recent_light_timer > 0.0:
			var away_from_light := global_position - _recent_light_position
			away_from_light.y = 0.0
			if not away_from_light.is_zero_approx():
				score += candidate.dot(away_from_light.normalized()) * 6.0
		if not _travel_direction.is_zero_approx():
			score += candidate.dot(_travel_direction) * 0.85
		if score > best_score:
			best_score = score
			best_direction = candidate

	if best_direction.is_zero_approx():
		best_direction = _choose_emergency_direction()
	_travel_direction = best_direction.normalized()


func _player_is_close() -> bool:
	if not is_instance_valid(_player):
		return false
	var flat_offset := global_position - _player.global_position
	flat_offset.y = 0.0
	return flat_offset.length() <= player_detection_distance


func _choose_emergency_direction() -> Vector3:
	var away_from_player := -_travel_direction
	if is_instance_valid(_player):
		away_from_player = global_position - _player.global_position
		away_from_player.y = 0.0
		if away_from_player.length_squared() > 0.001:
			away_from_player = away_from_player.normalized()
	var best_direction := Vector3.ZERO
	var best_score := -INF
	for index in 12:
		var angle := (float(index) / 12.0) * TAU + randf_range(-0.08, 0.08)
		var candidate := Vector3(sin(angle), 0.0, cos(angle))
		var clearance := _direction_clearance(candidate)
		if clearance < 0.38 or not _has_floor_ahead(candidate):
			continue
		var score := clearance * 9.0 + candidate.dot(away_from_player) * 6.5
		if not _travel_direction.is_zero_approx():
			score += candidate.dot(_travel_direction) * 0.45
		score += randf_range(-0.35, 0.35)
		if score > best_score:
			best_score = score
			best_direction = candidate
	if best_direction.is_zero_approx():
		best_direction = away_from_player if not away_from_player.is_zero_approx() else Vector3.FORWARD
	return best_direction.normalized()


func _direction_clearance(direction: Vector3) -> float:
	var world := get_world_3d()
	if world == null or direction.is_zero_approx():
		return 0.0
	var start := global_position + Vector3.UP * 0.16
	var exclusions: Array[RID] = [get_rid()]
	if _player is CollisionObject3D:
		exclusions.append((_player as CollisionObject3D).get_rid())
	# El collider ahora es redondo, por lo que un único sensor central basta. Las
	# colisiones laterales siguen provocando la salida de emergencia inmediata.
	var query := PhysicsRayQueryParameters3D.create(
		start,
		start + direction * obstacle_probe_distance,
		world_collision_mask,
		exclusions
	)
	query.collide_with_areas = false
	query.hit_from_inside = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	return clampf(start.distance_to(hit.position) / obstacle_probe_distance, 0.0, 1.0)


func _path_blocked(direction: Vector3) -> bool:
	return _direction_clearance(direction) < 0.34 or not _has_floor_ahead(direction)


func _has_floor_ahead(direction: Vector3) -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var start := global_position + direction * 0.62 + Vector3.UP * 0.35
	var exclusions: Array[RID] = [get_rid()]
	if _player is CollisionObject3D:
		exclusions.append((_player as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(
		start,
		start + Vector3.DOWN * 1.25,
		world_collision_mask,
		exclusions
	)
	query.collide_with_areas = false
	return not world.direct_space_state.intersect_ray(query).is_empty()


func _animate_rat(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.1:
		_motion_time += delta * horizontal_speed * 4.2
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-_travel_direction.x, -_travel_direction.z), minf(1.0, delta * 18.0))
		visual.position.y = 0.13 + absf(sin(_motion_time)) * 0.018
		tail.rotation.y = sin(_motion_time * 0.72) * 0.22
	else:
		visual.position.y = move_toward(visual.position.y, 0.13, delta * 0.2)
