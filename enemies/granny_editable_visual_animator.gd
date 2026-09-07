extends Node3D

## Adaptador visual del rig editable a los estados de monster_grandmother.gd.
## Todas las poses son offsets sobre la colocacion guardada en la escena, de
## modo que los ajustes manuales de brazos, manos y cabeza no se pierden.

const STATE_PATROL := 0
const STATE_INVESTIGATE := 1
const STATE_CHASE := 2
const STATE_SEARCH := 3
const STATE_ATTACK := 4
const STATE_EAT := 5

@export var idle_arm_sway := 0.045
@export var walk_arm_swing := 0.34
@export var chase_arm_swing := 0.52
@export var walk_bob_height := 0.018
@export_range(0.0, 0.5, 0.005) var turn_lean := 0.16
@export var pose_transition_speed := 9.0
@export_range(1.0, 1.5, 0.01) var head_scale_multiplier := 1.12
@export var head_down_offset := 0.5722
@export var resting_hand_height := 0.92
@export var resting_hand_width := 0.43
@export var resting_hand_forward := 0.1

@onready var _rig: Node3D = $CleanModel/EditableGrannyRig
@onready var _head: Node3D = $CleanModel/EditableGrannyRig/HeadPivot
@onready var _left_shoulder: Node3D = $CleanModel/EditableGrannyRig/LeftShoulderPivot
@onready var _left_elbow: Node3D = $CleanModel/EditableGrannyRig/LeftShoulderPivot/LeftElbowPivot
@onready var _left_wrist: Node3D = $CleanModel/EditableGrannyRig/LeftShoulderPivot/LeftElbowPivot/LeftWristPivot
@onready var _left_shoulder_joint: Node3D = $CleanModel/EditableGrannyRig/LeftShoulderPivot/LeftShoulderJoint
@onready var _left_sleeve: Node3D = $CleanModel/EditableGrannyRig/LeftShoulderPivot/LeftDressSleeve
@onready var _left_upper_arm: MeshInstance3D = $CleanModel/EditableGrannyRig/LeftShoulderPivot/LeftUpperArm
@onready var _left_forearm: MeshInstance3D = $CleanModel/EditableGrannyRig/LeftShoulderPivot/LeftElbowPivot/LeftForearm
@onready var _left_elbow_joint: Node3D = $CleanModel/EditableGrannyRig/LeftShoulderPivot/LeftElbowPivot/LeftElbowJoint
@onready var _left_wrist_joint: Node3D = $CleanModel/EditableGrannyRig/LeftShoulderPivot/LeftElbowPivot/LeftWristPivot/LeftWristJoint
@onready var _right_shoulder: Node3D = $CleanModel/EditableGrannyRig/RightShoulderPivot
@onready var _right_elbow: Node3D = $CleanModel/EditableGrannyRig/RightShoulderPivot/RightElbowPivot
@onready var _right_wrist: Node3D = $CleanModel/EditableGrannyRig/RightShoulderPivot/RightElbowPivot/RightWristPivot
@onready var _right_shoulder_joint: Node3D = $CleanModel/EditableGrannyRig/RightShoulderPivot/RightShoulderJoint
@onready var _right_sleeve: Node3D = $CleanModel/EditableGrannyRig/RightShoulderPivot/RightDressSleeve
@onready var _right_upper_arm: MeshInstance3D = $CleanModel/EditableGrannyRig/RightShoulderPivot/RightUpperArm
@onready var _right_forearm: MeshInstance3D = $CleanModel/EditableGrannyRig/RightShoulderPivot/RightElbowPivot/RightForearm
@onready var _right_elbow_joint: Node3D = $CleanModel/EditableGrannyRig/RightShoulderPivot/RightElbowPivot/RightElbowJoint
@onready var _right_wrist_joint: Node3D = $CleanModel/EditableGrannyRig/RightShoulderPivot/RightElbowPivot/RightWristPivot/RightWristJoint
@onready var _neck_seal: Node3D = $SeamRepairs/NeckSeal

