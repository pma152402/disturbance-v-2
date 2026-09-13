extends "res://enemies/monster_grandmother_imported.gd"

## Church variant: decisions use observed evidence, never a hidden player's position.
## The shared controller still owns collision, doors, stairs and child interactions.
enum Intent { ROAM, LISTEN, INVESTIGATE, HUNT, SEARCH, STRIKE }

@export_group("Church cognition")
@export var dark_sight_distance := 6.5
@export var recognition_seconds := 0.52
@export var evidence_memory_seconds := 4.5
@export var thorough_search_seconds := 26.0
@export var maximum_search_radius := 6.5
@export var alert_decay_seconds := 32.0
@export_group("Surface hunting")
@export var can_climb := true
@export var climb_speed := 1.25
var surface := preload("res://enemies/granny_surface_traversal.gd").new()

var intent := Intent.ROAM
var alertness := 0.0
var tension := 0.0
var gaze_position := Vector3.ZERO
var attack_side := 1.0
var attack_target_position := Vector3.ZERO
var _idle_clock := 0.0
var _sight_confirmed := false
var _recognition := 0.0
var _evidence_position := Vector3.ZERO
var _evidence_velocity := Vector3.ZERO
var _evidence_age := 1000.0
var _listen_remaining := 0.0
var _investigation_remaining := 0.0
var _search_remaining := 0.0
var _search_travel_remaining := 0.0
var _search_dwell := -1.0
var _search_best_distance := INF
var _search_no_progress := 0.0
var _search_visited: Array[Vector3] = []
var _recent_patrol: Array[Vector3] = []
var _attack_direction := Vector3.FORWARD
var _attack_locked := false
var _sound_cooldown := 0.0
var _emission_cache: Dictionary = {}
var _sense_samples := 0
var _search_path_queries := 0


func _ready() -> void:
	super._ready()
	surface.setup(self)
	gaze_position = global_position + global_basis.z * 3.0 + Vector3.UP
	_evidence_position = global_position
	# The reveal pulse belongs to the legacy variant; this one follows clues.
	supernatural_player_reveal = false


