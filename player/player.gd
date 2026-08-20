extends CharacterBody3D

@export var move_speed := 1.4
@export var sprint_speed := 4.8
@export var crouch_speed := 1.55
@export var prone_speed := 0.8
@export var acceleration := 10.0
@export var mouse_sensitivity := 0.0022
@export_range(1.0, 89.0, 1.0) var max_look_angle := 85.0
@export var bob_frequency := 7.0
@export var bob_vertical_amount := 0.06
@export var bob_horizontal_amount := 0.032
@export var bob_roll_degrees := 0.9
@export var sprint_bob_multiplier := 1.52
@export var lean_distance := 0.48
@export var lean_angle_degrees := 16.0
@export var lean_speed := 7.0
@export var max_stamina := 100.0
@export var stamina_drain_per_second := 5.5
@export var stamina_recovery_per_second := 6.0
@export var exhausted_recovery_threshold := 22.0
@export var jump_stamina_cost := 4.0
@export var crouch_stamina_cost := 1.0
@export var prone_stamina_cost := 2.0
@export var rise_stamina_cost := 1.5
@export var rise_from_prone_stamina_cost := 2.5
@export var crouch_transition_time := 0.32
@export var prone_transition_time := 0.55
@export var hand_aim_sensitivity := 0.0025
@export var hand_return_speed := 5.0
@export var jump_velocity := 4.1
@export var jump_windup_time := 0.11
@export var jump_recovery_time := 0.13
@export var upward_gravity_multiplier := 1.7
@export var falling_gravity_multiplier := 2.3
@export var can_throw_force := 8.5
@export var can_throw_upward_force := 1.25

enum Stance { STANDING, CROUCHED, PRONE }
enum JumpPhase { IDLE, WINDUP, RECOVERING }

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hand_rig: Node3D = $Head/Camera3D/HandRig
@onready var left_hand_rig: Node3D = $Head/Camera3D/LeftHandRig
@onready var left_hand: MeshInstance3D = $Head/Camera3D/LeftHandRig/LeftHand
@onready var held_can: Node3D = $Head/Camera3D/LeftHandRig/HeldCan
@onready var held_bottle: Node3D = $Head/Camera3D/LeftHandRig/HeldBottle
@onready var flashlight: SpotLight3D = $Head/Camera3D/HandRig/Flashlight
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var stamina_bar: ProgressBar = $StaminaUI/StaminaBar
@onready var interaction_prompt: Label = $StaminaUI/InteractionPrompt

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _camera_rest_position: Vector3
var _bob_phase := 0.0
var _lean_amount := 0.0
var _stamina := 100.0
var _is_exhausted := false
var _full_stamina_flash_timer := 0.0
var _ui_time := 0.0
var _stamina_fill_style: StyleBoxFlat
var _look_pitch := 0.0
var _hand_yaw := 0.0
var _hand_pitch := 0.0
var _is_aiming_hand := false
var _stance := Stance.STANDING
var _pending_stance := Stance.STANDING
var _stance_transition_timer := 0.0
var _stance_transition_duration := 0.0
var _stance_transition_elapsed := 0.0
var _stance_start_values := Vector3.ZERO
var _stance_target_values := Vector3.ZERO
var _jump_phase := JumpPhase.IDLE
var _jump_timer := 0.0
var _jump_start_head_y := 0.65
var _held_item: StringName = &""
var _flashlight_holstered := false
var _flashlight_was_on := true

const ThrownCanScene := preload("res://thrown_can.tscn")
const ThrownBottleScene := preload("res://thrown_bottle.tscn")