var _body: CharacterBody3D
var _player: CharacterBody3D
var _phase := 0.0
var _base_position := Vector3.ZERO
var _base_head_position := Vector3.ZERO
var _base_head_scale := Vector3.ONE
var _base_rig_rotation := Quaternion.IDENTITY
var _base_head_rotation := Quaternion.IDENTITY
var _base_left_shoulder := Quaternion.IDENTITY
var _base_left_elbow := Quaternion.IDENTITY
var _base_left_wrist := Quaternion.IDENTITY
var _base_right_shoulder := Quaternion.IDENTITY
var _base_right_elbow := Quaternion.IDENTITY
var _base_right_wrist := Quaternion.IDENTITY
var _left_upper_rest_direction := Vector3.DOWN
var _left_lower_rest_direction := Vector3.DOWN
var _right_upper_rest_direction := Vector3.DOWN
var _right_lower_rest_direction := Vector3.DOWN
var _skin_material: StandardMaterial3D
var _previous_yaw := 0.0
var _lean_amount := 0.0


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	# El usuario puede recolocar cada pieza visual desde el editor. Ajustamos el
	# origen de giro a la articulacion visible y restauramos inmediatamente las
	# transformaciones globales de los hijos: la pose no cambia, solo se corrige
	# el punto alrededor del que animara cada cadena.
	_recenter_pivot(_left_shoulder, _left_shoulder_joint)
	_recenter_pivot(_right_shoulder, _right_shoulder_joint)
	_recenter_pivot(_left_elbow, _left_elbow_joint)
	_recenter_pivot(_right_elbow, _right_elbow_joint)
	_recenter_pivot(_left_wrist, _left_wrist_joint)
	_recenter_pivot(_right_wrist, _right_wrist_joint)
	_base_position = position
	_base_head_position = _head.position
	_base_head_scale = _head.scale
	_head.scale = _base_head_scale * head_scale_multiplier
	_neck_seal.visible = false
	_remove_unused_hair_nodes()
	_remove_round_joint_markers()
	_left_sleeve.scale *= Vector3(0.92, 1.02, 0.88)
	_right_sleeve.scale *= Vector3(0.92, 1.02, 0.88)
	_refine_limb_shape(_left_upper_arm)
	_refine_limb_shape(_left_forearm)
	_refine_limb_shape(_right_upper_arm)
	_refine_limb_shape(_right_forearm)
	_apply_muted_skin_material()
	_base_rig_rotation = _rig.quaternion
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
	if is_instance_valid(_body):
		_previous_yaw = _body.rotation.y


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_body):
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D

	var actual_velocity := _body.get_real_velocity()
	var horizontal_speed := Vector2(actual_velocity.x, actual_velocity.z).length()
	var chase_speed := maxf(float(_body.get("chase_speed")), 0.01)
	var moving := clampf(horizontal_speed / chase_speed, 0.0, 1.0)
	var state := int(_body.get("current_state"))
	var waiting_covered_eyes := bool(_body.get("_waiting_covered_eyes"))
	var duck_amount := clampf(float(_body.get("_duck_amount")), 0.0, 1.0)
	var attack_timer := maxf(float(_body.get("_attack_timer")), 0.0)
	var crossing_door := _body.has_method(&"is_crossing_door") and bool(_body.call(&"is_crossing_door"))

	# Una sola fase para todo el personaje. Antes este nodo llevaba su propio
	# contador y el bob visual iba por libre respecto al sonido de paso que
	# dispara el controlador base; ahora ambos salen del mismo `_motion_phase`,
	# que a su vez avanza con la distancia recorrida.
	_phase = float(_body.get("_motion_phase"))

	# Inclinación hacia el interior del giro, tomada de la velocidad angular real
	# del cuerpo. Es lo que da peso a los cambios de dirección en un rig sin
	# piernas: sin ella la silueta rota sobre su eje como una torreta.
	var yaw_rate := wrapf(_body.rotation.y - _previous_yaw, -PI, PI) / maxf(delta, 0.0001)
	_previous_yaw = _body.rotation.y
	_lean_amount = lerpf(
		_lean_amount,
		clampf(yaw_rate * 0.11, -1.0, 1.0) * turn_lean * clampf(moving * 1.6, 0.0, 1.0),
		1.0 - exp(-6.0 * delta)
	)

	var player_distance := INF
	if is_instance_valid(_player):
		player_distance = _body.global_position.distance_to(_player.global_position)
	var reaching := (
		state == STATE_CHASE
		and is_instance_valid(_player)
		and player_distance >= 1.25
		and player_distance <= 2.65
		and absf(_player.global_position.y - _body.global_position.y) < 1.7
	)

	if waiting_covered_eyes:
		_apply_covered_eyes_pose(delta)
	elif crossing_door:
		_apply_door_cross_pose(delta)
	elif state == STATE_EAT:
		_apply_eating_pose(delta)
	elif state == STATE_ATTACK:
		_apply_attack_pose(delta, attack_timer)
	elif reaching:
		_apply_reaching_pose(delta)
	elif state in [STATE_INVESTIGATE, STATE_SEARCH]:
		_apply_alert_pose(delta, state, moving)
	else:
		_apply_locomotion_pose(delta, state, moving)

	_lock_head_to_body(state, delta)
	_apply_body_motion(delta, state, moving, duck_amount, waiting_covered_eyes, crossing_door)


