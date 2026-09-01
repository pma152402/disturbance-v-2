extends CharacterBody3D

enum MovementMode { DORMANT, GROUND, CLIMBING_WALL, CEILING, DROPPING, ATTACK }

@export var ground_speed := 2.15
@export var ceiling_speed := 2.75
@export var climb_speed := 1.65
@export var scuttle_speed_multiplier := 2.4
@export var scuttle_move_interval := Vector2(1.05, 1.75)
@export var scuttle_pause_interval := Vector2(1.6, 2.9)
@export var ceiling_standoff_distance := 2.7
@export var ceiling_surface_offset := 0.38
@export var vision_distance := 19.0
@export var hearing_distance := 10.0
@export var attack_distance := 1.15
@export var activation_distance := 14.0
@export var climb_min_distance := 5.0
@export var stuck_check_interval := 0.8
@export var max_wall_climb_time := 4.5
@export var starts_dormant := true
@export var starts_on_ceiling := true

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var body_collision: CollisionShape3D = $Collision
@onready var model: Node3D = $Model
@onready var body_rig: Node3D = $Model/BodyRig
@onready var head_rig: Node3D = $Model/BodyRig/HeadRig
@onready var front_left: Node3D = $Model/BodyRig/FrontLeftLimb
@onready var front_right: Node3D = $Model/BodyRig/FrontRightLimb
@onready var rear_left: Node3D = $Model/BodyRig/RearLeftLimb
@onready var rear_right: Node3D = $Model/BodyRig/RearRightLimb
@onready var front_left_joint: Node3D = $Model/BodyRig/FrontLeftLimb/Joint
@onready var front_right_joint: Node3D = $Model/BodyRig/FrontRightLimb/Joint
@onready var rear_left_joint: Node3D = $Model/BodyRig/RearLeftLimb/Joint
@onready var rear_right_joint: Node3D = $Model/BodyRig/RearRightLimb/Joint
@onready var wall_ray: RayCast3D = $WallRay
@onready var ceiling_ray: RayCast3D = $CeilingRay
@onready var sight_ray: RayCast3D = $SightRay
@onready var door_ray: RayCast3D = $DoorRay
@onready var skitter_sound: AudioStreamPlayer3D = $SkitterSound
@onready var breathing_sound: AudioStreamPlayer3D = $BreathingSound

var movement_mode := MovementMode.DORMANT
var _player: CharacterBody3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _target_refresh := 0.0
var _climb_cooldown := 2.0
var _door_cooldown := 0.0
var _ceiling_lost_timer := 0.0
var _ceiling_y := 0.0
var _last_valid_ceiling_position := Vector3.ZERO
var _wall_normal := Vector3.ZERO
var _wall_point := Vector3.ZERO
var _wall_climb_timer := 0.0
var _wall_progress_timer := 0.0
var _wall_last_height := 0.0
var _progress_timer := 0.0
var _last_progress_position := Vector3.ZERO
var _stuck_cycles := 0
var _recovery_timer := 0.0
var _recovery_direction := Vector3.ZERO
var _scuttle_active := true
var _scuttle_timer := 0.65
var _scuttle_speed_scale := 1.0
var _last_player_ceiling_position := Vector3.ZERO
var _ceiling_target_valid := false
var _motion_phase := 0.0
var _attack_timer := 0.0
var _attack_applied := false
var _last_step := -1