func _physics_process(delta: float) -> void:
	_idle_clock += delta
	_sound_cooldown = maxf(0.0, _sound_cooldown - delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
		if surface.active():
			surface.step(delta, _evidence_position, false)
		else:
			_stop_and_apply_gravity(delta)
		return
	if dormant_until_door_opens and not _dormant_released:
		_update_dormant_activation()
		_stop_and_apply_gravity(delta)
		return
	if remain_still:
		if surface.active():
			surface.step(delta, _evidence_position, false)
		else:
			_stop_and_apply_gravity(delta)
		return
	# El salto conserva el control físico hasta apoyar los pies. Una pista nueva
	# o la escalada no pueden girar la cápsula ni interrumpir la recepción.
	# El estado pertenece al controlador base; consultarlo evita una referencia
	# de miembro obsoleta durante la recarga de scripts heredados en el editor.
	if bool(get(&"_obstacle_jump_active")):
		_evidence_age += delta
		_apply_gravity(delta)
		_update_movement(delta)
		move_and_slide()
		_update_animation(delta)
		return
	if surface.active():
		_evidence_age += delta
		_photo_sense_timer -= delta
		if _photo_sense_timer <= 0.0:
			_photo_sense_timer = 0.2
			var aim := _player.global_position + Vector3.UP
			var sight := surface._ray(surface._center(), aim)
			var lit := (_player.has_method(&"is_personal_light_on") and bool(_player.call(&"is_personal_light_on"))) or (_player.has_method(&"is_flashlight_on") and bool(_player.call(&"is_flashlight_on")))
			var distance := surface._center().distance_to(aim)
			if distance > dark_sight_distance and distance < light_detection_distance and not lit:
				lit = _is_player_illuminated()
			if distance < (light_detection_distance if lit else dark_sight_distance) and (sight.is_empty() or sight.collider == _player):
				_evidence_position = _player.global_position
				_evidence_velocity = Vector3(_player.velocity.x, 0, _player.velocity.z).limit_length(5.0)
				_evidence_age = 0.0
				gaze_position = aim
		surface.step(delta, _evidence_position, can_climb and _evidence_age < evidence_memory_seconds)
		if not surface.active():
			_sight_confirmed = false
			_photo_sense_timer = 0.0
			intent = Intent.INVESTIGATE
			_investigation_remaining = evidence_memory_seconds
			_change_state(State.INVESTIGATE)
		return
	_prey_refresh_timer = maxf(0.0, _prey_refresh_timer - delta)
	if _prey_refresh_timer <= 0.0 or not _is_valid_prey(_prey):
		_refresh_preferred_prey()
	if current_state == State.EAT or (is_instance_valid(_prey) and _prey != _player):
		super._physics_process(delta)
		return
	_door_scan_timer = maxf(0.0, _door_scan_timer - delta)
	_door_cooldown = maxf(0.0, _door_cooldown - delta)
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	_target_refresh_timer = maxf(0.0, _target_refresh_timer - delta)
	_evidence_age += delta
	alertness = maxf(0.0, alertness - delta / maxf(alert_decay_seconds, 1.0))
	tension = move_toward(tension, maxf(alertness, _recognition), delta * 1.5)
	_apply_gravity(delta)
	if current_state == State.ATTACK:
		_update_attack(delta)
	else:
		_photo_sense_timer -= delta
		if _photo_sense_timer <= 0.0:
			_photo_sense_timer = maxf(perception_interval, 0.08)
			_sample_senses(_photo_sense_timer)
		_light_scan_timer -= delta
		if _light_scan_timer <= 0.0:
			_light_scan_timer = 0.25
			_remove_invalid_light_sources()
			_refresh_light_activation_states(0.25)
			if is_instance_valid(_pending_new_light):
				var source := _pending_new_light
				_pending_new_light = null
				_ignored_light_ids[source.get_instance_id()] = true
				if not _sight_confirmed and intent == Intent.ROAM:
					_accept_evidence(_light_ground_position(source), Vector3.ZERO, 0.3, 0.65)
		if can_climb and not _door_traversal_active and is_on_floor():
			surface.consider(delta, _evidence_position, intent in [Intent.HUNT, Intent.INVESTIGATE, Intent.SEARCH] and _evidence_age < evidence_memory_seconds)
			if surface.active():
				return
		_update_intent(delta)
		if current_state == State.ATTACK:
			_update_attack(delta)
		elif _door_traversal_active:
			_update_movement(delta)
		elif intent == Intent.LISTEN or (intent == Intent.SEARCH and _search_dwell >= 0.0) or (intent == Intent.ROAM and _patrol_wait_timer > 0.0):
			_brake_planar(braking, delta)
			_was_trying_to_move = false
			var look := gaze_position - global_position
			if look.length_squared() > 0.1:
				_turn_toward(atan2(look.x, look.z), delta, 1.8)
		else:
			_update_movement(delta)
	_update_frame_duck(delta)
	move_and_slide()
	_try_open_door()
	_update_animation(delta)


func _sample_senses(elapsed: float) -> void:
	_sense_samples += 1
	var offset := _player.global_position - global_position
	var distance := offset.length()
	var personal_light := (_player.has_method(&"is_personal_light_on") and bool(_player.call(&"is_personal_light_on"))) or (_player.has_method(&"is_flashlight_on") and bool(_player.call(&"is_flashlight_on")))
	var in_view := _inside_view_cone(offset, lerpf(112.0, 164.0, alertness)) or distance <= close_player_distance
	# Cheap range/cone rejection precedes lamp checks and physics rays.
	var visible := false
	var illuminated := personal_light
	if in_view and distance <= light_detection_distance and absf(offset.y) <= ledge_reach_height:
		if not illuminated and distance > close_player_distance:
			illuminated = _is_player_illuminated()
		if distance <= (light_detection_distance if illuminated else dark_sight_distance):
			visible = _has_clear_line_to(_player.global_position + Vector3.UP, _player)
			if not visible:
				visible = _has_clear_line_to(_player.global_position + Vector3.UP * 1.55, _player)
	_sight_confirmed = false
	if not visible:
		_recognition = maxf(0.0, _recognition - elapsed * 0.7)
		return
	var recognition_time := recognition_seconds * (0.42 if illuminated else 1.0)
	if distance <= close_player_distance:
		recognition_time = 0.08
	_recognition = minf(1.0, _recognition + elapsed / maxf(recognition_time, 0.08))
	# Even a glimpse turns her head, but only actual recognition starts a hunt.
	gaze_position = _player.global_position + Vector3.UP * 1.25
	if _recognition < 1.0:
		if intent == Intent.ROAM:
			_accept_evidence(_player.global_position, Vector3.ZERO, 0.25, 0.3)
		return
	_sight_confirmed = true
	_evidence_position = _player.global_position
	_evidence_velocity = Vector3(_player.velocity.x, 0.0, _player.velocity.z).limit_length(5.0)
	_evidence_age = 0.0
	_last_known_player_position = _evidence_position
	alertness = 1.0
	_player_hunt_active = true
	intent = Intent.HUNT
	_photo_behavior = PhotoBehavior.CLOSE_PLAYER
	_change_state(State.CHASE)


func _inside_view_cone(offset: Vector3, degrees: float) -> bool:
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length_squared() < 0.01:
		return true
	# Head inspection changes the visual field without spinning the whole body.
	var head_offset := gaze_position - global_position
	var head_yaw := clampf(wrapf(atan2(head_offset.x, head_offset.z) - rotation.y, -PI, PI), -0.42, 0.42)
	return global_basis.z.rotated(Vector3.UP, head_yaw).normalized().dot(flat.normalized()) >= cos(deg_to_rad(degrees * 0.5))


func _accept_evidence(point: Vector3, direction: Vector3, strength: float, pause: float) -> void:
	_evidence_position = point
	_evidence_velocity = direction
	_evidence_age = 0.0
	_last_known_player_position = point
	gaze_position = point + Vector3.UP * 1.2
	alertness = maxf(alertness, strength)
	_player_hunt_active = false
	intent = Intent.LISTEN
	_listen_remaining = pause
	_investigation_remaining = clampf(global_position.distance_to(point) / maxf(investigate_speed, 0.1) * 2.0 + 5.0, 6.0, 28.0)
	_photo_behavior = PhotoBehavior.FOOTSTEP
	_change_state(State.INVESTIGATE)
	_target_refresh_timer = 0.0


func _update_intent(delta: float) -> void:
	match intent:
		Intent.HUNT:
			if _sight_confirmed:
				# Intercept a short distance along observed travel instead of following
				# the exact same point behind a moving player.
				_last_known_player_position = _predicted_prey_position()
				_try_begin_attack()
			else:
				# Carry the last observed direction a short way; don't read live velocity.
				_last_known_player_position = _evidence_position
				intent = Intent.INVESTIGATE
				_investigation_remaining = evidence_memory_seconds + global_position.distance_to(_evidence_position) / maxf(investigate_speed, 0.1)
				_change_state(State.INVESTIGATE)
		Intent.LISTEN:
			_listen_remaining -= delta
			if _listen_remaining <= 0.0:
				intent = Intent.INVESTIGATE
		Intent.INVESTIGATE:
			_investigation_remaining -= delta
			gaze_position = _evidence_position + Vector3.UP * 1.2
			if global_position.distance_to(_last_known_player_position) < 0.85 or _investigation_remaining <= 0.0:
				_begin_lost_player_search()
		Intent.SEARCH:
			_update_lost_player_search(delta)
		Intent.ROAM:
			_update_patrol_wait(delta)
			_patrol_travel_timer -= delta
			if _patrol_wait_timer <= 0.0 and (global_position.distance_to(_patrol_target) < 0.9 or _patrol_travel_timer <= 0.0):
				_recent_patrol.append(global_position)
				if _recent_patrol.size() > 8:
					_recent_patrol.pop_front()
				_begin_patrol_wait()
			var scan := sin(_idle_clock * 0.7) * 0.6 if _patrol_wait_timer > 0.0 else 0.0
			gaze_position = global_position + (_patrol_target - global_position).normalized().rotated(Vector3.UP, scan) * 4.0 + Vector3.UP * 1.2


func _begin_lost_player_search() -> void:
	intent = Intent.SEARCH
	_player_hunt_active = false
	_photo_behavior = PhotoBehavior.CLOSE_MEMORY
	_search_anchor = _snap_to_navigation(_evidence_position)
	_last_known_player_position = _search_anchor
	_search_remaining = thorough_search_seconds * lerpf(0.65, 1.0, alertness)
	_search_travel_remaining = global_position.distance_to(_search_anchor) / maxf(patrol_speed * 0.72, 0.1) * 1.8 + 3.0
	_search_dwell = -1.0
	_search_best_distance = global_position.distance_to(_search_anchor)
	_search_no_progress = 0.0
	_search_step_index = 0
	_search_visited.clear()
	_target_refresh_timer = 0.0
	_change_state(State.SEARCH)


func _update_lost_player_search(delta: float) -> void:
	_search_remaining -= delta
	if _search_remaining <= 0.0:
		_return_to_patrol()
		return
	if _search_dwell >= 0.0:
		_search_dwell -= delta
		var direction := _evidence_velocity.normalized() if _evidence_velocity.length_squared() > 0.1 else global_basis.z
		gaze_position = global_position + direction.rotated(Vector3.UP, sin(_idle_clock * 1.65) * 1.1) * 3.0 + Vector3.UP
		if _search_dwell < 0.0:
			_choose_search_sector()
		return
	gaze_position = _last_known_player_position + Vector3.UP
	_search_travel_remaining -= delta
	var distance := global_position.distance_to(_last_known_player_position)
	if distance < _search_best_distance - 0.18 or _door_traversal_active:
		_search_best_distance = distance
		_search_no_progress = 0.0
	else:
		_search_no_progress += delta
	# Local steering can move sideways indefinitely without approaching a clue.
	# A search may abandon that sector after sustained non-progress and inspect another.
	if distance < 0.8 or _search_travel_remaining <= 0.0 or _search_no_progress >= 2.8:
		_search_visited.append(_last_known_player_position)
		_search_dwell = randf_range(0.8, 1.65)


func _choose_search_sector() -> void:
	_search_step_index += 1
	var direction := _evidence_velocity.normalized() if _evidence_velocity.length_squared() > 0.1 else (_search_anchor - global_position).normalized()
	if direction.length_squared() < 0.1:
		direction = global_basis.z
	var radius := minf(1.7 + _search_step_index * 1.05, maximum_search_radius)
	var best := global_position
	var best_score := -INF
	for index in 5:
		# First sector follows the observed escape direction, subsequent ones spread.
		var angle := float(index) * TAU / 5.0 + float(_search_step_index - 1) * 0.72
		var candidate := _snap_to_navigation(_search_anchor + direction.rotated(Vector3.UP, angle) * radius)
		if absf(candidate.y - _search_anchor.y) > 1.0 or candidate.distance_to(global_position) < 0.9:
			continue
		var score := -float(index) * 0.15
		for visited in _search_visited:
			score -= maxf(0.0, 2.5 - candidate.distance_to(visited)) * 3.0
		if score <= best_score:
			continue
		if _navigation_available:
			_search_path_queries += 1
			var path := NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, candidate, true)
			if path.size() < 2 or path[-1].distance_to(candidate) > 1.0:
				continue
		elif not _can_walk_directly_to(candidate):
			continue
		best = candidate
		best_score = score
	if best_score == -INF:
		_search_dwell = 1.2
		return
	_last_known_player_position = best
	_search_best_distance = global_position.distance_to(best)
	_search_no_progress = 0.0
	_search_travel_remaining = global_position.distance_to(best) / maxf(patrol_speed * 0.72, 0.1) * 1.8 + 2.0
	_target_refresh_timer = 0.0


