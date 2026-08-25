extends CharacterBody3D

signal state_changed(previous_state: State, new_state: State)

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, ATTACK }

const STAIR_LOWER_ANCHOR := Vector3(-1.328, 0.12, 3.0)
const STAIR_UPPER_ANCHOR := Vector3(-1.328, 4.18, -2.18)

@export var patrol_speed := 1.0
@export var investigate_speed := 1.45
@export var chase_speed := 3.15
@export var vision_distance := 15.0
@export_range(10.0, 160.0, 1.0) var vision_angle_degrees := 78.0
@export var hearing_distance := 7.5
@export var chase_memory_seconds := 12.0
@export var search_seconds := 8.0
@export var attack_distance := 1.05
@export var attack_cooldown := 1.65
@export var target_refresh_seconds := 0.16

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var door_ray: RayCast3D = $DoorRay
@onready var clearance_sensor: Node3D = $ClearanceSensor
@onready var head_forward_ray: RayCast3D = $ClearanceSensor/HeadForward
@onready var body_forward_ray: RayCast3D = $ClearanceSensor/BodyForward
@onready var overhead_ray: RayCast3D = $ClearanceSensor/Overhead
@onready var model: Node3D = $Model
@onready var torso: Node3D = $Model/TorsoRig
@onready var head_rig: Node3D = $Model/TorsoRig/HeadRig
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
var _player: CharacterBody3D
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


func _ready() -> void:
	_spawn_position = global_position
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if is_instance_valid(_player):
		_player_start_position = Vector2(_player.global_position.x, _player.global_position.z)
		_player_start_position_set = true
	navigation_agent.path_height_offset = 0.0
	navigation_agent.path_desired_distance = 0.35
	navigation_agent.target_desired_distance = 0.55
	navigation_agent.avoidance_enabled = false
	breathing_sound.stream = _make_breathing_sound()
	footstep_sound.stream = _make_footstep_sound()
	voice_sound.stream = _make_chase_voice()
	breathing_sound.play()
	call_deferred(&"_finish_navigation_setup")


func _finish_navigation_setup() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_navigation_available = NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0
	_choose_patrol_target()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
		if not is_instance_valid(_player):
			return
		_player_start_position = Vector2(_player.global_position.x, _player.global_position.z)
		_player_start_position_set = true

	_door_cooldown = maxf(0.0, _door_cooldown - delta)
	_target_refresh_timer = maxf(0.0, _target_refresh_timer - delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.2

	if not _player_has_moved:
		var player_position_2d := Vector2(_player.global_position.x, _player.global_position.z)
		var player_speed_2d := Vector2(_player.velocity.x, _player.velocity.z).length()
		if not _player_start_position_set:
			_player_start_position = player_position_2d
			_player_start_position_set = true
		_player_has_moved = player_position_2d.distance_to(_player_start_position) > 0.035 or player_speed_2d > 0.12
		if not _player_has_moved:
			velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)
			move_and_slide()
			_update_animation(delta)
			return

	var sees_player := _can_see_player()
	var hears_player := _can_hear_player()
	_update_awareness(delta, sees_player, hears_player)

	if current_state == State.ATTACK:
		_update_attack(delta)
	else:
		_update_movement(delta)
	_update_frame_duck(delta)

	move_and_slide()
	_try_open_door()
	_update_animation(delta)


func _update_awareness(delta: float, sees_player: bool, hears_player: bool) -> void:
	if sees_player:
		_last_known_player_position = _player.global_position
		_memory_timer = chase_memory_seconds
		if current_state != State.CHASE and current_state != State.ATTACK:
			_change_state(State.CHASE)
	elif hears_player and current_state in [State.PATROL, State.SEARCH]:
		_last_known_player_position = _player.global_position
		_change_state(State.INVESTIGATE)

	match current_state:
		State.PATROL:
			if global_position.distance_to(_patrol_target) < 0.85:
				_state_timer -= delta
				if _state_timer <= 0.0:
					_choose_patrol_target()
		State.INVESTIGATE:
			if sees_player:
				_change_state(State.CHASE)
			elif global_position.distance_to(_last_known_player_position) < 0.9:
				_change_state(State.SEARCH)
		State.CHASE:
			var changing_floor := absf(_player.global_position.y - global_position.y) > 1.15
			if sees_player or changing_floor:
				# Floors and the stair slab temporarily block line of sight. During that
				# transition she must keep following the live target instead of forgetting it.
				_last_known_player_position = _player.global_position
				_memory_timer = chase_memory_seconds
			else:
				_memory_timer -= delta
				if _memory_timer <= 0.0:
					_change_state(State.SEARCH)
			if global_position.distance_to(_player.global_position) <= attack_distance and sees_player:
				_change_state(State.ATTACK)
		State.SEARCH:
			_state_timer -= delta
			if sees_player:
				_change_state(State.CHASE)
			elif hears_player:
				_last_known_player_position = _player.global_position
				_change_state(State.INVESTIGATE)
			elif _state_timer <= 0.0:
				_choose_patrol_target()
				_change_state(State.PATROL)


