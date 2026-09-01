extends CharacterBody3D

@export var move_speed := 1.4
@export var sprint_speed := 4.8
@export var crouch_speed := 1.55
@export var prone_speed := 0.8
@export var acceleration := 10.0
@export var mouse_sensitivity := 0.0022
@export var zoom_min_fov := 35.0
@export var zoom_max_fov := 95.0
@export var zoom_step := 5.0
@export var zoom_smoothing := 9.0
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
@onready var right_hand_rig: Node3D = $Head/Camera3D/RightHandRig
@onready var right_hand: MeshInstance3D = $Head/Camera3D/RightHandRig/RightHand
@onready var held_can: Node3D = $Head/Camera3D/RightHandRig/HeldCan
@onready var held_bottle: Node3D = $Head/Camera3D/RightHandRig/HeldBottle
@onready var held_plunger: Node3D = $Head/Camera3D/RightHandRig/HeldPlunger
@onready var held_crowbar: Node3D = $Head/Camera3D/RightHandRig/HeldCrowbar
@onready var held_note: Node3D = $Head/Camera3D/RightHandRig/HeldNote
@onready var held_recipe_book: Node3D = $Head/Camera3D/RightHandRig/HeldRecipeBook
@onready var held_recipe_book_closed: Node3D = $Head/Camera3D/RightHandRig/HeldRecipeBookClosed
@onready var flashlight: SpotLight3D = $Head/Camera3D/HandRig/Flashlight
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var stamina_bar: ProgressBar = $StaminaUI/StaminaBar
@onready var interaction_prompt: Label = $InteractionUI/InteractionPrompt
@onready var note_controls_prompt: Label = $InteractionUI/NoteControlsPrompt
@onready var inventory_slots_ui: HBoxContainer = $InventoryUI/InventorySlots
@onready var inventory_panels: Array[PanelContainer] = [
	$InventoryUI/InventorySlots/Slot1,
	$InventoryUI/InventorySlots/Slot2,
	$InventoryUI/InventorySlots/Slot3,
]
@onready var inventory_labels: Array[Label] = [
	$InventoryUI/InventorySlots/Slot1/Content/Label,
	$InventoryUI/InventorySlots/Slot2/Label,
	$InventoryUI/InventorySlots/Slot3/Label,
]
@onready var inventory_flashlight_icon: TextureRect = $InventoryUI/InventorySlots/Slot1/Content/FlashlightIcon
@onready var holster_sound: AudioStreamPlayer = $HolsterSound
@onready var switch_sound: AudioStreamPlayer = $SwitchSound
@onready var flashlight_click_sound: AudioStreamPlayer = $FlashlightClickSound
@onready var footstep_sound: AudioStreamPlayer = $FootstepSound

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
var _jump_start_head_y := 0.9
var _held_item: StringName = &""
var _inventory_slots: Array[StringName] = [&"flashlight", &"", &""]
var _inventory_item_data: Array[Dictionary] = [{}, {}, {}]
var _selected_inventory_slot := 0
var _note_reading := false
var _held_note_rest_transform := Transform3D.IDENTITY
var _note_read_tween: Tween
var _recipe_book_reading := false
var _held_recipe_book_rest_transform := Transform3D.IDENTITY
var _recipe_book_read_tween: Tween
var _queued_recipe_page_direction := 0
var _inventory_ui_tween: Tween
var _key_inventory: Dictionary = {}
var _tool_inventory: Dictionary = {}
@export_category("Debug")
@export var debug_all_keys := true
var _flashlight_holstered := true
var _flashlight_was_on := true
var _flashlight_available := true
var _zoom_fov_target := 95.0
var _last_footstep_beat := -1
var _zoom_segments: Array[ColorRect] = []
var _monster_hits := 0
var _monster_hit_cooldown := 0.0
var _monster_restart_pending := false
var _skill_check_active := false
var _walker_controller: Node3D
var _walker_flashlight_was_drawn := false
var _ladder_controller: Node3D
var _freezer_controller: Node3D
var _freezer_previous_stance := Stance.STANDING

const ZOOM_SEGMENT_ON := Color(0.86, 0.9, 0.83, 0.92)
const ZOOM_SEGMENT_OFF := Color(0.20, 0.23, 0.20, 0.42)

const ThrownCanScene := preload("res://thrown_can.tscn")
const ThrownBottleScene := preload("res://thrown_bottle.tscn")
const DroppedFlashlightScene := preload("res://dropped_flashlight.tscn")
const DroppedNoteScene := preload("res://dropped_note.tscn")
const DroppedRecipeBookScene := preload("res://dropped_recipe_book.tscn")
const PlungerPickupScene := preload("res://house_props/toilet_plunger.tscn")
const CrowbarPickupScene := preload("res://house_props/crowbar_pickup.tscn")
const GameplaySounds := preload("res://sounds/gameplay_sound_factory.gd")
const INVENTORY_ITEM_NAMES := {
	&"can": "LATA",
	&"bottle": "BOTELLA",
	&"plunger": "DESATASCADOR",
	&"crowbar": "PALANCA",
	&"note": "NOTA",
	&"recipe_book": "RECETARIO",
}


