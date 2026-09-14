extends RefCounted
## Decisions use observed evidence; a retreat destination is never prey evidence.
enum Mode { WATCH, STALK, RETREAT, SPRINT, CHARGE }
var mode := Mode.WATCH
var brain: CharacterBody3D
var goal := Vector3.ZERO
var retreat_remaining := 0.0
var _goal_timer := 0.0
var stare_elapsed := 0.0
var sprint_remaining := 0.0
var sprint_count := 0
var _stare_camera_id := 0
var _sprint_threat := Vector3.ZERO
var _sprint_progress := Vector3.ZERO
var _sprint_stall := 0.0
var _sprint_origin := Vector3.ZERO
var _sprint_path := PackedVector3Array()
var _sprint_path_index := 0

func _begin_sprint(threat: Vector3) -> void:
	_sprint_threat = threat
	stare_elapsed = 0.0
	sprint_remaining = 3.2
	sprint_count += 1
	_sprint_stall = 0.0
	_sprint_origin = brain.global_position
	_sprint_progress = brain.global_position
	_sprint_path.clear()
	_goal_timer = 0.0
	mode = Mode.SPRINT
	brain._steering_timer = 0.0
	if brain._door_traversal_active:
		brain._end_door_traversal(false)

func update_stare(delta: float) -> void:
	if brain.remain_still or sprint_remaining > 0.0 or not brain.is_visible_in_tree():
		stare_elapsed = 0.0
		return
	# Once the mouth is fully open, the final pose must always launch, even if
	# its moving head leaves the reticle during the last quarter second.
	if stare_elapsed >= maxf(0.1, brain.stare_escape_seconds - 0.25):
		stare_elapsed += maxf(delta, 0.0)
		if stare_elapsed + 0.000001 >= brain.stare_escape_seconds:
			_begin_sprint(_sprint_threat)
		return
	var camera: Camera3D = brain.get_viewport().get_camera_3d()
	if camera == null:
		stare_elapsed = 0.0
		return
	if _stare_camera_id != camera.get_instance_id():
		stare_elapsed = 0.0
		_stare_camera_id = camera.get_instance_id()
	var focused := false
	var forward := -camera.global_basis.z.normalized()
	var points: Array[Vector3] = [brain._shadow_visual._head.global_position, brain.global_position + Vector3.UP * 1.4]
	for point in points:
		var offset := point - camera.global_position
		# Transformation requires a close observer, independently of light sensing.
		if offset.length() > brain.stare_activation_distance or offset.length() < 0.1:
			continue
		if forward.dot(offset.normalized()) < cos(deg_to_rad(7.5)):
			continue
		var sight: Dictionary = brain.surface._ray(point, camera.global_position)
		if sight.is_empty() or sight.collider == brain._player:
			focused = true
			break
	stare_elapsed = stare_elapsed + maxf(delta, 0.0) if focused else 0.0
	if focused:
		_sprint_threat = camera.global_position
	if stare_elapsed + 0.000001 >= brain.stare_escape_seconds:
		_begin_sprint(camera.global_position)

func hold_charge(delta: float) -> void:
	# Stop locomotion immediately, including an existing retreat/door route.
	# Gravity and light damage stay active while only the pose transforms.
	mode = Mode.CHARGE
	goal = brain.global_position
	brain._was_trying_to_move = false
	brain.velocity.x = 0.0
	brain.velocity.z = 0.0
	brain._apply_gravity(delta)
	brain.move_and_slide()
	brain.face_shadow_attention(brain.gaze_position - brain.global_position, delta, 6.0)

func _decide_sprint(delta: float) -> bool:
	if sprint_remaining <= 0.0:
		return false
	mode = Mode.SPRINT
	var moved := brain.global_position.distance_to(_sprint_progress)
	_sprint_progress = brain.global_position
	if moved > 0.01:
		# A blocked route cannot consume the sprint without ever running.
		sprint_remaining = maxf(0.05, sprint_remaining - delta)
		_sprint_stall = 0.0
	else:
		_sprint_stall += delta
	if _sprint_stall > 0.45:
		_goal_timer = 0.0
		_sprint_stall = 0.0
		brain._steering_timer = 0.0
	var far_enough := brain.global_position.distance_to(_sprint_origin) >= 8.0
	var arrived := not _sprint_path.is_empty() and goal.distance_to(brain.global_position) < 0.7
	if far_enough and arrived:
		sprint_remaining = 0.0
		mode = Mode.WATCH
		goal = brain.global_position
		brain.velocity.x = 0.0
		brain.velocity.z = 0.0
		return true
	if arrived:
		_goal_timer = 0.0
	if _goal_timer <= 0.0:
		_choose_sprint_goal()
		_goal_timer = 0.25 if _sprint_path.is_empty() else INF
	return true