func _update_movement(delta: float) -> void:
	var target := _patrol_target
	var speed := patrol_speed
	_force_stair_steering = false
	match current_state:
		State.INVESTIGATE:
			target = _last_known_player_position
			speed = investigate_speed
		State.CHASE:
			target = _player.global_position
			speed = chase_speed
			target = _get_floor_transition_target(target)
		State.SEARCH:
			target = _last_known_player_position
			speed = patrol_speed * 0.72

	if _target_refresh_timer <= 0.0:
		_target_refresh_timer = target_refresh_seconds
		_navigation_available = NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0
		if _navigation_available:
			navigation_agent.target_position = target

	var next_point := target
	if not _force_stair_steering and _navigation_available and not navigation_agent.is_navigation_finished():
		next_point = navigation_agent.get_next_path_position()
		next_point = _get_next_useful_path_point(next_point)
	var flat_direction := next_point - global_position
	flat_direction.y = 0.0
	if flat_direction.length_squared() > 0.015:
		flat_direction = flat_direction.normalized()
		if _smoothed_move_direction.length_squared() < 0.01:
			_smoothed_move_direction = flat_direction
		else:
			_smoothed_move_direction = _smoothed_move_direction.lerp(flat_direction, minf(delta * 5.0, 1.0)).normalized()
		velocity.x = move_toward(velocity.x, _smoothed_move_direction.x * speed, delta * 7.5)
		velocity.z = move_toward(velocity.z, _smoothed_move_direction.z * speed, delta * 7.5)
		var movement_yaw := atan2(_smoothed_move_direction.x, _smoothed_move_direction.z)
		clearance_sensor.rotation.y = wrapf(movement_yaw - rotation.y, -PI, PI)
		door_ray.rotation.y = clearance_sensor.rotation.y
		var facing_direction := _smoothed_move_direction
		if current_state == State.CHASE and is_instance_valid(_player):
			facing_direction = _player.global_position - global_position
			facing_direction.y = 0.0
		if facing_direction.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(facing_direction.x, facing_direction.z), minf(delta * 7.5, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 6.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 6.0)
		_smoothed_move_direction = _smoothed_move_direction.move_toward(Vector3.ZERO, delta * 4.0)


func _get_floor_transition_target(player_target: Vector3) -> Vector3:
	var player_is_upstairs := player_target.y > 2.65
	var player_is_downstairs := player_target.y < 1.65
	if player_is_upstairs and global_position.y < 3.72:
		var lower_distance := Vector2(
			global_position.x - STAIR_LOWER_ANCHOR.x,
			global_position.z - STAIR_LOWER_ANCHOR.z
		).length()
		if global_position.y < 0.8 and lower_distance > 0.72:
			return STAIR_LOWER_ANCHOR
		_force_stair_steering = true
		return STAIR_UPPER_ANCHOR
	if player_is_downstairs and global_position.y > 0.62:
		var upper_distance := Vector2(
			global_position.x - STAIR_UPPER_ANCHOR.x,
			global_position.z - STAIR_UPPER_ANCHOR.z
		).length()
		if global_position.y > 3.55 and upper_distance > 0.72:
			return STAIR_UPPER_ANCHOR
		_force_stair_steering = true
		return STAIR_LOWER_ANCHOR
	return player_target


func _get_next_useful_path_point(first_point: Vector3) -> Vector3:
	# On a floor change NavigationAgent can return a waypoint almost directly
	# above/below the body. Horizontal steering would then become zero forever.
	var first_flat := Vector2(first_point.x - global_position.x, first_point.z - global_position.z)
	if first_flat.length_squared() > 0.015:
		return first_point
	var path := navigation_agent.get_current_navigation_path()
	var start_index := navigation_agent.get_current_navigation_path_index()
	for path_index in range(start_index + 1, path.size()):
		var candidate := path[path_index]
		var candidate_flat := Vector2(candidate.x - global_position.x, candidate.z - global_position.z)
		if candidate_flat.length_squared() > 0.015:
			return candidate
	return first_point


func _update_frame_duck(delta: float) -> void:
	head_forward_ray.force_raycast_update()
	body_forward_ray.force_raycast_update()
	overhead_ray.force_raycast_update()
	var doorway_header_ahead := head_forward_ray.is_colliding() and not body_forward_ray.is_colliding()
	var low_ceiling_above := overhead_ray.is_colliding()
	if doorway_header_ahead or low_ceiling_above:
		_duck_hold_timer = 0.72
	else:
		_duck_hold_timer = maxf(0.0, _duck_hold_timer - delta)
	var target_duck := 1.0 if _duck_hold_timer > 0.0 else 0.0
	var duck_speed := 4.6 if target_duck > _duck_amount else 2.8
	_duck_amount = move_toward(_duck_amount, target_duck, delta * duck_speed)


