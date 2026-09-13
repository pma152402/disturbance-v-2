extends Node3D

## Cuerpo visual del jugador. No toma decisiones, no navega y no procesa input:
## el Player le entrega un estado compacto y este nodo solo construye la pose.

const WORLD_AVATAR_LAYER := 2
const GAIT := preload("res://player/locomotion_gait.gd")
const SELFIE_ITEM_SCENES := {
	&"flashlight": preload("res://pickups/dropped_flashlight.tscn"),
	&"can": preload("res://pickups/can_visual.tscn"),
	&"bottle": preload("res://pickups/bottle_visual.tscn"),
	&"plunger": preload("res://player/held_items/plunger.tscn"),
	&"crowbar": preload("res://player/held_items/crowbar.tscn"),
	&"flathead_screwdriver": preload("res://house_props/flathead_screwdriver.tscn"),
	&"note": preload("res://house_props/note_paper_visual.tscn"),
	&"recipe_book": preload("res://house_props/recipe_book_closed_visual.tscn"),
	&"matchbox": preload("res://player/held_items/matchbox_held_visual.tscn"),
	&"candle": preload("res://player/held_items/candle_held_visual.tscn"),
	&"tv_remote": preload("res://house_props/retro_tv_remote.tscn"),
	&"cassette": preload("res://house_props/cassette_tape.tscn"),
	&"camera_tripod": preload("res://house_props/camera_tripod.tscn"),
}
const SELFIE_ITEM_SIZES := {
	&"flashlight": 0.3, &"can": 0.18, &"bottle": 0.25,
	&"plunger": 0.56, &"crowbar": 0.56, &"flathead_screwdriver": 0.32,
	&"note": 0.25, &"recipe_book": 0.3, &"matchbox": 0.12,
	&"candle": 0.3, &"tv_remote": 0.2, &"cassette": 0.17,
	&"camera_tripod": 0.9,
}

@onready var body: Node3D = $Body
@onready var head: Node3D = $Body/Head
@onready var left_arm: Node3D = $Body/LeftArm
@onready var right_arm: Node3D = $Body/RightArm
@onready var left_forearm: Node3D = $Body/LeftArm/Forearm
@onready var right_forearm: Node3D = $Body/RightArm/Forearm
@onready var left_hand: MeshInstance3D = $Body/LeftArm/Forearm/Hand
@onready var right_hand: MeshInstance3D = $Body/RightArm/Forearm/Hand
@onready var left_leg: Node3D = $LeftLeg
@onready var right_leg: Node3D = $RightLeg
@onready var left_knee: Node3D = $LeftLeg/Knee
@onready var right_knee: Node3D = $RightLeg/Knee
@onready var backpack: Node3D = $Body/Backpack
@onready var left_eye: MeshInstance3D = $Body/Head/Face/LeftEye
@onready var right_eye: MeshInstance3D = $Body/Head/Face/RightEye
@onready var left_eye_white: MeshInstance3D = $Body/Head/Face/LeftEyeWhite
@onready var right_eye_white: MeshInstance3D = $Body/Head/Face/RightEyeWhite

var _rest: Dictionary = {}
var _root_rest_rotation := Vector3.ZERO
var _left_eye_rest_scale := Vector3.ONE
var _right_eye_rest_scale := Vector3.ONE
var _left_eye_white_rest_scale := Vector3.ONE
var _right_eye_white_rest_scale := Vector3.ONE
var _time := 0.0
var _step_phase := 0.0
var _motion_blend := 0.0
var _run_blend := 0.0
var _gait_direction := Vector3(0.0, 0.0, 1.0)
var _turn_blend := 0.0
var _acceleration_lean := Vector3.ZERO
var _previous_velocity := Vector3.ZERO
var _was_on_floor := true
var _landing_compression := 0.0
var _foot_parts: Dictionary = {}
var _stance_blend := 0.0
var _air_blend := 0.0
var _death_blend := 0.0
var _blink_timer := 2.8
var _blink_amount := 0.0
var _equipped_item: StringName = &""
var _selfie_item_mount: Node3D
var _selfie_item_visuals := {}
var _selfie_mode := false
var _ground_camera_mode := false
var _flashlight_on := false
var _ground_flashlight_bulb: Node3D
var _two_hand_tool: Node3D
var _two_hand_blend := 0.0

func set_two_hand_tool(tool: Node3D) -> void:
	_two_hand_tool = tool
	_two_hand_blend = 0.0
	_sync_selfie_item()


