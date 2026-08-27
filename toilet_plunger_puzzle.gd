extends StaticBody3D

const SkillCheckScene := preload("res://skill_check_minigame.tscn")

@export var released_key_id: StringName = &"master_bedroom_key"
@export var key_landing_global_position := Vector3(-4.65, 0.28, 7.65)

@onready var bowl_water: Node3D = $BowlWater
@onready var plunger_in_bowl: Node3D = $PlungerInBowl
var _completed := false
var _minigame_active := false
var _plunger_rest_position := Vector3.ZERO
var _plunger_pump_tween: Tween


func _ready() -> void:
	_plunger_rest_position = plunger_in_bowl.position


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
	_minigame_active = true
	var layer := SkillCheckScene.instantiate() as CanvasLayer
	get_tree().current_scene.add_child(layer)
	plunger_in_bowl.visible = true
	plunger_in_bowl.position = _plunger_rest_position
	plunger_in_bowl.scale = Vector3(0.88, 0.88, 0.88)
	if player.has_method(&"set_plunger_minigame_pose"):
		player.set_plunger_minigame_pose(true)
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
	_minigame_active = false
	if is_instance_valid(player) and player.has_method(&"set_skill_check_active"):
		player.set_skill_check_active(false)
	if is_instance_valid(layer):
		layer.queue_free()
	if not is_instance_valid(player) or not player.has_method(&"consume_held_item"):
		return
	if not player.consume_held_item(&"plunger"):
		return
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
	_minigame_active = false
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method(&"set_skill_check_active"):
		player.set_skill_check_active(false)
	if player != null and player.has_method(&"set_plunger_minigame_pose"):
		player.set_plunger_minigame_pose(false)
	plunger_in_bowl.visible = false
	plunger_in_bowl.position = _plunger_rest_position
	if is_instance_valid(layer):
		layer.queue_free()


func _find_puzzle_key() -> Node3D:
	for candidate in get_tree().get_nodes_in_group(&"collectible_keys"):
		if candidate is Node3D and candidate.get("key_id") == released_key_id:
			return candidate as Node3D
	return null
