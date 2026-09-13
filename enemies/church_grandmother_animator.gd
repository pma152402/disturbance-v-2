extends "res://enemies/granny_editable_visual_animator.gd"

const Brain := preload("res://enemies/church_grandmother.gd")
const UPPER_BACK_HINGE := Vector3(0.0, 6.9, 0.3)
const UPPER_BACK_HUNCH := 0.46
var _church: Brain
var _previous_speed := 0.0
var _weight_pitch := 0.0
var _waist_pivot := Vector3.ZERO
var _rig_rest_position := Vector3.ZERO


func _ready() -> void:
	super._ready()
	_church = get_parent() as Brain
	process_physics_priority = 1
	_apply_high_upper_back_hunch()
	_recapture_hunched_rest_pose()
	_rig_rest_position = _rig.position
	_waist_pivot = _rig.position + Vector3(0, UPPER_BACK_HINGE.y, 0)


func _apply_high_upper_back_hunch() -> void:
	# El vestido permanece recto hasta la espalda alta. Solo el ultimo tramo del
	# torso, los hombros y la cabeza giran alrededor del mismo quiebro.
	var torso := _rig.get_node("Body") as MeshInstance3D
	var bent_mesh := ArrayMesh.new()
	var torso_to_rig := torso.transform
	var rig_to_torso := torso_to_rig.affine_inverse()
	for surface in torso.mesh.get_surface_count():
		var arrays := torso.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in vertices.size():
			var rig_point := torso_to_rig * vertices[index]
			var bend_weight := smoothstep(UPPER_BACK_HINGE.y - 0.28, UPPER_BACK_HINGE.y + 0.28, rig_point.y)
			if bend_weight <= 0.0:
				continue
			var bend := Basis(Vector3.RIGHT, UPPER_BACK_HUNCH * bend_weight)
			rig_point = UPPER_BACK_HINGE + bend * (rig_point - UPPER_BACK_HINGE)
			vertices[index] = rig_to_torso * rig_point
			if normals.size() == vertices.size():
				var rig_normal := (torso_to_rig.basis * normals[index]).normalized()
				normals[index] = (rig_to_torso.basis * (bend * rig_normal)).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if normals.size() == vertices.size():
			arrays[Mesh.ARRAY_NORMAL] = normals
		bent_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		bent_mesh.surface_set_material(surface, torso.get_active_material(surface))
	torso.mesh = bent_mesh

	var upper_turn := Basis(Vector3.RIGHT, UPPER_BACK_HUNCH)
	var upper_rotation := Quaternion(Vector3.RIGHT, UPPER_BACK_HUNCH)
	for pivot in [_head, _left_shoulder, _right_shoulder]:
		pivot.position = UPPER_BACK_HINGE + upper_turn * (pivot.position - UPPER_BACK_HINGE)
		pivot.quaternion = (upper_rotation * pivot.quaternion).normalized()


func _recapture_hunched_rest_pose() -> void:
	# El IK debe considerar esta silueta como su reposo; de lo contrario intentaria
	# enderezar hombros y cuello en el primer frame.
	_base_head_position = _head.position
	_base_head_rotation = _head.quaternion
	_base_left_shoulder = _left_shoulder.quaternion
	_base_left_elbow = _left_elbow.quaternion
	_base_left_wrist = _left_wrist.quaternion
	_base_right_shoulder = _right_shoulder.quaternion
	_base_right_elbow = _right_elbow.quaternion
	_base_right_wrist = _right_wrist.quaternion
	_left_upper_rest_direction = (_left_shoulder.global_basis.inverse() * (_left_elbow.global_position - _left_shoulder.global_position)).normalized()
	_left_lower_rest_direction = (_left_elbow.global_basis.inverse() * (_left_wrist.global_position - _left_elbow.global_position)).normalized()
	_right_upper_rest_direction = (_right_shoulder.global_basis.inverse() * (_right_elbow.global_position - _right_shoulder.global_position)).normalized()
	_right_lower_rest_direction = (_right_elbow.global_basis.inverse() * (_right_wrist.global_position - _right_elbow.global_position)).normalized()


