@tool
extends StaticBody3D

signal openness_changed(value: float)
signal valve_opened
signal valve_closed
signal correct_setting_changed(is_correct: bool)

const GameplaySounds := preload("res://sounds/gameplay_sound_factory.gd")

enum ValveRole { WATER, AIR_INTAKE, AIR_OUTLET }

@export var initially_open := false
@export_range(0.0, 100.0, 1.0) var initial_percentage := 0.0
@export_range(0.5, 5.0, 0.1) var turn_duration := 1.8
@export_range(0.5, 5.0, 0.25) var wheel_turns := 2.5
@export_range(0.005, 0.1, 0.005) var mouse_wheel_step := 0.01
@export var randomize_initial_openness := true
@export_range(0.0, 100.0, 1.0) var correct_percentage := 70.0
@export_range(0.0, 10.0, 0.5) var correct_tolerance := 0.0
@export var interaction_enabled := true
@export var valve_role: ValveRole = ValveRole.WATER:
	set(value):
		valve_role = value

@onready var wheel_pivot: Node3D = $WheelPivot
@onready var turn_audio: AudioStreamPlayer3D = $TurnAudio

var openness := 0.0
var _turning := false
var _wheel_tween: Tween
var _manipulating := false
var _grab_local_point := Vector3(0.0, 0.28, 0.06)
var _was_at_correct_setting := false


func _ready() -> void:
	add_to_group(&"boiler_valve")
	if randomize_initial_openness and not Engine.is_editor_hint():
		openness = float(randi_range(0, 100)) / 100.0
	elif initial_percentage > 0.0:
		openness = initial_percentage / 100.0
	else:
		openness = 1.0 if initially_open else 0.0
	_apply_wheel_rotation()
	_was_at_correct_setting = is_at_correct_setting()
	if not Engine.is_editor_hint():
		turn_audio.stream = GameplaySounds.make_door_open()


func get_interaction_key() -> Key:
	return KEY_F


func uses_switch_sound() -> bool:
	return false


func get_interaction_text(_player: Node = null) -> String:
	if not interaction_enabled:
		return ""
	if _manipulating:
		return "RUEDA RATON  REGULAR  |  F  SOLTAR  [%d%%]" % roundi(openness * 100.0)
	if _turning:
		return "GIRANDO VALVULA..."
	return "F  COGER %s" % _get_role_name()


func interact(player: Node = null) -> bool:
	if not interaction_enabled or _turning:
		return false
	if _manipulating:
		end_manipulation()
		return true
	var grab_point := wheel_pivot.global_position + wheel_pivot.global_basis.y.normalized() * 0.28
	if is_instance_valid(player) and "interaction_ray" in player:
		var player_ray := player.get("interaction_ray") as RayCast3D
		if is_instance_valid(player_ray) and player_ray.is_colliding():
			grab_point = player_ray.get_collision_point()
	begin_manipulation(player, grab_point)
	return true


func begin_manipulation(player: Node, grab_world_point: Vector3) -> void:
	if _manipulating:
		return
	if is_instance_valid(_wheel_tween):
		_wheel_tween.kill()
	_turning = false
	_manipulating = true
	var local_point := wheel_pivot.to_local(grab_world_point)
	var radial := Vector2(local_point.x, local_point.y)
	if radial.length() < 0.08:
		radial = Vector2.UP * 0.28
	else:
		radial = radial.normalized() * clampf(radial.length(), 0.22, 0.31)
	_grab_local_point = Vector3(radial.x, radial.y, 0.06)
	if is_instance_valid(player) and player.has_method(&"begin_valve_manipulation"):
		player.call(&"begin_valve_manipulation", self)


func adjust_with_mouse_wheel(direction: float) -> void:
	if not _manipulating or is_zero_approx(direction):
		return
	var previous_openness := openness
	openness = roundf(clampf(openness + direction * mouse_wheel_step, 0.0, 1.0) * 100.0) / 100.0
	if not is_equal_approx(previous_openness, openness):
		_apply_wheel_rotation()
		openness_changed.emit(openness)
		_update_correct_setting_state()
		if is_instance_valid(turn_audio) and not turn_audio.playing:
			turn_audio.pitch_scale = lerpf(0.82, 1.18, openness)
			turn_audio.play()


func end_manipulation() -> void:
	if not _manipulating:
		return
	_manipulating = false
	_emit_valve_state()


func is_being_manipulated() -> bool:
	return _manipulating


func get_grab_world_position() -> Vector3:
	return wheel_pivot.to_global(_grab_local_point)


func set_open(open: bool, immediate := false) -> void:
	var target := 1.0 if open else 0.0
	if immediate or Engine.is_editor_hint():
		openness = target
		_turning = false
		_apply_wheel_rotation()
		_update_correct_setting_state()
		_emit_valve_state()
		return
	if is_instance_valid(_wheel_tween):
		_wheel_tween.kill()
	_turning = true
	if is_instance_valid(turn_audio):
		turn_audio.pitch_scale = 1.18 if open else 0.92
		turn_audio.play()
	_wheel_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wheel_tween.tween_method(_set_openness, openness, target, turn_duration * absf(target - openness))
	_wheel_tween.tween_callback(_finish_turn)


func set_openness(value: float, immediate := false) -> void:
	var target := clampf(value, 0.0, 1.0)
	if immediate or Engine.is_editor_hint():
		openness = target
		_apply_wheel_rotation()
		openness_changed.emit(openness)
		_update_correct_setting_state()
		return
	if is_instance_valid(_wheel_tween):
		_wheel_tween.kill()
	_turning = true
	_wheel_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wheel_tween.tween_method(_set_openness, openness, target, turn_duration * absf(target - openness))
	_wheel_tween.tween_callback(_finish_turn)


func is_open() -> bool:
	return openness >= 0.99


func get_openness() -> float:
	return openness


func is_at_correct_setting() -> bool:
	return absf(openness * 100.0 - correct_percentage) <= correct_tolerance + 0.001


func _set_openness(value: float) -> void:
	openness = clampf(value, 0.0, 1.0)
	_apply_wheel_rotation()
	openness_changed.emit(openness)
	_update_correct_setting_state()


func _apply_wheel_rotation() -> void:
	if is_instance_valid(wheel_pivot):
		wheel_pivot.rotation.z = openness * TAU * wheel_turns


func _finish_turn() -> void:
	_turning = false
	_emit_valve_state()


func _emit_valve_state() -> void:
	openness_changed.emit(openness)
	_update_correct_setting_state()
	if is_open():
		valve_opened.emit()
	elif openness <= 0.01:
		valve_closed.emit()


func _update_correct_setting_state() -> void:
	var correct_now := is_at_correct_setting()
	if correct_now == _was_at_correct_setting:
		return
	_was_at_correct_setting = correct_now
	correct_setting_changed.emit(correct_now)


func _get_role_name() -> String:
	match valve_role:
		ValveRole.AIR_INTAKE:
			return "ENTRADA DE AIRE"
		ValveRole.AIR_OUTLET:
			return "SALIDA DE AIRE"
		_:
			return "VALVULA DE AGUA"