func _apply_door_cross_pose(delta: float) -> void:
	# Al comprometer el cruce recoge hombros y manos. Además de hacerlo legible,
	# evita que la silueta parezca atravesar los marcos estrechos con los brazos.
	var forward := _body.global_basis.z.normalized()
	var right := _body.global_basis.x.normalized()
	var center := _body.global_position + Vector3.UP * 0.92 + forward * 0.18
	_pose_arm_ik(
		_left_shoulder, _left_elbow, _left_wrist,
		_base_left_shoulder, _base_left_elbow,
		_left_upper_rest_direction, _left_lower_rest_direction,
		center + right * 0.18, 1.0, delta, 12.0
	)
	_pose_arm_ik(
		_right_shoulder, _right_elbow, _right_wrist,
		_base_right_shoulder, _base_right_elbow,
		_right_upper_rest_direction, _right_lower_rest_direction,
		center - right * 0.18, -1.0, delta, 12.0
	)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.12, 0.0, -0.16), delta, 12.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, -0.12, 0.0, 0.16), delta, 12.0)


func _apply_locomotion_pose(delta: float, state: int, moving: float) -> void:
	# Pose compacta: las manos descansan junto a las caderas en lugar de
	# conservar la T-pose del modelo. El IK mantiene cada brazo unido.
	var side := (_left_shoulder.global_position - _right_shoulder.global_position).normalized()
	var forward := _body.global_basis.z.normalized()
	var stride := sin(_phase) * 0.11 * moving
	var breathing := sin(_phase * 0.72) * 0.015 * (1.0 - moving)
	var chase_amount := 1.0 if state == STATE_CHASE else 0.0
	var target_center := _body.global_position + Vector3.UP * (resting_hand_height + breathing + chase_amount * 0.08)
	target_center += forward * (resting_hand_forward + chase_amount * 0.22)
	var left_target := target_center + side * resting_hand_width + forward * stride
	var right_target := target_center - side * resting_hand_width - forward * stride
	_pose_arm_ik(
		_left_shoulder, _left_elbow, _left_wrist,
		_base_left_shoulder, _base_left_elbow,
		_left_upper_rest_direction, _left_lower_rest_direction,
		left_target, 1.0, delta, pose_transition_speed
	)
	_pose_arm_ik(
		_right_shoulder, _right_elbow, _right_wrist,
		_base_right_shoulder, _base_right_elbow,
		_right_upper_rest_direction, _right_lower_rest_direction,
		right_target, -1.0, delta, pose_transition_speed
	)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.08, 0.0, -0.12), delta, pose_transition_speed)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, -0.08, 0.0, 0.12), delta, pose_transition_speed)


func _apply_alert_pose(delta: float, state: int, moving: float) -> void:
	# En investigación tantea el espacio con una mano. Durante la búsqueda abre
	# más ambos brazos y barre la habitación, diferenciándola de la persecución.
	var forward := _body.global_basis.z.normalized()
	var right := _body.global_basis.x.normalized()
	var searching := 1.0 if state == STATE_SEARCH else 0.0
	var scan := sin(_phase * 0.48)
	var center := _body.global_position + Vector3.UP * lerpf(1.0, 1.12, searching)
	var left_target := center + forward * (0.38 + searching * 0.18) + right * (0.34 + scan * 0.08)
	var right_target := center + forward * (0.08 + searching * 0.3) - right * (0.38 - scan * 0.08)
	_pose_arm_ik(
		_left_shoulder, _left_elbow, _left_wrist,
		_base_left_shoulder, _base_left_elbow,
		_left_upper_rest_direction, _left_lower_rest_direction,
		left_target, 1.0, delta, 8.5
	)
	_pose_arm_ik(
		_right_shoulder, _right_elbow, _right_wrist,
		_base_right_shoulder, _base_right_elbow,
		_right_upper_rest_direction, _right_lower_rest_direction,
		right_target, -1.0, delta, 8.5
	)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.16, 0.0, -0.12), delta, 9.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, -0.1, 0.0, 0.12), delta, 9.0)


