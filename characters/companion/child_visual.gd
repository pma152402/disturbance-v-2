extends Node3D

@onready var body: Node3D = $Body
@onready var head: Node3D = $Body/Head
@onready var left_arm: Node3D = $Body/LeftArm
@onready var right_arm: Node3D = $Body/RightArm
@onready var left_forearm: Node3D = $Body/LeftArm/Forearm
@onready var right_forearm: Node3D = $Body/RightArm/Forearm
@onready var left_leg: Node3D = $LeftLeg
@onready var right_leg: Node3D = $RightLeg
@onready var left_knee: Node3D = $LeftLeg/Knee
@onready var right_knee: Node3D = $RightLeg/Knee
@onready var left_eye: MeshInstance3D = $Body/Head/Face/LeftEye
@onready var right_eye: MeshInstance3D = $Body/Head/Face/RightEye
@onready var shoes: Array[Node3D] = [$LeftLeg/Knee/Shoe, $RightLeg/Knee/Shoe]
@onready var soles: Array[Node3D] = [$LeftLeg/Knee/Sole, $RightLeg/Knee/Sole]

var _time := 0.0
var _step_phase := 0.0
var _locomotion := 0.0
var _blink_timer := 2.4
var _blink_amount := 0.0
var _base_head_position := Vector3.ZERO
var _base_body_position := Vector3.ZERO
var _base_left_eye_position := Vector3.ZERO
var _base_right_eye_position := Vector3.ZERO
var _posture_target := 0.0
var _posture_blend := 0.0
var _dead_target := 0.0
var _dead_blend := 0.0
var _has_motion_context := false
var _ground_speed := 0.0
var _turn_velocity := 0.0
var _gaze_target := Vector3.ZERO
var _gaze_yaw := 0.0
var _gaze_pitch := 0.0
var _door_tension := 0.0
var _door_target := 0.0
var _settle := 0.0


func set_motion_context(speed: float, turn_velocity: float, gaze: Vector3, crossing: bool) -> void:
	_has_motion_context = true
	_ground_speed = maxf(speed, 0.0)
	_turn_velocity = clampf(turn_velocity, -3.0, 3.0)
	_gaze_target = gaze
	_door_target = 1.0 if crossing else 0.0


func _ready() -> void:
	_base_head_position = head.position
	_base_body_position = body.position
	_base_left_eye_position = left_eye.position
	_base_right_eye_position = right_eye.position


func set_companion_posture(posture: int) -> void:
	_posture_target = clampf(float(posture), 0.0, 2.0)


func set_companion_dead(dead: bool) -> void:
	_dead_target = 1.0 if dead else 0.0
	if dead:
		_posture_target = 0.0


