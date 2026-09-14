extends "res://enemies/grandmother_crawler_animator.gd"

const UPRIGHT_CONTACTS := [Vector3(0.27, 0.85, 0.13), Vector3(-0.27, 0.85, 0.13), Vector3(0.14, 0.065, -0.10), Vector3(-0.14, 0.065, -0.10)]
var _pain_clock := 0.0
var _pain := 0.0
var _tremor := 0.0
var _charge_pose := 0.0
var _sprinting := false
const PAIN_POSE_SECONDS := 0.2
const PAIN_SNAP_SECONDS := 0.03
# Distinct, asymmetric silhouettes: reach above the skull, wrench sideways,
# throw one arm forward. Neither hand settles on the pelvis.
const PAIN_POSES := [
	[Vector3(-0.18, -0.18, 0.18), Vector3(0.55, -0.75, 0.60), Vector3(0.10, -0.70, 0.40), Vector3(0.50, 2.40, 0.35), Vector3(-0.85, 1.90, 0.50)],
	[Vector3(0.19, -0.30, 0.26), Vector3(-0.65, 0.90, -0.65), Vector3(-0.15, 0.80, -0.40), Vector3(0.85, 1.65, 0.65), Vector3(-0.35, 2.45, -0.18)],
	[Vector3(-0.12, -0.08, -0.10), Vector3(-0.70, -0.90, 0.50), Vector3(0.15, -0.65, -0.25), Vector3(0.40, 2.35, -0.15), Vector3(-0.75, 0.85, 0.65)],
	[Vector3(0.18, -0.24, 0.22), Vector3(0.65, 0.65, -0.70), Vector3(-0.10, 0.75, 0.40), Vector3(0.80, 0.95, 0.65), Vector3(-0.50, 2.35, 0.35)],
	[Vector3(-0.20, -0.28, 0.30), Vector3(0.70, -0.60, 0.70), Vector3(0.12, -0.85, 0.35), Vector3(0.38, 2.50, 0.25), Vector3(-0.75, 1.90, -0.20)],
	[Vector3(0.15, -0.12, 0.05), Vector3(-0.55, 0.90, -0.55), Vector3(-0.15, 0.70, -0.35), Vector3(0.75, 1.95, 0.60), Vector3(-0.45, 2.45, 0.30)],
]
var _pain_blend := 0.0
var _pain_pose_index := 0
var _pain_chest := Vector3.ZERO
var _pain_head := Vector3.ZERO
var _pain_twist := Vector3.ZERO
var _pain_hands: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]

func _update_pain_pose(delta: float) -> void:
	_pain = _church.light_pain
	_pain_blend = smoothstep(0.0, 0.20, _pain)
	if _pain <= 0.0:
		_pain_clock = 0.0
		_pain_pose_index = 0
		_tremor = 0.0
		return
	_pain_clock += maxf(delta, 0.0)
	var step := floori((_pain_clock + 0.000001) / PAIN_POSE_SECONDS)
	_pain_pose_index = step % PAIN_POSES.size()
	var previous := (step - 1) % PAIN_POSES.size() if step > 0 else 0
	var snap := smoothstep(0.0, PAIN_SNAP_SECONDS, maxf(0.0, _pain_clock - step * PAIN_POSE_SECONDS))
	var from: Array = PAIN_POSES[previous]
	var to: Array = PAIN_POSES[_pain_pose_index]
	_pain_chest = from[0].lerp(to[0], snap)
	_pain_head = from[1].lerp(to[1], snap)
	_pain_twist = from[2].lerp(to[2], snap)
	for i in 2:
		_pain_hands[i] = from[i + 3].lerp(to[i + 3], snap)
	# Small shivers between the much larger five-per-second pose snaps.
	_tremor = (sin(_pain_clock * TAU * 9.3) * 0.65 + sin(_pain_clock * TAU * 13.7) * 0.35) * _pain

func _pain_shoulder_basis() -> Basis:
	return Basis.from_euler(_pain_twist * _pain_blend)

func _ready() -> void:
	super._ready()
	var slim := preload("res://enemies/shadow_humanoid_surface.gd")
	torso.set_script(slim)
	torso.bust_depth = 0.035
	collar.set_script(slim)
	collar.profile_scale = Vector2(0.65, 0.65)
	for leg in legs:
		leg.set_script(slim)
		leg.profile_scale = Vector2(0.50, 0.52)
	_base_head_scale *= Vector3(0.78, 1.0, 0.85)
	for wrist in [_left_wrist, _right_wrist]: wrist.scale *= 0.72
	for arm in _continuous_arms:
		arm.thickness_scale = 0.42
		# Keep a sealed wrist and shoulder while reducing their local collars.
		for i in [0, 1, 7, 8]: arm._radii[i] *= 0.68
	_physics_process(0.016)

