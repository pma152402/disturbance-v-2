extends Node3D

@export var light_paths: Array[NodePath] = []
@export var glow_mesh_paths: Array[NodePath] = []
@export var starts_on := true

var is_on := false


func _ready() -> void:
	set_lamp_enabled(starts_on)


func set_lamp_enabled(enabled: bool) -> void:
	is_on = enabled
	for path: NodePath in light_paths:
		var light := get_node_or_null(path) as Light3D
		if light != null:
			light.visible = enabled
	for path: NodePath in glow_mesh_paths:
		var glow := get_node_or_null(path) as GeometryInstance3D
		if glow != null:
			glow.visible = enabled


func toggle_lamp() -> bool:
	set_lamp_enabled(not is_on)
	return is_on
