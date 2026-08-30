extends CharacterBody3D

@export var required_tool_id: StringName = &"crowbar"
@export var required_tool_name := "PALANCA"

@onready var collision_shape: CollisionShape3D = $Collision
@onready var boards_root: Node3D = $Boards

var _removed := false
var _removing := false


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if _removed or _removing:
		return ""
	if player != null and player.has_method(&"has_tool") and player.has_tool(required_tool_id):
		return "F  QUITAR TABLONES"
	return "NECESITAS %s" % required_tool_name.to_upper()


func interact(player: Node = null) -> bool:
	if _removed or _removing:
		return true
	if player == null or not player.has_method(&"has_tool") or not player.has_tool(required_tool_id):
		return true
	if player.has_method(&"consume_held_item"):
		player.consume_held_item(&"crowbar")
	_removing = true
	collision_layer = 0
	collision_shape.set_deferred("disabled", true)
	for index in range(boards_root.get_child_count()):
		var board := boards_root.get_child(index) as Node3D
		if board == null:
			continue
		var direction := -1.0 if index % 2 == 0 else 1.0
		var tween := board.create_tween()
		tween.tween_interval(index * 0.13)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(
			board,
			"position",
			board.position + Vector3(direction * 0.48, -0.16 - index * 0.05, 0.58),
			0.38,
		)
		tween.parallel().tween_property(
			board,
			"rotation",
			board.rotation + Vector3(0.28 * direction, 0.18 * direction, 0.42 * direction),
			0.38,
		)
		tween.tween_property(board, "position", board.position + Vector3(direction * 0.62, -1.15, 0.82), 0.42)
		tween.tween_callback(board.queue_free)
	var finish := get_tree().create_timer(1.35)
	finish.timeout.connect(func() -> void:
		_removed = true
		_removing = false
	)
	return true