func _apply_covered_eyes_pose(delta: float) -> void:
	var face_forward := _body.global_basis.z.normalized()
	var face_right := _body.global_basis.x.normalized()
	# El nodo de ojos del GLB conserva un origen exportado incorrecto; la cara
	# visible esta centrada respecto a HeadPivot.
	# El pivote de la muneca debe quedar por encima del ojo porque la palma del
	# modelo cuelga unos centimetros por debajo de ese pivote.
	var eye_center := _head.global_position + Vector3.UP * 0.235 + face_forward * 0.07
	_pose_arm_ik(
		_left_shoulder, _left_elbow, _left_wrist,
		_base_left_shoulder, _base_left_elbow,
		_left_upper_rest_direction, _left_lower_rest_direction,
		eye_center + face_right * 0.115 + Vector3.DOWN * 0.035,
		1.0, delta, 7.5
	)
	_pose_arm_ik(
		_right_shoulder, _right_elbow, _right_wrist,
		_base_right_shoulder, _base_right_elbow,
		_right_upper_rest_direction, _right_lower_rest_direction,
		eye_center - face_right * 0.115 + Vector3.DOWN * 0.035,
		-1.0, delta, 7.5
	)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, 0.08, 0.0, -0.18), delta, 8.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, 0.08, 0.0, 0.18), delta, 8.0)


func _apply_reaching_pose(delta: float) -> void:
	var target_center := _body.global_position + _body.global_basis.z * 1.1 + Vector3.UP * 1.08
	var target_right := _body.global_basis.x.normalized()
	if is_instance_valid(_player):
		target_center = _player.global_position + Vector3.UP * 1.05
		target_right = _player.global_basis.x.normalized()
	_pose_arm_ik(
		_left_shoulder, _left_elbow, _left_wrist,
		_base_left_shoulder, _base_left_elbow,
		_left_upper_rest_direction, _left_lower_rest_direction,
		target_center + target_right * 0.18,
		1.0, delta, 9.5
	)
	_pose_arm_ik(
		_right_shoulder, _right_elbow, _right_wrist,
		_base_right_shoulder, _base_right_elbow,
		_right_upper_rest_direction, _right_lower_rest_direction,
		target_center - target_right * 0.18,
		-1.0, delta, 9.5
	)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, 0.0, 0.0, -0.08), delta, 9.5)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, 0.0, 0.0, 0.08), delta, 9.5)


func _apply_attack_pose(delta: float, attack_timer: float) -> void:
	var windup_time := maxf(float(_body.get("attack_windup_seconds")), 0.05)
	var hit_time := maxf(float(_body.get("attack_hit_seconds")), windup_time + 0.05)
	var end_time := maxf(float(_body.get("attack_animation_seconds")), hit_time + 0.1)
	var windup := clampf(attack_timer / windup_time, 0.0, 1.0)
	var strike := clampf((attack_timer - windup_time) / (hit_time - windup_time), 0.0, 1.0)
	var recovery := clampf((attack_timer - hit_time) / (end_time - hit_time), 0.0, 1.0)
	var thrust := strike * (1.0 - recovery)
	var forward := _body.global_basis.z.normalized()
	var right := _body.global_basis.x.normalized()
	var target_center := _body.global_position + forward * lerpf(0.28 - windup * 0.14, 1.25, thrust) + Vector3.UP * lerpf(1.18, 1.02, thrust)
	if is_instance_valid(_player):
		target_center = target_center.lerp(_player.global_position + Vector3.UP * 1.0, thrust * 0.85)
	_pose_arm_ik(
		_left_shoulder, _left_elbow, _left_wrist,
		_base_left_shoulder, _base_left_elbow,
		_left_upper_rest_direction, _left_lower_rest_direction,
		target_center + right * 0.11,
		1.0, delta, 16.0
	)
	_pose_arm_ik(
		_right_shoulder, _right_elbow, _right_wrist,
		_base_right_shoulder, _base_right_elbow,
		_right_upper_rest_direction, _right_lower_rest_direction,
		target_center - right * 0.11,
		-1.0, delta, 16.0
	)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.1 * thrust, 0.0, -0.08), delta, 15.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, -0.1 * thrust, 0.0, 0.08), delta, 15.0)