func _ready() -> void:
	add_to_group(&"monster")
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if starts_on_ceiling:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		# El cuerpo visual se invierte alrededor de la raiz. El collider debe quedar
		# justo bajo el techo; con el desplazamiento de suelo (+0.64) atravesaba la
		# losa y la fisica terminaba expulsando al monstruo por arriba.
		body_collision.position.y = 0.06
		ceiling_ray.force_raycast_update()
		var initial_ceiling_gap := INF
		if ceiling_ray.is_colliding():
			initial_ceiling_gap = ceiling_ray.get_collision_point().y - global_position.y
		if initial_ceiling_gap >= 0.12 and initial_ceiling_gap <= 1.0:
			_ceiling_y = ceiling_ray.get_collision_point().y - ceiling_surface_offset
			global_position.y = _ceiling_y
		else:
			_ceiling_y = global_position.y
		model.rotation.x = PI
		_last_valid_ceiling_position = global_position
		movement_mode = MovementMode.DORMANT if starts_dormant else MovementMode.CEILING
	else:
		movement_mode = MovementMode.DORMANT if starts_dormant else MovementMode.GROUND
	navigation_agent.avoidance_enabled = false
	_last_progress_position = global_position
	skitter_sound.stream = _make_creature_sound(0.14, 72.0, 0.5, false)
	breathing_sound.stream = _make_creature_sound(2.4, 39.0, 0.18, true)
	breathing_sound.play()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
		if not is_instance_valid(_player):
			return

	_target_refresh = maxf(0.0, _target_refresh - delta)
	_climb_cooldown = maxf(0.0, _climb_cooldown - delta)
	_door_cooldown = maxf(0.0, _door_cooldown - delta)
	_recovery_timer = maxf(0.0, _recovery_timer - delta)

	match movement_mode:
		MovementMode.DORMANT:
			_update_dormant(delta)
		MovementMode.GROUND:
			_update_ground(delta)
		MovementMode.CLIMBING_WALL:
			_update_wall_climb(delta)
		MovementMode.CEILING:
			_update_ceiling(delta)
		MovementMode.DROPPING:
			_update_drop(delta)
		MovementMode.ATTACK:
			_update_attack(delta)

	_update_pose(delta)


func _update_dormant(delta: float) -> void:
	velocity = Vector3.ZERO
	if starts_on_ceiling:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		global_position.y = _ceiling_y
	var player_offset := _player.global_position - global_position
	var allowed_vertical_distance := 4.2 if starts_on_ceiling else 2.0
	var close_on_same_floor := (
		Vector2(player_offset.x, player_offset.z).length() <= activation_distance
		and absf(player_offset.y) <= allowed_vertical_distance
	)
	if close_on_same_floor:
		movement_mode = MovementMode.CEILING if starts_on_ceiling else MovementMode.GROUND
		_ceiling_lost_timer = 0.0
		_scuttle_active = true
		_scuttle_timer = randf_range(scuttle_move_interval.x, scuttle_move_interval.y)
		_scuttle_speed_scale = randf_range(0.9, 1.12)
		if starts_on_ceiling:
			_capture_player_ceiling_position()
	var look := _player.global_position - global_position
	look.y = 0.0
	if look.length_squared() > 0.01:
		var ceiling_yaw_offset := PI if starts_on_ceiling else 0.0
		rotation.y = lerp_angle(
			rotation.y,
			atan2(look.x, look.z) + ceiling_yaw_offset,
			minf(delta * 2.0, 1.0)
		)


func _update_ground(delta: float) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.3

	var target := _player.global_position
	if _target_refresh <= 0.0:
		_target_refresh = 0.2
		navigation_agent.target_position = target

	var direction := Vector3.ZERO
	var current_path: PackedVector3Array = navigation_agent.get_current_navigation_path()
	var has_navigation_path := current_path.size() >= 2 and not navigation_agent.is_navigation_finished()
	if has_navigation_path:
		direction = navigation_agent.get_next_path_position() - global_position
	elif absf(target.y - global_position.y) <= 1.6 and _has_line_of_sight():
		# Solo perseguimos en linea recta cuando realmente vemos al jugador. Una
		# ruta vacia nunca debe convertir una pared en el siguiente objetivo.
		direction = target - global_position
	direction.y = 0.0
	if _recovery_timer > 0.0 and _recovery_direction.length_squared() > 0.01:
		direction = _recovery_direction
	var scuttling := _update_scuttle_cycle(delta)
	if direction.length_squared() > 0.02 and scuttling:
		direction = direction.normalized()
		var burst_speed := ground_speed * scuttle_speed_multiplier * _scuttle_speed_scale
		velocity.x = move_toward(velocity.x, direction.x * burst_speed, delta * 26.0)
		velocity.z = move_toward(velocity.z, direction.z * burst_speed, delta * 26.0)
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(delta * 8.0, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
		if direction.length_squared() > 0.02:
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(delta * 4.5, 1.0))
	move_and_slide()
	_try_open_door()
	_update_ground_recovery(delta, direction if scuttling else Vector3.ZERO)

	var distance := global_position.distance_to(_player.global_position)
	if distance <= attack_distance and _has_line_of_sight():
		_begin_attack()
	elif (
		_climb_cooldown <= 0.0
		and distance >= climb_min_distance
		and (_stuck_cycles >= 3 or _player.global_position.y - global_position.y > 2.2)
	):
		_try_begin_wall_climb()


