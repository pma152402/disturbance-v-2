extends Area3D

@export var open_angle := 82.0
@export var animation_time := 0.75
@export_group("Cerradura")
@export var required_key_id: StringName = &"basement_key"
@export var required_key_name := "LLAVE DEL SÓTANO"
@export var starts_unlocked := false
var _open := false
var _moving := false
var _is_unlocked := false
@onready var left_hinge: Node3D = $LeftHinge
@onready var right_hinge: Node3D = $RightHinge

func _ready() -> void:
	_is_unlocked = starts_unlocked

func get_interaction_key() -> Key:
	return KEY_F

func get_interaction_text(player: Node = null) -> String:
	if not _is_unlocked:
		if player != null and player.has_method(&"has_key") and player.has_key(required_key_id):
			return "F  USAR %s" % required_key_name.to_upper()
		return "NECESITAS %s" % required_key_name.to_upper()
	return "F  CERRAR SOTANO" if _open else "F  ABRIR SOTANO"

func interact(player: Node = null) -> bool:
	if _moving:
		return false
	if not _is_unlocked:
		if player == null or not player.has_method(&"has_key") or not player.has_key(required_key_id):
			return true
		_is_unlocked = true
	_moving = true
	_open = not _open
	var target := deg_to_rad(open_angle if _open else 0.0)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(left_hinge, "rotation:z", target, animation_time)
	tween.tween_property(right_hinge, "rotation:z", -target, animation_time)
	tween.finished.connect(func(): _moving = false)
	return true