func _apply_eating_pose(delta: float) -> void:
	# El rig importado necesita su propia pose porque sustituye visualmente al
	# modelo procedural del controlador base. Las manos se alternan entre el
	# cuerpo y la boca para que no parezca un simple bucle de brazos simétrico.
	var target := _body.get("_eating_target") as Node3D
	var forward := _body.global_basis.z.normalized()
	var right := _body.global_basis.x.normalized()
	var body_center := _body.global_position + forward * 0.55 + Vector3.UP * 0.18
	if is_instance_valid(target):
		body_center = target.global_position + Vector3.UP * 0.16
	var mouth_center := _head.global_position + forward * 0.12 + Vector3.DOWN * 0.08
	var cycle := fposmod(float(_body.get("_eating_elapsed")) * 1.35, 1.0)
	var left_transfer := smoothstep(0.08, 0.43, cycle) * (1.0 - smoothstep(0.48, 0.86, cycle))
	var shifted_cycle := fposmod(cycle + 0.5, 1.0)
	var right_transfer := smoothstep(0.08, 0.43, shifted_cycle) * (1.0 - smoothstep(0.48, 0.86, shifted_cycle))
	var left_target := (body_center + right * 0.19).lerp(mouth_center + right * 0.1, left_transfer)
	var right_target := (body_center - right * 0.19).lerp(mouth_center - right * 0.1, right_transfer)
	_pose_arm_ik(
		_left_shoulder, _left_elbow, _left_wrist,
		_base_left_shoulder, _base_left_elbow,
		_left_upper_rest_direction, _left_lower_rest_direction,
		left_target, 1.0, delta, 10.5
	)
	_pose_arm_ik(
		_right_shoulder, _right_elbow, _right_wrist,
		_base_right_shoulder, _base_right_elbow,
		_right_upper_rest_direction, _right_lower_rest_direction,
		right_target, -1.0, delta, 10.5
	)
	var bite := maxf(left_transfer, right_transfer)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, -0.2 * bite, 0.0, -0.18), delta, 11.0)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, -0.2 * bite, 0.0, 0.18), delta, 11.0)


func _lock_head_to_body(state: int, delta: float) -> void:
	# Conserva el anclaje del cuello, pero permite pequeños movimientos legibles
	# de atención. No se anima la posición, sólo una rotación contenida.
	_head.position = _base_head_position + Vector3(0.0, -head_down_offset, 0.0)
	var yaw := 0.0
	var pitch := 0.0
	if state == STATE_INVESTIGATE:
		yaw = sin(_phase * 0.34) * 0.16
		pitch = -0.06
	elif state == STATE_SEARCH:
		yaw = sin(_phase * 0.42) * 0.34
		pitch = -0.1 + sin(_phase * 0.21) * 0.04
	elif state == STATE_CHASE:
		pitch = -0.11
	elif state == STATE_EAT:
		yaw = sin(_phase * 0.28) * 0.045
		pitch = 0.48 + absf(sin(float(_body.get("_eating_elapsed")) * 8.5)) * 0.12
	if state != STATE_EAT and _body.has_method(&"get_attention_position"):
		var target: Vector3 = _body.call(&"get_attention_position")
		var local_direction := _body.global_basis.inverse() * (target - _body.global_position)
		if Vector2(local_direction.x, local_direction.z).length_squared() > 0.04:
			yaw += clampf(atan2(local_direction.x, local_direction.z), -0.42, 0.42)
	var target_rotation := _base_head_rotation * Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch)
	_head.quaternion = _head.quaternion.slerp(target_rotation, 1.0 - exp(-6.0 * delta))
	_head.scale = _base_head_scale * head_scale_multiplier

