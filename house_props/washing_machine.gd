extends StaticBody3D

signal puzzle_completed

const MinigameScene := preload("res://washing_machine_minigame.tscn")
const GameplaySounds := preload("res://sounds/gameplay_sound_factory.gd")

@export var minigame_enabled := true

@onready var program_dial: MeshInstance3D = $ProgramDial
@onready var power_button: MeshInstance3D = $PowerButton
@onready var control_audio: AudioStreamPlayer3D = $ControlAudio

var _completed := false
var _minigame_active := false
var _active_player: Node
var _active_layer: CanvasLayer
var _player_was_processing_input := true
var _player_was_processing_physics := true
var _button_rest_position := Vector3.ZERO
var _button_tween: Tween
var _dial_tween: Tween


func _ready() -> void:
	_button_rest_position = power_button.position
	control_audio.stream = GameplaySounds.make_switch_click()


func _exit_tree() -> void:
	if _minigame_active:
		_restore_player()


func get_interaction_key() -> Key:
	return KEY_F


func uses_switch_sound() -> bool:
	return false


func get_interaction_text(_player: Node = null) -> String:
	if not minigame_enabled or _minigame_active:
		return ""
	if _completed:
		return "CICLO DE LAVADO CONFIGURADO"
	return "F  USAR LAVADORA"


func interact(player: Node = null) -> bool:
	if not minigame_enabled:
		return false
	if _completed or _minigame_active:
		return true
	_start_minigame(player)
	return true


func _start_minigame(player: Node) -> void:
	_minigame_active = true
	_active_player = player
	_active_layer = MinigameScene.instantiate() as CanvasLayer
	get_tree().current_scene.add_child(_active_layer)
	var minigame := _active_layer.get_node("WashingMachineMinigame")
	minigame.completed.connect(_on_minigame_completed)
	minigame.cancelled.connect(_on_minigame_cancelled)
	minigame.selection_changed.connect(_on_selection_changed)
	minigame.program_submitted.connect(_on_program_submitted)
	_lock_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _lock_player() -> void:
	if not is_instance_valid(_active_player):
		return
	_player_was_processing_input = _active_player.is_processing_input()
	_player_was_processing_physics = _active_player.is_physics_processing()
	if _active_player.has_method(&"set_skill_check_active"):
		_active_player.call(&"set_skill_check_active", true)
	if _active_player is CharacterBody3D:
		(_active_player as CharacterBody3D).velocity = Vector3.ZERO
	_active_player.set_process_input(false)
	_active_player.set_physics_process(false)


func _restore_player() -> void:
	if is_instance_valid(_active_player):
		_active_player.set_process_input(_player_was_processing_input)
		_active_player.set_physics_process(_player_was_processing_physics)
		if _active_player.has_method(&"set_skill_check_active"):
			_active_player.call(&"set_skill_check_active", false)
	_active_player = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_selection_changed(program: int) -> void:
	if is_instance_valid(_dial_tween):
		_dial_tween.kill()
	var target_angle := -TAU * float(program - 1) / 9.0
	_dial_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dial_tween.tween_property(program_dial, "rotation:y", target_angle, 0.11)
	_play_control_click(0.82 + float(program) * 0.018)


func _on_program_submitted(_program: int, correct: bool) -> void:
	if is_instance_valid(_button_tween):
		_button_tween.kill()
	power_button.position = _button_rest_position
	_button_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_button_tween.tween_property(power_button, "position", _button_rest_position + Vector3(0.0, 0.0, 0.035), 0.07)
	_button_tween.set_ease(Tween.EASE_OUT)
	_button_tween.tween_property(power_button, "position", _button_rest_position, 0.12)
	_play_control_click(1.12 if correct else 0.68)


func _play_control_click(pitch: float) -> void:
	control_audio.pitch_scale = pitch
	control_audio.play()


func _on_minigame_completed() -> void:
	_completed = true
	_minigame_active = false
	_restore_player()
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null
	puzzle_completed.emit()


func _on_minigame_cancelled() -> void:
	_minigame_active = false
	_restore_player()
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null