func _update_scuttle_cycle(delta: float) -> bool:
	_scuttle_timer -= delta
	if _scuttle_timer <= 0.0:
		_scuttle_active = not _scuttle_active
		if _scuttle_active:
			_scuttle_timer = randf_range(scuttle_move_interval.x, scuttle_move_interval.y)
			_scuttle_speed_scale = randf_range(0.9, 1.14)
			if movement_mode == MovementMode.CEILING:
				_capture_player_ceiling_position()
		else:
			_scuttle_timer = randf_range(scuttle_pause_interval.x, scuttle_pause_interval.y)
	return _scuttle_active


func _capture_player_ceiling_position() -> void:
	if not is_instance_valid(_player):
		_ceiling_target_valid = false
		return
	# La posicion queda congelada durante todo el impulso. Aunque el jugador se
	# aparte, la criatura termina la carrera hacia el ultimo lugar donde lo vio.
	_last_player_ceiling_position = Vector3(
		_player.global_position.x,
		global_position.y,
		_player.global_position.z
	)
	_ceiling_target_valid = true


func _begin_scuttle_pause() -> void:
	_scuttle_active = false
	_scuttle_timer = randf_range(scuttle_pause_interval.x, scuttle_pause_interval.y)
	velocity.x = 0.0
	velocity.z = 0.0


func _update_ground_recovery(delta: float, intended_direction: Vector3) -> void:
	var hit_wall := false
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var normal := collision.get_normal()
		if absf(normal.y) > 0.45:
			continue
		hit_wall = true
		var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
		if tangent.dot(intended_direction) < (-tangent).dot(intended_direction):
			tangent = -tangent
		_recovery_direction = tangent

	_progress_timer += delta
	if _progress_timer < stuck_check_interval:
		if hit_wall and _recovery_timer <= 0.0:
			_recovery_timer = 0.28
		return

	var moved_distance := Vector2(
		global_position.x - _last_progress_position.x,
		global_position.z - _last_progress_position.z
	).length()
	var trying_to_move := intended_direction.length_squared() > 0.02
	if trying_to_move and moved_distance < 0.1:
		_stuck_cycles = mini(_stuck_cycles + 1, 6)
		_target_refresh = 0.0
		if _recovery_direction.length_squared() <= 0.01:
			var side_sign := -1.0 if _stuck_cycles % 2 == 0 else 1.0
			_recovery_direction = Vector3(
				-intended_direction.z * side_sign,
				0.0,
				intended_direction.x * side_sign
			).normalized()
		_recovery_timer = 0.5
	else:
		_stuck_cycles = 0
		if not hit_wall:
			_recovery_direction = Vector3.ZERO
	_progress_timer = 0.0
	_last_progress_position = global_position