func _return_to_patrol() -> void:
	intent = Intent.ROAM
	_player_hunt_active = false
	_photo_behavior = PhotoBehavior.PATROL
	_focused_static_light = null
	_recognition = 0.0
	_change_state(State.PATROL)
	if not _choose_roaming_target():
		_patrol_target = _spawn_position
		_patrol_travel_timer = patrol_travel_timeout
	_patrol_wait_timer = randf_range(0.8, 1.6)
	_target_refresh_timer = 0.0


func _choose_roaming_target() -> bool:
	# Keep the existing handling of door-separated navigation islands.
	var best := Vector3.ZERO
	var best_score := -INF
	var best_timeout := patrol_travel_timeout
	for attempt in 3:
		if not super._choose_roaming_target():
			continue
		var score := global_position.distance_to(_patrol_target) * 0.08
		for visited in _recent_patrol:
			score -= maxf(0.0, 8.0 - visited.distance_to(_patrol_target))
		if score > best_score:
			best_score = score
			best = _patrol_target
			best_timeout = _patrol_travel_timer
	if best_score == -INF:
		return false
	_patrol_target = best
	_patrol_travel_timer = best_timeout
	return true


func _on_player_footstep_heard(world_position: Vector3, audible_radius: float) -> void:
	if remain_still or _prey != _player or (dormant_until_door_opens and not _dormant_released) or current_state in [State.ATTACK, State.EAT] or _sight_confirmed or _sound_cooldown > 0.0:
		return
	var distance := global_position.distance_to(world_position)
	if absf(world_position.y - global_position.y) > 3.3 or distance > audible_radius:
		return
	var clear := _has_clear_line_to(world_position + Vector3.UP * 0.8, _player)
	if not clear and distance > audible_radius * 0.55:
		return
	_sound_cooldown = 0.55
	var uncertainty := 0.0 if clear else minf(distance * 0.13, 1.2)
	var clue := world_position + Vector3(randf_range(-uncertainty, uncertainty), 0.0, randf_range(-uncertainty, uncertainty))
	# Repeated steps update the destination without restarting the listening pause.
	var pause := 0.0 if intent in [Intent.INVESTIGATE, Intent.SEARCH] else randf_range(0.25, 0.5)
	_accept_evidence(_snap_to_navigation(clue), Vector3.ZERO, 0.6, pause)