func _ready() -> void:
	add_to_group(&"player")
	_camera_rest_position = camera.position
	_stamina = max_stamina
	stamina_bar.max_value = max_stamina
	stamina_bar.value = _stamina
	_stamina_fill_style = stamina_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	stamina_bar.add_theme_stylebox_override("fill", _stamina_fill_style)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var pressed_key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		if pressed_key == KEY_F and _try_interact(pressed_key):
			get_viewport().set_input_as_handled()
			return
		if pressed_key == KEY_L:
			_toggle_flashlight_holster()
			get_viewport().set_input_as_handled()
			return
		if pressed_key == KEY_CTRL:
			_request_stance(Stance.STANDING if _stance == Stance.CROUCHED else Stance.CROUCHED)
			get_viewport().set_input_as_handled()
			return
		if pressed_key == KEY_X:
			_request_stance(Stance.STANDING if _stance == Stance.PRONE else Stance.PRONE)
			get_viewport().set_input_as_handled()
			return
		if pressed_key == KEY_SPACE:
			_request_jump()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion := event as InputEventMouseMotion
		_is_aiming_hand = Input.is_key_pressed(KEY_ALT)
		# Normal camera look remains active even while Alt controls the hand.
		rotate_y(-mouse_motion.screen_relative.x * mouse_sensitivity)
		_look_pitch = clampf(
			_look_pitch - mouse_motion.screen_relative.y * mouse_sensitivity,
			deg_to_rad(-max_look_angle), deg_to_rad(max_look_angle)
		)

		if _is_aiming_hand:
			_hand_yaw = clampf(
				_hand_yaw - mouse_motion.screen_relative.x * hand_aim_sensitivity,
				deg_to_rad(-32.0), deg_to_rad(32.0)
			)
			_hand_pitch = clampf(
				_hand_pitch - mouse_motion.screen_relative.y * hand_aim_sensitivity,
				deg_to_rad(-25.0), deg_to_rad(25.0)
			)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT and not _flashlight_holstered:
			flashlight.visible = not flashlight.visible
			get_viewport().set_input_as_handled()
			return
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if not _held_item.is_empty() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_throw_held_item()
				get_viewport().set_input_as_handled()
				return
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_update_stance_transition(delta)
	head.rotation.x = _look_pitch
	head.rotation.y = 0.0

	if not is_on_floor():
		var gravity_multiplier := upward_gravity_multiplier if velocity.y > 0.0 else falling_gravity_multiplier
		velocity.y -= _gravity * gravity_multiplier * delta
	else:
		velocity.y = 0.0
	_update_jump(delta)

	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if (
		Input.is_action_just_pressed(&"sprint")
		and _stance == Stance.CROUCHED
		and _stance_transition_timer <= 0.0
	):
		_request_stance(Stance.STANDING)
	var previous_stamina := _stamina
	var wants_to_sprint := (
		Input.is_action_pressed(&"sprint")
		and input_vector.length_squared() > 0.01
		and _stance == Stance.STANDING
		and _stance_transition_timer <= 0.0
		and _jump_phase == JumpPhase.IDLE
	)
	var is_sprinting := wants_to_sprint and not _is_exhausted and _stamina > 0.0

	if is_sprinting:
		_stamina = maxf(0.0, _stamina - stamina_drain_per_second * delta)
		if _stamina <= 0.0:
			_is_exhausted = true
			is_sprinting = false
	else:
		_stamina = minf(max_stamina, _stamina + stamina_recovery_per_second * delta)
		if _is_exhausted and _stamina >= exhausted_recovery_threshold:
			_is_exhausted = false

	var current_speed := move_speed
	if is_sprinting:
		current_speed = sprint_speed
	elif _stance == Stance.CROUCHED:
		current_speed = crouch_speed
	elif _stance == Stance.PRONE:
		current_speed = prone_speed
	if _stance_transition_timer > 0.0:
		current_speed *= 0.4
	if _jump_phase == JumpPhase.WINDUP:
		current_speed *= 0.45
	var move_direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var target_velocity := move_direction * current_speed

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	move_and_slide()
	_update_interaction_prompt()
	_update_camera_motion(delta, input_vector, is_sprinting)
	_update_stamina_ui(delta, previous_stamina, is_sprinting)
	camera.fov = lerpf(camera.fov, 80.0 if is_sprinting else 75.0, minf(delta * 5.0, 1.0))


func _update_camera_motion(delta: float, input_vector: Vector2, is_sprinting: bool) -> void:
	var is_walking := is_on_floor() and input_vector.length_squared() > 0.01
	var target_position := _camera_rest_position
	var bob_roll := 0.0
	var hand_bob_position := Vector3.ZERO
	var hand_bob_roll := 0.0

	if is_walking:
		var bob_multiplier := sprint_bob_multiplier if is_sprinting else 1.0
		var hand_bob_multiplier := 1.15 if is_sprinting else 1.0
		_bob_phase += delta * bob_frequency * bob_multiplier
		target_position += Vector3(
			cos(_bob_phase * 0.5) * bob_horizontal_amount * bob_multiplier,
			(absf(sin(_bob_phase)) - 0.5) * bob_vertical_amount * bob_multiplier,
			0.0
		)
		bob_roll = sin(_bob_phase * 0.5) * deg_to_rad(bob_roll_degrees) * bob_multiplier
		hand_bob_position = Vector3(
			-cos(_bob_phase * 0.5) * bob_horizontal_amount * hand_bob_multiplier * 1.2,
			-(absf(sin(_bob_phase)) - 0.5) * bob_vertical_amount * hand_bob_multiplier,
			0.0
		)
		hand_bob_roll = -sin(_bob_phase * 0.5) * deg_to_rad(bob_roll_degrees) * hand_bob_multiplier

	var lean_input := Input.get_axis(&"lean_left", &"lean_right")
	_lean_amount = move_toward(_lean_amount, lean_input, lean_speed * delta)
	target_position.x += _lean_amount * lean_distance
	var target_roll := bob_roll - _lean_amount * deg_to_rad(lean_angle_degrees)

	camera.position = camera.position.lerp(target_position, minf(delta * 13.0, 1.0))
	camera.rotation.z = lerpf(camera.rotation.z, target_roll, minf(delta * 11.0, 1.0))

	if not Input.is_key_pressed(KEY_ALT):
		_is_aiming_hand = false
		_hand_yaw = lerpf(_hand_yaw, 0.0, minf(delta * hand_return_speed, 1.0))
		_hand_pitch = lerpf(_hand_pitch, 0.0, minf(delta * hand_return_speed, 1.0))
	hand_rig.position = hand_rig.position.lerp(hand_bob_position, minf(delta * 14.0, 1.0))
	var left_vertical_bob := Vector3(0.0, -hand_bob_position.y * 0.72, 0.0)
	left_hand_rig.position = left_hand_rig.position.lerp(left_vertical_bob, minf(delta * 14.0, 1.0))
	var target_hand_rotation := Vector3(_hand_pitch, _hand_yaw, hand_bob_roll)
	hand_rig.rotation = hand_rig.rotation.lerp(target_hand_rotation, minf(delta * 12.0, 1.0))
	left_hand_rig.rotation.z = lerpf(left_hand_rig.rotation.z, 0.0, minf(delta * 12.0, 1.0))


