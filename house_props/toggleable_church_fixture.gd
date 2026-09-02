extends Node3D

@export var light_paths: Array[NodePath] = []
@export var glow_mesh_paths: Array[NodePath] = []
@export var starts_on := true

var is_on := false
var _requested_on := false


func _ready() -> void:
	add_to_group(&"house_power_consumers")
	set_lamp_enabled(starts_on)


func set_lamp_enabled(enabled: bool) -> void:
	_requested_on = enabled
	refresh_house_power()


func refresh_house_power() -> void:
	is_on = _requested_on and _house_power_available()
	for path: NodePath in light_paths:
		var light := get_node_or_null(path) as Light3D
		if light != null:
			light.visible = is_on
	for path: NodePath in glow_mesh_paths:
		var glow := get_node_or_null(path) as GeometryInstance3D
		if glow != null:
			glow.visible = is_on


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