func _choose_sprint_goal() -> void:
	brain._refresh_navigation_state()
	var origin: Vector3 = brain.global_position
	var away := (origin - _sprint_threat).slide(Vector3.UP).normalized()
	if away.length_squared() < 0.01:
		away = -brain.global_basis.z
	var best_score := -INF
	_sprint_path.clear()
	_sprint_path_index = 1
	goal = origin
	# Include lateral exits and routes that initially approach the observer to
	# get out of a dead end. Navigation may turn corners before moving away.
	for distance in [24.0, 16.0, 9.0, 4.0, 1.5]:
		for index in 16:
			var direction := away.rotated(Vector3.UP, float(index) * TAU / 16.0)
			var candidate: Vector3 = origin + direction * distance
			var path := PackedVector3Array()
			if brain._navigation_available:
				candidate = brain._snap_to_navigation(candidate)
				if absf(candidate.y - origin.y) > 1.0:
					continue
				path = NavigationServer3D.map_get_path(brain.get_world_3d().navigation_map, origin, candidate, true, brain.navigation_agent.navigation_layers)
				if path.size() < 2 or path[-1].distance_to(candidate) > 0.5:
					continue
			elif brain._can_walk_directly_to(candidate):
				path = PackedVector3Array([origin, candidate])
			else:
				continue
			var displacement := candidate.distance_to(origin)
			if displacement < 1.0:
				continue
			var support: Dictionary = brain.surface._ray(candidate + Vector3.UP * 0.4, candidate + Vector3.DOWN * 0.6)
			if support.is_empty() or support.normal.y < 0.7:
				continue
			var score := displacement * 0.8 + candidate.distance_to(_sprint_threat) * 0.6
			var light: Dictionary = brain._shadow_visual.shadow_coat.light_sensor.sample_at_offset(candidate - origin)
			score -= float(light.exposure) * 8.0
			if score > best_score:
				best_score = score
				goal = candidate
				_sprint_path = path
		if not _sprint_path.is_empty() and goal.distance_to(origin) >= 8.0:
			break

func _init(actor: CharacterBody3D) -> void:
	brain = actor
	goal = brain.global_position

func step(delta: float) -> void:
	if brain.remain_still:
		brain._stop_and_apply_gravity(delta)
		return
	brain._idle_clock += delta
	brain._evidence_age += delta
	brain._steering_timer = maxf(0.0, brain._steering_timer - delta)
	brain._update_camera_stalking(delta)
	if not is_instance_valid(brain._player):
		brain._player = brain.get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	brain._prey = brain._player
	brain._photo_sense_timer -= delta
	if is_instance_valid(brain._player) and brain._photo_sense_timer <= 0.0:
		brain._photo_sense_timer = 0.12
		brain._sample_senses(0.12)
	brain._player_hunt_active = false
	brain.current_state = brain.State.INVESTIGATE
	brain.intent = brain.Intent.LISTEN
	var camera: Camera3D = brain.get_viewport().get_camera_3d()
	var watched: bool = brain._sight_confirmed and camera != null and brain._is_in_camera_frame(camera)
	if watched:
		var sight: Dictionary = brain.surface._ray(brain._shadow_visual._head.global_position, camera.global_position)
		watched = sight.is_empty() or sight.collider == brain._player
	decide(delta, watched)
	if brain.surface.active():
		brain.surface.step(delta, goal, mode != Mode.WATCH)
		return
	if not brain.surface.ensure_body_clear():
		return
	if mode == Mode.RETREAT and brain.can_climb and brain.is_on_floor():
		brain.surface.consider(delta, goal, true)
		if brain.surface.active():
			brain._update_upright_stance(delta)
			return
	brain._apply_gravity(delta)
	brain._door_scan_timer = maxf(0.0, brain._door_scan_timer - delta)
	brain._door_cooldown = maxf(0.0, brain._door_cooldown - delta)
	if brain._door_traversal_active:
		brain._update_door_traversal(delta)
	else:
		_move(delta)
	brain.move_and_slide()
	brain._try_open_door()

func decide(delta: float, watched: bool) -> void:
	retreat_remaining = maxf(0.0, retreat_remaining - delta)
	_goal_timer -= delta
	if _decide_sprint(delta):
		return
	var memory: bool = brain._evidence_age < brain.evidence_memory_seconds
	var distance := brain.global_position.distance_to(brain._evidence_position)
	if memory and (distance < brain.retreat_distance or (watched and distance < brain.stalking_distance + 2.0)):
		retreat_remaining = 2.0
	var previous := mode
	if retreat_remaining > 0.0:
		mode = Mode.RETREAT
	elif memory and not watched and brain.can_stalk_offscreen() and distance > brain.stalking_distance + 0.8:
		mode = Mode.STALK
	else:
		mode = Mode.WATCH
	if memory:
		brain.gaze_position = brain._evidence_position + Vector3.UP * 1.25
	if mode == Mode.WATCH:
		goal = brain.global_position
	elif previous != mode or _goal_timer <= 0.0:
		_goal_timer = 0.8
		var away: Vector3 = (brain.global_position - brain._evidence_position).slide(Vector3.UP).normalized()
		if away.length_squared() < 0.01:
			away = -brain.global_basis.z
		goal = _choose_retreat_goal(away) if mode == Mode.RETREAT else brain._evidence_position + away * brain.stalking_distance