func _ready() -> void:
	_root_rest_rotation = rotation
	for joint: Node3D in [
		body, head, left_arm, right_arm, left_forearm, right_forearm, left_hand, right_hand,
		left_leg, right_leg, left_knee, right_knee, backpack,
	]:
		_rest[joint] = joint.transform
	for leg: Node3D in [left_leg, right_leg]:
		var shoe := leg.get_node("Knee/Shoe") as MeshInstance3D
		var sole := leg.get_node("Knee/Sole") as MeshInstance3D
		_foot_parts[leg] = [shoe, sole]
		_rest[shoe] = shoe.transform
		_rest[sole] = sole.transform
	_left_eye_rest_scale = left_eye.scale
	_right_eye_rest_scale = right_eye.scale
	_left_eye_white_rest_scale = left_eye_white.scale
	_right_eye_white_rest_scale = right_eye_white.scale
	_selfie_item_mount = Node3D.new()
	_selfie_item_mount.name = "SelfieItemMount"
	_selfie_item_mount.position = Vector3(0.0, -0.055, 0.018)
	left_hand.add_child(_selfie_item_mount)
	set_hidden_from_player_camera(true)


func set_hidden_from_player_camera(hidden: bool) -> void:
	var layer_mask := WORLD_AVATAR_LAYER if hidden else 1
	for descendant in find_children("*", "GeometryInstance3D", true, false):
		(descendant as GeometryInstance3D).layers = layer_mask


func set_player_dead(dead: bool) -> void:
	if dead:
		_death_blend = maxf(_death_blend, 0.001)
	else:
		_death_blend = 0.0
		rotation = _root_rest_rotation