func _toggle_flashlight_holster() -> void:
	_flashlight_holstered = not _flashlight_holstered
	if _flashlight_holstered:
		_flashlight_was_on = flashlight.visible
		flashlight.visible = false
		hand_rig.visible = false
	else:
		hand_rig.visible = true
		flashlight.visible = _flashlight_was_on


func _get_interactable() -> Node:
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return null
	var collider := interaction_ray.get_collider() as Node
	if collider != null and collider.has_method(&"interact"):
		return collider
	return null


func _try_interact(pressed_key: Key) -> bool:
	var target := _get_interactable()
	if target == null:
		return false
	if target.has_method(&"get_interaction_key") and target.get_interaction_key() != pressed_key:
		return false
	var picked_up: bool = target.interact(self)
	if picked_up:
		interaction_prompt.hide()
	return picked_up


func _update_interaction_prompt() -> void:
	var target := _get_interactable()
	interaction_prompt.visible = target != null
	if target != null:
		interaction_prompt.text = target.get_interaction_text(self)


func pick_up_item(item_type: StringName) -> bool:
	if not _held_item.is_empty() or item_type not in [&"can", &"bottle"]:
		return false
	_held_item = item_type
	left_hand.visible = true
	var held_visual := held_can if item_type == &"can" else held_bottle
	held_visual.visible = true
	held_visual.scale = Vector3.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(held_visual, "scale", Vector3.ONE, 0.2)
	return true


func pick_up_can() -> bool:
	return pick_up_item(&"can")


func is_holding_can() -> bool:
	return _held_item == &"can"


func is_holding_item() -> bool:
	return not _held_item.is_empty()


func _throw_held_item() -> void:
	if _held_item.is_empty():
		return
	var thrown_scene: PackedScene = ThrownCanScene if _held_item == &"can" else ThrownBottleScene
	_held_item = &""
	held_can.visible = false
	held_bottle.visible = false
	left_hand.visible = false
	var thrown_item := thrown_scene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(thrown_item)
	var forward := -camera.global_basis.z.normalized()
	var left := -camera.global_basis.x.normalized()
	thrown_item.global_position = camera.global_position + forward * 0.68 + left * 0.13
	thrown_item.global_rotation = Vector3(0.15, rotation.y, -0.25)
	thrown_item.linear_velocity = velocity * 0.35
	thrown_item.apply_central_impulse(forward * can_throw_force + Vector3.UP * can_throw_upward_force)
	thrown_item.apply_torque_impulse(Vector3(0.45, 0.8, -0.55))

func _request_stance(target_stance: Stance) -> void:
	if _stance_transition_timer > 0.0 or target_stance == _stance:
		return
	if not _try_spend_stamina(_get_stance_stamina_cost(target_stance)):
		return
	_pending_stance = target_stance
	_stance_transition_duration = prone_transition_time if (
		target_stance == Stance.PRONE or _stance == Stance.PRONE
	) else crouch_transition_time
	_stance_transition_timer = _stance_transition_duration
	_stance_transition_elapsed = 0.0
	var capsule := collision_shape.shape as CapsuleShape3D
	_stance_start_values = Vector3(head.position.y, capsule.height, collision_shape.position.y)
	_stance_target_values = _get_stance_values(target_stance)


