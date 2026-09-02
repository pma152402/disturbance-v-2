@tool
extends Node3D

@export_range(0, 2) var layout_variant := 0:
	set(value):
		layout_variant = clampi(value, 0, 2)
		_apply_variant()


func _ready() -> void:
	_apply_variant()


func _apply_variant() -> void:
	for index in range(3):
		var layout := get_node_or_null("Layout%d" % index) as Node3D
		if layout != null:
			layout.visible = index == layout_variant
