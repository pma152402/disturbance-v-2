@tool
extends StaticBody3D
## Reusable courtyard lantern. No per-frame script or flickering light.
@export var enabled := true:
	set(value):
		enabled = value
		_update_light()
@export var light_color := Color(1.0, 0.76, 0.43):
	set(value):
		light_color = value
		_update_light()
@export_range(0.0, 8.0, 0.1) var energy := 1.8:
	set(value):
		energy = value
		_update_light()
@export_range(1.0, 18.0, 0.5) var light_range := 8.0:
	set(value):
		light_range = value
		_update_light()

func _ready() -> void:
	_update_light()

func set_lamp_enabled(value: bool) -> void:
	enabled = value

func _update_light() -> void:
	var light := get_node_or_null("WarmLight") as OmniLight3D
	if light == null: return
	light.visible = enabled
	light.light_color = light_color
	light.light_energy = energy
	light.omni_range = light_range
	var bulb := get_node_or_null("Bulb") as MeshInstance3D
	if bulb != null:
		var material := bulb.material_override as StandardMaterial3D
		if material != null:
			material = material.duplicate() as StandardMaterial3D
			material.emission_enabled = enabled
			material.emission = light_color
			bulb.material_override = material