func update_player_animation(
	delta: float,
	local_velocity: Vector3,
	stance: float,
	on_floor: bool,
	_sprinting: bool,
	look_pitch: float,
	turn_speed: float,
	equipped_item: StringName,
	action: StringName = &"",
	flashlight_on: bool = false,
	gait_phase: float = -1.0,
	gait_cycle_scale: float = 1.0
) -> void:
	_time += delta
	_equipped_item = equipped_item
	_flashlight_on = flashlight_on
	_sync_selfie_item()
	var horizontal_speed := Vector2(local_velocity.x, local_velocity.z).length()
	var target_motion := smoothstep(0.035, 0.45, horizontal_speed)
	_motion_blend = lerpf(_motion_blend, target_motion, 1.0 - exp(-delta * (9.0 if target_motion > _motion_blend else 6.0)))
	_stance_blend = lerpf(_stance_blend, clampf(stance, 0.0, 2.0), 1.0 - exp(-delta * 9.0))
	_run_blend = lerpf(_run_blend, GAIT.run_weight(horizontal_speed, _stance_blend), 1.0 - exp(-delta * 7.0))
	_turn_blend = lerpf(_turn_blend, clampf(turn_speed, -5.0, 5.0), 1.0 - exp(-delta * 8.0))
	if horizontal_speed > 0.035:
		# El modelo mira hacia +Z y el controlador del jugador hacia -Z.
		var direction := Vector3(-local_velocity.x, 0.0, -local_velocity.z) / horizontal_speed
		_gait_direction = _gait_direction.lerp(direction, 1.0 - exp(-delta * 12.0))
	var acceleration := (local_velocity - _previous_velocity) / maxf(delta, 0.0001)
	var lean_target := Vector3(clampf(-acceleration.z * 0.012, -0.09, 0.09), 0.0, clampf(acceleration.x * 0.012, -0.08, 0.08))
	_acceleration_lean = _acceleration_lean.lerp(lean_target, 1.0 - exp(-delta * 7.0))
	if on_floor and not _was_on_floor:
		_landing_compression = clampf(-_previous_velocity.y / 8.0, 0.0, 1.0)
	_landing_compression *= exp(-delta * 9.0)
	_previous_velocity = local_velocity
	_was_on_floor = on_floor
	_air_blend = lerpf(_air_blend, 0.0 if on_floor else 1.0, 1.0 - exp(-delta * 10.0))
	if _death_blend > 0.0:
		_death_blend = move_toward(_death_blend, 1.0, delta * 1.25)

	if gait_phase >= 0.0:
		_step_phase = gait_phase
	elif on_floor:
		_step_phase += GAIT.phase_advance(delta, horizontal_speed, stance)
	_update_blink(delta)
	_reset_pose()

	# Mantener la pose de Ctrl completa en stance == 1. Antes empezaba a
	# deshacerse demasiado pronto y el personaje apenas llegaba a agacharse.
	var crouch := 1.0 - smoothstep(1.0, 1.72, _stance_blend)
	crouch *= smoothstep(0.02, 0.9, _stance_blend)
	var prone := smoothstep(1.0, 2.0, _stance_blend)
	var step := sin(_step_phase)
	var grounded_motion := _motion_blend * (1.0 - _air_blend)
	var strafe := -_gait_direction.x * grounded_motion
	var stride := -cos(_step_phase - 0.18) * grounded_motion * lerpf(0.42, 0.85, _run_blend) * _gait_direction.z
	var transfer := sin(_step_phase + 0.25) * grounded_motion
	var hip_yaw := cos(_step_phase) * lerpf(0.045, 0.085, _run_blend) * grounded_motion * (1.0 - prone)
	var body_bob := (1.0 - cos(_step_phase * 2.0)) * lerpf(0.042, 0.032, _run_blend) * grounded_motion * lerpf(1.0, 0.12, crouch)
	var hip_drop := -0.006 - lerpf(lerpf(0.086, 0.14, _run_blend), 0.015, crouch) * grounded_motion - crouch * 0.28
	var pelvis := Vector3(transfer * lerpf(0.018, 0.028, crouch), hip_drop + body_bob - _landing_compression * 0.045, -crouch * 0.055)
	var support := lerpf(lerpf(0.62, 0.38, _run_blend), 0.72, crouch)
	var travel := GAIT.cycle_length(horizontal_speed, stance) * support * gait_cycle_scale
	var lift := lerpf(lerpf(0.075, 0.24, _run_blend), 0.065, crouch)
	_pose_ground_leg(left_leg, left_knee, GAIT.foot_sample(_step_phase, support, travel, lift), pelvis, hip_yaw, grounded_motion)
	_pose_ground_leg(right_leg, right_knee, GAIT.foot_sample(_step_phase + PI, support, travel, lift), pelvis, hip_yaw, grounded_motion)
	if prone > 0.0:
		_blend_crawl_leg(left_leg, left_knee, step, prone)
		_blend_crawl_leg(right_leg, right_knee, -step, prone)

	var idle_breath := sin(_time * 1.65) * 0.006 * (1.0 - _motion_blend)
	var torso_pitch := crouch * 0.38 + _run_blend * 0.18 * _gait_direction.z + _acceleration_lean.x
	var torso_roll := -transfer * 0.025 - _turn_blend * 0.014 * grounded_motion - strafe * 0.045 + _acceleration_lean.z
	_apply_joint(
		body,
		pelvis.lerp(Vector3(step * 0.018 * _motion_blend, -0.54, 0.12), prone) + Vector3.UP * idle_breath,
		Vector3(lerpf(torso_pitch, 1.18, prone), -hip_yaw * 0.7, torso_roll)
	)
	_apply_joint(
		head,
		Vector3(0.0, sin(_time * 1.2) * 0.004 * (1.0 - _motion_blend), prone * 0.025),
		Vector3(clampf(look_pitch * 0.52, -0.48, 0.48) - torso_pitch * 0.7 * (1.0 - prone) - prone * 0.94, hip_yaw * 0.5 - _turn_blend * 0.018, -torso_roll * 0.65)
	)
	_apply_joint(backpack, Vector3.ZERO, Vector3(sin(_step_phase * 2.0 - 0.5) * 0.018 * grounded_motion, 0.0, -transfer * 0.025))

	_apply_arm_pose(stride, crouch, prone, action)
	if _air_blend > 0.001:
		_apply_air_pose(local_velocity.y)
	if _death_blend > 0.0:
		_apply_death_pose()
	_apply_blink()
	_update_ground_flashlight_orientation()
	if is_instance_valid(_two_hand_tool) and _death_blend == 0.0:
		_pose_two_hand_tool(delta)


