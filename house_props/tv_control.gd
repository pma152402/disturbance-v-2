extends StaticBody3D

@export_enum("power", "channel", "volume") var action := "power"

@onready var visual: MeshInstance3D = $Visual

var _press_tween: Tween


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return 2.0


func get_interaction_text(_player: Node = null) -> String:
	var television := get_parent()
	if television.has_method(&"get_control_prompt"):
		return str(television.call(&"get_control_prompt", action))
	return ""


func interact(_player: Node = null) -> bool:
	var television := get_parent()
	if not television.has_method(&"activate_control"):
		return false
	var activated := bool(television.call(&"activate_control", action))
	if activated:
		_animate_press()
	return activated


func uses_switch_sound() -> bool:
	return false


func _animate_press() -> void:
	if is_instance_valid(_press_tween):
		_press_tween.kill()
	# Los diales siempre regresan a cero. El boton de encendido conserva en
	# cambio la profundidad de enclavado que acaba de fijar el televisor.
	var rest_z := visual.position.z if action == "power" else 0.0
	_press_tween = create_tween()
	_press_tween.tween_property(visual, "position:z", rest_z + 0.018, 0.055)
	_press_tween.tween_property(visual, "position:z", rest_z, 0.09)