func _body_landmarks(breath: float, bob: float) -> Array[Vector3]:
	var crouch: float = _church.humanoid_crouch
	var pelvis := Vector3(0, 1.22 + breath + bob - crouch * 0.55, -0.10)
	var chest := Vector3(0, 1.89 + breath - bob - crouch * 0.65, 0.12 + crouch * 0.08)
	pelvis += Vector3(-_pain_chest.x * 0.18, -0.045, 0) * _pain_blend
	chest += _pain_chest * _pain_blend * lerpf(0.75, 1.0, _pain) + Vector3(_tremor * 0.012, 0, 0)
	chest += Vector3(0, -0.30, 0.40) * _charge_pose * (1.0 - _pain_blend)
	if _sprinting:
		chest += Vector3(0, -0.16, 0.26) * (1.0 - _pain_blend)
	return [pelvis, chest]

func _shoulder_offset(side: float) -> Vector3:
	return _pain_shoulder_basis() * Vector3(side * 0.175, 0, -0.02)

func _arm_mount_offset(side: float) -> Vector3:
	return _pain_shoulder_basis() * Vector3(side * 0.10, 0, -0.02)

func _rest_contact(index: int) -> Vector3:
	var point: Vector3 = UPRIGHT_CONTACTS[index]
	if index < 2: point.y -= _church.humanoid_crouch * 0.32
	return point

func _hand_basis(index: int) -> Basis:
	var side := 1.0 if index == 0 else -1.0
	var recoil := Basis(Vector3.FORWARD, side * (_pain * 0.35 + _tremor * 0.12))
	return _body.global_basis * recoil * _palm_rest[index]

func _leg_pole(side: float) -> Vector3:
	return Vector3(side * 0.08, 0.1, 1.0)

func _pose_node(node: Node3D, target: Quaternion, delta: float, speed: float) -> void:
	if node == _head:
		var direction: Vector3 = _head.get_parent().global_basis.orthonormalized().inverse() * (_church.get_attention_position() - _head.global_position)
		var yaw := clampf(atan2(direction.x, direction.z), -1.3, 1.3)
		var pitch := clampf(-atan2(direction.y, maxf(Vector2(direction.x, direction.z).length(), 0.01)), -0.85, 0.85)
		target = Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch)
		var convulsion := Basis.from_euler(_pain_head + Vector3(_tremor * 0.05, 0, _tremor * 0.06)).get_rotation_quaternion()
		target = target.slerp(convulsion, _pain_blend)
		node.quaternion = node.quaternion.slerp(target, 1.0 - exp(-lerpf(16.0, 95.0, _pain_blend) * delta)).normalized()
		return
	super._pose_node(node, target, delta, speed)

func _update_contacts(travel: Vector3, delta: float) -> void:
	for i in 4:
		var nominal := _body.global_transform * _rest_contact(i)
		if i < 2:
			# Hands hang beside the thighs, with small opposing walking swings.
			var swing := sin(_travel_phase * TAU + i * PI) * _speed_blend * (0.38 if _sprinting else 0.12)
			contacts[i] = nominal + _body.global_basis.z * swing
			var extended := Vector3(1.35 if i == 0 else -1.35, 1.45 - _church.humanoid_crouch * 0.32, 0.85)
			contacts[i] = contacts[i].lerp(_body.global_transform * extended, _charge_pose)
			if _pain > 0.0:
				var recoil: Vector3 = _pain_hands[i] - Vector3.UP * _church.humanoid_crouch * 0.40
				recoil.x += _tremor * 0.015
				contacts[i] = contacts[i].lerp(_body.global_transform * recoil, _pain_blend)
			anchors[i] = contacts[i]
			continue
		var phase := fposmod(_travel_phase + (i - 2) * 0.5, 1.0)
		var moving := _speed_blend > 0.025 and travel.length_squared() > 0.000001
		var swing := moving and phase >= 0.55
		if anchors[i].distance_to(nominal) > 0.6:
			anchors[i] = _support(nominal)
		if swing and not swinging[i]:
			releases[i] = contacts[i]
			landings[i] = _support(nominal + travel.normalized() * 0.26)
		if not swing and swinging[i]:
			anchors[i] = landings[i]
		swinging[i] = swing
		if not moving:
			anchors[i] = anchors[i].lerp(_support(nominal), 1.0 - exp(-10.0 * delta))
		if swing:
			var t := (phase - 0.55) / 0.45
			contacts[i] = releases[i].lerp(landings[i], smoothstep(0.0, 1.0, t)) + _body.global_basis.y * sin(t * PI) * 0.10
		else:
			contacts[i] = anchors[i]

func _physics_process(delta: float) -> void:
	_sprinting = _church.stalking != null and _church.stalking.sprint_remaining > 0.0
	var target: float = shadow_coat.smile_progress if shadow_coat != null and not _sprinting else 0.0
	_charge_pose = move_toward(_charge_pose, target, maxf(delta, 0.0) * 8.0)
	_update_pain_pose(delta)
	super._physics_process(delta)
	if shadow_coat == null:
		return
	# These procedural meshes assign their source material again on every pose.
	torso.material_override = shadow_coat.material
	collar.material_override = shadow_coat.material
	for leg in legs:
		leg.material_override = shadow_coat.material