func _on_player_switched_on_light(_source: Node3D) -> void:
	_photo_sense_timer = 0.0


func _predicted_prey_position() -> Vector3:
	if _prey != _player:
		return super._predicted_prey_position()
	var lead := clampf(global_position.distance_to(_evidence_position) / 12.0, 0.0, 0.45) if _sight_confirmed else 0.0
	return _evidence_position + _evidence_velocity * lead


func _try_begin_attack() -> void:
	if _prey != _player:
		super._try_begin_attack()
		return
	var toward := _evidence_position - global_position
	toward.y = 0.0
	if _sight_confirmed and global_basis.z.dot(toward.normalized()) > 0.65 and _has_attack_contact(attack_distance + 0.18) and can_begin_attack():
		_change_state(State.ATTACK)


func _change_state(new_state: State) -> void:
	if new_state == State.ATTACK and current_state != State.ATTACK and _prey == _player:
		intent = Intent.STRIKE
		_attack_direction = (_evidence_position - global_position) * Vector3(1, 0, 1)
		_attack_direction = _attack_direction.normalized() if _attack_direction.length_squared() > 0.01 else global_basis.z.normalized()
		_attack_locked = false
		attack_side *= -1.0
		attack_target_position = global_position + _attack_direction * 1.3 + Vector3.UP
	super._change_state(new_state)