func _try_begin_wall_climb() -> void:
	ceiling_ray.force_raycast_update()
	if not ceiling_ray.is_colliding():
		return
	var found_wall := false
	var best_score := INF
	var chosen_rotation := 0.0
	var player_direction := _player.global_position - global_position
	player_direction.y = 0.0
	player_direction = player_direction.normalized()
	var scan_rotations: Array[float] = [0.0, PI * 0.5, -PI * 0.5, PI]
	for scan_rotation: float in scan_rotations:
		wall_ray.rotation.y = scan_rotation
		wall_ray.force_raycast_update()
		if not wall_ray.is_colliding():
			continue
		var wall_collider := wall_ray.get_collider() as Node
		if wall_collider != null and (wall_collider.has_method(&"interact") or wall_collider.is_in_group(&"door")):
			continue
		var candidate_normal := wall_ray.get_collision_normal().normalized()
		if absf(candidate_normal.y) > 0.28:
			continue
		var candidate_point := wall_ray.get_collision_point()
		var hit_direction := candidate_point - global_position
		hit_direction.y = 0.0
		var collision_distance := hit_direction.length()
		if collision_distance <= 0.01:
			continue
		var alignment := hit_direction.normalized().dot(player_direction)
		if alignment < -0.15:
			continue
		var candidate_score := collision_distance + (1.0 - alignment) * 1.5
		if candidate_score < best_score:
			best_score = candidate_score
			chosen_rotation = scan_rotation
			_wall_normal = candidate_normal
			_wall_point = candidate_point
			found_wall = true
	if not found_wall:
		return
	wall_ray.rotation.y = chosen_rotation
	_ceiling_y = ceiling_ray.get_collision_point().y - ceiling_surface_offset
	if _ceiling_y - global_position.y < 1.1:
		return
	movement_mode = MovementMode.CLIMBING_WALL
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	velocity = Vector3.ZERO
	_wall_climb_timer = 0.0
	_wall_progress_timer = 0.0
	_wall_last_height = global_position.y


func _update_wall_climb(delta: float) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_wall_climb_timer += delta
	if _wall_climb_timer >= max_wall_climb_time:
		_abort_wall_climb()
		return

	var cling_point := _wall_point + _wall_normal * 0.34
	var to_wall := cling_point - global_position
	to_wall.y = 0.0
	if to_wall.length() > 0.14:
		var approach_direction := to_wall.normalized()
		velocity = approach_direction * ground_speed
		rotation.y = lerp_angle(rotation.y, atan2(-_wall_normal.x, -_wall_normal.z), minf(delta * 8.0, 1.0))
	else:
		var cling_force := -_wall_normal * 0.18
		velocity = cling_force + Vector3.UP * climb_speed
	move_and_slide()

	if to_wall.length() <= 0.2:
		if global_position.y > _wall_last_height + 0.035:
			_wall_last_height = global_position.y
			_wall_progress_timer = 0.0
		else:
			_wall_progress_timer += delta
		if _wall_progress_timer > 0.85:
			_abort_wall_climb()
			return

	if global_position.y >= _ceiling_y - 0.08 and to_wall.length() <= 0.24:
		global_position.y = _ceiling_y
		movement_mode = MovementMode.CEILING
		velocity = Vector3.ZERO
		_ceiling_lost_timer = 0.0
		_last_valid_ceiling_position = global_position


func _abort_wall_climb() -> void:
	movement_mode = MovementMode.GROUND
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	velocity = _wall_normal * 0.65
	velocity.y = -0.25
	_climb_cooldown = 5.0
	_target_refresh = 0.0
	_stuck_cycles = 0
	_recovery_timer = 0.45
	_recovery_direction = _wall_normal