func _update_stance_transition(delta: float) -> void:
	if _stance_transition_timer <= 0.0:
		return
	_stance_transition_elapsed += delta
	_stance_transition_timer = maxf(0.0, _stance_transition_duration - _stance_transition_elapsed)
	var progress := clampf(_stance_transition_elapsed / _stance_transition_duration, 0.0, 1.0)
	var eased_progress := progress * progress * (3.0 - 2.0 * progress)
	var capsule := collision_shape.shape as CapsuleShape3D
	head.position.y = lerpf(_stance_start_values.x, _stance_target_values.x, eased_progress)
	capsule.height = lerpf(_stance_start_values.y, _stance_target_values.y, eased_progress)
	collision_shape.position.y = lerpf(_stance_start_values.z, _stance_target_values.z, eased_progress)
	if progress >= 1.0:
		_stance = _pending_stance


func _get_stance_values(target_stance: Stance) -> Vector3:
	match target_stance:
		Stance.STANDING:
			return Vector3(0.65, 1.8, 0.0)
		Stance.CROUCHED:
			return Vector3(0.17, 1.2, -0.3)
		Stance.PRONE:
			return Vector3(-0.36, 0.65, -0.575)
	return Vector3(0.65, 1.8, 0.0)


func _request_jump() -> void:
	if (
		_jump_phase != JumpPhase.IDLE
		or not is_on_floor()
		or _stance != Stance.STANDING
		or _stance_transition_timer > 0.0
	):
		return
	if not _try_spend_stamina(jump_stamina_cost):
		return
	_jump_phase = JumpPhase.WINDUP
	_jump_timer = 0.0
	_jump_start_head_y = head.position.y


func _update_jump(delta: float) -> void:
	if _jump_phase == JumpPhase.IDLE:
		return

	_jump_timer += delta
	if _jump_phase == JumpPhase.WINDUP:
		var windup_progress := clampf(_jump_timer / jump_windup_time, 0.0, 1.0)
		var eased_windup := windup_progress * windup_progress * (3.0 - 2.0 * windup_progress)
		head.position.y = lerpf(_jump_start_head_y, 0.51, eased_windup)
		if windup_progress >= 1.0:
			velocity.y = jump_velocity
			_jump_phase = JumpPhase.RECOVERING
			_jump_timer = 0.0
			_jump_start_head_y = head.position.y
	elif _jump_phase == JumpPhase.RECOVERING:
		var recovery_progress := clampf(_jump_timer / jump_recovery_time, 0.0, 1.0)
		var eased_recovery := recovery_progress * recovery_progress * (3.0 - 2.0 * recovery_progress)
		head.position.y = lerpf(_jump_start_head_y, 0.65, eased_recovery)
		if recovery_progress >= 1.0:
			head.position.y = 0.65
			_jump_phase = JumpPhase.IDLE


func _get_stance_stamina_cost(target_stance: Stance) -> float:
	if target_stance == Stance.PRONE:
		return prone_stamina_cost
	if target_stance == Stance.CROUCHED:
		return rise_stamina_cost if _stance == Stance.PRONE else crouch_stamina_cost
	if _stance == Stance.PRONE:
		return rise_from_prone_stamina_cost
	return rise_stamina_cost


func _try_spend_stamina(cost: float) -> bool:
	if _stamina < cost:
		return false
	_stamina = maxf(0.0, _stamina - cost)
	if _stamina <= 0.0:
		_is_exhausted = true
	return true


func _update_stamina_ui(delta: float, previous_stamina: float, is_sprinting: bool) -> void:
	_ui_time += delta
	stamina_bar.value = _stamina
	var stamina_ratio := _stamina / max_stamina
	var danger_amount := clampf((0.3 - stamina_ratio) / 0.3, 0.0, 1.0)
	_stamina_fill_style.bg_color = Color(1.0, 1.0, 1.0, 0.8).lerp(
		Color(1.0, 0.06, 0.045, 0.8), danger_amount
	)

	if previous_stamina < max_stamina and is_equal_approx(_stamina, max_stamina):
		_full_stamina_flash_timer = 0.65

	var target_alpha := 0.0
	if stamina_ratio <= 0.3:
		# The lower the stamina, the stronger the warning pulse.
		var pulse := 0.58 + absf(sin(_ui_time * 11.0)) * 0.42
		target_alpha = lerpf(1.0, pulse, danger_amount)
	elif is_sprinting or stamina_ratio < 0.999:
		target_alpha = 1.0
	elif _full_stamina_flash_timer > 0.0:
		_full_stamina_flash_timer = maxf(0.0, _full_stamina_flash_timer - delta)
		target_alpha = 0.45 + absf(sin(_ui_time * 15.0)) * 0.55

	stamina_bar.modulate.a = lerpf(stamina_bar.modulate.a, target_alpha, minf(delta * 10.0, 1.0))