func update_companion_animation(delta: float, movement: float, waiting: bool) -> void:
	for index in 2:
		shoes[index].rotation.x = 0.0
		shoes[index].position = Vector3(0.0, -0.29, 0.055)
		soles[index].rotation.x = 0.0
		soles[index].position = Vector3(0.0, -0.35, 0.055)
	_time += delta
	_door_tension = lerpf(_door_tension, _door_target, 1.0 - exp(-4.0 * delta))
	_dead_blend = move_toward(_dead_blend, _dead_target, delta * (1.15 if _dead_target > _dead_blend else 2.2))
	_posture_blend = move_toward(_posture_blend, _posture_target, delta * 2.4)
	# Pesos con ease-in/out: las rodillas y manos no cambian de velocidad de
	# golpe al atravesar la postura agachada camino del gateo.
	var crouch_weight := 0.0
	var prone_weight := 0.0
	if _posture_blend <= 1.0:
		crouch_weight = smoothstep(0.0, 1.0, _posture_blend)
	else:
		var prone_transition := smoothstep(0.0, 1.0, _posture_blend - 1.0)
		crouch_weight = 1.0 - prone_transition
		prone_weight = prone_transition
	var target_locomotion := clampf(movement, 0.0, 1.0) * (1.0 - _dead_blend)
	_locomotion = move_toward(_locomotion, target_locomotion, delta * (3.6 if target_locomotion > _locomotion else 5.2))
	if _locomotion > 0.015:
		var cadence := lerpf(4.2, 8.4, _locomotion)
		cadence *= lerpf(1.0, 0.82, crouch_weight)
		cadence *= lerpf(1.0, 0.67, prone_weight)
		if _has_motion_context:
			# Fase ligada a distancia física, no a la intención: al bloquearse
			# contra una puerta los pies dejan de caminar sobre el sitio.
			cadence = _ground_speed * TAU / lerpf(0.82, 0.5, prone_weight)
		_step_phase += delta * cadence
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_amount = 1.0
		_blink_timer = randf_range(2.1, 5.2)
	_blink_amount = move_toward(_blink_amount, 0.0, delta * 9.0)
	var eye_scale_y := lerpf(1.0, 0.08, clampf(_blink_amount * 2.0, 0.0, 1.0))
	eye_scale_y *= lerpf(1.0, 0.12, _dead_blend)
	left_eye.scale.y = eye_scale_y * 0.82
	right_eye.scale.y = eye_scale_y * 0.82
	$Body/Head/Face/LeftEyeWhite.scale.y = 0.88 * eye_scale_y
	$Body/Head/Face/RightEyeWhite.scale.y = 0.88 * eye_scale_y

	var step_sine := sin(_step_phase)
	var step_cosine := cos(_step_phase)
	var double_step := sin(_step_phase * 2.0)
	var stride_scale := lerpf(1.0, 0.58, crouch_weight)
	stride_scale = lerpf(stride_scale, 0.3, prone_weight)
	var stride := step_sine * 0.43 * _locomotion * stride_scale
	var crouch_step_depth := (0.12 + maxf(0.0, -step_cosine) * 0.16) * crouch_weight * _locomotion
	var crawl_reach := step_sine * 0.24 * prone_weight * _locomotion
	var foot_lift_left := maxf(0.0, step_sine) * 0.016 * _locomotion * (1.0 - prone_weight)
	var foot_lift_right := maxf(0.0, -step_sine) * 0.016 * _locomotion * (1.0 - prone_weight)
	left_leg.rotation.x = stride - (0.76 + crouch_step_depth) * crouch_weight + (1.38 + crawl_reach) * prone_weight
	right_leg.rotation.x = -stride - (0.76 + crouch_step_depth) * crouch_weight + (1.38 - crawl_reach) * prone_weight
	left_knee.rotation.x = (0.05 + maxf(0.0, -step_sine) * 0.36) * _locomotion + (1.18 + maxf(0.0, step_sine) * 0.18 * _locomotion) * crouch_weight + (0.2 - crawl_reach * 0.35) * prone_weight
	right_knee.rotation.x = (0.05 + maxf(0.0, step_sine) * 0.36) * _locomotion + (1.18 + maxf(0.0, -step_sine) * 0.18 * _locomotion) * crouch_weight + (0.2 + crawl_reach * 0.35) * prone_weight
	var leg_height := lerpf(0.72, 0.55, crouch_weight)
	leg_height = lerpf(leg_height, 0.3, prone_weight)
	left_leg.position.y = leg_height + foot_lift_left
	right_leg.position.y = leg_height + foot_lift_right
	# En suelo avanzan pares diagonales: brazo izquierdo con pierna derecha.
	# La flexion extra al apoyar evita el aspecto de "nadar" en el aire.
	left_arm.rotation.x = -stride * 0.48 - 0.22 * crouch_weight + (-1.48 - crawl_reach) * prone_weight
	right_arm.rotation.x = stride * 0.48 - 0.22 * crouch_weight + (-1.48 + crawl_reach) * prone_weight
	var left_hand_load := maxf(0.0, -step_cosine) * prone_weight * _locomotion
	var right_hand_load := maxf(0.0, step_cosine) * prone_weight * _locomotion
	left_forearm.rotation.x = -0.12 - maxf(0.0, stride) * 0.12 - 0.34 * crouch_weight - (0.42 + left_hand_load * 0.28) * prone_weight
	right_forearm.rotation.x = -0.12 + minf(0.0, stride) * 0.12 - 0.34 * crouch_weight - (0.42 + right_hand_load * 0.28) * prone_weight
	left_arm.rotation.z = -0.07 - 0.04 * crouch_weight - 0.18 * prone_weight
	right_arm.rotation.z = 0.07 + 0.04 * crouch_weight + 0.18 * prone_weight
	var crouch_bob := absf(double_step) * 0.018 * crouch_weight * _locomotion
	var crawl_bob := absf(step_cosine) * 0.012 * prone_weight * _locomotion
	body.position = _base_body_position + Vector3(
		step_sine * 0.012 * prone_weight * _locomotion,
		absf(double_step) * 0.012 * _locomotion + crouch_bob + crawl_bob - 0.29 * crouch_weight - 0.53 * prone_weight,
		-0.008 * _locomotion + 0.045 * crouch_weight + (0.11 + step_cosine * 0.015 * _locomotion) * prone_weight
	)
	body.rotation.x = -0.022 * _locomotion - 0.15 * crouch_weight + (1.34 + double_step * 0.025 * _locomotion) * prone_weight
	body.rotation.y = step_sine * 0.026 * _locomotion + step_sine * 0.045 * prone_weight * _locomotion
	body.rotation.z = step_sine * 0.012 * _locomotion + step_sine * 0.035 * prone_weight * _locomotion

	var idle_weight := (1.0 - _locomotion) * (1.0 - _dead_blend)
	head.position = _base_head_position + Vector3(0.0, sin(_time * 1.6) * 0.008 * idle_weight + crawl_bob * 0.3, 0.02 * prone_weight)
	head.rotation.z = sin(_time * 0.55) * 0.035 * idle_weight
	var natural_head_pitch := (0.035 + sin(_time * 0.7) * 0.018) * idle_weight if waiting else sin(_time * 1.1) * 0.012
	head.rotation.x = natural_head_pitch + 0.1 * crouch_weight + (-1.13 - step_cosine * 0.025 * _locomotion) * prone_weight
	head.rotation.y = sin(_time * 0.38) * 0.075 * idle_weight
	var idle_gaze := sin(_time * 0.42) * 0.007 * idle_weight
	left_eye.position = _base_left_eye_position + Vector3(idle_gaze, 0.0, 0.0)
	right_eye.position = _base_right_eye_position + Vector3(idle_gaze, 0.0, 0.0)
	body.scale = Vector3(1.0, 1.0 + sin(_time * 1.8) * 0.006 * idle_weight, 1.0)
	if _has_motion_context and _dead_blend < 0.01:
		_apply_grounded_motion(delta, crouch_weight, prone_weight, idle_weight)
	# Caida lateral con el cuerpo entero, amortiguada para que no parezca un
	# cambio instantaneo de pose. El origen en los pies mantiene el cadaver en el suelo.
	rotation.z = lerp_angle(0.0, 1.46, _dead_blend)
	position.y = lerpf(0.0, 0.18, _dead_blend)
	body.rotation.x += 0.16 * _dead_blend
	head.rotation.z += 0.2 * _dead_blend