func _physics_process(delta: float) -> void:
	if is_instance_valid(_church) and bool(_church.get("_obstacle_jump_active")):
		_apply_obstacle_jump_pose(delta)
		return
	if is_instance_valid(_church) and _church.surface.active():
		_apply_climbing_pose(delta)
		return
	super._physics_process(delta)


func _apply_obstacle_jump_pose(delta: float) -> void:
	var forward := _body.global_basis.z.normalized()
	var right := _body.global_basis.x.normalized()
	var origin := _body.global_position
	var duration := maxf(float(_church.get("_obstacle_jump_duration")), 0.1)
	var progress := clampf(float(_church.get("_obstacle_jump_elapsed")) / duration, 0.0, 1.0)
	var tuck := sin(progress * PI) * (1.0 - smoothstep(0.55, 0.88, progress))
	# Recuperar el reposo antes del contacto, sin conservar la inclinación de
	# impulso durante los siguientes saltos de la cadena.
	_pose_node(_rig, _offset_pose(_base_rig_rotation, tuck * 0.32, 0.0, 0.0), delta, 20.0)
	_rig.position = _rig_rest_position
	position = position.lerp(_base_position + Vector3.DOWN * tuck * 0.08, 1.0 - exp(-12.0 * delta))
	var hand_center := origin + Vector3.UP * (1.62 + tuck * 0.18) + forward * (0.68 + tuck * 0.2)
	_hands(hand_center + right * 0.48, hand_center - right * 0.48, delta, 14.0, true)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.34, 0.0, -0.18), delta, 12.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, -0.34, 0.0, 0.18), delta, 12.0)
	_lock_head_to_body(STATE_CHASE, delta)
	for arm in _continuous_arms:
		arm.update_surface()


func _apply_climbing_pose(delta: float) -> void:
	var up := _body.global_basis.y.normalized()
	var forward := _body.global_basis.z.normalized()
	var right := _body.global_basis.x.normalized()
	var step := sin(_church._idle_clock * 4.0)
	var crawling := _church.surface.phase != _church.surface.Phase.DROP
	_pose_node(_rig, _offset_pose(_base_rig_rotation, 1.0 if crawling else 0.18, step * 0.04, 0.0), delta, 8.0)
	_rig.position = _rig_rest_position
	position = _base_position
	# Alternating grasp/release strokes in the surface frame, including upside down.
	var grip := _body.global_position + up * (0.08 if crawling else 0.9)
	var reach := 1.2 if crawling else 0.25
	_hands(grip + right * 0.4 + forward * (reach + step * 0.18) + up * maxf(step, 0.0) * 0.12,
		grip - right * 0.4 + forward * (reach - step * 0.18) + up * maxf(-step, 0.0) * 0.12, delta, 12.0)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.5, 0, -0.18), delta, 10.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, -0.5, 0, 0.18), delta, 10.0)
	_lock_head_to_body(STATE_CHASE, delta)
	for arm in _continuous_arms:
		arm.update_surface()


func _hands(left: Vector3, right: Vector3, delta: float, responsiveness: float = 8.0, raised: bool = false) -> void:
	var left_pole := Vector3.ZERO
	var right_pole := Vector3.ZERO
	var solve_delta := delta
	if raised:
		# Interpolate the hand path, then solve the joints directly. Blending
		# shoulder quaternions can take the short route behind the back even
		# when the final hand target is above the head.
		var blend := minf(delta * responsiveness, 1.0)
		left = _left_wrist.global_position.lerp(left, blend)
		right = _right_wrist.global_position.lerp(right, blend)
		var front := _body.global_basis.z.normalized()
		var side := _body.global_basis.x.normalized()
		left_pole = front + Vector3.UP * 0.55 + side * 0.6
		right_pole = front + Vector3.UP * 0.55 - side * 0.6
		solve_delta = 1.0
	_pose_arm_ik(_left_shoulder, _left_elbow, _left_wrist, _base_left_shoulder, _base_left_elbow,
		_left_upper_rest_direction, _left_lower_rest_direction, left, 1.0, solve_delta, responsiveness, left_pole)
	_pose_arm_ik(_right_shoulder, _right_elbow, _right_wrist, _base_right_shoulder, _base_right_elbow,
		_right_upper_rest_direction, _right_lower_rest_direction, right, -1.0, solve_delta, responsiveness, right_pole)


