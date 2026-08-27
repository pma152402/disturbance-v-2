extends Area3D

@export var open_angle := 82.0
@export var animation_time := 0.75
var _open := false
var _moving := false
@onready var left_hinge: Node3D = $LeftHinge
@onready var right_hinge: Node3D = $RightHinge

func get_interaction_key() -> Key:
	return KEY_F

func get_interaction_text(_player: Node = null) -> String:
	return "F  CERRAR SOTANO" if _open else "F  ABRIR SOTANO"

func interact(_player: Node = null) -> bool:
	if _moving:
		return false
	_moving = true
	_open = not _open
	var target := deg_to_rad(open_angle if _open else 0.0)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(left_hinge, "rotation:z", target, animation_time)
	tween.tween_property(right_hinge, "rotation:z", -target, animation_time)
	tween.finished.connect(func(): _moving = false)
	return true
