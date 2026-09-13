extends RigidBody3D

@export var requires_battery := false
@export var battery_id: StringName = &"flashlight_battery"
@onready var light: SpotLight3D = $SpotLight3D
var _being_picked_up := false
var _battery_installed := true


func _ready() -> void:
	_battery_installed = not requires_battery
	if requires_battery:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		light.visible = false


func set_light_enabled(enabled: bool) -> void:
	light.visible = enabled and _battery_installed


func set_battery_installed(installed: bool) -> void:
	_battery_installed = installed
	if not installed:
		light.visible = false


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if not _battery_installed:
		if player != null and player.has_method(&"has_tool") and player.has_tool(battery_id):
			return "F  COGER LINTERNA E INSTALAR PILA"
		return "F  COGER LINTERNA (SIN PILA)"
	return "F  COGER LINTERNA"


func interact(player: Node = null) -> bool:
	if _being_picked_up or player == null or not player.has_method(&"recover_flashlight"):
		return false
	var install_carried_battery: bool = (
		not _battery_installed
		and player.has_method(&"has_tool")
		and player.has_tool(battery_id)
		and player.has_method(&"consume_tool")
	)
	if not player.recover_flashlight(light.visible, _battery_installed or install_carried_battery):
		return false
	if install_carried_battery:
		player.consume_tool(battery_id)
	_being_picked_up = true
	queue_free()
	return true