func _pose_ground_leg(upper: Node3D, knee: Node3D, sample: Vector3, pelvis: Vector3, hip_yaw: float, weight: float) -> void:
	var upper_rest := _rest[upper] as Transform3D
	var knee_rest := _rest[knee] as Transform3D
	var parts: Array = _foot_parts[upper]
	var shoe_rest := _rest[parts[0]] as Transform3D
	var ankle_local := Vector3(0.0, shoe_rest.origin.y, 0.0)
	var ankle_rest := upper_rest * knee_rest * ankle_local
	var side := -1.0 if upper == left_leg else 1.0
	var foot_yaw := side * 0.045 + _gait_direction.x * 0.24 * weight
	var foot_basis := Basis.from_euler(Vector3(sample.z * weight, foot_yaw, 0.0))
	var target := ankle_rest + _gait_direction * sample.x * weight
	# Compensa el talón y la punta contra la cota original de la suela. Rotar
	# solo la espinilla hacía que el zapato atravesara el suelo en cada apoyo.
	var sole := parts[1] as MeshInstance3D
	var sole_rest := _rest[sole] as Transform3D
	var bounds := sole.get_aabb()
	var floor_y := INF
	var rotated_bottom := INF
	for corner in 8:
		var point := sole_rest * bounds.get_endpoint(corner) - ankle_local
		floor_y = minf(floor_y, (ankle_rest + point).y)
		rotated_bottom = minf(rotated_bottom, (foot_basis * point).y)
	target.y = floor_y - rotated_bottom + sample.y * weight
	var hip_rotation := Basis(Vector3.UP, hip_yaw)
	_apply_joint(upper, pelvis + hip_rotation * upper_rest.origin - upper_rest.origin, Vector3.ZERO)
	_solve_leg(upper, knee, ankle_local, to_global(target))
	var solved_ankle := knee.to_global(ankle_local)
	# Zapato y suela giran juntos alrededor del tobillo, conservando los ajustes
	# de tamaño y forma que ya tiene el modelo editable.
	for part: Node3D in parts:
		var rest := _rest[part] as Transform3D
		part.global_transform = Transform3D(
			global_basis * foot_basis * rest.basis,
			solved_ankle + global_basis * foot_basis * (rest.origin - ankle_local)
		)


func _solve_leg(upper: Node3D, knee: Node3D, ankle_local: Vector3, target: Vector3) -> void:
	var hip := upper.global_position
	var ankle := knee.to_global(ankle_local)
	var thigh_length := hip.distance_to(knee.global_position)
	var shin_length := knee.global_position.distance_to(ankle)
	var offset := target - hip
	if offset.length_squared() < 0.000001 or minf(thigh_length, shin_length) < 0.001:
		return
	var direction := offset.normalized()
	var reach := clampf(offset.length(), absf(thigh_length - shin_length) + 0.001, thigh_length + shin_length - 0.001)
	var along := (thigh_length * thigh_length - shin_length * shin_length + reach * reach) / (2.0 * reach)
	var forward := global_basis.z.normalized()
	var pole := (forward - direction * forward.dot(direction)).normalized()
	var bend := hip + direction * along + pole * sqrt(maxf(0.0, thigh_length * thigh_length - along * along))
	upper.global_basis = Basis(Quaternion((knee.global_position - hip).normalized(), (bend - hip).normalized())) * upper.global_basis
	var solved_target := hip + direction * reach
	knee.global_basis = Basis(Quaternion((knee.to_global(ankle_local) - knee.global_position).normalized(), (solved_target - knee.global_position).normalized())) * knee.global_basis


func _blend_crawl_leg(upper: Node3D, knee: Node3D, step: float, prone: float) -> void:
	var standing_upper := upper.transform
	var standing_knee := knee.transform
	_apply_joint(upper, Vector3(0.0, -0.36, 0.0), Vector3(0.38 + step * 0.3 * _motion_blend, 0.0, 0.0))
	_apply_joint(knee, Vector3.ZERO, Vector3(1.2 + maxf(-step, 0.0) * 0.42 * _motion_blend, 0.0, 0.0))
	upper.transform = standing_upper.interpolate_with(upper.transform, prone)
	knee.transform = standing_knee.interpolate_with(knee.transform, prone)
	for part: Node3D in _foot_parts[upper]:
		part.transform = part.transform.interpolate_with(_rest[part] as Transform3D, prone)


func _pose_two_hand_tool(delta: float) -> void:
	_two_hand_blend = minf(1.0, _two_hand_blend + delta * 4.0)
	var support: Node3D = _two_hand_tool.get_node("SupportGrip")
	var power: Node3D = _two_hand_tool.get_node("PowerGrip")
	var blend := smoothstep(0.0, 1.0, _two_hand_blend)
	# Rodillas flexionadas, torso orientado a la tarea y codos separados.
	var center := (support.global_position + power.global_position) * 0.5
	var low := clampf((global_position.y + 1.05 - center.y) * 0.7, 0.0, 0.38) * blend
	var rise := clampf(center.y - (global_position.y + 1.25), 0.0, 0.035) * blend
	body.position.y += rise - low
	body.position.z += 0.24 * blend
	_add_joint_rotation(left_leg, Vector3(-low * 1.5, 0, -0.08 * blend))
	_add_joint_rotation(right_leg, Vector3(-low * 1.5, 0, 0.08 * blend))
	_add_joint_rotation(left_knee, Vector3(low * 3, 0, 0))
	_add_joint_rotation(right_knee, Vector3(low * 3, 0, 0))
	_solve_arm_to_target(left_arm, left_forearm, left_hand, left_hand.global_position.lerp(support.global_position, blend), -global_basis.x.normalized() + Vector3.DOWN * 0.3)
	_solve_arm_to_target(right_arm, right_forearm, right_hand, right_hand.global_position.lerp(power.global_position, blend), global_basis.x.normalized() + Vector3.DOWN * 0.3)
	for hand: Node3D in [left_hand, right_hand]:
		var hand_scale := hand.global_basis.get_scale()
		hand.global_basis = _two_hand_tool.global_basis.orthonormalized().rotated(_two_hand_tool.global_basis.z.normalized(), PI / 2 if hand == left_hand else -PI / 2).scaled(hand_scale)
	var contact: Vector3 = body.to_local(_two_hand_tool.get_node("HookContact").global_position) - head.position
	head.transform = _rest[head]
	_add_joint_rotation(head, Vector3(clampf(-atan2(contact.y, maxf(Vector2(contact.x, contact.z).length(), 0.01)), -0.55, 0.6), clampf(atan2(contact.x, contact.z), -0.45, 0.45), 0))


