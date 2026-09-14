extends "res://enemies/church_grandmother.gd"
## Independent skin/locomotion variant; inherits the church creature's senses,
## evidence memory, search, doors and combat without changing the original.
var _ceiling_route_timer := 0.0
var _ceiling_goal := Vector3.ZERO
var _has_ceiling_goal := false
var _ceiling_route_age := 0.0
var _ceiling_best_distance := INF
var _ceiling_stall := 0.0
var _surface_sense_timer := 0.0
@export_group("Pursuit priority")
@export_range(3.0, 10.0, 0.25) var close_ground_pursuit_distance := 6.0
@export_group("Spider jumps")
@export var spider_jump_enabled := true
@export_range(3.0, 10.0, 0.25) var spider_stuck_seconds := 4.0
@export_range(1, 3, 1) var spider_max_consecutive_jumps := 3
@export_range(0.4, 2.0, 0.05) var spider_moving_stuck_seconds := 0.8
var _spider_stuck_elapsed := 0.0
var _spider_stuck_origin := Vector3.ZERO
var _spider_forced_jumps := 0
var _spider_chain_remaining := 0
var _spider_chain_direction := Vector3.ZERO
var _spider_last_landing_alignment := 1.0
var _spider_retry_timer := 0.0
var _spider_goal_stall := 0.0
var _spider_progress_goal := Vector3.ZERO
var _spider_best_goal_distance := INF
var _spider_was_advancing := false
var _escape_walk_remaining := 0.0
var _escape_walk_direction := Vector3.ZERO
var _steering_timer := 0.0
var _steering_direction := Vector3.ZERO
var _pursuit_latched := false
var _spider_meal_suspended := false
var _offscreen_seconds := 0.0
var _camera_frame_points: Array[Node3D] = []
var vomit: Node3D
var _spider_chain_reason := "stuck"

func on_player_attack_landed(target: Node3D, hits: int) -> void:
	if is_instance_valid(vomit) and target == _player and hits < 3:
		vomit.unlocked = true
		# Actual contact provides a fresh, legitimate observation of the prey.
		_evidence_position = target.global_position
		_evidence_age = 0.0
		_sight_confirmed = true

func begin_vomit_escape() -> void:
	_spider_chain_remaining = mini(randi_range(2, 3), spider_max_consecutive_jumps)
	_spider_chain_reason = "vomit_escape"
	_spider_chain_direction = -global_basis.z.normalized()
	_spider_retry_timer = 0.0
	_spider_stuck_elapsed = 0.0
	_spider_goal_stall = 0.0
	_has_ceiling_goal = false
	_change_state(State.INVESTIGATE)