func _update_attack(delta: float) -> void:
	if _prey != _player:
		super._update_attack(delta)
		return
	_attack_timer += delta
	# Only the first half of anticipation can correct aim; the strike is dodgeable.
	if not _attack_locked and _attack_timer < attack_windup_seconds * 0.55 and is_instance_valid(_player) and _has_clear_line_to_prey_body():
		var toward := (_player.global_position - global_position) * Vector3(1, 0, 1)
		if toward.length_squared() > 0.01:
			_attack_direction = _attack_direction.slerp(toward.normalized(), minf(delta * 3.0, 1.0)).normalized()
	else:
		_attack_locked = true
	_turn_toward(atan2(_attack_direction.x, _attack_direction.z), delta, 5.0)
	attack_target_position = global_position + _attack_direction * 1.3 + Vector3.UP
	gaze_position = attack_target_position
	if _attack_timer >= attack_windup_seconds and _attack_timer <= attack_hit_seconds:
		_accelerate_planar(_attack_direction, 1.5, delta)
	else:
		_brake_planar(14.0, delta)
	if _attack_timer >= attack_hit_seconds and not _attack_applied:
		_attack_applied = true
		if is_instance_valid(_player):
			var toward := (_player.global_position - global_position) * Vector3(1, 0, 1)
			if _attack_direction.dot(toward.normalized()) >= cos(deg_to_rad(48.0)) and _has_attack_contact(attack_distance + 0.4) and _has_clear_line_to_prey_body():
				if _player.has_method(&"receive_monster_attack"):
					_player.call(&"receive_monster_attack", self)
	if _attack_timer >= attack_animation_seconds:
		_sight_confirmed = false
		_photo_sense_timer = 0.0
		intent = Intent.INVESTIGATE
		_investigation_remaining = evidence_memory_seconds
		_change_state(State.INVESTIGATE)


