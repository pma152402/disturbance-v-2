@tool
extends Node3D

const IMAGE_HEIGHT := 0.9
const FRAME_THICKNESS := 0.07
const FRAME_DEPTH := 0.06

var _refresh_pending := true

@export_category("Picture")
@export var photo_texture: Texture2D:
	set(value):
		photo_texture = value
		_queue_refresh()

@export_category("Frame")
@export var frame_color := Color(0.24, 0.115, 0.045, 1.0):
	set(value):
		frame_color = value
		_queue_refresh()


func _ready() -> void:
	_refresh_pending = true
	set_process(true)


func _process(_delta: float) -> void:
	if not _refresh_pending:
		set_process(false)
		return
	_refresh_pending = false
	_update_photo_material()
	_update_frame_geometry()
	_update_frame_material()
	set_process(false)


func _queue_refresh() -> void:
	_refresh_pending = true
	if is_inside_tree():
		set_process(true)


func _update_photo_material() -> void:
	var image := get_node_or_null("Image") as MeshInstance3D
	if image == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE if photo_texture != null else Color(0.16, 0.13, 0.1, 1.0)
	material.albedo_texture = photo_texture
	material.roughness = 0.82
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	image.material_override = material


func _update_frame_geometry() -> void:
	var image := get_node_or_null("Image") as MeshInstance3D
	var backing := get_node_or_null("Backing") as MeshInstance3D
	var top := get_node_or_null("Frame/Top") as MeshInstance3D
	var bottom := get_node_or_null("Frame/Bottom") as MeshInstance3D
	var left := get_node_or_null("Frame/Left") as MeshInstance3D
	var right := get_node_or_null("Frame/Right") as MeshInstance3D
	var collision := get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	if image == null or backing == null or top == null or bottom == null or left == null or right == null:
		return

	var aspect := 16.0 / 9.0
	if photo_texture != null and photo_texture.get_height() > 0:
		aspect = float(photo_texture.get_width()) / float(photo_texture.get_height())
	var image_width := IMAGE_HEIGHT * aspect
	var outer_width := image_width + FRAME_THICKNESS * 2.0
	var outer_height := IMAGE_HEIGHT + FRAME_THICKNESS * 2.0

	var image_mesh := QuadMesh.new()
	image_mesh.size = Vector2(image_width, IMAGE_HEIGHT)
	image.mesh = image_mesh

	var horizontal_mesh := BoxMesh.new()
	horizontal_mesh.size = Vector3(outer_width, FRAME_THICKNESS, FRAME_DEPTH)
	top.mesh = horizontal_mesh
	bottom.mesh = horizontal_mesh
	top.position = Vector3(0, (IMAGE_HEIGHT + FRAME_THICKNESS) * 0.5, 0)
	bottom.position = Vector3(0, -(IMAGE_HEIGHT + FRAME_THICKNESS) * 0.5, 0)

	var vertical_mesh := BoxMesh.new()
	vertical_mesh.size = Vector3(FRAME_THICKNESS, IMAGE_HEIGHT, FRAME_DEPTH)
	left.mesh = vertical_mesh
	right.mesh = vertical_mesh
	left.position = Vector3(-(image_width + FRAME_THICKNESS) * 0.5, 0, 0)
	right.position = Vector3((image_width + FRAME_THICKNESS) * 0.5, 0, 0)

	var backing_mesh := BoxMesh.new()
	backing_mesh.size = Vector3(outer_width, outer_height, FRAME_DEPTH * 0.5)
	backing.mesh = backing_mesh
	backing.scale = Vector3.ONE

	if collision != null:
		var shape := BoxShape3D.new()
		shape.size = Vector3(outer_width, outer_height, FRAME_DEPTH)
		collision.shape = shape


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