func _apply_arm_pose(stride: float, crouch: float, prone: float, action: StringName) -> void:
	var left_swing := -stride * lerpf(0.7, 0.9, _run_blend)
	var right_swing := stride * lerpf(0.7, 0.9, _run_blend)
	var elbow_lag := sin(_step_phase - 0.4) * _motion_blend
	var left_forearm_bend := -0.16 - _run_blend * 0.85 - maxf(-left_swing, 0.0) * 0.35 + elbow_lag * 0.065
	var right_forearm_bend := -0.16 - _run_blend * 0.85 - maxf(-right_swing, 0.0) * 0.35 - elbow_lag * 0.065
	var left_inward := -0.06
	var right_inward := 0.06
	var action_pulse := sin(_time * 8.0) * 0.055 if not action.is_empty() else 0.0

	if prone > 0.01:
		left_swing = lerpf(left_swing, -1.42 - sin(_step_phase) * 0.22 * _motion_blend, prone)
		right_swing = lerpf(right_swing, -1.42 + sin(_step_phase) * 0.22 * _motion_blend, prone)
		left_forearm_bend = lerpf(left_forearm_bend, -0.62, prone)
		right_forearm_bend = lerpf(right_forearm_bend, -0.62, prone)
	elif action == &"ladder":
		var climb := sin(_time * 4.8)
		left_swing = -1.72 - climb * 0.24
		right_swing = -1.72 + climb * 0.24
		left_forearm_bend = -0.38 + climb * 0.12
		right_forearm_bend = -0.38 - climb * 0.12
		left_inward = -0.2
		right_inward = 0.2
	elif action == &"walker":
		left_swing = -1.12
		right_swing = -1.12
		left_forearm_bend = -0.34
		right_forearm_bend = -0.34
		left_inward = -0.28
		right_inward = 0.28
	elif action == &"valve":
		left_swing = -1.28 + action_pulse
		right_swing = -1.28 - action_pulse
		left_forearm_bend = -0.7
		right_forearm_bend = -0.7
		left_inward = -0.34
		right_inward = 0.34
	else:
		match _equipped_item:
			&"flashlight":
				left_swing = -1.08 + action_pulse
				left_forearm_bend = -0.5
				left_inward = -0.22
				right_swing *= 0.25
			&"note", &"recipe_book":
				left_swing = -1.0
				right_swing = -1.0
				left_forearm_bend = -0.64
				right_forearm_bend = -0.64
				left_inward = -0.32
				right_inward = 0.32
			&"candle":
				right_swing = -0.92 + action_pulse
				right_forearm_bend = -0.42
				right_inward = 0.18
				left_swing *= 0.3
			&"plunger", &"crowbar", &"flathead_screwdriver", &"camera_tripod":
				right_swing = -1.13 + action_pulse
				right_forearm_bend = -0.58
				right_inward = 0.2
				left_swing *= 0.22
			&"can", &"bottle", &"matchbox", &"tv_remote", &"cassette":
				right_swing = -0.82 + action_pulse
				right_forearm_bend = -0.38
				right_inward = 0.16
				left_swing *= 0.35

	left_swing -= crouch * 0.2
	right_swing -= crouch * 0.2
	var arm_twist := cos(_step_phase - 0.2) * _motion_blend * 0.035 * (1.0 - prone)
	_apply_joint(left_arm, Vector3.ZERO, Vector3(left_swing, arm_twist, left_inward - _run_blend * 0.07))
	_apply_joint(right_arm, Vector3.ZERO, Vector3(right_swing, -arm_twist, right_inward + _run_blend * 0.07))
	_apply_joint(left_forearm, Vector3.ZERO, Vector3(left_forearm_bend - crouch * 0.2, 0.0, 0.0))
	_apply_joint(right_forearm, Vector3.ZERO, Vector3(right_forearm_bend - crouch * 0.2, 0.0, 0.0))