func _try_ledge_attack() -> bool:
	if _prey == _player and not _sight_confirmed:
		return false
	return super._try_ledge_attack()


func _is_prey_right_beside_on_stairs() -> bool:
	if _prey == _player and not _sight_confirmed:
		return false
	return super._is_prey_right_beside_on_stairs()


func _update_eating(delta: float) -> void:
	var was_eating := current_state == State.EAT
	super._update_eating(delta)
	if was_eating and current_state != State.EAT and _prey == _player:
		# Shared eating code selects the next prey. Re-enter perception before hunting
		# the player, otherwise the last child's meal would disclose their location.
		_sight_confirmed = false
		_photo_sense_timer = 0.0
		_return_to_patrol()


func _give_up_unreachable_target() -> void:
	if _prey != _player:
		super._give_up_unreachable_target()
	elif intent == Intent.SEARCH:
		_search_travel_remaining = 0.0
	else:
		_begin_lost_player_search()


func get_attention_position() -> Vector3:
	if _prey != _player or current_state == State.EAT or _door_traversal_active:
		return super.get_attention_position()
	return gaze_position


func _update_animation(delta: float) -> void:
	# The procedural Model is hidden in this scene. Animate only the imported rig.
	var horizontal_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	_motion_phase += delta * PI * horizontal_speed / maxf(stride_length, 0.05)
	var beat := floori(_motion_phase / PI)
	if horizontal_speed > 0.25 and is_on_floor() and beat != _last_step_beat:
		_last_step_beat = beat
		footstep_sound.pitch_scale = randf_range(0.82, 1.02) + clampf(horizontal_speed / maxf(chase_speed, 0.01), 0.0, 1.0) * 0.08
		footstep_sound.play()


func _find_visible_emission(node: Node) -> Light3D:
	var key := node.get_instance_id()
	if not _emission_cache.has(key):
		var lights: Array[Light3D] = []
		_collect_emissions(node, lights)
		_emission_cache[key] = lights
	for light: Light3D in _emission_cache[key]:
		if is_instance_valid(light) and light.is_visible_in_tree() and light.light_energy > 0.01:
			return light
	return null


func _collect_emissions(node: Node, lights: Array[Light3D]) -> void:
	if node is Light3D:
		lights.append(node as Light3D)
	for child in node.get_children():
		_collect_emissions(child, lights)


func get_behavior_debug_state() -> Dictionary:
	return {"intent": Intent.keys()[intent], "alertness": alertness, "recognition": _recognition,
		"visible": _sight_confirmed, "evidence": _evidence_position, "evidence_age": _evidence_age,
		"search_sector": _search_step_index, "sense_samples": _sense_samples, "search_paths": _search_path_queries,
		"obstacle_jumps": get(&"_obstacle_jump_count"), "consecutive_jumps": get(&"_obstacle_jump_chain_count"),
		"navigation_detour": _navigation_detour_timer > 0.0}