func _apply_grounded_motion(delta: float, crouch: float, prone: float, idle: float) -> void:
	var standing := 1.0 - crouch - prone
	_settle = lerpf(_settle, clampf(_ground_speed / 0.75, 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	# Apoyo largo y retorno corto; IK de dos segmentos mantiene los tobillos
	# a altura de suelo en vez de levantar toda la pierna como un péndulo.
	if standing > 0.001:
		_pose_planted_leg(left_leg, left_knee, _step_phase, standing)
		_pose_planted_leg(right_leg, right_knee, _step_phase + PI, standing)
		body.position.y -= 0.055 * standing
	# Objetivo respecto al cuerpo, independiente de la rotación anterior de cabeza.
	var local_gaze := body.to_local(_gaze_target) - head.position
	var target_yaw := clampf(atan2(local_gaze.x, local_gaze.z), -0.65, 0.65)
	var target_pitch := clampf(-atan2(local_gaze.y, maxf(Vector2(local_gaze.x, local_gaze.z).length(), 0.1)), -0.35, 0.28)
	_gaze_yaw = lerpf(_gaze_yaw, target_yaw, 1.0 - exp(-5.0 * delta))
	_gaze_pitch = lerpf(_gaze_pitch, target_pitch, 1.0 - exp(-4.0 * delta))
	head.rotation.y += _gaze_yaw * (1.0 - prone * 0.7)
	head.rotation.x += _gaze_pitch * (1.0 - prone)
	head.rotation.z -= _turn_velocity * 0.015 * _settle
	body.rotation.z -= _turn_velocity * 0.025 * _settle * standing
	body.rotation.x += 0.035 * _door_tension * standing
	# Respiración y pequeños cambios de peso asimétricos, sin desplazar pies.
	body.position.x += (sin(_time * 0.63) + sin(_time * 1.07) * 0.35) * 0.006 * idle
	left_forearm.rotation.x -= (0.08 + 0.035 * sin(_time * 0.8)) * idle + _door_tension * 0.18
	right_forearm.rotation.x -= 0.035 * idle + _door_tension * 0.12
	left_arm.rotation.z -= 0.025 * sin(_time * 0.71) * idle
	right_arm.rotation.z += 0.018 * sin(_time * 0.93 + 1.2) * idle
	$Body/Backpack.rotation.x = -sin(_step_phase) * 0.025 * _settle
	$Body/Head/Face/LeftBrow.rotation.z = -0.12 - _door_tension * 0.1
	$Body/Head/Face/RightBrow.rotation.z = 0.12 + _door_tension * 0.08


func _pose_planted_leg(leg: Node3D, knee: Node3D, phase: float, weight: float) -> void:
	var cycle := fposmod(phase / TAU, 1.0)
	var foot_z := 0.0
	var lift := 0.0
	if cycle < 0.6:
		foot_z = lerpf(0.246, -0.246, cycle / 0.6)
	else:
		var swing := (cycle - 0.6) / 0.4
		foot_z = lerpf(-0.246, 0.246, smoothstep(0.0, 1.0, swing))
		lift = sin(swing * PI) * 0.075
	foot_z *= _settle
	lift *= _settle
	var down := 0.59 - lift
	var length_to_ankle := clampf(Vector2(down, foot_z).length(), 0.05, 0.639)
	var hip_angle := -atan2(foot_z, down) - acos(clampf(length_to_ankle / 0.64, -1.0, 1.0))
	var knee_angle := PI - acos(clampf((0.32 * 0.32 * 2.0 - length_to_ankle * length_to_ankle) / (2.0 * 0.32 * 0.32), -1.0, 1.0))
	leg.rotation.x = lerpf(leg.rotation.x, hip_angle, weight)
	knee.rotation.x = lerpf(knee.rotation.x, knee_angle, weight)
	leg.position.y = lerpf(leg.position.y, 0.635, weight)
	# Compensación del tobillo: suela horizontal durante el apoyo.
	var shoe := knee.get_node_or_null("Shoe") as Node3D
	if shoe != null:
		shoe.rotation.x = -(leg.rotation.x + knee.rotation.x) * weight
		var sole := knee.get_node("Sole") as Node3D
		sole.rotation.x = shoe.rotation.x
		# Ambos elementos comparten tobillo, no pivotes separados.
		var ankle := Vector3(0.0, -0.32, 0.0)
		shoe.position = ankle + Basis(Vector3.RIGHT, shoe.rotation.x) * Vector3(0.0, 0.03, 0.055)
		sole.position = ankle + Basis(Vector3.RIGHT, shoe.rotation.x) * Vector3(0.0, -0.03, 0.055)