func _apply_air_pose(vertical_speed: float) -> void:
	var rising := clampf(vertical_speed / 4.0, -1.0, 1.0)
	_add_joint_rotation(left_leg, Vector3(-0.18 - rising * 0.12, 0.0, -0.04) * _air_blend)
	_add_joint_rotation(right_leg, Vector3(0.28 + rising * 0.08, 0.0, 0.04) * _air_blend)
	_add_joint_rotation(left_knee, Vector3(0.48, 0.0, 0.0) * _air_blend)
	_add_joint_rotation(right_knee, Vector3(0.72, 0.0, 0.0) * _air_blend)
	_add_joint_rotation(left_arm, Vector3(-0.18, 0.0, -0.12) * _air_blend)
	_add_joint_rotation(right_arm, Vector3(-0.18, 0.0, 0.12) * _air_blend)


func _apply_death_pose() -> void:
	rotation.z = lerp_angle(_root_rest_rotation.z, _root_rest_rotation.z + 1.48, _death_blend)
	_add_joint_rotation(body, Vector3(0.14, 0.0, 0.0) * _death_blend)
	_add_joint_rotation(head, Vector3(0.08, -0.12, 0.22) * _death_blend)
	_add_joint_rotation(left_arm, Vector3(-0.28, 0.0, -0.35) * _death_blend)
	_add_joint_rotation(right_arm, Vector3(0.18, 0.0, 0.25) * _death_blend)


func _update_blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_amount = 1.0
		_blink_timer = randf_range(2.2, 5.4)
	_blink_amount = move_toward(_blink_amount, 0.0, delta * 8.5)


func _apply_blink() -> void:
	var openness := lerpf(1.0, 0.08, clampf(_blink_amount * 2.0, 0.0, 1.0))
	openness *= lerpf(1.0, 0.12, _death_blend)
	left_eye.scale = Vector3(_left_eye_rest_scale.x, _left_eye_rest_scale.y * openness, _left_eye_rest_scale.z)
	right_eye.scale = Vector3(_right_eye_rest_scale.x, _right_eye_rest_scale.y * openness, _right_eye_rest_scale.z)
	left_eye_white.scale = Vector3(_left_eye_white_rest_scale.x, _left_eye_white_rest_scale.y * openness, _left_eye_white_rest_scale.z)
	right_eye_white.scale = Vector3(_right_eye_white_rest_scale.x, _right_eye_white_rest_scale.y * openness, _right_eye_white_rest_scale.z)




func fit_selfie_camera(lens: Vector3, grip_offset: Vector3) -> Vector3:
	var reach := right_arm.global_position.distance_to(right_forearm.global_position) + right_forearm.global_position.distance_to(right_hand.global_position)
	var offset := lens + grip_offset - right_arm.global_position
	return right_arm.global_position + offset.limit_length(reach * 0.97) - grip_offset


func hold_selfie_camera(grip: Vector3) -> void:
	_solve_arm_to_target(right_arm, right_forearm, right_hand, grip, global_basis.x.normalized() + Vector3.DOWN)


func pose_selfie(lens_position: Vector3, _lens_basis: Basis, grip_position: Vector3) -> void:
	hold_selfie_camera(grip_position)
	_look_at_selfie_camera(lens_position)
	if _equipped_item.is_empty():
		return
	# El brazo libre cae casi estirado. Solo avanza un poco desde el hombro para
	# que la linterna u otro objeto se lean delante del cuerpo y no pegados a el.
	var shoulder := left_arm.global_position
	var toward_lens := shoulder.direction_to(lens_position)
	toward_lens.y = 0.0
	toward_lens = toward_lens.normalized()
	var item_grip := shoulder + Vector3.DOWN * 0.4 + toward_lens * 0.15 - global_basis.x.normalized() * 0.045
	_solve_arm_to_target(left_arm, left_forearm, left_hand, item_grip, -global_basis.x.normalized() + Vector3.DOWN * 0.12)


func _look_at_selfie_camera(lens_position: Vector3) -> void:
	var desired := head.global_position.direction_to(lens_position)
	if desired.length_squared() < 0.001:
		return
	var current_forward := head.global_basis.z.normalized()
	var turn := Quaternion(current_forward, desired.normalized())
	head.global_basis = Basis(turn) * head.global_basis