func _listening() -> bool:
	return _church.intent == Brain.Intent.LISTEN or (_church.intent == Brain.Intent.SEARCH and _church._search_dwell >= 0.0)


func _apply_locomotion_pose(delta: float, state: int, moving: float) -> void:
	if state == STATE_CHASE:
		_apply_hunting_arms(delta)
		return
	var forward := _body.global_basis.z.normalized()
	var right := _body.global_basis.x.normalized()
	var clock := _church._idle_clock
	var stride := sin(_phase) * moving
	var vigilance := _church.tension
	var center := _body.global_position + Vector3.UP * resting_hand_height
	# One arm leads, the other trails; idle motion has its own clock, not foot phase.
	var left := center + right * resting_hand_width + forward * (0.13 + stride * 0.16 + vigilance * 0.18)
	var other := center - right * resting_hand_width + forward * (0.02 - stride * 0.1)
	left.y += sin(clock * 1.13) * 0.018 + vigilance * 0.06
	other.y += sin(clock * 0.83 + 2.1) * 0.025 - 0.075
	_hands(left, other, delta, 6.5)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.12, 0.0, -0.12 - vigilance * 0.08), delta, 5.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, 0.06, 0.0, 0.18), delta, 5.0)


func _apply_alert_pose(delta: float, state: int, moving: float) -> void:
	var forward := _body.global_basis.z.normalized()
	var right := _body.global_basis.x.normalized()
	var center := _body.global_position + Vector3.UP
	var scan := sin(_church._idle_clock * 1.1)
	var left := center + right * 0.37 + forward * (0.44 + scan * 0.07)
	var other := center - right * 0.4 + forward * 0.08 + Vector3.DOWN * 0.1
	if _listening():
		left = _head.global_position + right * 0.28 + forward * 0.06 + Vector3.DOWN * 0.12
		other += forward * 0.16
	elif state == STATE_SEARCH:
		left += forward * 0.12 + Vector3.DOWN * 0.1
		other += forward * 0.15
	left += forward * sin(_phase) * moving * 0.045
	_hands(left, other, delta, 5.5 if _listening() else 7.5)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.2, 0.0, -0.22), delta, 6.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, -0.06, 0.0, 0.12), delta, 6.0)


func _apply_hunting_arms(delta: float, reaching: bool = false) -> void:
	var forward := _body.global_basis.z.normalized()
	var right := _body.global_basis.x.normalized()
	var origin := _body.global_position
	var sway := sin(_church._idle_clock * 3.2) * 0.035
	# Brazos casi extendidos desde el codo y un 30 % mas abiertos que antes.
	var reach := 1.12 if reaching else 0.98
	_hands(origin + Vector3.UP * (1.83 + sway) + right * 0.5 + forward * reach,
		origin + Vector3.UP * (1.74 - sway) - right * 0.5 + forward * (reach + 0.06), delta, 12.0, true)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.18, 0, -0.14), delta, 10.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, -0.18, 0, 0.14), delta, 10.0)


func _apply_reaching_pose(delta: float) -> void:
	_apply_hunting_arms(delta, true)


func _apply_attack_pose(delta: float, attack_timer: float) -> void:
	var windup := smoothstep(0.0, _church.attack_windup_seconds * 0.68, attack_timer)
	var strike := smoothstep(_church.attack_windup_seconds, _church.attack_hit_seconds, attack_timer)
	var recovery := smoothstep(_church.attack_hit_seconds + 0.06, _church.attack_animation_seconds, attack_timer)
	var player_target := _church._prey == _church._player
	var forward := _church._attack_direction if player_target else _body.global_basis.z.normalized()
	var right := _body.global_basis.x.normalized()
	var origin := _body.global_position
	# Raise in front of the face, hold overhead, then cut downward. Neither
	# preparation nor recovery sends the hand below the waist or behind her.
	var loaded := origin + Vector3.UP * lerpf(1.78, 2.45, windup) + forward * (0.78 + sin(windup * PI) * 0.18) + right * _church.attack_side * 0.5
	var contact := _church.attack_target_position if player_target else origin + forward * 1.1 + Vector3.UP * 0.9
	var striking := loaded.lerp(contact + right * _church.attack_side * 0.16, strike)
	striking = striking.lerp(origin + Vector3.UP * 1.78 + right * _church.attack_side * 0.5 + forward * 0.78, recovery)
	var guarding := origin + Vector3.UP * 1.78 - right * _church.attack_side * 0.5 + forward * 0.78
	_hands(striking if _church.attack_side > 0.0 else guarding, guarding if _church.attack_side > 0.0 else striking, delta, 28.0, true)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.16 * strike, 0.0, -0.16), delta, 12.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, -0.16 * strike, 0.0, 0.16), delta, 12.0)


