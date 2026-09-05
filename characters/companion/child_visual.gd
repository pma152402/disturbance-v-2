extends Node3D

@onready var body: Node3D = $Body
@onready var head: Node3D = $Body/Head
@onready var left_arm: Node3D = $Body/LeftArm
@onready var right_arm: Node3D = $Body/RightArm
@onready var left_forearm: Node3D = $Body/LeftArm/Forearm
@onready var right_forearm: Node3D = $Body/RightArm/Forearm
@onready var left_leg: Node3D = $LeftLeg
@onready var right_leg: Node3D = $RightLeg
@onready var left_eye: MeshInstance3D = $Body/Head/Face/LeftEye
@onready var right_eye: MeshInstance3D = $Body/Head/Face/RightEye

var _time := 0.0
var _blink_timer := 2.4
var _blink_amount := 0.0
var _base_head_position := Vector3.ZERO


func _ready() -> void:
	_base_head_position = head.position


func update_companion_animation(delta: float, movement: float, waiting: bool) -> void:
	_time += delta
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_amount = 1.0
		_blink_timer = randf_range(2.1, 5.2)
	_blink_amount = move_toward(_blink_amount, 0.0, delta * 9.0)
	var eye_scale_y := lerpf(1.0, 0.08, clampf(_blink_amount * 2.0, 0.0, 1.0))
	left_eye.scale.y = eye_scale_y
	right_eye.scale.y = eye_scale_y

	var walk_phase := _time * lerpf(3.0, 8.5, clampf(movement, 0.0, 1.0))
	var stride := sin(walk_phase) * 0.62 * clampf(movement, 0.0, 1.0)
	left_leg.rotation.x = stride
	right_leg.rotation.x = -stride
	left_arm.rotation.x = -stride * 0.72
	right_arm.rotation.x = stride * 0.72
	left_forearm.rotation.x = -0.16 - maxf(0.0, stride) * 0.18
	right_forearm.rotation.x = -0.16 + minf(0.0, stride) * 0.18
	body.position.y = 0.87 + absf(sin(walk_phase * 2.0)) * 0.025 * movement
	body.rotation.z = sin(walk_phase) * 0.025 * movement

	var idle_weight := 1.0 - clampf(movement, 0.0, 1.0)
	head.position = _base_head_position + Vector3(0.0, sin(_time * 1.6) * 0.008, 0.0)
	head.rotation.z = sin(_time * 0.55) * 0.035 * idle_weight
	head.rotation.x = (0.035 + sin(_time * 0.7) * 0.018) * idle_weight if waiting else sin(_time * 1.1) * 0.012
	body.scale.y = 1.0 + sin(_time * 1.8) * 0.006

