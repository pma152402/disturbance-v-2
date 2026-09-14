extends RefCounted
## Local shelter choices at 2 Hz; movement keeps the crawler's collision solver.
var brain: CharacterBody3D
var active := false
var goal := Vector3.ZERO
var has_goal := false
var _safe_seconds := 0.0
var _scan_timer := 0.0
var _away := Vector3.ZERO
var _clearance_remaining := 0.0
var _walk_progress_position := Vector3.ZERO
var _walk_stall := 0.0

func _init(actor: CharacterBody3D) -> void:
	brain = actor

func step(delta: float, sensor: Node3D) -> bool:
	var lit: bool = sensor.exposure >= brain.minimum_light_exposure
	if lit:
		if not active:
			active = true
			has_goal = false
			_scan_timer = 0.0
			_walk_progress_position = brain.global_position
			_walk_stall = 0.0
			brain._has_ceiling_goal = false
			brain._spider_chain_remaining = 0
			brain._escape_walk_remaining = 0.0
			brain.surface.winding_up = false
		_safe_seconds = 0.0
		_clearance_remaining = 0.65
		_away = sensor.light_away_direction
	elif active:
		_safe_seconds += delta
		_clearance_remaining = maxf(0.0, _clearance_remaining - delta)
		# Stay sheltered briefly instead of immediately running back into the beam.
		if _safe_seconds >= 3.0 and brain.dissolution <= 0.001 and not brain.surface.spider_busy():
			active = false
			has_goal = false
			brain._target_refresh_timer = 0.0
			brain._photo_sense_timer = 0.0
			return false
	if not active or brain.remain_still:
		return false
	if not brain.surface.ensure_body_clear():
		return true
	brain._idle_clock += delta
	brain._evidence_age += delta
	brain._steering_timer = maxf(0.0, brain._steering_timer - delta)
	brain._door_cooldown = maxf(0.0, brain._door_cooldown - delta)
	brain._door_scan_timer = maxf(0.0, brain._door_scan_timer - delta)
	brain._change_state(brain.State.INVESTIGATE)
	brain.intent = brain.Intent.INVESTIGATE
	brain._sight_confirmed = false
	_scan_timer -= delta
	if lit and _scan_timer <= 0.0:
		_scan_timer = 0.5
		_choose_shelter(sensor)
	# Move a little deeper into cover; stopping exactly on the cone edge lets
	# a head turn expose the taller silhouette again and reverse the escape.
	var seeking_shelter := has_goal and (lit or _clearance_remaining > 0.0)
	var destination: Vector3 = goal if seeking_shelter else brain.surface._center()
	brain.gaze_position = destination
	if brain.surface.active():
		if not lit and brain.surface.phase == brain.surface.Phase.WALL and not brain.surface.spider_busy() and not brain.surface.corner_active:
			if not brain.surface._attachment_support(brain.surface._center(), brain.surface.normal, 1.8).is_empty():
				brain.velocity = Vector3.ZERO
				brain.surface.wants_to_travel = false
				return true
		if brain.surface.phase == brain.surface.Phase.WALL and has_goal:
			brain.surface.wall_travel_sign = 1.0 if goal.y >= brain.surface._center().y else -1.0
		brain.surface.step(delta, destination, seeking_shelter)
		return true
	brain.surface.spider_jump_cooldown = maxf(0.0, brain.surface.spider_jump_cooldown - delta)
	brain.surface.spider_settling = maxf(0.0, brain.surface.spider_settling - delta)
	brain._apply_gravity(delta)
	if brain._door_traversal_active:
		brain._update_door_traversal(delta)
	elif not seeking_shelter or brain.surface.spider_settling > 0.0:
		brain._brake_planar(brain.braking, delta)
		brain._was_trying_to_move = false
	else:
		var next := goal
		if brain._navigation_available:
			next = brain.navigation_agent.get_next_path_position()
		var direction := (next - brain.global_position).slide(Vector3.UP)
		if direction.length_squared() > 0.02:
			direction = brain._steer_around_nearby_obstacle(direction.normalized())
			# A light-triggered sprint reaches its speed quickly without changing
			# the ordinary stalking/retreat acceleration or bypassing collisions.
			var planar := Vector2(brain.velocity.x, brain.velocity.z)
			var desired: Vector2 = Vector2(direction.x, direction.z) * brain.light_escape_speed
			planar = planar.move_toward(desired, maxf(brain.acceleration, 12.0) * delta)
			brain.velocity.x = planar.x
			brain.velocity.z = planar.y
			brain.face_shadow_attention(direction, delta, 8.0)
			brain.clearance_sensor.rotation.y = wrapf(atan2(direction.x, direction.z) - brain.rotation.y, -PI, PI)
			brain.door_ray.rotation.y = brain.clearance_sensor.rotation.y
			brain._was_trying_to_move = true
		else:
			brain._brake_planar(brain.braking, delta)
			_scan_timer = minf(_scan_timer, 0.1)
	brain._update_frame_duck(delta)
	brain.move_and_slide()
	brain._try_open_door()
	brain._update_animation(delta)
	# Retain safe stuck recovery, aimed at shelter rather than the player.
	if lit:
		_recover_if_stuck(delta, destination)
	return true

