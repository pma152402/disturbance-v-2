extends Node3D
## Runtime weather only. This script never changes editable geometry.
func _ready() -> void:
	preload("res://school_rain_shelter.gd").install(self)