func _ready() -> void:
	add_to_group(&"player")
	for child in $ZoomUI/ZoomMeter/ZoomSegments.get_children():
		if child is ColorRect:
			_zoom_segments.append(child as ColorRect)
	hand_rig.visible = false
	_held_note_rest_transform = held_note.transform
	_held_recipe_book_rest_transform = held_recipe_book.transform
	flashlight.visible = false
	_camera_rest_position = camera.position
	_stamina = max_stamina
	stamina_bar.max_value = max_stamina
	stamina_bar.value = _stamina
	_stamina_fill_style = stamina_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	stamina_bar.add_theme_stylebox_override("fill", _stamina_fill_style)
	camera.make_current()
	camera.fov = zoom_max_fov
	_zoom_fov_target = zoom_max_fov
	_update_zoom_meter()
	_update_inventory_ui()
	inventory_slots_ui.visible = false
	inventory_slots_ui.modulate.a = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	holster_sound.stream = GameplaySounds.make_switch_click()
	footstep_sound.stream = GameplaySounds.make_footstep()
	if held_recipe_book.has_signal(&"page_turn_finished"):
		held_recipe_book.connect(&"page_turn_finished", Callable(self, &"_on_recipe_page_turn_finished"))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var pressed_key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		if _skill_check_active and pressed_key in [KEY_F, KEY_SPACE]:
			return
		if pressed_key == KEY_R:
			get_viewport().set_input_as_handled()
			get_tree().call_deferred(&"reload_current_scene")
			return
		if is_instance_valid(_freezer_controller):
			if pressed_key == KEY_F:
				_freezer_controller.call(&"request_exit", self)
				get_viewport().set_input_as_handled()
				return
			if pressed_key in [KEY_CTRL, KEY_X]:
				get_viewport().set_input_as_handled()
				return
		if _held_item == &"recipe_book" and _recipe_book_reading and pressed_key in [KEY_Q, KEY_E]:
			_turn_recipe_book_pages(-1 if pressed_key == KEY_Q else 1)
			get_viewport().set_input_as_handled()
			return
		if pressed_key in [KEY_1, KEY_2, KEY_3]:
			_select_inventory_slot(pressed_key - KEY_1)
			_show_inventory_temporarily()
			get_viewport().set_input_as_handled()
			return
		if pressed_key == KEY_G and not _skill_check_active:
			_drop_selected_inventory_item()
			get_viewport().set_input_as_handled()
			return
		if pressed_key == KEY_F and is_instance_valid(_ladder_controller):
			_ladder_controller.call(&"stop_climbing", false)
			get_viewport().set_input_as_handled()
			return
		if pressed_key == KEY_F and is_instance_valid(_walker_controller):
			_walker_controller.call(&"stop_moving")
			get_viewport().set_input_as_handled()
			return
		if pressed_key == KEY_F and _try_interact(pressed_key):
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
			if is_instance_valid(_ladder_controller):
				_ladder_controller.call(&"stop_climbing", true)
				get_viewport().set_input_as_handled()
				return
			_request_jump()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion := event as InputEventMouseMotion
		_is_aiming_hand = Input.is_key_pressed(KEY_ALT)
		var zoom_sensitivity_scale := clampf(camera.fov / 75.0, 0.42, 1.2)
		# Normal camera look remains active even while Alt controls the hand.
		rotate_y(-mouse_motion.screen_relative.x * mouse_sensitivity * zoom_sensitivity_scale)
		_look_pitch = clampf(
			_look_pitch - mouse_motion.screen_relative.y * mouse_sensitivity * zoom_sensitivity_scale,
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
		if mouse_button.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var wheel_amount := maxf(mouse_button.factor, 1.0) * zoom_step
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_fov_target = clampf(_zoom_fov_target - wheel_amount, zoom_min_fov, zoom_max_fov)
				get_viewport().set_input_as_handled()
				return
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_fov_target = clampf(_zoom_fov_target + wheel_amount, zoom_min_fov, zoom_max_fov)
				get_viewport().set_input_as_handled()
				return
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT and _held_item == &"note" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_set_note_reading(not _note_reading)
			get_viewport().set_input_as_handled()
			return
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT and _held_item == &"recipe_book" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_set_recipe_book_reading(not _recipe_book_reading)
			get_viewport().set_input_as_handled()
			return
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT and _flashlight_available and not _flashlight_holstered and _selected_inventory_slot == 0:
			flashlight.visible = not flashlight.visible
			flashlight_click_sound.pitch_scale = randf_range(0.98, 1.02)
			flashlight_click_sound.play()
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
	_monster_hit_cooldown = maxf(0.0, _monster_hit_cooldown - delta)
	_update_stance_transition(delta)
	head.rotation.x = _look_pitch
	head.rotation.y = 0.0
	if is_instance_valid(_freezer_controller):
		velocity = Vector3.ZERO
		_update_interaction_prompt()
		_update_camera_motion(delta, Vector2.ZERO, false)
		var freezer_zoom_weight := 1.0 - exp(-zoom_smoothing * delta)
		camera.fov = lerpf(camera.fov, _zoom_fov_target, freezer_zoom_weight)
		_update_zoom_meter()
		return
	if is_instance_valid(_ladder_controller):
		var ladder_input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		velocity = Vector3.ZERO
		_ladder_controller.call(&"drive_from_player", ladder_input, delta)
		_update_interaction_prompt()
		_update_camera_motion(delta, Vector2.ZERO, false)
		_update_footsteps(delta, Vector2.ZERO, false)
		var previous_ladder_stamina := _stamina
		_stamina = minf(max_stamina, _stamina + stamina_recovery_per_second * delta)
		_update_stamina_ui(delta, previous_ladder_stamina, false)
		var ladder_zoom_weight := 1.0 - exp(-zoom_smoothing * delta)
		camera.fov = lerpf(camera.fov, _zoom_fov_target, ladder_zoom_weight)
		_update_zoom_meter()
		return
	if is_instance_valid(_walker_controller):
		var walker_input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		velocity = Vector3.ZERO
		_walker_controller.call(&"drive_from_player", walker_input, delta)
		_update_interaction_prompt()
		_update_camera_motion(delta, walker_input, false)
		_update_footsteps(delta, Vector2.ZERO, false)
		var previous_walker_stamina := _stamina
		_stamina = minf(max_stamina, _stamina + stamina_recovery_per_second * delta)
		_update_stamina_ui(delta, previous_walker_stamina, false)
		var walker_zoom_weight := 1.0 - exp(-zoom_smoothing * delta)
		camera.fov = lerpf(camera.fov, _zoom_fov_target, walker_zoom_weight)
		_update_zoom_meter()
		return

	if not is_on_floor():
		var gravity_multiplier := upward_gravity_multiplier if velocity.y > 0.0 else falling_gravity_multiplier
		velocity.y -= _gravity * gravity_multiplier * delta
	else:
		velocity.y = 0.0
	_update_jump(delta)

	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_update_auto_prone(input_vector)
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
	_update_footsteps(delta, input_vector, is_sprinting)
	_update_stamina_ui(delta, previous_stamina, is_sprinting)
	var zoom_ratio := inverse_lerp(zoom_min_fov, zoom_max_fov, _zoom_fov_target)
	var sprint_fov_bonus := lerpf(1.0, 5.0, zoom_ratio) if is_sprinting else 0.0
	var desired_fov := _zoom_fov_target + sprint_fov_bonus
	var zoom_weight := 1.0 - exp(-zoom_smoothing * delta)
	camera.fov = lerpf(camera.fov, desired_fov, zoom_weight)
	_update_zoom_meter()


func _update_zoom_meter() -> void:
	var zoom_amount := clampf(
		inverse_lerp(zoom_max_fov, zoom_min_fov, camera.fov) * 100.0,
		0.0,
		100.0
	)
	var lit_segments := roundi(zoom_amount * float(_zoom_segments.size()) / 100.0)
	for index in _zoom_segments.size():
		_zoom_segments[index].color = ZOOM_SEGMENT_ON if index < lit_segments else ZOOM_SEGMENT_OFF
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

	var lock_lean := _recipe_book_reading or is_instance_valid(_freezer_controller)
	var lean_input := 0.0 if lock_lean else Input.get_axis(&"lean_left", &"lean_right")
	_lean_amount = 0.0 if lock_lean else move_toward(_lean_amount, lean_input, lean_speed * delta)
	target_position.x += _lean_amount * lean_distance
	var target_roll := bob_roll - _lean_amount * deg_to_rad(lean_angle_degrees)

	camera.position = camera.position.lerp(target_position, minf(delta * 13.0, 1.0))
	camera.rotation.z = lerpf(camera.rotation.z, target_roll, minf(delta * 11.0, 1.0))

	if not Input.is_key_pressed(KEY_ALT):
		_is_aiming_hand = false
		_hand_yaw = lerpf(_hand_yaw, 0.0, minf(delta * hand_return_speed, 1.0))
		_hand_pitch = lerpf(_hand_pitch, 0.0, minf(delta * hand_return_speed, 1.0))
	hand_rig.position = hand_rig.position.lerp(hand_bob_position, minf(delta * 14.0, 1.0))
	var right_vertical_bob := Vector3(0.0, -hand_bob_position.y * 0.72, 0.0)
	right_hand_rig.position = right_hand_rig.position.lerp(right_vertical_bob, minf(delta * 14.0, 1.0))
	var target_hand_rotation := Vector3(_hand_pitch, _hand_yaw, hand_bob_roll)
	hand_rig.rotation = hand_rig.rotation.lerp(target_hand_rotation, minf(delta * 12.0, 1.0))
	right_hand_rig.rotation.z = lerpf(right_hand_rig.rotation.z, 0.0, minf(delta * 12.0, 1.0))


func _select_inventory_slot(slot_index: int) -> void:
	if slot_index == 0 and _selected_inventory_slot == 0 and not _flashlight_holstered:
		_flashlight_was_on = flashlight.visible
		flashlight.visible = false
		hand_rig.visible = false
		_flashlight_holstered = true
		_update_inventory_ui()
	else:
		_equip_inventory_slot(slot_index)
	if slot_index == 0 and _flashlight_available:
		holster_sound.pitch_scale = randf_range(0.97, 1.03)
		holster_sound.play()


func _inventory_item_name(item_type: StringName) -> String:
	return INVENTORY_ITEM_NAMES.get(item_type, "VACIO") as String


func _update_inventory_ui() -> void:
	for index in range(_inventory_slots.size()):
		inventory_labels[index].text = str(index + 1) if index == 0 else "%d\n%s" % [index + 1, _inventory_item_name(_inventory_slots[index])]
		inventory_panels[index].modulate = Color(1.0, 1.0, 1.0, 0.78 if index == _selected_inventory_slot else 0.32)
	inventory_flashlight_icon.visible = _inventory_slots[0] == &"flashlight"


func _show_inventory_temporarily() -> void:
	if is_instance_valid(_inventory_ui_tween):
		_inventory_ui_tween.kill()
	inventory_slots_ui.visible = true
	_inventory_ui_tween = create_tween()
	_inventory_ui_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_inventory_ui_tween.tween_property(inventory_slots_ui, "modulate:a", 1.0, 0.18)
	_inventory_ui_tween.tween_interval(2.15)
	_inventory_ui_tween.set_ease(Tween.EASE_IN)
	_inventory_ui_tween.tween_property(inventory_slots_ui, "modulate:a", 0.0, 0.55)
	_inventory_ui_tween.tween_callback(func() -> void: inventory_slots_ui.visible = false)


func _hide_all_held_visuals() -> void:
	_set_note_reading(false, true)
	_set_recipe_book_reading(false, true)
	held_can.visible = false
	held_bottle.visible = false
	held_plunger.visible = false
	held_crowbar.visible = false
	held_note.visible = false
	held_recipe_book.visible = false
	held_recipe_book_closed.visible = false
	right_hand.visible = false


func _set_note_reading(active: bool, immediate := false) -> void:
	if active and _held_item != &"note":
		return
	_note_reading = active
	if is_instance_valid(_note_read_tween):
		_note_read_tween.kill()
	var target_position := Vector3(0.0, -0.005, -0.24) if active else _held_note_rest_transform.origin
	var target_rotation := Vector3.ZERO if active else _held_note_rest_transform.basis.get_euler()
	var target_scale := Vector3.ONE * 1.28 if active else _held_note_rest_transform.basis.get_scale()
	if immediate:
		held_note.position = target_position
		held_note.rotation = target_rotation
		held_note.scale = target_scale
	else:
		_note_read_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_note_read_tween.set_parallel(true)
		_note_read_tween.tween_property(held_note, "position", target_position, 0.2)
		_note_read_tween.tween_property(held_note, "rotation", target_rotation, 0.2)
		_note_read_tween.tween_property(held_note, "scale", target_scale, 0.2)
	right_hand.visible = not active and _held_item == &"note"


func _set_recipe_book_reading(active: bool, immediate := false) -> void:
	if active and _held_item != &"recipe_book":
		return
	_recipe_book_reading = active
	if not active:
		_queued_recipe_page_direction = 0
	if is_instance_valid(_recipe_book_read_tween):
		_recipe_book_read_tween.kill()
	var target_position := Vector3(0.0, -0.09, -0.46) if active else _held_recipe_book_rest_transform.origin
	var target_rotation := _held_recipe_book_rest_transform.basis.get_euler()
	var target_scale := Vector3.ONE * 0.9 if active else _held_recipe_book_rest_transform.basis.get_scale()
	if immediate:
		held_recipe_book.position = target_position
		held_recipe_book.rotation = target_rotation
		held_recipe_book.scale = target_scale
		held_recipe_book.visible = active and _held_item == &"recipe_book"
		held_recipe_book_closed.visible = not active and _held_item == &"recipe_book"
	else:
		if active:
			held_recipe_book.visible = true
			held_recipe_book_closed.visible = false
			held_recipe_book.position = target_position
			held_recipe_book.rotation = target_rotation
			held_recipe_book.scale = Vector3(0.06, target_scale.y, target_scale.z)
		_recipe_book_read_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_recipe_book_read_tween.set_parallel(true)
		_recipe_book_read_tween.tween_property(held_recipe_book, "position", target_position, 0.22)
		_recipe_book_read_tween.tween_property(held_recipe_book, "rotation", target_rotation, 0.22)
		_recipe_book_read_tween.tween_property(held_recipe_book, "scale", target_scale if active else Vector3(0.06, target_scale.y, target_scale.z), 0.22)
		if not active:
			_recipe_book_read_tween.chain().tween_callback(func() -> void:
				held_recipe_book.visible = false
				held_recipe_book.scale = target_scale
				held_recipe_book_closed.visible = _held_item == &"recipe_book"
				right_hand.visible = _held_item == &"recipe_book"
			)
	right_hand.visible = immediate and not active and _held_item == &"recipe_book"


func _equip_inventory_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _inventory_slots.size():
		return false
	var item_type := _inventory_slots[slot_index]
	if _selected_inventory_slot == 0 and not _flashlight_holstered:
		_flashlight_was_on = flashlight.visible
	flashlight.visible = false
	hand_rig.visible = false
	_hide_all_held_visuals()
	_held_item = &""
	_selected_inventory_slot = slot_index
	if item_type.is_empty():
		_flashlight_holstered = true
	elif item_type == &"flashlight":
		if not _flashlight_available:
			_update_inventory_ui()
			return false
		_flashlight_holstered = false
		hand_rig.visible = true
		flashlight.visible = _flashlight_was_on
	else:
		_flashlight_holstered = true
		_held_item = item_type
		right_hand.visible = true
		match item_type:
			&"can": held_can.visible = true
			&"bottle": held_bottle.visible = true
			&"plunger": held_plunger.visible = true
			&"crowbar": held_crowbar.visible = true
			&"note":
				held_note.visible = true
				_configure_held_note(_inventory_item_data[slot_index])
			&"recipe_book":
				held_recipe_book.visible = false
				held_recipe_book_closed.visible = true
				_configure_held_recipe_book(_inventory_item_data[slot_index])
	_update_inventory_ui()
	return true


func _find_empty_inventory_slot() -> int:
	for index in range(1, _inventory_slots.size()):
		if _inventory_slots[index].is_empty():
			return index
	return -1


func can_store_inventory_item() -> bool:
	return _find_empty_inventory_slot() >= 0


func _store_inventory_item(item_type: StringName, item_data: Dictionary = {}) -> bool:
	var slot_index := _find_empty_inventory_slot()
	if slot_index < 0:
		return false
	_inventory_slots[slot_index] = item_type
	_inventory_item_data[slot_index] = item_data.duplicate(true)
	return _equip_inventory_slot(slot_index)


func _clear_inventory_item(item_type: StringName) -> bool:
	if (
		_selected_inventory_slot > 0
		and _selected_inventory_slot < _inventory_slots.size()
		and _inventory_slots[_selected_inventory_slot] == item_type
	):
		_inventory_slots[_selected_inventory_slot] = &""
		_inventory_item_data[_selected_inventory_slot] = {}
		_update_inventory_ui()
		return true
	for index in range(1, _inventory_slots.size()):
		if _inventory_slots[index] == item_type:
			_inventory_slots[index] = &""
			_inventory_item_data[index] = {}
			_update_inventory_ui()
			return true
	return false


func _return_to_flashlight_slot() -> void:
	if _flashlight_available and _inventory_slots[0] == &"flashlight":
		_selected_inventory_slot = 0
		_held_item = &""
		_hide_all_held_visuals()
		flashlight.visible = false
		hand_rig.visible = false
		_flashlight_holstered = true
		_update_inventory_ui()
	else:
		_held_item = &""
		_hide_all_held_visuals()
		_update_inventory_ui()


func play_switch_sound() -> void:
	switch_sound.pitch_scale = randf_range(0.97, 1.03)
	switch_sound.play()


func set_skill_check_active(active: bool) -> void:
	_skill_check_active = active


func set_plunger_minigame_pose(active: bool) -> void:
	if _held_item != &"plunger":
		return
	held_plunger.visible = not active
	right_hand.visible = not active


func set_crowbar_minigame_pose(active: bool) -> void:
	if _held_item != &"crowbar":
		return
	held_crowbar.visible = not active
	right_hand.visible = not active


func _update_footsteps(_delta: float, input_vector: Vector2, is_sprinting: bool) -> void:
	var moving := is_on_floor() and input_vector.length_squared() > 0.01 and Vector2(velocity.x, velocity.z).length() > 0.18
	if not moving or _jump_phase != JumpPhase.IDLE or _stance_transition_timer > 0.0:
		_last_footstep_beat = int(floor(_bob_phase / PI))
		return

	# El minimo vertical del balanceo ocurre cada PI radianes: ahi apoya un pie.
	var current_beat := int(floor(_bob_phase / PI))
	if current_beat == _last_footstep_beat:
		return
	_last_footstep_beat = current_beat

	var volume := -25.0
	if is_sprinting:
		volume = -20.5
	elif _stance == Stance.CROUCHED:
		volume = -29.0
	elif _stance == Stance.PRONE:
		volume = -32.0
	footstep_sound.volume_db = volume + randf_range(-1.2, 0.8)
	footstep_sound.pitch_scale = randf_range(0.88, 1.12)
	footstep_sound.play()


func _get_interactable() -> Node:
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return null
	var collider := interaction_ray.get_collider() as Node
	if collider != null and collider.has_method(&"interact") and _is_interactable_in_range(collider):
		return collider
	return null


func _is_interactable_in_range(target: Node) -> bool:
	if target == null or not target.has_method(&"get_interaction_distance"):
		return true
	var allowed_distance := maxf(0.0, float(target.call(&"get_interaction_distance")))
	return interaction_ray.global_position.distance_to(interaction_ray.get_collision_point()) <= allowed_distance


func _try_interact(pressed_key: Key) -> bool:
	var target := _get_interactable()
	if target == null:
		return false
	if target.has_method(&"get_interaction_key") and target.get_interaction_key() != pressed_key:
		return false
	var picked_up: bool = target.interact(self)
	if picked_up:
		if target.has_method(&"uses_switch_sound") and target.uses_switch_sound():
			play_switch_sound()
		interaction_prompt.hide()
	return picked_up


func _update_interaction_prompt() -> void:
	note_controls_prompt.visible = false
	if is_instance_valid(_freezer_controller):
		interaction_prompt.visible = true
		interaction_prompt.text = "F  SALIR DEL CONGELADOR"
		return
	if is_instance_valid(_ladder_controller):
		interaction_prompt.visible = true
		interaction_prompt.text = "F  SOLTAR ESCALERA"
		return
	if is_instance_valid(_walker_controller):
		interaction_prompt.visible = true
		interaction_prompt.text = "F  SOLTAR ANDADOR"
		return
	if _held_item == &"note":
		interaction_prompt.visible = false
		note_controls_prompt.visible = true
		note_controls_prompt.text = "G  SOLTAR NOTA    RMB  %s" % ("CERRAR" if _note_reading else "AMPLIAR")
		return
	if _held_item == &"recipe_book":
		interaction_prompt.visible = false
		note_controls_prompt.visible = true
		note_controls_prompt.text = "G  SOLTAR LIBRO    %s" % ("Q/E  PAGINAS    RMB  CERRAR" if _recipe_book_reading else "RMB  ABRIR")
		return
	var target := _get_interactable()
	interaction_prompt.visible = target != null
	if target != null:
		interaction_prompt.text = target.get_interaction_text(self)


func pick_up_item(item_type: StringName) -> bool:
	if item_type not in [&"can", &"bottle"] or not _store_inventory_item(item_type):
		return false
	var held_visual := held_can if item_type == &"can" else held_bottle
	held_visual.scale = Vector3.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(held_visual, "scale", Vector3.ONE, 0.2)
	return true


func pick_up_note(title: String, text: String, paper_color: Color, ink_color: Color) -> bool:
	var note_data := {
		"title": title,
		"text": text,
		"paper_color": paper_color,
		"ink_color": ink_color,
	}
	if not _store_inventory_item(&"note", note_data):
		return false
	held_note.scale = Vector3.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(held_note, "scale", Vector3.ONE, 0.22)
	return true


func _configure_held_note(data: Dictionary) -> void:
	if held_note.has_method(&"configure_note"):
		held_note.call(&"configure_note", data)


func pick_up_recipe_book(data: Dictionary) -> bool:
	if not _store_inventory_item(&"recipe_book", data):
		return false
	held_recipe_book.scale = Vector3.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(held_recipe_book, "scale", _held_recipe_book_rest_transform.basis.get_scale(), 0.24)
	return true


func _configure_held_recipe_book(data: Dictionary) -> void:
	if held_recipe_book.has_method(&"configure_book"):
		held_recipe_book.call(&"configure_book", data)
	if held_recipe_book_closed.has_method(&"configure_book"):
		held_recipe_book_closed.call(&"configure_book", data)


func _turn_recipe_book_pages(direction: int) -> void:
	if _held_item != &"recipe_book" or not held_recipe_book.has_method(&"turn_pages"):
		return
	if held_recipe_book.has_method(&"is_page_turning") and bool(held_recipe_book.call(&"is_page_turning")):
		_queued_recipe_page_direction = signi(direction)
		return
	var new_page_index := int(held_recipe_book.call(&"turn_pages", direction))
	if _selected_inventory_slot > 0 and _selected_inventory_slot < _inventory_item_data.size():
		_inventory_item_data[_selected_inventory_slot]["page_index"] = new_page_index


func _on_recipe_page_turn_finished() -> void:
	if _queued_recipe_page_direction != 0:
		call_deferred(&"_consume_queued_recipe_page_turn")


func _consume_queued_recipe_page_turn() -> void:
	if _queued_recipe_page_direction == 0:
		return
	var direction := _queued_recipe_page_direction
	_queued_recipe_page_direction = 0
	if _held_item == &"recipe_book" and _recipe_book_reading:
		_turn_recipe_book_pages(direction)


func pick_up_can() -> bool:
	return pick_up_item(&"can")


func is_holding_can() -> bool:
	return _held_item == &"can"


func is_holding_item() -> bool:
	return not _held_item.is_empty()


func is_holding_item_type(item_type: StringName) -> bool:
	return _held_item == item_type


func begin_moving_walker(walker: Node3D) -> bool:
	if walker == null or is_instance_valid(_walker_controller) or is_instance_valid(_ladder_controller) or not _held_item.is_empty():
		return false
	_walker_flashlight_was_drawn = _selected_inventory_slot == 0 and _flashlight_available and not _flashlight_holstered
	if _walker_flashlight_was_drawn:
		_flashlight_was_on = flashlight.visible
		flashlight.visible = false
		hand_rig.visible = false
		_flashlight_holstered = true
	_walker_controller = walker
	_jump_phase = JumpPhase.IDLE
	velocity = Vector3.ZERO
	add_collision_exception_with(walker)
	return true


func sync_to_walker(world_position: Vector3, walker_yaw: float) -> void:
	if not is_instance_valid(_walker_controller):
		return
	global_position = world_position
	rotation.y = walker_yaw
	velocity = Vector3.ZERO


func end_moving_walker(walker: Node3D) -> void:
	if walker != _walker_controller:
		return
	remove_collision_exception_with(walker)
	_walker_controller = null
	velocity = Vector3.ZERO
	if _walker_flashlight_was_drawn and _flashlight_available:
		_equip_inventory_slot(0)
	_walker_flashlight_was_drawn = false


func begin_climbing_ladder(ladder: Node3D) -> bool:
	if (
		ladder == null
		or is_instance_valid(_ladder_controller)
		or is_instance_valid(_walker_controller)
		or not _held_item.is_empty()
		or _stance != Stance.STANDING
		or _stance_transition_timer > 0.0
	):
		return false
	_ladder_controller = ladder
	_jump_phase = JumpPhase.IDLE
	velocity = Vector3.ZERO
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_collision_exception_with(ladder)
	return true


func sync_to_ladder(world_position: Vector3, ladder_yaw: float) -> void:
	if not is_instance_valid(_ladder_controller):
		return
	global_position = world_position
	rotation.y = ladder_yaw
	velocity = Vector3.ZERO


func end_climbing_ladder(ladder: Node3D, launch_velocity := Vector3.ZERO) -> void:
	if ladder != _ladder_controller:
		return
	remove_collision_exception_with(ladder)
	_ladder_controller = null
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	velocity = launch_velocity


func enter_chest_freezer(freezer: Node3D, hiding_world_position: Vector3, facing_direction: Vector3) -> bool:
	if (
		freezer == null
		or is_instance_valid(_freezer_controller)
		or is_instance_valid(_ladder_controller)
		or is_instance_valid(_walker_controller)
		or _skill_check_active
	):
		return false
	_freezer_previous_stance = _stance
	_freezer_controller = freezer
	_jump_phase = JumpPhase.IDLE
	velocity = Vector3.ZERO
	global_position = hiding_world_position
	var flat_facing := Vector3(facing_direction.x, 0.0, facing_direction.z).normalized()
	if not flat_facing.is_zero_approx():
		look_at(global_position + flat_facing, Vector3.UP)
	_set_stance_immediate(Stance.CROUCHED)
	collision_shape.disabled = true
	_hide_all_held_visuals()
	return true


func leave_chest_freezer(exit_world_position: Vector3, facing_direction: Vector3) -> void:
	if not is_instance_valid(_freezer_controller):
		return
	global_position = exit_world_position
	var flat_facing := Vector3(facing_direction.x, 0.0, facing_direction.z).normalized()
	if not flat_facing.is_zero_approx():
		look_at(global_position + flat_facing, Vector3.UP)
	_freezer_controller = null
	collision_shape.disabled = false
	_set_stance_immediate(_freezer_previous_stance)
	velocity = Vector3.ZERO
	_equip_inventory_slot(_selected_inventory_slot)


func _set_stance_immediate(target_stance: Stance) -> void:
	var values := _get_stance_values(target_stance)
	var capsule := collision_shape.shape as CapsuleShape3D
	head.position.y = values.x
	capsule.height = values.y
	collision_shape.position.y = values.z
	_stance = target_stance
	_pending_stance = target_stance
	_stance_transition_timer = 0.0
	_stance_transition_elapsed = 0.0


func pick_up_plunger() -> bool:
	if not _store_inventory_item(&"plunger"):
		return false
	held_plunger.scale = Vector3.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(held_plunger, "scale", Vector3(0.72, 0.72, 0.72), 0.24)
	return true


func pick_up_crowbar() -> bool:
	if not _store_inventory_item(&"crowbar"):
		return false
	add_tool(&"crowbar")
	held_crowbar.scale = Vector3.ONE * 0.03
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(held_crowbar, "scale", Vector3(0.58, 0.58, 0.58), 0.24)
	return true


func consume_held_item(item_type: StringName) -> bool:
	if _held_item != item_type:
		return false
	_clear_inventory_item(item_type)
	_tool_inventory.erase(item_type)
	_held_item = &""
	if item_type == &"plunger":
		held_plunger.visible = false
	elif item_type == &"crowbar":
		held_crowbar.visible = false
	right_hand.visible = false
	_return_to_flashlight_slot()
	return true


func recover_flashlight(was_on: bool) -> bool:
	if _flashlight_available:
		return false
	_flashlight_available = true
	_flashlight_was_on = was_on
	_inventory_slots[0] = &"flashlight"
	_flashlight_holstered = true
	flashlight.visible = false
	hand_rig.visible = false
	_update_inventory_ui()
	return true


func _drop_selected_inventory_item() -> void:
	if _selected_inventory_slot < 0 or _selected_inventory_slot >= _inventory_slots.size():
		return
	var item_type := _inventory_slots[_selected_inventory_slot]
	var item_data := _inventory_item_data[_selected_inventory_slot].duplicate(true)
	if item_type.is_empty():
		return
	if item_type == &"flashlight":
		_drop_flashlight()
		return

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var forward := -camera.global_basis.z.normalized()
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = -global_basis.z.normalized()
	else:
		forward = forward.normalized()
	var drop_position := global_position + forward * 0.7 + Vector3.UP * 0.12

	if item_type == &"note":
		var dropped_note := DroppedNoteScene.instantiate() as RigidBody3D
		scene_root.add_child(dropped_note)
		if dropped_note.has_method(&"configure_note"):
			dropped_note.call(&"configure_note", item_data)
		dropped_note.global_position = camera.global_position + (-camera.global_basis.z.normalized()) * 0.62 + Vector3.DOWN * 0.12
		dropped_note.global_basis = camera.global_basis
		dropped_note.linear_velocity = velocity * 0.18 + (-camera.global_basis.z.normalized()) * 0.32 + Vector3.UP * 0.12
		dropped_note.angular_velocity = Vector3(randf_range(-0.7, 0.7), randf_range(-0.35, 0.35), randf_range(-0.9, 0.9))
	elif item_type == &"recipe_book":
		var dropped_book := DroppedRecipeBookScene.instantiate() as RigidBody3D
		scene_root.add_child(dropped_book)
		if dropped_book.has_method(&"configure_book"):
			dropped_book.call(&"configure_book", item_data)
		dropped_book.global_position = drop_position + Vector3.UP * 0.34
		dropped_book.global_rotation = Vector3(0.08, rotation.y, -0.12)
		dropped_book.linear_velocity = velocity * 0.12 + forward * 0.2
		dropped_book.angular_velocity = Vector3(randf_range(-0.4, 0.4), randf_range(-0.35, 0.35), randf_range(-0.5, 0.5))
	elif item_type in [&"can", &"bottle"]:
		var dropped_scene: PackedScene = ThrownCanScene if item_type == &"can" else ThrownBottleScene
		var dropped_item := dropped_scene.instantiate() as RigidBody3D
		scene_root.add_child(dropped_item)
		dropped_item.global_position = drop_position + Vector3.UP * 0.32
		dropped_item.global_rotation = Vector3(0.08, rotation.y, -0.18)
		dropped_item.linear_velocity = Vector3.ZERO
		dropped_item.angular_velocity = Vector3.ZERO
		if item_type == &"bottle" and dropped_item.has_method(&"set_dropped_safely"):
			dropped_item.call(&"set_dropped_safely")
	else:
		var pickup_scene: PackedScene = PlungerPickupScene if item_type == &"plunger" else CrowbarPickupScene
		var dropped_pickup := pickup_scene.instantiate() as Node3D
		scene_root.add_child(dropped_pickup)
		dropped_pickup.global_position = drop_position
		dropped_pickup.rotation = Vector3(0.0, rotation.y, 0.12 if item_type == &"crowbar" else 0.0)

	_clear_inventory_item(item_type)
	_tool_inventory.erase(item_type)
	_return_to_flashlight_slot()


func _drop_flashlight() -> void:
	if not _flashlight_available:
		return
	var was_on := flashlight.visible if not _flashlight_holstered else _flashlight_was_on
	var dropped := DroppedFlashlightScene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(dropped)
	var forward := -camera.global_basis.z.normalized()
	forward.y = 0.0
	forward = forward.normalized()
	dropped.global_position = global_position + forward * 0.32 + Vector3.UP * 0.5
	dropped.global_basis = camera.global_basis
	dropped.linear_velocity = Vector3.ZERO
	dropped.angular_velocity = Vector3.ZERO
	dropped.call(&"set_light_enabled", was_on)
	_flashlight_available = false
	_inventory_slots[0] = &""
	_flashlight_holstered = true
	_flashlight_was_on = was_on
	flashlight.visible = false
	hand_rig.visible = false
	_update_inventory_ui()


func add_key(key_id: StringName) -> bool:
	if key_id.is_empty():
		return false
	_key_inventory[key_id] = true
	return true


func has_key(key_id: StringName) -> bool:
	return debug_all_keys or (not key_id.is_empty() and _key_inventory.has(key_id))


func add_tool(tool_id: StringName) -> bool:
	if tool_id.is_empty():
		return false
	_tool_inventory[tool_id] = true
	return true


func has_tool(tool_id: StringName) -> bool:
	return not tool_id.is_empty() and _tool_inventory.has(tool_id)


func _throw_held_item() -> void:
	if _held_item.is_empty():
		return
	if _held_item not in [&"can", &"bottle"]:
		return
	var thrown_type := _held_item
	var thrown_scene: PackedScene = ThrownCanScene if thrown_type == &"can" else ThrownBottleScene
	_clear_inventory_item(thrown_type)
	_held_item = &""
	held_can.visible = false
	held_bottle.visible = false
	right_hand.visible = false
	var thrown_item := thrown_scene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(thrown_item)
	var forward := -camera.global_basis.z.normalized()
	var right := camera.global_basis.x.normalized()
	thrown_item.global_position = camera.global_position + forward * 0.68 + right * 0.13
	thrown_item.global_rotation = Vector3(0.15, rotation.y, -0.25)
	thrown_item.linear_velocity = velocity * 0.35
	thrown_item.apply_central_impulse(forward * can_throw_force + Vector3.UP * can_throw_upward_force)
	thrown_item.apply_torque_impulse(Vector3(0.45, 0.8, -0.55))
	_return_to_flashlight_slot()

func _request_stance(target_stance: Stance) -> void:
	if _stance_transition_timer > 0.0 or target_stance == _stance:
		return
	# Never expand the player's collider into a table, ceiling or other low obstacle.
	if (
		_get_stance_values(target_stance).y > _get_stance_values(_stance).y
		and not _stance_fits_at(target_stance, Vector3.ZERO)
	):
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


func _update_auto_prone(input_vector: Vector2) -> void:
	if (
		_stance != Stance.CROUCHED
		or _stance_transition_timer > 0.0
		or not Input.is_key_pressed(KEY_CTRL)
		or input_vector.length_squared() <= 0.01
	):
		return
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()
	var world_direction := (transform.basis * local_direction).normalized()
	var look_ahead := world_direction * 0.52
	if (
		not _stance_fits_at(Stance.CROUCHED, look_ahead)
		and _stance_fits_at(Stance.PRONE, look_ahead)
	):
		_request_stance(Stance.PRONE)


func _stance_fits_at(target_stance: Stance, world_offset: Vector3) -> bool:
	var values := _get_stance_values(target_stance)
	var current_capsule := collision_shape.shape as CapsuleShape3D
	var test_capsule := CapsuleShape3D.new()
	test_capsule.radius = current_capsule.radius
	test_capsule.height = values.y
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = test_capsule
	query.transform = Transform3D(global_basis, global_position + world_offset + global_basis * Vector3(0.0, values.z, 0.0))
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


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
			return Vector3(0.9, 2.1, 0.15)
		Stance.CROUCHED:
			return Vector3(0.17, 1.2, -0.3)
		Stance.PRONE:
			return Vector3(-0.36, 0.65, -0.575)
	return Vector3(0.9, 2.1, 0.15)


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
		head.position.y = lerpf(_jump_start_head_y, 0.9, eased_recovery)
		if recovery_progress >= 1.0:
			head.position.y = 0.9
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


func receive_monster_attack(attacker: Node3D) -> void:
	if _monster_hit_cooldown > 0.0 or _monster_restart_pending:
		return
	_monster_hit_cooldown = 1.15
	_monster_hits += 1
	_stamina = maxf(0.0, _stamina - 34.0)
	_is_exhausted = true
	var away := global_position - attacker.global_position
	away.y = 0.0
	if away.length_squared() > 0.01:
		away = away.normalized()
		velocity.x += away.x * 4.2
		velocity.z += away.z * 4.2
	velocity.y = maxf(velocity.y, 1.1)
	_look_pitch = clampf(_look_pitch + deg_to_rad(randf_range(-7.0, 5.0)), deg_to_rad(-max_look_angle), deg_to_rad(max_look_angle))
	if _monster_hits >= 3:
		_monster_restart_pending = true
		_restart_after_monster_catch()


func _restart_after_monster_catch() -> void:
	await get_tree().create_timer(0.85).timeout
	get_tree().reload_current_scene()


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
