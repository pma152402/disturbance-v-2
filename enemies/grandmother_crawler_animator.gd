extends "res://enemies/church_grandmother_animator.gd"
## Four contact gait in the actor's surface frame. A planted limb keeps its world
## anchor; its next swing follows distance actually travelled, never a free clock.
const SkinSurface := preload("res://enemies/crawler_surface_mesh.gd")
const MODEL_SCALE := 0.207
const LEG_SEGMENT_LENGTH := 0.73
const REST_CONTACTS := [Vector3(0.43, 0.065, 0.67), Vector3(-0.43, 0.065, 0.67), Vector3(0.29, 0.065, -0.88), Vector3(-0.29, 0.065, -0.88)]
const OFFSETS := [0.0, 0.5, 0.75, 0.25]
var anatomy: Node3D
var torso: MeshInstance3D
var collar: MeshInstance3D
var legs: Array[MeshInstance3D] = []
var hips: Array[Node3D] = []
var knees: Array[Node3D] = []
var ankles: Array[Node3D] = []
var anchors: Array[Vector3] = []
var releases: Array[Vector3] = []
var landings: Array[Vector3] = []
var swinging: Array[bool] = []
var contacts: Array[Vector3] = []
var _cloth: Material
var _leg_cloth: Material
var _travel_phase := 0.0
var _last_origin := Vector3.ZERO
var _last_basis := Basis.IDENTITY
var _speed_blend := 0.0
var _rear := 0.0
var _palm_rest: Array[Basis] = []
var _initialized := false
var _settling := false
var shadow_coat: RefCounted
var _crawler_hair: MeshInstance3D

@export_group("Acecho en sombras")
@export var shadow_coat_enabled := true
@export_range(0.5, 8.0, 0.1) var shadow_reveal_distance := 2.2
@export_range(3.0, 20.0, 0.1) var shadow_full_distance := 9.0
@export_range(0.0, 1.0, 0.01) var shadow_darkness := 0.94

func _ready() -> void:
	super._ready()
	_crawler_hair = get_parent().get_node_or_null("FloatingHair") as MeshInstance3D
	var old_body := _rig.get_node("Body") as MeshInstance3D
	_cloth = old_body.get_active_material(0).duplicate()
	# The imported texture is a full-character atlas, not a tiling fabric.
	# Map only its intact dress panel onto the new fitted garments.
	if _cloth is StandardMaterial3D:
		_cloth.uv1_scale = Vector3(0.16, 0.30, 1)
		_cloth.uv1_offset = Vector3(0.37, 0.06, 0)
		_cloth.albedo_color = Color(0.68, 0.65, 0.60)
		_cloth.roughness = 0.96
	_leg_cloth = _cloth.duplicate()
	if _leg_cloth is StandardMaterial3D:
		_leg_cloth.albedo_color *= Color(0.55, 0.53, 0.50)
	old_body.visible = false
	for arm in _continuous_arms:
		arm._cloth = _cloth
		arm.thickness_scale = 0.82
	# Lengthen the anatomical bones, not the entire hand/arm node scale, so the
	# wrist pivot, palm closure and IK continue to share exactly the same points.
	for elbow in [_left_elbow, _right_elbow]:
		elbow.position *= 1.50
	for wrist in [_left_wrist, _right_wrist]:
		wrist.position *= 1.50
	anatomy = Node3D.new()
	anatomy.name = "CrawlerAnatomy"
	anatomy.scale = Vector3.ONE / MODEL_SCALE
	_rig.add_child(anatomy)
	torso = SkinSurface.new()
	torso.name = "ContinuousTorso"
	torso.bust_depth = 0.24
	anatomy.add_child(torso)
	collar = SkinSurface.new()
	collar.name = "NeckConnection"
	anatomy.add_child(collar)
	for side in [1.0, -1.0]:
		var hip := Node3D.new()
		hip.name = "LeftHip" if side > 0 else "RightHip"
		anatomy.add_child(hip)
		var knee := Node3D.new()
		knee.name = "Knee"
		hip.add_child(knee)
		var ankle := Node3D.new()
		ankle.name = "Ankle"
		knee.add_child(ankle)
		hips.append(hip)
		knees.append(knee)
		ankles.append(ankle)
		var leg := SkinSurface.new()
		leg.name = "ContinuousLegLeft" if side > 0 else "ContinuousLegRight"
		anatomy.add_child(leg)
		legs.append(leg)
	for palm in [_left_palm, _right_palm]:
		# Store the wrist in the creature's surface frame. The church instance is
		# authored with a 90-degree spawn rotation; caching a global basis applies
		# that rotation twice later and twists the right hand away from its arm.
		var wrist := palm.get_parent() as Node3D
		_palm_rest.append((_body.global_basis.inverse() * wrist.global_basis).orthonormalized())
	for i in 4:
		anchors.append(Vector3.ZERO)
		releases.append(Vector3.ZERO)
		landings.append(Vector3.ZERO)
		contacts.append(Vector3.ZERO)
		swinging.append(false)
	_last_origin = _body.global_position
	_last_basis = _body.global_basis
	_reset_contacts()
	_initialized = true
	_physics_process(0.016)

