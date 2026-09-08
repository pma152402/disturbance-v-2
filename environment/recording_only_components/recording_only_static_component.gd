@tool
extends Node3D

## Controlador no destructivo para componentes editables exclusivos de cinta.
## No crea ni reconstruye nodos: únicamente cambia su capa de renderizado.

const RECORDING_ONLY_VISIBILITY_MASK := 1 << 19

@export_category("Revelado en la cinta")
@export_range(2.0, 20.0, 0.1) var maximum_recording_distance := 7.0
@export_range(0.0, 3.0, 0.05) var distance_fade_margin := 1.0
@export_category("Vista del editor")
@export var show_editor_preview := true:
	set(value):
		show_editor_preview = value
		if is_inside_tree():
			_apply_visibility(self)


func _ready() -> void:
	_apply_visibility(self)


func _apply_visibility(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		if Engine.is_editor_hint():
			geometry.layers = 1
			geometry.visible = show_editor_preview
		else:
			geometry.layers = RECORDING_ONLY_VISIBILITY_MASK
			geometry.visible = true
			geometry.visibility_range_end = maximum_recording_distance
			geometry.visibility_range_end_margin = minf(distance_fade_margin, maximum_recording_distance)
			geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in node.get_children():
		_apply_visibility(child)
