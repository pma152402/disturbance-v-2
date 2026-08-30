@tool
extends Node3D

const BAND_SHADER := preload("res://pastel_wall_band.gdshader")
const CATACOMBS_SCENE := preload("res://church_catacombs.tscn")
const SKIP_WALL_BAND_GROUP := &"skip_wall_band"


func _ready() -> void:
	# Mantener el laberinto fuera de house_baked en el editor. Durante el juego
	# se instancia como hijo de la casa, conservando las mismas coordenadas.
	if not Engine.is_editor_hint() and get_node_or_null("ChurchCatacombs") == null:
		var catacombs := CATACOMBS_SCENE.instantiate()
		catacombs.name = &"ChurchCatacombs"
		add_child(catacombs)
	var overlay := ShaderMaterial.new()
	overlay.shader = BAND_SHADER
	_apply_to_wall_meshes(self, overlay)


func _apply_to_wall_meshes(branch: Node, overlay: ShaderMaterial) -> int:
	if _skips_wall_band(branch):
		return 0

	var applied := 0
	for child: Node in branch.get_children():
		# A tagged branch is intentionally opaque: do not change it or inspect
		# any descendants that may use their own materials.
		if _skips_wall_band(child):
			continue
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if _is_wall_surface(mesh_instance):
				mesh_instance.material_overlay = null
				mesh_instance.material_override = overlay
				applied += 1
		applied += _apply_to_wall_meshes(child, overlay)
	return applied


func _skips_wall_band(branch: Node) -> bool:
	return (
		branch.is_in_group(SKIP_WALL_BAND_GROUP)
		or bool(branch.get_meta(SKIP_WALL_BAND_GROUP, false))
	)


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
