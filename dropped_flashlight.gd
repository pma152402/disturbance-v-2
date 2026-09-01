extends RigidBody3D

@export var requires_battery := false
@export var battery_id: StringName = &"flashlight_battery"
@onready var light: SpotLight3D = $SpotLight3D
var _being_picked_up := false


func _ready() -> void:
	if requires_battery:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		light.visible = false


func set_light_enabled(enabled: bool) -> void:
	light.visible = enabled


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if requires_battery:
		if player == null or not player.has_method(&"has_tool") or not player.has_tool(battery_id):
			return "NECESITAS UNA PILA"
		return "F  INSTALAR PILA Y COGER LINTERNA"
	return "F  COGER LINTERNA"


func interact(player: Node = null) -> bool:
	if _being_picked_up or player == null or not player.has_method(&"recover_flashlight"):
		return false
	if requires_battery and (
		not player.has_method(&"has_tool")
		or not player.has_tool(battery_id)
		or not player.has_method(&"consume_tool")
	):
		return true
	if not player.recover_flashlight(false if requires_battery else light.visible):
		return false
	if requires_battery:
		player.consume_tool(battery_id)
	_being_picked_up = true
	queue_free()
	return true
