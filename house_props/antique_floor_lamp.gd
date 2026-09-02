extends Node3D

@onready var bulb: MeshInstance3D = $Bulb
@onready var warm_light: OmniLight3D = $WarmLight

@export var starts_on := false
var is_on := false
var _requested_on := false
var _bulb_material: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"house_power_consumers")
	_bulb_material = bulb.get_active_material(0).duplicate() as StandardMaterial3D
	bulb.set_surface_override_material(0, _bulb_material)
	set_lamp_enabled(starts_on)


func set_lamp_enabled(enabled: bool) -> void:
	_requested_on = enabled
	refresh_house_power()


func refresh_house_power() -> void:
	is_on = _requested_on and _house_power_available()
	bulb.visible = true
	if _bulb_material != null:
		_bulb_material.emission_enabled = is_on
		_bulb_material.albedo_color = Color(1.0, 0.69, 0.34, 1.0) if is_on else Color(0.32, 0.27, 0.19, 1.0)
	warm_light.visible = is_on


func _house_power_available() -> bool:
	var panels := get_tree().get_nodes_in_group(&"house_power_panel")
	if panels.is_empty():
		return true
	return bool(panels[0].call(&"is_house_power_available"))


func toggle_lamp() -> bool:
	set_lamp_enabled(not _requested_on)
	return _requested_on


func get_requested_lamp_state() -> bool:
	return _requested_on