func _update_ceiling(delta: float) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	ceiling_ray.force_raycast_update()
	var ceiling_gap := INF
	if ceiling_ray.is_colliding():
		ceiling_gap = ceiling_ray.get_collision_point().y - global_position.y
	var has_valid_ceiling := ceiling_gap >= 0.12 and ceiling_gap <= 1.0
	if has_valid_ceiling:
		_ceiling_lost_timer = 0.0
		var desired_y := ceiling_ray.get_collision_point().y - ceiling_surface_offset
		global_position.y = move_toward(global_position.y, desired_y, delta * 1.8)
		_last_valid_ceiling_position = global_position
	else:
		_ceiling_lost_timer += delta

	if not _ceiling_target_valid:
		_capture_player_ceiling_position()
	var direction := _last_player_ceiling_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.02:
		direction = _get_ceiling_steering(direction.normalized())
	var scuttling := _update_scuttle_cycle(delta)
	var player_flat_distance := Vector2(
		_player.global_position.x - global_position.x,
		_player.global_position.z - global_position.z
	).length()
	var target_flat_distance := Vector2(
		_last_player_ceiling_position.x - global_position.x,
		_last_player_ceiling_position.z - global_position.z
	).length()
	if scuttling and (player_flat_distance <= ceiling_standoff_distance or target_flat_distance <= 0.45):
		_begin_scuttle_pause()
		scuttling = false
	if direction.length_squared() > 0.02 and scuttling and has_valid_ceiling:
		var burst_speed := ceiling_speed * scuttle_speed_multiplier * _scuttle_speed_scale
		velocity.x = move_toward(velocity.x, direction.x * burst_speed, delta * 30.0)
		velocity.z = move_toward(velocity.z, direction.z * burst_speed, delta * 30.0)
		velocity.y = 0.0
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z) + PI, minf(delta * 9.0, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 24.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 24.0)
		velocity.y = 0.0
		var watch_direction := _player.global_position - global_position
		watch_direction.y = 0.0
		if watch_direction.length_squared() > 0.02:
			rotation.y = lerp_angle(
				rotation.y,
				atan2(watch_direction.x, watch_direction.z) + PI,
				minf(delta * 5.0, 1.0)
			)
	move_and_slide()

	# Esta evolucion pertenece al techo: ni la cercania ni una pared ni perder
	# vision provocan una caida. Si pisa un borde sin techo, vuelve al ultimo
	# punto de agarre en lugar de atravesar la losa o caer al suelo.
	if _ceiling_lost_timer > 0.18:
		velocity = Vector3.ZERO
		global_position = global_position.move_toward(_last_valid_ceiling_position, delta * 5.0)


func _get_ceiling_steering(desired_direction: Vector3) -> Vector3:
	var ray_origin := global_position - Vector3.UP * 0.08
	var ray_end := ray_origin + desired_direction * 1.25
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_direction
	var normal: Vector3 = hit.normal
	normal.y = 0.0
	if normal.length_squared() <= 0.01:
		return Vector3.ZERO
	var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
	if (-tangent).dot(desired_direction) > tangent.dot(desired_direction):
		tangent = -tangent
	return tangent


func _update_drop(delta: float) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	velocity.y -= _gravity * 1.35 * delta
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.02:
		direction = direction.normalized()
		velocity.x = move_toward(velocity.x, direction.x * ground_speed * 0.55, delta * 3.0)
		velocity.z = move_toward(velocity.z, direction.z * ground_speed * 0.55, delta * 3.0)
	move_and_slide()
	if is_on_floor():
		movement_mode = MovementMode.GROUND
		velocity.y = -0.2


func _begin_attack() -> void:
	movement_mode = MovementMode.ATTACK
	_attack_timer = 0.0
	_attack_applied = false


func _update_attack(delta: float) -> void:
	_attack_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, delta * 14.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 14.0)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(delta * 12.0, 1.0))
	if _attack_timer >= 0.34 and not _attack_applied:
		_attack_applied = true
		if global_position.distance_to(_player.global_position) <= attack_distance + 0.7:
			if _player.has_method(&"receive_monster_attack"):
				_player.call(&"receive_monster_attack", self)
	if _attack_timer >= 1.15:
		movement_mode = MovementMode.GROUND


func _has_line_of_sight() -> bool:
	var origin := head_rig.global_position
	var target := _player.global_position + Vector3.UP * 0.65
	if origin.distance_to(target) > vision_distance:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _player


func _try_open_door() -> void:
	if _door_cooldown > 0.0 or Vector2(velocity.x, velocity.z).length() < 0.3:
		return
	door_ray.force_raycast_update()
	if not door_ray.is_colliding():
		return
	var collider := door_ray.get_collider()
	if collider != null and collider.has_method(&"ensure_open_for_npc"):
		_door_cooldown = 1.0
		collider.call_deferred(&"ensure_open_for_npc", self)


