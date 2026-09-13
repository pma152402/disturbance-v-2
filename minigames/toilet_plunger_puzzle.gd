extends StaticBody3D

const SkillCheckScene := preload("res://minigames/skill_check_minigame.tscn")

@export var released_key_id: StringName = &"master_bedroom_key"
@export var key_landing_global_position := Vector3(-4.65, 0.28, 7.65)

@onready var bowl_water: Node3D = $BowlWater
@onready var plunger_in_bowl: Node3D = $PlungerInBowl
var _completed := false
var _minigame_active := false
var _plunger_rest_position := Vector3.ZERO
var _plunger_pump_tween: Tween
var _active_player: Node
var _active_layer: CanvasLayer
var _plunger_committed := false


func _ready() -> void:
	_plunger_rest_position = plunger_in_bowl.position


func get_camera_observation_state() -> Dictionary:
	if _minigame_active:
		return {
			"id": &"unclogging_toilet",
			"label": "DESATASCANDO WC",
			"state": &"in_progress",
			"priority": 4.0,
		}
	if _completed:
		return {
			"id": &"toilet_unclogged",
			"label": "WC DESATASCADO",
			"state": &"completed",
		}
	return {
		"id": &"clogged_toilet",
		"label": "WC ATASCADO",
		"state": &"clogged",
	}


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if _completed:
		return ""
	if _minigame_active:
		return ""
	if player != null and player.has_method(&"is_holding_item_type") and player.is_holding_item_type(&"plunger"):
		return "F  USAR DESATASCADOR"
	return ""


func interact(player: Node = null) -> bool:
	if _completed or player == null or not player.has_method(&"is_holding_item_type"):
		return false
	if not player.is_holding_item_type(&"plunger"):
		return true
	_start_skill_checks(player)
	return true


func _start_skill_checks(player: Node) -> void:
	if _minigame_active:
		return
	# Commit the held tool before showing its world model. Keeping both representations
	# alive was the source of the duplicated plunger and the stuck interaction state.
	if not player.has_method(&"consume_held_item") or not player.consume_held_item(&"plunger"):
		return
	_minigame_active = true
	_plunger_committed = true
	_active_player = player
	var layer := SkillCheckScene.instantiate() as CanvasLayer
	_active_layer = layer
	get_tree().root.add_child(layer)
	plunger_in_bowl.visible = true
	plunger_in_bowl.position = _plunger_rest_position
	plunger_in_bowl.scale = Vector3(0.88, 0.88, 0.88)
	var skill_check := layer.get_node("SkillCheck")
	skill_check.completed.connect(_on_skill_checks_completed.bind(player, layer))
	skill_check.cancelled.connect(_on_skill_checks_cancelled.bind(layer))
	skill_check.attempted.connect(_on_skill_check_attempted)
	if player.has_method(&"set_skill_check_active"):
		player.set_skill_check_active(true)


func _on_skill_check_attempted() -> void:
	if is_instance_valid(_plunger_pump_tween):
		_plunger_pump_tween.kill()
	plunger_in_bowl.position = _plunger_rest_position
	_plunger_pump_tween = create_tween()
	_plunger_pump_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_plunger_pump_tween.tween_property(
		plunger_in_bowl,
		"position",
		_plunger_rest_position + Vector3(0.0, -0.22, 0.0),
		0.12
	)
	_plunger_pump_tween.set_ease(Tween.EASE_OUT)
	_plunger_pump_tween.tween_property(
		plunger_in_bowl,
		"position",
		_plunger_rest_position + Vector3(0.0, 0.18, 0.0),
		0.22
	)
	_plunger_pump_tween.tween_property(plunger_in_bowl, "position", _plunger_rest_position, 0.11)


func _on_skill_checks_completed(player: Node, layer: CanvasLayer) -> void:
	_finish_minigame_state(player, layer)
	_plunger_committed = false
	_completed = true
	_show_plunger_in_bowl()
	var key := _find_puzzle_key()
	if key != null and key.has_method(&"reveal_from_toilet"):
		key.reveal_from_toilet(bowl_water.global_position, key_landing_global_position)


func _show_plunger_in_bowl() -> void:
	plunger_in_bowl.visible = true
	plunger_in_bowl.position = _plunger_rest_position
	plunger_in_bowl.scale = Vector3(0.88, 0.88, 0.88)


func _on_skill_checks_cancelled(layer: CanvasLayer) -> void:
	var player := _active_player
	_finish_minigame_state(player, layer)
	plunger_in_bowl.visible = false
	plunger_in_bowl.position = _plunger_rest_position
	if _plunger_committed and is_instance_valid(player) and player.has_method(&"pick_up_plunger"):
		player.pick_up_plunger()
	_plunger_committed = false


func _finish_minigame_state(player: Node, layer: CanvasLayer) -> void:
	_minigame_active = false
	if is_instance_valid(player) and player.has_method(&"set_skill_check_active"):
		player.set_skill_check_active(false)
	if is_instance_valid(layer):
		layer.queue_free()
	_active_player = null
	_active_layer = null


func _exit_tree() -> void:
	# Never leave the player blocked if this toilet or its room is removed mid-check.
	if is_instance_valid(_active_player) and _active_player.has_method(&"set_skill_check_active"):
		_active_player.set_skill_check_active(false)
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()


func _find_puzzle_key() -> Node3D:
	for candidate in get_tree().get_nodes_in_group(&"collectible_keys"):
		if candidate is Node3D and candidate.get("key_id") == released_key_id:
			return candidate as Node3D
	return null