func _choose_retreat_goal(away: Vector3, travel_distance: float = 3.5, threat: Vector3 = Vector3.INF) -> Vector3:
	var best: Vector3 = brain.global_position
	var best_score := -INF
	var threat_position: Vector3 = brain._evidence_position if not threat.is_finite() else threat
	brain._refresh_navigation_state()
	for angle in [0.0, -0.65, 0.65, -1.25, 1.25]:
		var candidate: Vector3 = brain.global_position + away.rotated(Vector3.UP, angle) * travel_distance
		if brain.surface.active():
			if brain.surface._attachment_support(candidate, brain.surface.normal, 1.8).is_empty():
				continue
		elif brain._navigation_available:
			var snapped: Vector3 = brain._snap_to_navigation(candidate)
			var path := NavigationServer3D.map_get_path(brain.get_world_3d().navigation_map, brain.global_position, snapped, true, brain.navigation_agent.navigation_layers)
			if path.size() >= 2 and path[-1].distance_to(snapped) <= 0.5 and snapped.distance_to(candidate) < 0.8:
				candidate = snapped
			elif not brain._can_walk_directly_to(candidate):
				continue
		elif not brain._can_walk_directly_to(candidate):
			continue
		if not brain.surface.active():
			var support: Dictionary = brain.surface._ray(candidate + Vector3.UP * 0.4, candidate + Vector3.DOWN * 0.6)
			if support.is_empty() or support.normal.y < 0.7: continue
		var separation := candidate.distance_to(threat_position)
		if separation < brain.global_position.distance_to(threat_position) + 0.5:
			continue
		var score: float = separation - absf(angle) * 0.2
		var cover: Dictionary = brain.surface._ray(candidate + Vector3.UP * 1.5, threat_position + Vector3.UP * 1.3)
		if not cover.is_empty() and cover.collider != brain._player:
			score += 3.0
		var sensor: Node3D = brain._shadow_visual.shadow_coat.light_sensor
		var light: Dictionary = sensor.sample_at_offset(candidate - brain.global_position)
		score -= float(light.exposure) * 12.0
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _move(delta: float) -> void:
	var next := goal
	if mode == Mode.SPRINT:
		# Keep the selected escape path independent of perception's nav target.
		while _sprint_path_index < _sprint_path.size() - 1 and brain.global_position.distance_to(_sprint_path[_sprint_path_index]) < 0.55:
			_sprint_path_index += 1
		next = _sprint_path[_sprint_path_index] if _sprint_path_index < _sprint_path.size() else brain.global_position
	elif mode != Mode.WATCH and brain._navigation_available:
		if brain.navigation_agent.target_position.distance_to(goal) > 0.25:
			brain.navigation_agent.target_position = goal
		var path_point: Vector3 = brain.navigation_agent.get_next_path_position()
		if brain.navigation_agent.get_current_navigation_path().size() >= 2:
			next = path_point
		elif not brain._can_walk_directly_to(goal):
			next = brain.global_position
	var direction := (next - brain.global_position).slide(Vector3.UP)
	brain._was_trying_to_move = mode != Mode.WATCH and direction.length() > 0.25
	if brain._was_trying_to_move:
		direction = brain._steer_around_nearby_obstacle(direction.normalized())
		var speed: float = brain.retreat_speed if mode == Mode.RETREAT else brain.stalking_speed
		if mode == Mode.SPRINT:
			var planar := Vector2(brain.velocity.x, brain.velocity.z)
			planar = planar.move_toward(Vector2(direction.x, direction.z) * brain.retreat_speed * brain.stare_escape_speed_multiplier, 200.0 * delta)
			brain.velocity.x = planar.x
			brain.velocity.z = planar.y
		else:
			brain._accelerate_planar(direction, speed, delta)
		brain.face_shadow_attention(direction, delta, 6.0)
		brain.clearance_sensor.rotation.y = wrapf(atan2(direction.x, direction.z) - brain.rotation.y, -PI, PI)
		brain.door_ray.rotation.y = brain.clearance_sensor.rotation.y
	else:
		brain._brake_planar(brain.braking, delta)
		var look: Vector3 = brain.gaze_position - brain.global_position
		if look.length_squared() > 0.1:
			brain.face_shadow_attention(look, delta, 6.0)