func _apply_body_motion(delta: float, state: int, moving: float, duck_amount: float, covered_eyes: bool, crossing_door: bool) -> void:
	var chase_amount := 1.0 if state == STATE_CHASE else 0.0
	var attack_amount := 0.0
	if state == STATE_ATTACK:
		attack_amount = sin(clampf(float(_body.get("_attack_timer")) / 0.72, 0.0, 1.0) * PI)
	var eating_amount := 1.0 if state == STATE_EAT else 0.0
	var chew_lean := absf(sin(float(_body.get("_eating_elapsed")) * 8.5)) * 0.07 * eating_amount
	var lean_x := -0.045 - chase_amount * 0.16 - duck_amount * 0.2 - attack_amount * 0.2 + eating_amount * (0.82 + chew_lean)
	if covered_eyes:
		lean_x = -0.18
	elif crossing_door:
		lean_x = -0.14
	# `_phase * 0.5` es un balanceo por cada dos zancadas: el traspaso de peso de
	# un pie al otro. Ahora que la fase sigue la velocidad real, coincide con el
	# paso que suena.
	var sway_z := sin(_phase * 0.5) * lerpf(0.012, 0.035, moving) + sin(_phase * 0.7) * 0.025 * eating_amount
	if not covered_eyes and not crossing_door:
		sway_z += _lean_amount
	_pose_node(_rig, _offset_pose(_base_rig_rotation, lean_x, 0.0, sway_z), delta, 7.0)

	var bob := (absf(sin(_phase)) - 0.5) * walk_bob_height * moving
	var breathing := sin(Time.get_ticks_msec() * 0.0018) * 0.008
	position = position.lerp(
		_base_position + Vector3(0.0, bob + breathing - duck_amount * 0.38 - eating_amount * 0.54, eating_amount * 0.08),
		minf(delta * 8.0, 1.0)
	)


func _remove_unused_hair_nodes() -> void:
	for node_name in [&"HairCap", &"LeftHairTuft", &"RightHairTuft"]:
		var hair := _head.get_node_or_null(NodePath(node_name))
		if hair:
			hair.free()


func _remove_round_joint_markers() -> void:
	# Estas piezas redondas eran guias del rig editable, no partes anatomicas.
	for marker in [
		_left_shoulder_joint, _left_elbow_joint, _left_wrist_joint,
		_right_shoulder_joint, _right_elbow_joint, _right_wrist_joint,
	]:
		marker.visible = false
	for side_path in [
		"CleanModel/EditableGrannyRig/LeftShoulderPivot/LeftElbowPivot/LeftWristPivot",
		"CleanModel/EditableGrannyRig/RightShoulderPivot/RightElbowPivot/RightWristPivot",
	]:
		var wrist_root := get_node(side_path)
		for child in wrist_root.get_children():
			if "Knuckle" in child.name:
				child.visible = false
	for seal_name in [&"LeftArmpitSeal", &"RightArmpitSeal"]:
		var seal := $SeamRepairs.get_node_or_null(NodePath(seal_name))
		if seal:
			seal.visible = false


func _refine_limb_shape(limb: Node3D) -> void:
	# Un poco mas largos para solapar el corte del codo y mas estrechos para
	# recuperar una proporcion humana, sin volver a introducir bolas de union.
	limb.scale *= Vector3(0.88, 1.18, 0.88)


func _apply_muted_skin_material() -> void:
	_skin_material = StandardMaterial3D.new()
	_skin_material.albedo_color = Color(0.48, 0.34, 0.31, 1.0)
	_skin_material.roughness = 0.96
	for shoulder in [_left_shoulder, _right_shoulder]:
		for mesh in _collect_meshes(shoulder):
			if "DressSleeve" not in mesh.name:
				mesh.material_override = _skin_material


