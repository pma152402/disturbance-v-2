extends RefCounted

# Lista deliberadamente limitada a decoracion fija. No se agrupan piezas de
# puertas, puzles, luces, actores, ni se modifica la escena editable.
const FIXED_SCENES := [
	"office_bookcase_oak", "office_bookcase_low", "office_bookcase_steel",
	"office_bookcase_stepped", "office_document_trays", "office_archive_trolley",
	"office_pencil_cup", "office_visitor_chair", "office_wire_wastebasket",
	"darkroom_print_drying_rack", "darkroom_film_canisters",
	"kitchen_canned_goods", "kitchen_spice_jar_set", "board_game_stack",
	"detailed_wooden_barrel", "detailed_wooden_crate", "church_pew",
	"metal_wall_shelves", "empty_bird_cage", "wood_and_fabric_folding_screen",
]
const RENDER_PROPERTIES := [
	"layers", "cast_shadow", "gi_mode", "material_override", "material_overlay",
	"transparency", "visibility_range_begin", "visibility_range_begin_margin",
	"visibility_range_end", "visibility_range_end_margin", "visibility_range_fade_mode",
	"extra_cull_margin", "ignore_occlusion_culling", "sorting_offset",
	"sorting_use_aabb_center", "lod_bias",
]


static func optimize(branch: Node) -> Dictionary:
	var result := {"source_meshes": 0, "batches": 0}
	_visit(branch, result)
	return result


static func _visit(node: Node, result: Dictionary) -> void:
	var scene_name := node.scene_file_path.get_file().get_basename()
	if scene_name in FIXED_SCENES and _is_static_tree(node):
		_batch_parents(node, result)
		return
	for child in node.get_children():
		_visit(child, result)


static func _is_static_tree(node: Node) -> bool:
	if node.get_script() != null or node is AnimationPlayer or node is AnimationTree:
		return false
	if node is RigidBody3D or node is CharacterBody3D or node is AnimatableBody3D:
		return false
	for child in node.get_children():
		if not _is_static_tree(child):
			return false
	return true


static func _batch_parents(parent: Node, result: Dictionary) -> void:
	var groups: Dictionary = {}
	for child in parent.get_children():
		_batch_parents(child, result)
		if child is not MeshInstance3D or child.get_child_count() != 0:
			continue
		var source := child as MeshInstance3D
		if source.mesh == null or not source.visible or source.is_set_as_top_level():
			continue
		if source.skin != null or source.get_blend_shape_count() > 0:
			continue
		if not source.visibility_parent.is_empty() or source.custom_aabb != AABB():
			continue
		var opaque := true
		for surface in source.mesh.get_surface_count():
			var material := source.get_active_material(surface)
			if material is not StandardMaterial3D or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.next_pass != null:
				opaque = false
		if not opaque or source.material_overlay != null or source.transparency != 0.0:
			continue
		var key: Array = [source.mesh]
		for property in RENDER_PROPERTIES:
			key.append(source.get(property))
		for surface in source.mesh.get_surface_count():
			key.append(source.get_surface_override_material(surface))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(source)
	for group: Array in groups.values():
		if group.size() < 3:
			continue
		var first := group[0] as MeshInstance3D
		var batch := MultiMeshInstance3D.new()
		batch.name = "StaticDecorBatch_%s" % first.name
		for property in RENDER_PROPERTIES:
			batch.set(property, first.get(property))
		var mesh := first.mesh
		var has_surface_override := false
		for surface in mesh.get_surface_count():
			has_surface_override = has_surface_override or first.get_surface_override_material(surface) != null
		if has_surface_override:
			mesh = mesh.duplicate() as Mesh
			if mesh is PrimitiveMesh:
				mesh.material = first.get_active_material(0)
			else:
				for surface in mesh.get_surface_count():
					mesh.surface_set_material(surface, first.get_active_material(surface))
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = group.size()
		batch.multimesh = multi
		parent.add_child(batch)
		for index in group.size():
			var source := group[index] as MeshInstance3D
			# Mismo padre, matriz local integra: no descomponer escala/rotacion.
			multi.set_instance_transform(index, source.transform)
			parent.remove_child(source)
			source.free()
		result.source_meshes += group.size()
		result.batches += 1