func _recover_if_stuck(delta: float, destination: Vector3) -> void:
	if brain.global_position.distance_to(_walk_progress_position) > 0.12 or brain.global_position.distance_to(destination) < 0.4:
		_walk_progress_position = brain.global_position
		_walk_stall = 0.0
	else:
		_walk_stall += delta
	if _walk_stall >= 0.65:
		has_goal = false
		_scan_timer = 0.0
		_walk_stall = 0.0
		brain._steering_timer = 0.0
		brain._recovery_side *= -1.0

func _choose_shelter(sensor: Node3D) -> void:
	var surface: RefCounted = brain.surface
	var attached: bool = surface.active()
	var normal: Vector3 = surface.normal if attached else Vector3.UP
	var away := _away.slide(normal).normalized()
	if away.length_squared() < 0.1:
		away = brain.global_basis.z.slide(normal).normalized()
	var center: Vector3 = surface._center()
	var origin: Vector3 = center if attached else brain.global_position
	var arrival_distance := 1.8 if attached and surface.phase == surface.Phase.CEILING else 0.5
	if has_goal and goal.distance_to(origin) > arrival_distance and _walk_stall < 0.6:
		var remaining := goal - origin
		var previous: Dictionary = sensor.sample_at_offset(remaining)
		var clearance_center := goal if attached else goal + Vector3.UP * 0.7
		var supported: bool = not surface._attachment_support(clearance_center, normal, 1.8).is_empty()
		if previous.exposure < brain.minimum_light_exposure and supported and surface._spider_pose_is_clear(clearance_center, normal, remaining.normalized()):
			# A short wall route would otherwise alternate up/down as its moving
			# sampling ring crossed the floor or ceiling before reaching shelter.
			return
	brain._refresh_navigation_state()
	var best_score := INF
	var best := Vector3.ZERO
	var found := false
	# Six candidates, both lateral exits and retreat. Wall travel is vertical.
	for index in 6:
		var angle: float = [0.0, 1.15, -1.15, 0.0, 1.8, -1.8][index]
		var reach := (4.0 if index < 3 else 5.0) if attached else (2.2 if index < 3 else 4.0)
		var offset := away.rotated(normal, angle) * reach
		if attached and surface.phase == surface.Phase.WALL:
			offset = Vector3.UP * (2.0 + floori(index / 2.0)) * (1.0 if index % 2 == 0 else -1.0)
		var candidate: Vector3 = (center if attached else brain.global_position) + offset
		if attached:
			if surface._attachment_support(candidate, normal, 1.8).is_empty(): continue
			if not surface._spider_pose_is_clear(candidate, normal, offset.normalized()): continue
		else:
			var floor_hit: Dictionary = surface._ray(candidate + Vector3.UP * 0.6, candidate + Vector3.DOWN * 0.8)
			if floor_hit.is_empty() or floor_hit.normal.y < 0.7: continue
			candidate.y = floor_hit.position.y + 0.02
			if brain._navigation_available:
				var snapped: Vector3 = brain._snap_to_navigation(candidate)
				if snapped.distance_to(candidate) > 0.8: continue
				candidate = snapped
				var path := NavigationServer3D.map_get_path(brain.get_world_3d().navigation_map, brain.global_position, candidate, true, brain.navigation_agent.navigation_layers)
				if path.size() < 2 or path[-1].distance_to(candidate) > 0.5: continue
			elif not brain._can_walk_directly_to(candidate):
				continue
			if not surface._spider_pose_is_clear(candidate + Vector3.UP * 0.7, Vector3.UP, offset.normalized()): continue
		var displacement: Vector3 = candidate - (center if attached else brain.global_position)
		var sample: Dictionary = sensor.sample_at_offset(displacement)
		var score: float = sample.exposure * 12.0 + displacement.length() * 0.10 - displacement.normalized().dot(away) * 0.2
		# Commit to a chosen side unless another route is meaningfully safer.
		if has_goal and candidate.distance_to(goal) < 1.5: score -= 0.25
		if score < best_score:
			best_score = score
			best = candidate
			found = true
	has_goal = found
	if found:
		goal = best
		if not attached and brain._navigation_available:
			brain.navigation_agent.target_position = goal