func _update_camera_stalking(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _is_in_camera_frame(camera):
		_offscreen_seconds = 0.0
	else:
		# Enter slowly after leaving frame, cancel immediately on being framed.
		_offscreen_seconds += delta

func can_stalk_offscreen() -> bool:
	return _offscreen_seconds >= 0.2

func _is_in_camera_frame(camera: Camera3D) -> bool:
	# Test the complete articulated envelope, so a visible head/hand at the
	# edge still cancels stalking even when the root lies outside the picture.
	var bounds := AABB(global_position, Vector3.ZERO)
	for point in _camera_frame_points:
		bounds = bounds.expand(point.global_position)
	bounds = bounds.grow(0.28)
	var center := bounds.get_center()
	var extents := bounds.size * 0.5
	for plane: Plane in camera.get_frustum():
		if plane.distance_to(center) > plane.normal.abs().dot(extents):
			return false
	return true

func _get_pursuit_approach_scale(distance: float) -> float:
	if can_stalk_offscreen() or _prey != _player:
		return super._get_pursuit_approach_scale(distance)
	# Preserve the physical stop at contact, but do not creep toward a player
	# who is framing her. Attack windups and collision recovery stay separate.
	return 0.0 if distance <= chase_stop_distance else 1.0

func get_surface_hunt_speed(memory_valid: bool) -> float:
	if memory_valid and not can_stalk_offscreen():
		return maxf(climb_speed, chase_speed * 0.72)
	return climb_speed

func _turn_toward(target_yaw: float, delta: float, responsiveness: float) -> void:
	# This agile variant keeps the original creature's controller untouched.
	super._turn_toward(target_yaw, delta, responsiveness * 2.4)

func _physics_process(delta: float) -> void:
	if not surface.ensure_body_clear(): return
	_update_camera_stalking(delta)
	if is_instance_valid(vomit) and vomit.step(delta):
		return
	_steering_timer = maxf(0.0, _steering_timer - delta)
	if not surface.active():
		surface.spider_jump_cooldown = maxf(0.0, surface.spider_jump_cooldown - delta)
		surface.spider_settling = maxf(0.0, surface.spider_settling - delta)
		surface._spider_recent_timer -= delta
		if surface._spider_recent_timer <= 0.0:
			surface._spider_recent.clear()
	_update_spider_jump_behavior(delta)
	if not surface.active() and surface.spider_settling > 0.0:
		_stop_and_apply_gravity(delta)
		return
	if surface.active() and is_instance_valid(_player) and not remain_still:
		_stair_commitment = StairCommitment.NONE
		_force_stair_steering = false
		_idle_clock += delta
		_evidence_age += delta
		_attack_cooldown_timer = maxf(0, _attack_cooldown_timer - delta)
		_surface_sense_timer -= delta
		if _surface_sense_timer <= 0:
			_surface_sense_timer = 0.15
			_sense_from_ceiling()
		if not can_climb:
			surface.phase = surface.Phase.DROP
			surface.winding_up = false
		surface.step(delta, _evidence_position, _evidence_age < evidence_memory_seconds)
		if not surface.active():
			_has_ceiling_goal = false
			_ceiling_route_timer = 0.0
			_photo_sense_timer = 0.0
			_resume_after_escape()
		return
	surface.landing_recovery = maxf(0, surface.landing_recovery - delta)
	_ceiling_route_timer -= delta
	var keep_ground_pursuit := should_keep_ground_pursuit()
	if keep_ground_pursuit and _has_ceiling_goal:
		# Do not turn away from a nearby visible/recently occluded player merely
		# because the periodic ceiling route scanner found a wall behind her.
		_has_ceiling_goal = false
		_ceiling_route_timer = 0.8
		_ceiling_route_age = 0.0
		_target_refresh_timer = 0.0
	if can_climb and not keep_ground_pursuit and not surface.active() and surface.cooldown <= 0.0 and not remain_still and not _door_traversal_active and current_state not in [State.ATTACK, State.EAT]:
		if _ceiling_route_timer <= 0:
			_ceiling_route_timer = 1.2
			if not _has_ceiling_goal:
				var entry: Dictionary = surface.find_ceiling_entry(18.0)
				if not entry.is_empty():
					_ceiling_goal = entry.position
					_has_ceiling_goal = true
					_ceiling_route_age = 0.0
					_ceiling_stall = 0.0
					_ceiling_best_distance = INF
					_refresh_navigation_state()
					if _navigation_available:
						navigation_agent.target_position = _ceiling_goal
		if _has_ceiling_goal:
			_ceiling_route_age += delta
			var distance := global_position.distance_to(_ceiling_goal)
			if distance < _ceiling_best_distance - 0.08:
				_ceiling_best_distance = distance
				_ceiling_stall = 0.0
			else:
				_ceiling_stall += delta
			if _ceiling_stall > 3.0 or _ceiling_route_age > 18.0:
				surface.reject_entry(_ceiling_goal)
				_has_ceiling_goal = false
				_ceiling_route_timer = 0.0
	super._physics_process(delta)

func _update_intent(delta: float) -> void:
	super._update_intent(delta)
	if should_keep_ground_pursuit():
		_cancel_ceiling_detour()
	if _has_ceiling_goal and surface.cooldown <= 0.0:
		_patrol_wait_timer = 0.0
		_search_dwell = -1.0
		if intent == Intent.LISTEN:
			intent = Intent.INVESTIGATE

func _update_movement(delta: float) -> void:
	if should_keep_ground_pursuit():
		_cancel_ceiling_detour()
	if _escape_walk_remaining > 0.0 and not _door_traversal_active:
		_escape_walk_remaining -= delta
		var direction := _steer_around_nearby_obstacle(_escape_walk_direction)
		_accelerate_planar(direction, investigate_speed, delta)
		_turn_toward(atan2(direction.x, direction.z), delta, 5.0)
		_was_trying_to_move = true
		return
	if not _has_ceiling_goal or surface.cooldown > 0 or _door_traversal_active or _stair_commitment != StairCommitment.NONE:
		super._update_movement(delta)
		return
	var next := _ceiling_goal
	if _navigation_available:
		if navigation_agent.target_position.distance_to(_ceiling_goal) > 0.1:
			navigation_agent.target_position = _ceiling_goal
		next = navigation_agent.get_next_path_position()
	elif not _can_walk_directly_to(_ceiling_goal):
		_has_ceiling_goal = false
		surface.reject_entry(_ceiling_goal)
		super._update_movement(delta)
		return
	var direction := (next - global_position).slide(Vector3.UP)
	if direction.length() > 0.1:
		direction = _steer_around_nearby_obstacle(direction.normalized())
		_accelerate_planar(direction, investigate_speed, delta)
		_turn_toward(atan2(direction.x, direction.z), delta, 7.0)
		_was_trying_to_move = true
	else:
		_brake_planar(braking, delta)

func _sense_from_ceiling() -> void:
	_sight_confirmed = false
	if not is_instance_valid(_player):
		return
	var aim := _player.global_position + Vector3.UP
	var lit := (_player.has_method(&"is_personal_light_on") and bool(_player.call(&"is_personal_light_on"))) or (_player.has_method(&"is_flashlight_on") and bool(_player.call(&"is_flashlight_on")))
	var distance := surface._center().distance_to(aim)
	if not lit and distance > dark_sight_distance and distance < light_detection_distance:
		lit = _is_player_illuminated()
	if distance > (light_detection_distance if lit else dark_sight_distance) or not _has_clear_line_to(aim, _player):
		return
	_sight_confirmed = true
	_evidence_position = _player.global_position
	_evidence_velocity = _player.velocity.limit_length(5.0)
	_evidence_age = 0.0
	gaze_position = aim
	intent = Intent.HUNT

func should_keep_ground_pursuit() -> bool:
	if surface.active() or not is_instance_valid(_player):
		return false
	# Distance comes from the last observation, never a hidden player's live
	# transform. Separate entry/exit radii stop oscillation at the 6 m boundary.
	var planar_distance := Vector2(_evidence_position.x - global_position.x, _evidence_position.z - global_position.z).length()
	var limit := close_ground_pursuit_distance + (2.0 if _pursuit_latched else 0.0)
	# A bank can occlude the sight ray for a few frames. Preserve pursuit through
	# that brief interruption, then allow climbing once the player is truly lost.
	_pursuit_latched = planar_distance <= limit and (_sight_confirmed or (_pursuit_latched and _evidence_age < 1.1))
	return _pursuit_latched

func _sample_senses(elapsed: float) -> void:
	super._sample_senses(elapsed)
	if should_keep_ground_pursuit():
		_cancel_ceiling_detour()

func _cancel_ceiling_detour() -> void:
	if _has_ceiling_goal:
		_has_ceiling_goal = false
		_ceiling_route_age = 0.0
		_ceiling_route_timer = 1.2
		_target_refresh_timer = 0.0
		if _navigation_available:
			navigation_agent.target_position = _evidence_position

func _steer_around_nearby_obstacle(direction: Vector3) -> Vector3:
	# Retain a successful side choice briefly; ray-fan left/right ties otherwise
	# change every frame between adjacent pew corners.
	if _door_traversal_active or surface.active():
		return super._steer_around_nearby_obstacle(direction)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = surface.collision.shape
	query.transform = surface.collision.global_transform
	query.transform.origin += Vector3.UP * 0.035
	query.exclude = _movement_probe_exclusions()
	query.collision_mask = collision_mask
	query.margin = 0.004
	var space := get_world_3d().direct_space_state
	var frontal := surface._ray(query.transform.origin, query.transform.origin + direction * 0.8)
	if not frontal.is_empty() and _find_npc_door(frontal.collider as Node) != null:
		return direction
	query.motion = direction * 0.7
	if space.cast_motion(query)[0] >= 0.99:
		return direction
	if _steering_timer > 0.0 and _steering_direction.dot(direction) > -0.15:
		query.motion = _steering_direction * 0.65
		if space.cast_motion(query)[0] >= 0.99:
			return _steering_direction
	for angle in [0.55, -0.55, 1.0, -1.0, 1.45, -1.45]:
		var candidate := direction.rotated(Vector3.UP, float(angle) * _recovery_side)
		query.motion = candidate * 0.65
		if space.cast_motion(query)[0] >= 0.99:
			_steering_timer = 0.65
			_steering_direction = candidate
			return candidate
	return super._steer_around_nearby_obstacle(direction)

func can_ceiling_pounce() -> bool:
	return _sight_confirmed and _evidence_age < 0.3 and _attack_cooldown_timer <= 0 and is_instance_valid(_player) and _has_clear_line_to(_player.global_position + Vector3.UP, _player)

func check_pounce_contact(from: Vector3, to: Vector3, contact: Dictionary = {}) -> bool:
	if not is_instance_valid(_player) or not _player.has_method(&"receive_monster_attack"):
		return false
	var chest := _player.global_position + Vector3.UP * 0.85
	var motion := to - from
	var fraction := clampf((chest - from).dot(motion) / maxf(motion.length_squared(), 0.00001), 0, 1)
	var physical_contact := int(contact.get("collider_id", 0)) == _player.get_instance_id()
	# The head projects ahead of the collider. Damage must originate inside the
	# physical body, otherwise a face protruding past a thin wall could hit through it.
	var sight: Dictionary = surface._ray(surface._center(), chest)
	var clear: bool = sight.is_empty() or sight.collider == _player
	if (not physical_contact and chest.distance_to(from + motion * fraction) > 0.85) or not clear:
		return false
	_player.call(&"receive_monster_attack", self)
	_attack_cooldown_timer = 2.0
	return true

func _init() -> void:
	surface = preload("res://enemies/grandmother_crawler_traversal.gd").new()
	# La escena desactiva el salto bípedo heredado. Sus propiedades se aplican
	# después de _init, por lo que asignarlo aquí no asegura ese aislamiento.

func _ready() -> void:
	super._ready()
	# El agente usa metros de mundo, mientras la cápsula hereda la escala.
	var body_scale := global_basis.get_scale().abs().y
	navigation_agent.height *= body_scale
	navigation_agent.radius *= body_scale
	var visual := get_node("EditableVisual")
	_camera_frame_points.assign([visual._head, visual._left_shoulder, visual._right_shoulder,
		visual._left_elbow, visual._right_elbow, visual._left_wrist, visual._right_wrist])
	_camera_frame_points.append_array(visual.hips)
	_camera_frame_points.append_array(visual.knees)
	_camera_frame_points.append_array(visual.ankles)
	visual.shadow_coat = _create_shadow_coat()
	visual.shadow_coat.configure(self, visual)
	surface.cooldown = 1.0
	_spider_stuck_origin = global_position
	_setup_vomit(visual)

func _setup_vomit(visual: Node3D) -> void:
	vomit = preload("res://enemies/crawler_vomit_attack.gd").new()
	vomit.name = "VomitAttack"
	add_child(vomit)
	vomit.setup(self, visual)

func _create_shadow_coat() -> RefCounted:
	return preload("res://enemies/crawler_shadow_coat.gd").new()

func _update_spider_jump_behavior(delta: float) -> void:
	if not spider_jump_enabled or remain_still or (dormant_until_door_opens and not _dormant_released):
		_spider_chain_remaining = 0
		_spider_stuck_elapsed = 0.0
		_spider_goal_stall = 0.0
		_spider_best_goal_distance = INF
		_spider_was_advancing = false
		_spider_stuck_origin = surface._center()
		return
	_spider_retry_timer = maxf(0.0, _spider_retry_timer - delta)
	if surface.spider_busy() or surface.pouncing or surface.winding_up:
		_spider_stuck_elapsed = 0.0
		_spider_goal_stall = 0.0
		_spider_best_goal_distance = INF
		_spider_was_advancing = false
		_spider_stuck_origin = surface._center()
		return
	if _spider_chain_remaining > 0:
		# A new decision is made only after all four limbs had time to settle.
		# Reacquiring a nearby player immediately ends the escape chain.
		if _spider_chain_reason != "vomit_escape" and should_keep_ground_pursuit():
			_spider_chain_remaining = 0
			_resume_after_escape()
			return
		var next_target: Dictionary = surface.find_spider_jump_target(_spider_chain_direction)
		surface.spider_jump_cooldown = 0.0
		if not next_target.is_empty() and surface.begin_spider_jump(next_target, false, _spider_chain_reason):
			_spider_chain_remaining -= 1
			_spider_chain_direction = (surface.spider_target_position - surface._center()).normalized()
			return
		_spider_chain_remaining = 0
		_spider_chain_reason = "stuck"
		_resume_after_escape()
	# Ground movement intent stays cached while attached. Using it up here
	# mistook every deliberate perch for a blocked chase and jumped every 0.8 s.
	var trying_to_advance: bool = surface.wants_to_travel if surface.active() else _was_trying_to_move and current_state not in [State.ATTACK, State.EAT]
	# La pausa de un ataque no es tiempo bloqueada al volver a caminar.
	# Cada cambio entre espera y avance inicia su propio intervalo de muestra.
	if trying_to_advance != _spider_was_advancing:
		_spider_stuck_elapsed = 0.0
		_spider_stuck_origin = surface._center()
	_spider_was_advancing = trying_to_advance
	# Track the capsule centre, not the actor origin: pivoting between wall and
	# ceiling can move the origin without making any real physical progress.
	var moved: float = surface._center().distance_to(_spider_stuck_origin)
	if moved >= 0.16:
		_spider_stuck_elapsed = 0.0
		_spider_stuck_origin = surface._center()
	else:
		_spider_stuck_elapsed += delta
	# Moverse alrededor del mismo banco no es progreso. El objetivo se mantiene
	# estable entre muestras para detectar también oscilaciones laterales.
	var goal := _ceiling_goal if _has_ceiling_goal else _last_known_player_position if intent in [Intent.HUNT, Intent.INVESTIGATE, Intent.SEARCH] else _patrol_target
	# Rodear un banco puede alejarla temporalmente de la presa. Medir contra
	# el siguiente tramo de la ruta evita confundir ese desvío con un atasco.
	if not surface.active() and _navigation_available:
		var path := navigation_agent.get_current_navigation_path()
		var path_index := navigation_agent.get_current_navigation_path_index()
		if path_index >= 0 and path_index < path.size() and not navigation_agent.is_navigation_finished():
			goal = path[path_index]
		elif _navigation_detour_timer > 0.0:
			goal = _navigation_detour
	var goal_distance := surface._center().distance_to(goal)
	# Al trepar, ganar altura puede alejarla del objetivo del suelo. Allí manda
	# el progreso físico y la recuperación de esquinas del controlador de superficie.
	if not trying_to_advance or surface.active() or goal.distance_to(_spider_progress_goal) > 0.75 or goal_distance < _spider_best_goal_distance - 0.12:
		_spider_best_goal_distance = goal_distance
		_spider_progress_goal = goal
		_spider_goal_stall = 0.0
	else:
		_spider_goal_stall += delta
	var stuck_limit := spider_moving_stuck_seconds if trying_to_advance else spider_stuck_seconds
	if (_spider_stuck_elapsed < stuck_limit and _spider_goal_stall < 1.5) or _spider_retry_timer > 0.0:
		return
	if surface.corner_active or surface.phase == surface.Phase.DROP:
		surface.recover_blocked_transition()
		_spider_retry_timer = 0.8
		return
	var escape_direction := global_basis.z
	if _evidence_age < evidence_memory_seconds and intent in [Intent.HUNT, Intent.INVESTIGATE, Intent.SEARCH]:
		escape_direction = (_evidence_position - global_position).normalized()
	var escape_target: Dictionary = surface.find_spider_jump_target(escape_direction)
	surface.spider_jump_cooldown = 0.0
	_spider_retry_timer = 0.8
	if surface.begin_spider_jump(escape_target, false, "stuck"):
		if _door_traversal_active:
			_end_door_traversal(false)
		_spider_meal_suspended = _spider_meal_suspended or (current_state == State.EAT and is_instance_valid(_eating_target))
		_change_state(State.INVESTIGATE)
		_spider_forced_jumps += 1
		_spider_chain_remaining = randi_range(1, spider_max_consecutive_jumps) - 1
		_spider_chain_reason = "stuck"
		_spider_chain_direction = (surface.spider_target_position - surface._center()).normalized()
		_spider_stuck_elapsed = 0.0
	else:
		# No physically safe arc exists here. Replan a walking route; don't keep
		# throwing the same invalid jump at this geometry every physics frame.
		_target_refresh_timer = 0.0
		_has_ceiling_goal = false
		_recovery_side *= -1.0
		_choose_navigation_detour(goal, _smoothed_move_direction)
		_escape_walk_remaining = 0.0 if _navigation_detour_timer > 0.0 else 0.4
		_escape_walk_direction = global_basis.x * _recovery_side
		_patrol_wait_timer = 0.0
		_search_dwell = -1.0
		if intent == Intent.LISTEN:
			intent = Intent.INVESTIGATE
		if intent == Intent.SEARCH:
			_search_travel_remaining = 0.0

func on_spider_jump_landed(_reason: String, landing_normal: Vector3, _landing_phase: int) -> void:
	_spider_last_landing_alignment = global_basis.y.normalized().dot(landing_normal.normalized())
	_spider_stuck_elapsed = 0.0
	_spider_stuck_origin = surface._center()
	_spider_goal_stall = 0.0
	_spider_best_goal_distance = INF
	_steering_timer = 0.0
	_escape_walk_remaining = 0.0
	_smoothed_move_direction = global_basis.z.slide(landing_normal).normalized()
	_recovery_timer = 0.0
	_has_ceiling_goal = false
	_ceiling_route_timer = 1.2
	_target_refresh_timer = 0.0
	# Crucially, do not create imaginary evidence at a random position. Existing
	# visual memory and search state remain authoritative after the recovery.
	if _spider_chain_remaining <= 0:
		_spider_chain_reason = "stuck"
		_resume_after_escape()

func _resume_after_escape() -> void:
	if _spider_meal_suspended and not surface.active():
		_spider_meal_suspended = false
		if is_instance_valid(_eating_target):
			_eating_started = false
			_eating_approach_timer = eating_approach_timeout
			_change_state(State.EAT)
			return
	if _sight_confirmed and is_instance_valid(_player):
		intent = Intent.HUNT
		_change_state(State.CHASE)
	elif _evidence_age < evidence_memory_seconds:
		intent = Intent.INVESTIGATE
		_last_known_player_position = _evidence_position
		_investigation_remaining = maxf(1.0, evidence_memory_seconds - _evidence_age)
		_change_state(State.INVESTIGATE)
	else:
		_return_to_patrol()
	_target_refresh_timer = 0.0

func on_spider_jump_aborted() -> void:
	_spider_chain_remaining = 0
	_spider_chain_reason = "stuck"
	_spider_stuck_elapsed = 0.0
	_spider_goal_stall = 0.0
	_spider_best_goal_distance = INF
	_spider_stuck_origin = surface._center()
	_spider_retry_timer = 1.0
	_has_ceiling_goal = false
	_ceiling_route_timer = maxf(_ceiling_route_timer, 1.0)
	_target_refresh_timer = 0.0

func _has_clear_line_to(point: Vector3, target: Node) -> bool:
	# Sight originates at this creature's actual low head.
	var visual := get_node("EditableVisual")
	var from: Vector3 = visual._head.global_position
	var hit := surface._ray(from, point)
	if hit.is_empty():
		return true
	var collider := hit.collider as Node
	return collider == target or (is_instance_valid(target) and target.is_ancestor_of(collider))
