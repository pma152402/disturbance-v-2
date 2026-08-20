@tool
extends Node3D

const BAND_SHADER := preload("res://pastel_wall_band.gdshader")


func _ready() -> void:
	var overlay := ShaderMaterial.new()
	overlay.shader = BAND_SHADER
	_apply_to_wall_meshes(self, overlay)


func _apply_to_wall_meshes(branch: Node, overlay: ShaderMaterial) -> int:
	var applied := 0
	for child: Node in branch.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if _is_wall_surface(mesh_instance):
				mesh_instance.material_overlay = null
				mesh_instance.material_override = overlay
				applied += 1
		applied += _apply_to_wall_meshes(child, overlay)
	return applied


func _is_wall_surface(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh != null:
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index)
			if material is ShaderMaterial:
				var shader := (material as ShaderMaterial).shader
				if shader != null and shader.resource_path.ends_with("pastel_wall_band.gdshader"):
					return true
	# Respaldo para paredes con material sobrescrito por el editor.
	var parent_node := mesh_instance.get_parent()
	if mesh_instance.name != &"Mesh" or parent_node == null:
		return false
	var parent_name := String(parent_node.name).to_lower()
	return "wall" in parent_name or "partition" in parent_name or "lintel" in parent_name
