extends Node3D

@onready var bulb: MeshInstance3D = $Bulb
@onready var warm_light: OmniLight3D = $WarmLight

@export var starts_on := false
var is_on := false


func _ready() -> void:
	set_lamp_enabled(starts_on)


func set_lamp_enabled(enabled: bool) -> void:
	is_on = enabled
	bulb.visible = enabled
	warm_light.visible = enabled


func toggle_lamp() -> bool:
	set_lamp_enabled(not is_on)
	return is_on