func _solve_arm_to_target(upper: Node3D, forearm: Node3D, hand: Node3D, target: Vector3, pole_hint: Vector3) -> void:
	# IK de dos segmentos que conserva conectados hombro, codo y mano.
	var shoulder := upper.global_position
	var upper_length := shoulder.distance_to(forearm.global_position)
	var lower_length := forearm.global_position.distance_to(hand.global_position)
	var target_vector := target - shoulder
	if upper_length < 0.001 or lower_length < 0.001 or target_vector.length_squared() < 0.000001:
		return
	var direction := target_vector.normalized()
	var distance := clampf(target_vector.length(), absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
	var solved_target := shoulder + direction * distance
	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var pole := pole_hint - direction * pole_hint.dot(direction)
	if pole.length_squared() < 0.001:
		pole = direction.cross(Vector3.UP)
	pole = pole.normalized()
	var elbow := shoulder + direction * along + pole * sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var upper_turn := Quaternion((forearm.global_position - shoulder).normalized(), (elbow - shoulder).normalized())
	upper.global_basis = Basis(upper_turn) * upper.global_basis
	var lower_turn := Quaternion((hand.global_position - forearm.global_position).normalized(), (solved_target - forearm.global_position).normalized())
	forearm.global_basis = Basis(lower_turn) * forearm.global_basis


func set_selfie_mode(active: bool) -> void:
	_selfie_mode = active
	_sync_selfie_item()


func set_ground_camera_mode(active: bool) -> void:
	_ground_camera_mode = active
	_sync_selfie_item()


func _sync_selfie_item() -> void:
	if not is_instance_valid(_selfie_item_mount):
		return
	for visual in _selfie_item_visuals.values():
		if is_instance_valid(visual):
			(visual as Node3D).visible = false
	if is_instance_valid(_ground_flashlight_bulb):
		_ground_flashlight_bulb.visible = false
	if is_instance_valid(_two_hand_tool) or (not _selfie_mode and not _ground_camera_mode) or _equipped_item.is_empty() or not SELFIE_ITEM_SCENES.has(_equipped_item):
		return
	if not _selfie_item_visuals.has(_equipped_item):
		_selfie_item_visuals[_equipped_item] = _build_selfie_item_visual(_equipped_item)
	var selected := _selfie_item_visuals.get(_equipped_item) as Node3D
	if is_instance_valid(selected):
		selected.visible = true
		if _equipped_item == &"camera_tripod":
			# En vista externa usa la derecha; en selfie esa mano lleva la camara.
			var mount: Node3D = right_hand if _ground_camera_mode else _selfie_item_mount
			if selected.get_parent() != mount:
				selected.reparent(mount, false)
			selected.position = Vector3.ZERO if mount == right_hand else -mount.position
		if _equipped_item == &"flashlight" and not _ground_camera_mode:
			# Restaurar la orientacion original usada por el plano selfie.
			selected.rotation = Vector3(0.0, 0.0, PI * 0.5)
	if is_instance_valid(_ground_flashlight_bulb):
		_ground_flashlight_bulb.visible = (
			_ground_camera_mode
			and _equipped_item == &"flashlight"
			and _flashlight_on
		)


func _build_selfie_item_visual(item_type: StringName) -> Node3D:
	var packed := SELFIE_ITEM_SCENES[item_type] as PackedScene
	var source := packed.instantiate()
	var wrapper := Node3D.new()
	wrapper.name = "Selfie%s" % String(item_type).to_pascal_case()
	_selfie_item_mount.add_child(wrapper)
	var content := Node3D.new()
	wrapper.add_child(content)
	var bounds_state := {"has_bounds": false, "bounds": AABB()}
	_copy_item_meshes(source, content, Transform3D.IDENTITY, true, bounds_state)
	var carry_grip := source.get_node_or_null("CarryGrip") as Node3D
	var carry_position := carry_grip.position if carry_grip != null else Vector3.ZERO
	source.free()
	if bool(bounds_state["has_bounds"]):
		var bounds := bounds_state["bounds"] as AABB
		var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var target_size := float(SELFIE_ITEM_SIZES.get(item_type, 0.25))
		var fit_scale := target_size / maxf(longest, 0.001)
		wrapper.scale = Vector3.ONE * fit_scale
		content.position = -bounds.get_center()
		if item_type == &"camera_tripod":
			content.position = -carry_position
	if item_type == &"flashlight":
		_ground_flashlight_bulb = _build_ground_camera_flashlight_bulb(content)
	# Los assets conservan su silueta real; solo orientamos la empunadura hacia
	# la palma. Los objetos largos quedan paralelos al antebrazo.
	if item_type in [&"flashlight", &"crowbar", &"flathead_screwdriver", &"tv_remote"]:
		wrapper.rotation.z = PI * 0.5
	elif item_type == &"cassette" or item_type == &"note" or item_type == &"recipe_book":
		wrapper.rotation.x = PI * 0.5
	wrapper.visible = false
	return wrapper


func _build_ground_camera_flashlight_bulb(content: Node3D) -> Node3D:
	# La linterna copiada para el avatar solo conserva mallas. Este emisor se
	# coloca sobre su lente real y pertenece exclusivamente a la vista de suelo.
	var bulb_root := Node3D.new()
	bulb_root.name = "GroundCameraFlashlightBulb"
	bulb_root.position = Vector3(0.024, 0.027, -0.3)
	bulb_root.visible = false
	content.add_child(bulb_root)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.82, 0.5, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.58, 0.18, 1.0)
	material.emission_energy_multiplier = 5.0

	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = 0.061
	lens_mesh.height = 0.122
	lens_mesh.radial_segments = 12
	lens_mesh.rings = 6
	lens_mesh.material = material

	var lens := MeshInstance3D.new()
	lens.name = "LitLens"
	lens.mesh = lens_mesh
	lens.scale = Vector3(1.0, 1.0, 0.26)
	lens.layers = WORLD_AVATAR_LAYER
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb_root.add_child(lens)

	var halo := OmniLight3D.new()
	halo.name = "LensHalo"
	halo.light_color = Color(1.0, 0.58, 0.2, 1.0)
	halo.light_energy = 0.42
	halo.omni_range = 0.38
	halo.shadow_enabled = false
	bulb_root.add_child(halo)
	return bulb_root