func _update_attack(delta: float) -> void:
	_attack_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z), minf(delta * 10.0, 1.0))
	if _attack_timer >= 0.42 and not _attack_applied:
		_attack_applied = true
		if global_position.distance_to(_player.global_position) < attack_distance + 0.55:
			if _player.has_method(&"receive_monster_attack"):
				_player.call(&"receive_monster_attack", self)
	if _attack_timer >= attack_cooldown:
		_change_state(State.CHASE)


func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	var previous := current_state
	current_state = new_state
	_state_timer = search_seconds if new_state == State.SEARCH else randf_range(0.8, 2.0)
	if new_state == State.ATTACK:
		_attack_timer = 0.0
		_attack_applied = false
	elif new_state == State.CHASE and not voice_sound.playing:
		voice_sound.pitch_scale = randf_range(0.9, 1.06)
		voice_sound.play()
	emit_signal(&"state_changed", previous, new_state)


func _can_see_player() -> bool:
	var eye_position := global_position + Vector3.UP * 2.65
	var target_position := _player.global_position + Vector3.UP * 0.65
	var to_target := target_position - eye_position
	if to_target.length() > vision_distance:
		return false
	var forward := global_basis.z.normalized()
	if rad_to_deg(forward.angle_to(to_target.normalized())) > vision_angle_degrees * 0.5:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye_position, target_position, 1)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == _player


func _can_hear_player() -> bool:
	var player_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if player_speed < 0.35:
		return false
	var effective_distance := hearing_distance * clampf(player_speed / 1.4, 0.65, 1.8)
	return global_position.distance_to(_player.global_position) <= effective_distance


func _choose_patrol_target() -> void:
	_state_timer = randf_range(1.2, 3.0)
	var candidate := _spawn_position + Vector3(randf_range(-6.5, 6.5), 0.0, randf_range(-6.5, 6.5))
	if _navigation_available:
		candidate = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, candidate)
	_patrol_target = candidate


func _try_open_door() -> void:
	if _door_cooldown > 0.0 or velocity.length_squared() < 0.2:
		return
	if not door_ray.is_colliding():
		return
	var collider := door_ray.get_collider()
	if collider and collider.has_method(&"interact"):
		_door_cooldown = 1.0
		collider.call_deferred(&"interact", self)


func _update_animation(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving_amount := clampf(horizontal_speed / maxf(chase_speed, 0.01), 0.0, 1.0)
	var cadence := lerpf(2.8, 8.2, moving_amount)
	_motion_phase += delta * cadence
	var leg_swing := sin(_motion_phase) * lerpf(0.18, 0.72, moving_amount)
	var arm_swing := sin(_motion_phase) * lerpf(0.08, 0.46, moving_amount)
	var chase_amount := 1.0 if current_state == State.CHASE else 0.0

	if current_state == State.ATTACK:
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
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -arm_swing + chase_amount * 0.35, minf(delta * 10.0, 1.0))
		right_arm.rotation.x = lerpf(right_arm.rotation.x, arm_swing + chase_amount * 0.35, minf(delta * 10.0, 1.0))
		left_elbow.rotation.x = lerpf(left_elbow.rotation.x, 0.16 + chase_amount * 0.52, minf(delta * 10.0, 1.0))
		right_elbow.rotation.x = lerpf(right_elbow.rotation.x, 0.16 + chase_amount * 0.52, minf(delta * 10.0, 1.0))
		torso.rotation.x = lerpf(torso.rotation.x, -0.07 - chase_amount * 0.18 - _duck_amount * 0.16, minf(delta * 8.0, 1.0))
	torso.position.y = lerpf(torso.position.y, 1.9 - _duck_amount * 0.62, minf(delta * 7.0, 1.0))
	torso.rotation.y = lerp_angle(torso.rotation.y, 0.0, minf(delta * 11.0, 1.0))
	torso.rotation.z = lerp_angle(torso.rotation.z, 0.0, minf(delta * 11.0, 1.0))

	var search_scan := sin(_motion_phase * 0.42) * 0.62 if current_state == State.SEARCH else 0.0
	head_rig.rotation.x = lerp_angle(head_rig.rotation.x, 0.0, minf(delta * 15.0, 1.0))
	head_rig.rotation.y = lerp_angle(head_rig.rotation.y, search_scan, minf(delta * 4.0, 1.0))
	head_rig.rotation.z = lerp_angle(head_rig.rotation.z, sin(_motion_phase * 0.23) * 0.045, minf(delta * 6.0, 1.0))
	model.position.y = (absf(sin(_motion_phase)) - 0.5) * 0.055 * moving_amount + sin(Time.get_ticks_msec() * 0.0018) * 0.012

	if horizontal_speed > 0.25 and is_on_floor():
		var beat := floori(_motion_phase / PI)
		if beat != _last_step_beat:
			_last_step_beat = beat
			footstep_sound.pitch_scale = randf_range(0.82, 1.02) + moving_amount * 0.08
			footstep_sound.play()


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