func _reset_contacts() -> void:
	_settling = false
	for i in 4:
		anchors[i] = _support(_body.global_transform * _rest_contact(i))
		releases[i] = anchors[i]
		landings[i] = anchors[i]
		contacts[i] = anchors[i]
		swinging[i] = false

func _support(point: Vector3) -> Vector3:
	var up := _body.global_basis.y.normalized()
	var query := PhysicsRayQueryParameters3D.create(point + up * 0.4, point - up * 0.5, _body.collision_mask | (1 << 19), [_body.get_rid()])
	var hit := _body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.dot(up) > 0.55:
		return hit.position + up * 0.065 * _body.global_basis.get_scale().abs().y
	return point

func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	if shadow_coat != null:
		shadow_coat.update(delta)
	var up := _body.global_basis.y.normalized()
	var travel := (_body.global_position - _last_origin).slide(up)
	var distance := travel.length()
	var turning := _last_basis.z.angle_to(_body.global_basis.z)
	var changing_surface := _last_basis.y.normalized().dot(up) < 0.9995
	var airborne: bool = _church.surface.spider_leaping or _church.surface.pouncing or (_church.surface.phase == _church.surface.Phase.DROP and not _church.surface.spider_winding_up)
	if distance > 0.6 or changing_surface:
		_reset_contacts()
		distance = 0.0
	_speed_blend = lerpf(_speed_blend, 0.0 if airborne else clampf(distance / maxf(delta, 0.001) / 2.2, 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	if not airborne: _travel_phase += distance / 0.65 + turning * 0.15
	_last_origin = _body.global_position
	_last_basis = _body.global_basis
	var attack := _church.current_state == STATE_ATTACK and not _church.surface.active()
	var windup := smoothstep(0.0, _church.attack_windup_seconds, _church._attack_timer) if attack else 0.0
	var recovery := smoothstep(_church.attack_hit_seconds, _church.attack_animation_seconds, _church._attack_timer) if attack else 0.0
	var rear_target := windup * (1.0 - recovery)
	var vomit_attack: Node3D = _church.get("vomit")
	var vomiting: bool = is_instance_valid(vomit_attack) and vomit_attack.stationary()
	if _church.surface.spider_winding_up:
		rear_target = -0.62 * smoothstep(0.0, 0.42, _church.surface.spider_windup_time)
	elif _church.surface.spider_leaping:
		var landing_blend := _jump_landing_blend()
		var extension := smoothstep(0.0, 0.22, _flight_progress())
		rear_target = lerpf(lerpf(-0.62, 0.10, extension), -0.10, landing_blend)
	elif _church.surface.pouncing:
		rear_target = lerpf(-0.32, -0.08, _jump_landing_blend())
	elif _church.surface.winding_up:
		rear_target = -0.40 * smoothstep(0.0, 0.55, _church.surface.windup_time)
	elif _church.surface.landing_recovery > 0:
		var absorption := clampf(1.0 - _church.surface.landing_recovery / 0.38, 0.0, 1.0)
		rear_target = -0.44 * sin(PI * pow(absorption, 0.7))
	if _church.current_state == STATE_EAT:
		rear_target = 0.2
	if vomiting:
		if vomit_attack.phase == vomit_attack.Phase.WINDUP:
			rear_target = -0.34 * sin(clampf(vomit_attack.elapsed / vomit_attack.WINDUP_SECONDS, 0.0, 1.0) * PI)
		elif vomit_attack.phase == vomit_attack.Phase.SPRAY:
			rear_target = 0.12 + sin(vomit_attack.elapsed * 15.0) * 0.025
		else:
			rear_target = -0.10
	_rear = lerpf(_rear, rear_target, 1.0 - exp(-12.0 * delta))
	var breath := sin(_church._idle_clock * 1.7) * 0.006
	var bob := 0.0 if airborne else sin(_travel_phase * TAU * 2.0) * _speed_blend * 0.016
	var landmarks := _body_landmarks(breath, bob)
	var pelvis: Vector3 = landmarks[0]
	var chest: Vector3 = landmarks[1]
	var neck := chest + Vector3(0, 0.09, 0.085)
	_head.position = (neck + Vector3(0, 0.055, 0.035) * head_scale_multiplier) / MODEL_SCALE
	var attention := _body.global_basis.inverse() * (_church.get_attention_position() - _head.global_position)
	var yaw := clampf(atan2(attention.x, attention.z), -0.45, 0.45)
	var pitch := clampf(-atan2(attention.y, maxf(Vector2(attention.x, attention.z).length(), 0.1)), -0.20, 0.16)
	var head_target := Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch + 0.10)
	if vomiting:
		var direction: Vector3 = _body.global_basis.orthonormalized().inverse() * vomit_attack.aim_direction
		var aim_yaw := clampf(atan2(direction.x, direction.z), -vomit_attack.MAX_HEAD_YAW, vomit_attack.MAX_HEAD_YAW)
		var aim_pitch := clampf(-atan2(direction.y, maxf(Vector2(direction.x, direction.z).length(), 0.001)), -vomit_attack.MAX_HEAD_PITCH, vomit_attack.MAX_HEAD_PITCH)
		head_target = Quaternion(Vector3.UP, aim_yaw) * Quaternion(Vector3.RIGHT, aim_pitch) * Quaternion(Vector3.BACK, vomit_attack.head_roll)
		# Lift only the articulated head when looking backwards so the mouth
		# clears the shoulders; the generated neck keeps both ends connected.
		_head.position.y += smoothstep(0.0, 0.8, -direction.z) * 0.14 / MODEL_SCALE
	_pose_node(_head, head_target, delta, 24.0 if vomiting else 6.0)
	_head.scale = _base_head_scale * head_scale_multiplier
	if _crawler_hair != null:
		_crawler_hair.head_size_multiplier = head_scale_multiplier
	_left_shoulder.position = (chest + _shoulder_offset(1.0)) / MODEL_SCALE
	_right_shoulder.position = (chest + _shoulder_offset(-1.0)) / MODEL_SCALE
	# The elongated blouse remains continuous between the chest and pelvis.
	torso.build(PackedVector3Array([pelvis + Vector3(0, -0.015, -0.10), pelvis, pelvis.lerp(chest, 0.32) + Vector3(0, 0.04, 0), pelvis.lerp(chest, 0.65) + Vector3(0, 0.035, 0), chest, neck]), PackedVector2Array([Vector2(0.18, 0.13), Vector2(0.25, 0.17), Vector2(0.20, 0.15), Vector2(0.26, 0.20), Vector2(0.30, 0.20), Vector2(0.085, 0.080)]), _cloth)
	var head_mount := anatomy.to_local(_head.to_global(Vector3(0, 0.15, 0.08)))
	collar.build(PackedVector3Array([neck - Vector3(0, 0.035, 0.02), neck, head_mount]), PackedVector2Array([Vector2(0.085, 0.080), Vector2(0.080, 0.075), Vector2(0.09, 0.09) * head_scale_multiplier]), _skin_material)
	_update_contacts(travel, delta)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_pose_leg(i, pelvis + Vector3(side * 0.16, -0.035, -0.03), anatomy.to_local(contacts[i + 2]), side)
		var shoulder: Node3D = _left_shoulder if i == 0 else _right_shoulder
		var elbow: Node3D = _left_elbow if i == 0 else _right_elbow
		var wrist: Node3D = _left_wrist if i == 0 else _right_wrist
		var palm: MeshInstance3D = _left_palm if i == 0 else _right_palm
		var palm_target := contacts[i]
		# Hands and feet use the same staged flight contacts. No second hand-only
		# override may keep the palms tucked while the rest of the rig lands.
		if _church.current_state == STATE_EAT:
			var meal := _church.get("_eating_target") as Node3D
			var meal_point := _body.global_transform * Vector3(side * 0.16, 0.18, 0.6)
			if is_instance_valid(meal):
				meal_point = meal.global_position + up * 0.16 + _body.global_basis.x * side * 0.16
			var cycle := fposmod(_church._eating_elapsed * 1.35 + i * 0.5, 1.0)
			var transfer := smoothstep(0.08, 0.43, cycle) * (1.0 - smoothstep(0.48, 0.86, cycle))
			palm_target = meal_point.lerp(_head.global_position + _body.global_basis * Vector3(side * 0.1, -0.08, 0.12), transfer)
		if attack and side == _church.attack_side:
			var load_point := _body.global_transform * Vector3(side * 0.38, 1.58, 0.55)
			var strike := smoothstep(_church.attack_windup_seconds, _church.attack_hit_seconds, _church._attack_timer)
			var hit_point := _body.global_transform * Vector3(side * 0.18, 0.70, 1.0)
			palm_target = palm_target.lerp(load_point.lerp(hit_point, strike), windup * (1.0 - recovery))
		# Rotate the complete hand about its anatomical wrist. Keep its heel
		# embedded in the continuous forearm even while rearing to strike.
		var hand_basis := _hand_basis(i)
		wrist.global_basis = hand_basis.scaled(wrist.global_basis.get_scale())
		var target := _correct_wrist_target_for_palm(wrist, palm, palm_target)
		_pose_arm_ik(shoulder, elbow, wrist, _base_left_shoulder if i == 0 else _base_right_shoulder, _base_left_elbow if i == 0 else _base_right_elbow, _left_upper_rest_direction if i == 0 else _right_upper_rest_direction, _left_lower_rest_direction if i == 0 else _right_lower_rest_direction, target, side, 1.0, 1.0, _body.global_basis * Vector3(side, 0.35, -0.65))
		wrist.global_basis = hand_basis.scaled(wrist.global_basis.get_scale())
	for i in 2:
		_continuous_arms[i].mount = (chest + _arm_mount_offset(1.0 if i == 0 else -1.0)) / MODEL_SCALE
		_continuous_arms[i].update_surface()

func _body_landmarks(breath: float, bob: float) -> Array[Vector3]:
	return [Vector3(0, 1.09 + breath + bob + _rear * 0.12, -0.60), Vector3(0, 0.95 + breath - bob + _rear * 0.34, 0.36 - _rear * 0.10)]

func _shoulder_offset(side: float) -> Vector3:
	return Vector3(side * 0.285, 0, -0.035)

func _arm_mount_offset(side: float) -> Vector3:
	return Vector3(side * 0.20, 0, -0.035)

func _rest_contact(index: int) -> Vector3:
	return REST_CONTACTS[index]

func _hand_basis(index: int) -> Basis:
	# La escala de muñeca se aplica después; no multiplicarla otra vez por frame.
	return _body.global_basis.orthonormalized() * Basis(Vector3.RIGHT, -PI * 0.5) * _palm_rest[index]

func _leg_pole(side: float) -> Vector3:
	return Vector3(side * 0.85, 0.1, 0.6)

func _jump_landing_blend() -> float:
	return smoothstep(0.42, 0.76, _flight_progress()) if _church.surface.pouncing else smoothstep(0.58, 0.88, _flight_progress())

func _flight_progress() -> float:
	if _church.surface.pouncing:
		return clampf(_church.surface.pounce_time / maxf(_church.surface.pounce_flight_duration, 0.1), 0.0, 1.0)
	return clampf(_church.surface.spider_flight_time / maxf(_church.surface.spider_flight_duration, 0.1), 0.0, 1.0)


func _update_contacts(travel: Vector3, _delta: float) -> void:
	var dropping: bool = _church.surface.phase == _church.surface.Phase.DROP and not _church.surface.spider_winding_up
	if _church.surface.spider_settling > 0.0:
		_speed_blend = 0.0
		_reset_contacts()
		return
	var idle: bool = not dropping and _speed_blend < 0.025 and travel.length_squared() < 0.000001
	if idle and not _settling:
		for i in 4:
			landings[i] = _support(_body.global_transform * REST_CONTACTS[i])
	_settling = idle
	for i in 4:
		var phase := fposmod(_travel_phase + OFFSETS[i], 1.0)
		var nominal: Vector3 = _body.global_transform * REST_CONTACTS[i]
		var swing := phase >= 0.68
		if _church.surface.spider_leaping or _church.surface.pouncing:
			var side := 1.0 if i % 2 == 0 else -1.0
			var tucked := Vector3(side * 0.40, 0.34, 0.42) if i < 2 else Vector3(side * 0.24, 0.34, -0.22)
			# Abrir las cuatro extremidades antes del contacto: mantenerlas recogidas
			# hasta aterrizar hacía que el torso pareciese caer primero de espaldas.
			var lift := smoothstep(0.0, 0.18, _flight_progress())
			var flight_pose: Vector3 = REST_CONTACTS[i].lerp(tucked, lift).lerp(REST_CONTACTS[i], _jump_landing_blend())
			contacts[i] = _body.global_transform * flight_pose
			anchors[i] = contacts[i]
			swinging[i] = false
			continue
		if dropping:
			contacts[i] = nominal + _body.global_basis.y * 0.19
			anchors[i] = contacts[i]
			swinging[i] = false
			continue
		if idle:
			anchors[i] = contacts[i].lerp(landings[i], 1.0 - exp(-12.0 * _delta))
			contacts[i] = anchors[i]
			swinging[i] = false
			continue
		if swing and not swinging[i]:
			releases[i] = anchors[i]
			landings[i] = _support(nominal + travel.normalized() * (0.23 if i < 2 else 0.38) * _body.global_basis.get_scale().abs().y)
		if not swing and swinging[i]:
			anchors[i] = landings[i]
		# A sudden turn/transition can make an old world anchor unreachable.
		# Release it locally rather than stretching bones or dragging a hand.
		if anchors[i].distance_to(nominal) > 0.38 * _body.global_basis.get_scale().abs().y:
			anchors[i] = anchors[i].lerp(_support(nominal), 0.3)
		swinging[i] = swing
		if swing:
			var t := clampf((phase - 0.68) / 0.32, 0.0, 1.0)
			contacts[i] = releases[i].lerp(landings[i], smoothstep(0.0, 1.0, t)) + _body.global_basis.y * sin(t * PI) * (0.09 if i < 2 else 0.12)
		else:
			contacts[i] = anchors[i]

func _pose_leg(index: int, hip: Vector3, foot: Vector3, side: float) -> void:
	var direction := (foot - hip).normalized()
	var length := clampf(hip.distance_to(foot), 0.08, LEG_SEGMENT_LENGTH * 2.0 - 0.02)
	var along := length * 0.5
	var pole := _leg_pole(side).slide(direction).normalized()
	var knee := hip + direction * along + pole * sqrt(maxf(0, LEG_SEGMENT_LENGTH * LEG_SEGMENT_LENGTH - along * along))
	foot = hip + direction * length
	hips[index].position = hip
	knees[index].position = knee - hip
	ankles[index].position = foot - knee
	var toe := foot + Vector3(0, -0.022, 0.17)
	legs[index].build(PackedVector3Array([hip + Vector3(-side * 0.035, 0.04, 0.02), hip, hip.lerp(knee, 0.45), knee, knee.lerp(foot, 0.4), foot, toe, toe + Vector3(0, 0, 0.07)]), PackedVector2Array([Vector2(0.125, 0.12), Vector2(0.115, 0.105), Vector2(0.084, 0.084), Vector2(0.062, 0.062), Vector2(0.064, 0.060), Vector2(0.052, 0.048), Vector2(0.080, 0.038), Vector2(0.062, 0.025)]), _leg_cloth)