func _update_pose(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := clampf(speed / maxf(ground_speed, 0.01), 0.0, 1.0)
	var phase_speed := 9.5 if movement_mode == MovementMode.CLIMBING_WALL else 10.5 * moving
	_motion_phase += delta * phase_speed
	var waiting_on_ceiling := movement_mode == MovementMode.DORMANT and starts_on_ceiling
	var ceiling_rotation := PI if movement_mode == MovementMode.CEILING or waiting_on_ceiling else 0.0
	if movement_mode == MovementMode.CLIMBING_WALL:
		ceiling_rotation = PI * 0.5
	model.rotation.x = lerp_angle(model.rotation.x, ceiling_rotation, minf(delta * 5.0, 1.0))
	var attached_to_surface := movement_mode in [MovementMode.CLIMBING_WALL, MovementMode.CEILING] or waiting_on_ceiling
	var collision_height := 0.06 if attached_to_surface else 0.64
	body_collision.position.y = move_toward(body_collision.position.y, collision_height, delta * 2.4)

	var stride := sin(_motion_phase) * (0.18 + moving * 0.62)
	var counter_stride := sin(_motion_phase + PI) * (0.18 + moving * 0.62)
	front_left.rotation.x = lerp_angle(front_left.rotation.x, -0.2 + stride, minf(delta * 13.0, 1.0))
	rear_right.rotation.x = lerp_angle(rear_right.rotation.x, 0.15 + stride, minf(delta * 13.0, 1.0))
	front_right.rotation.x = lerp_angle(front_right.rotation.x, -0.2 + counter_stride, minf(delta * 13.0, 1.0))
	rear_left.rotation.x = lerp_angle(rear_left.rotation.x, 0.15 + counter_stride, minf(delta * 13.0, 1.0))
	front_left_joint.rotation.x = lerp_angle(front_left_joint.rotation.x, 0.72 - stride * 0.42, minf(delta * 14.0, 1.0))
	front_right_joint.rotation.x = lerp_angle(front_right_joint.rotation.x, 0.72 - counter_stride * 0.42, minf(delta * 14.0, 1.0))
	rear_left_joint.rotation.x = lerp_angle(rear_left_joint.rotation.x, -0.62 + stride * 0.38, minf(delta * 14.0, 1.0))
	rear_right_joint.rotation.x = lerp_angle(rear_right_joint.rotation.x, -0.62 + counter_stride * 0.38, minf(delta * 14.0, 1.0))

	var attack_lunge := sin(clampf(_attack_timer / 0.65, 0.0, 1.0) * PI) if movement_mode == MovementMode.ATTACK else 0.0
	body_rig.position.z = lerpf(body_rig.position.z, attack_lunge * 0.34, minf(delta * 12.0, 1.0))
	body_rig.position.y = 1.25 + absf(sin(_motion_phase * 2.0)) * 0.055 * moving
	head_rig.rotation.z = lerp_angle(head_rig.rotation.z, sin(_motion_phase * 0.37) * 0.12, minf(delta * 5.0, 1.0))
	head_rig.rotation.x = lerp_angle(head_rig.rotation.x, -0.12 + attack_lunge * 0.38, minf(delta * 8.0, 1.0))

	if speed > 0.3:
		var step := floori(_motion_phase / (PI * 0.5))
		if step != _last_step:
			_last_step = step
			skitter_sound.pitch_scale = randf_range(0.72, 1.18)
			skitter_sound.play()


func _make_creature_sound(duration: float, frequency: float, volume: float, looped: bool) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(duration * mix_rate)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(duration * 10000.0 + frequency * 31.0)
	for sample_index in sample_count:
		var time := float(sample_index) / float(mix_rate)
		var envelope := 0.72 + sin(time * TAU / duration) * 0.2 if looped else sin(PI * time / duration)
		var scrape := sin(time * TAU * frequency) * 0.45 + sin(time * TAU * frequency * 2.73) * 0.22
		var noise := rng.randf_range(-1.0, 1.0) * 0.46
		var sample := clampf((scrape + noise) * envelope * volume, -1.0, 1.0)
		pcm.encode_s16(sample_index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = pcm
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = sample_count
	return stream