func _lock_head_to_body(state: int, delta: float) -> void:
	if state == STATE_EAT or _church._prey != _church._player:
		super._lock_head_to_body(state, delta)
		return
	_head.position = _base_head_position + Vector3(0.0, -head_down_offset, 0.0)
	var direction := _body.global_basis.inverse() * (_church.get_attention_position() - _head.global_position)
	var yaw := clampf(atan2(direction.x, direction.z), -0.58, 0.58)
	var pitch := clampf(-atan2(direction.y, maxf(Vector2(direction.x, direction.z).length(), 0.1)), -0.2, 0.2) - _church.tension * 0.07
	var tilt := 0.1 if _listening() else sin(_church._idle_clock * 0.6) * 0.025
	var target := _base_head_rotation * Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch) * Quaternion(Vector3.BACK, tilt)
	_head.quaternion = _head.quaternion.slerp(target, 1.0 - exp(-7.5 * delta))
	_head.scale = _base_head_scale * head_scale_multiplier


func _apply_body_motion(delta: float, state: int, moving: float, duck_amount: float, covered_eyes: bool, crossing_door: bool) -> void:
	if state == STATE_EAT or covered_eyes or crossing_door or _church._prey != _church._player:
		_rig.position = _rig.position.lerp(_rig_rest_position, 1.0 - exp(-8.0 * delta))
		super._apply_body_motion(delta, state, moving, duck_amount, covered_eyes, crossing_door)
		return
	var speed := Vector2(_body.get_real_velocity().x, _body.get_real_velocity().z).length()
	var acceleration_pitch := clampf((speed - _previous_speed) / maxf(delta, 0.001) * -0.012, -0.07, 0.07)
	_previous_speed = speed
	_weight_pitch = lerpf(_weight_pitch, acceleration_pitch, 1.0 - exp(-5.0 * delta))
	# El tramo inferior apenas se inclina: la encorvadura fuerte ya sucede por
	# encima de UPPER_BACK_HINGE, haciendo visible una espalda recta y otra doblada.
	var lean := 0.045 + moving * 0.045 + _church.tension * 0.015 - _weight_pitch
	var twist := sin(_phase) * moving * 0.025
	var sway := sin(_phase * 0.5) * moving * 0.03 + _lean_amount
	if _listening():
		lean += 0.055
		sway += 0.025
	if state == STATE_ATTACK:
		var windup := smoothstep(0.0, _church.attack_windup_seconds, _church._attack_timer)
		var strike := smoothstep(_church.attack_windup_seconds, _church.attack_hit_seconds, _church._attack_timer)
		var recover := 1.0 - smoothstep(_church.attack_hit_seconds, _church.attack_animation_seconds, _church._attack_timer)
		lean += (strike * 0.27 - windup * 0.09) * recover
		twist += _church.attack_side * (windup * -0.16 + strike * 0.32) * recover
	var breathing := sin(_church._idle_clock * lerpf(1.8, 2.9, _church.tension))
	sway += sin(_church._idle_clock * 0.65) * 0.009 * (1.0 - moving)
	_pose_node(_rig, _offset_pose(_base_rig_rotation, lean, twist, sway), delta, 7.0)
	# Bend around the waist rather than tipping the whole dress from the feet.
	var rotation_delta := _rig.basis * Basis(_base_rig_rotation).inverse()
	_rig.position = _waist_pivot + rotation_delta * (_rig_rest_position - _waist_pivot)
	var bob := (absf(sin(_phase)) - 0.5) * walk_bob_height * moving
	position = position.lerp(_base_position + Vector3(0.0, bob + breathing * 0.008, 0.0), 1.0 - exp(-8.0 * delta))