func _collect_meshes(root_node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root_node.get_children():
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		result.append_array(_collect_meshes(child))
	return result


func _pose_wrists(delta: float, moving: float) -> void:
	var wrist_roll := sin(_phase * 0.83) * 0.035 * lerpf(0.35, 1.0, moving)
	_pose_node(_left_wrist, _offset_pose(_base_left_wrist, 0.0, 0.0, wrist_roll), delta, pose_transition_speed)
	_pose_node(_right_wrist, _offset_pose(_base_right_wrist, 0.0, 0.0, -wrist_roll), delta, pose_transition_speed)


func _offset_pose(base: Quaternion, x: float, y: float, z: float) -> Quaternion:
	return (
		base
		* Quaternion(Vector3.RIGHT, x)
		* Quaternion(Vector3.UP, y)
		* Quaternion(Vector3.FORWARD, z)
	).normalized()


func _pose_node(node: Node3D, target: Quaternion, delta: float, speed: float) -> void:
	node.quaternion = node.quaternion.slerp(target, minf(delta * speed, 1.0)).normalized()


func _pose_arm_ik(
	shoulder: Node3D,
	elbow: Node3D,
	wrist: Node3D,
	base_shoulder: Quaternion,
	base_elbow: Quaternion,
	upper_rest_direction: Vector3,
	lower_rest_direction: Vector3,
	target_position: Vector3,
	outward_side: float,
	delta: float,
	speed: float
) -> void:
	var shoulder_position := shoulder.global_position
	var upper_length := shoulder_position.distance_to(elbow.global_position)
	var lower_length := elbow.global_position.distance_to(wrist.global_position)
	var shoulder_to_target := target_position - shoulder_position
	var target_distance := shoulder_to_target.length()
	if upper_length < 0.01 or lower_length < 0.01 or target_distance < 0.01:
		return

	var reach_min := absf(upper_length - lower_length) + 0.01
	var reach_max := upper_length + lower_length - 0.01
	var solved_distance := clampf(target_distance, reach_min, reach_max)
	var target_direction := shoulder_to_target / target_distance
	var solved_target := shoulder_position + target_direction * solved_distance
	var along_distance := (
		upper_length * upper_length
		- lower_length * lower_length
		+ solved_distance * solved_distance
	) / (2.0 * solved_distance)
	var bend_height := sqrt(maxf(0.0, upper_length * upper_length - along_distance * along_distance))
	var outward := _body.global_basis.x.normalized() * outward_side
	var bend_direction := outward - target_direction * outward.dot(target_direction)
	if bend_direction.length_squared() < 0.001:
		bend_direction = Vector3.UP.cross(target_direction)
	bend_direction = bend_direction.normalized()
	var elbow_target := shoulder_position + target_direction * along_distance + bend_direction * bend_height

	var shoulder_parent := shoulder.get_parent() as Node3D
	var shoulder_parent_basis := shoulder_parent.global_basis.orthonormalized()
	var base_upper_parent_direction := (Basis(base_shoulder) * upper_rest_direction).normalized()
	var desired_upper_parent_direction := (shoulder_parent_basis.inverse() * (elbow_target - shoulder_position).normalized()).normalized()
	var shoulder_delta := Quaternion(base_upper_parent_direction, desired_upper_parent_direction)
	var desired_shoulder := (shoulder_delta * base_shoulder).normalized()

	var desired_shoulder_global_basis := shoulder_parent_basis * Basis(desired_shoulder)
	var base_lower_shoulder_direction := (Basis(base_elbow) * lower_rest_direction).normalized()
	var desired_lower_shoulder_direction := (desired_shoulder_global_basis.inverse() * (solved_target - elbow_target).normalized()).normalized()
	var elbow_delta := Quaternion(base_lower_shoulder_direction, desired_lower_shoulder_direction)
	var desired_elbow := (elbow_delta * base_elbow).normalized()

	_pose_node(shoulder, desired_shoulder, delta, speed)
	_pose_node(elbow, desired_elbow, delta, speed + 1.0)


func _recenter_pivot(pivot: Node3D, visible_joint: Node3D) -> void:
	if not is_instance_valid(pivot) or not is_instance_valid(visible_joint):
		return
	var joint_position := visible_joint.global_position
	var child_transforms: Array[Transform3D] = []
	for child in pivot.get_children():
		if child is Node3D:
			child_transforms.append((child as Node3D).global_transform)
		else:
			child_transforms.append(Transform3D.IDENTITY)
	pivot.global_position = joint_position
	for child_index in pivot.get_child_count():
		var child := pivot.get_child(child_index)
		if child is Node3D:
			(child as Node3D).global_transform = child_transforms[child_index]