func _update_ground_flashlight_orientation() -> void:
	if not _ground_camera_mode or _equipped_item != &"flashlight":
		return
	var flashlight_visual := _selfie_item_visuals.get(&"flashlight") as Node3D
	if not is_instance_valid(flashlight_visual) or not flashlight_visual.visible:
		return
	# El OBJ de la linterna apunta por su -Z. Conservamos la posicion animada de
	# la mano pero anulamos la rotacion vertical heredada del brazo.
	var forward := head.global_basis.z.normalized()
	var up := head.global_basis.y.normalized()
	if forward.length_squared() < 0.001 or absf(forward.dot(up)) > 0.98:
		up = Vector3.UP
	var world_scale := flashlight_visual.global_basis.get_scale()
	flashlight_visual.global_basis = Basis.looking_at(forward, up).scaled(world_scale)


func _copy_item_meshes(source: Node, destination: Node3D, parent_transform: Transform3D, parent_visible: bool, bounds_state: Dictionary) -> void:
	var combined := parent_transform
	var branch_visible := parent_visible
	if source is Node3D:
		combined = parent_transform * (source as Node3D).transform
		branch_visible = parent_visible and (source as Node3D).visible
	if source is MeshInstance3D and branch_visible:
		var original := source as MeshInstance3D
		if original.mesh != null:
			var copy := MeshInstance3D.new()
			copy.mesh = original.mesh
			copy.material_override = original.material_override
			copy.cast_shadow = original.cast_shadow
			copy.transparency = original.transparency
			copy.layers = WORLD_AVATAR_LAYER
			copy.transform = combined
			for surface in original.mesh.get_surface_count():
				copy.set_surface_override_material(surface, original.get_surface_override_material(surface))
			destination.add_child(copy)
			var mesh_bounds := combined * original.get_aabb()
			if bool(bounds_state["has_bounds"]):
				bounds_state["bounds"] = (bounds_state["bounds"] as AABB).merge(mesh_bounds)
			else:
				bounds_state["has_bounds"] = true
				bounds_state["bounds"] = mesh_bounds
	for child in source.get_children():
		_copy_item_meshes(child, destination, combined, branch_visible, bounds_state)




func _reset_pose() -> void:
	for joint in _rest:
		(joint as Node3D).transform = _rest[joint] as Transform3D


func _apply_joint(joint: Node3D, position_offset: Vector3, rotation_offset: Vector3) -> void:
	var base := _rest[joint] as Transform3D
	joint.transform = Transform3D(base.basis * Basis.from_euler(rotation_offset), base.origin + position_offset)


func _add_joint_rotation(joint: Node3D, rotation_offset: Vector3) -> void:
	joint.transform.basis = joint.transform.basis * Basis.from_euler(rotation_offset)
