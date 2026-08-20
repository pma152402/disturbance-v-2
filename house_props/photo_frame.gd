@tool
extends Node3D

@export_category("Picture")
@export var photo_texture: Texture2D:
	set(value):
		photo_texture = value
		_update_photo_material()

@export_category("Frame")
@export var frame_color := Color(0.24, 0.115, 0.045, 1.0):
	set(value):
		frame_color = value
		_update_frame_material()


func _ready() -> void:
	_update_photo_material()
	_update_frame_material()


func _update_photo_material() -> void:
	var image := get_node_or_null("Image") as MeshInstance3D
	if image == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE if photo_texture != null else Color(0.16, 0.13, 0.1, 1.0)
	material.albedo_texture = photo_texture
	material.roughness = 0.82
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	image.material_override = material


func _update_frame_material() -> void:
	var frame := get_node_or_null("Frame") as Node3D
	if frame == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = frame_color
	material.roughness = 0.92
	for child in frame.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = material
