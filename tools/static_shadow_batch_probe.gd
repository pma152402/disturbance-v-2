extends RefCounted

## Experimento reversible: mantiene mallas/materiales/color/colisiones originales.
## Agrupa solo pases de sombra, entre materiales opacos de igual rasterización.
## No se instala en la partida normal. Ejecutar tras los optimizadores de inicio.
const GeometryProbe := preload("res://tools/static_geometry_merge_probe.gd")
const PROBE_META := &"static_shadow_batch_probe"
const CELL_SIZE := 4.0
const MIN_GROUP_SIZE := 3
const COPY_PROPERTIES := [&"layers", &"extra_cull_margin", &"ignore_occlusion_culling"]
var _batches: Array[MeshInstance3D] = []
var _sources: Array[Dictionary] = []


func install(branch: Node3D) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := {"scanned": 0, "eligible": 0, "sources": 0, "batches": 0,
		"triangles_before": 0, "triangles_after": 0, "array_bytes": 0, "skipped": {}}
	if not is_instance_valid(branch) or not branch.is_inside_tree():
		return result
	var groups: Dictionary = {}
	_scan(branch, branch, groups, result)
	for group: Array in groups.values():
		if group.size() >= MIN_GROUP_SIZE:
			_merge(group, result)
	result["shadow_instance_reduction"] = result.sources - result.batches
	result["build_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	return result


func restore() -> void:
	for state: Dictionary in _sources:
		if is_instance_valid(state.node):
			state.node.cast_shadow = state.cast_shadow
	for batch in _batches:
		if is_instance_valid(batch):
			batch.free()
	_sources.clear()
	_batches.clear()


func _scan(node: Node, boundary: Node, groups: Dictionary, result: Dictionary) -> void:
	for child in node.get_children():
		if child is AnimationPlayer or child is AnimationTree:
			return
	if node != boundary:
		if node.get_script() != null or node is RigidBody3D or node is CharacterBody3D or node is AnimatableBody3D or node is AnimationPlayer or node is AnimationTree or GeometryProbe._has_connections(node):
			return
	if node is MeshInstance3D:
		var source := node as MeshInstance3D
		result.scanned += 1
		var reason := _exclusion_reason(source)
		if not reason.is_empty():
			result.skipped[reason] = int(result.skipped.get(reason, 0)) + 1
		else:
			result.eligible += 1
			var center := (source.global_transform * source.mesh.get_aabb()).get_center() / CELL_SIZE
			var cell := Vector3i(floori(center.x), floori(center.y), floori(center.z))
			# Mismo padre: heredan movimiento/visibilidad juntos. La celda evita
			# combinar salas lejanas en un único volumen de descarte.
			var key: Array = [source.get_parent(), cell, _shadow_cull(source)]
			for property: StringName in COPY_PROPERTIES:
				key.append(source.get(property))
			if not groups.has(key):
				groups[key] = []
			groups[key].append(source)
	for child in node.get_children():
		_scan(child, boundary, groups, result)


static func _exclusion_reason(source: MeshInstance3D) -> String:
	if source.has_meta(PROBE_META) or not source.is_visible_in_tree(): return "hidden_or_probe"
	if source.cast_shadow not in [GeometryInstance3D.SHADOW_CASTING_SETTING_ON, GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED]: return "no_original_shadow"
	if source.get_child_count() != 0 or source.get_parent() is not Node3D: return "children_or_parent"
	# Solo primitivas sin LOD: no introducir una silueta distinta a distancia.
	if source.mesh is not PrimitiveMesh or source.mesh.get_surface_count() != 1: return "nonprimitive"
	if source.skin != null or source.get_blend_shape_count() > 0: return "skin"
	if source.is_set_as_top_level() or not source.visibility_parent.is_empty() or source.custom_aabb != AABB(): return "custom_visibility"
	if source.visibility_range_begin != 0.0 or source.visibility_range_end != 0.0 or source.transparency != 0.0 or source.material_overlay != null: return "fade_or_overlay"
	if absf(source.global_basis.determinant()) < 0.000001: return "singular_transform"
	var bounds := source.global_transform * source.mesh.get_aabb()
	if maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) > CELL_SIZE: return "large_mesh"
	var material := source.get_active_material(0) as StandardMaterial3D
	if material == null: return "shader_or_missing_material"
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.next_pass != null: return "alpha_or_next_pass"
	if material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or material.grow or material.proximity_fade_enabled or material.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED: return "vertex_or_fade_effect"
	if material.no_depth_test or material.depth_draw_mode != BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY: return "custom_depth"
	# Conservador respecto a parallax, normales, SSS y deformación de vértices.
	if material.normal_enabled or material.heightmap_enabled or material.subsurf_scatter_enabled: return "special_depth_material"
	var arrays := source.mesh.surface_get_arrays(0)
	if GeometryProbe._attribute_format(arrays) < 0 or arrays[Mesh.ARRAY_NORMAL] == null or arrays[Mesh.ARRAY_NORMAL].size() != arrays[Mesh.ARRAY_VERTEX].size(): return "unsupported_arrays"
	return ""


static func _shadow_cull(source: MeshInstance3D) -> int:
	return BaseMaterial3D.CULL_DISABLED if source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED else (source.get_active_material(0) as StandardMaterial3D).cull_mode


func _merge(sources: Array, result: Dictionary) -> void:
	var first := sources[0] as MeshInstance3D
	var parent := first.get_parent() as Node3D
	var center := (first.global_transform * first.mesh.get_aabb()).get_center() / CELL_SIZE
	var world_origin := Vector3(floor(center.x), floor(center.y), floor(center.z)) * CELL_SIZE
	var batch_transform := Transform3D(Basis.IDENTITY, parent.to_local(world_origin))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for source: MeshInstance3D in sources:
		var arrays := source.mesh.surface_get_arrays(0)
		var relative := batch_transform.affine_inverse() * source.transform
		var normal_basis := relative.basis.inverse().transposed()
		var vertex_offset := vertices.size()
		var original_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in original_vertices:
			vertices.append(relative * vertex)
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
			normals.append((normal_basis * normal).normalized())
		var original_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := original_indices.size() if not original_indices.is_empty() else original_vertices.size()
		var winding: Array = [0, 2, 1] if relative.basis.determinant() < 0.0 else [0, 1, 2]
		for triangle in range(0, count, 3):
			for corner: int in winding:
				indices.append(vertex_offset + (original_indices[triangle + corner] if not original_indices.is_empty() else triangle + corner))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.cull_mode = _shadow_cull(first)
	mesh.surface_set_material(0, material)
	var batch := MeshInstance3D.new()
	batch.name = "StaticShadowBatchProbe"
	batch.set_meta(PROBE_META, true)
	batch.mesh = mesh
	batch.transform = batch_transform
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	batch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for property: StringName in COPY_PROPERTIES:
		batch.set(property, first.get(property))
	parent.add_child(batch)
	for source: MeshInstance3D in sources:
		_sources.append({"node": source, "cast_shadow": source.cast_shadow})
		source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_batches.append(batch)
	result.sources += sources.size()
	result.batches += 1
	result.triangles_before += indices.size() / 3
	result.triangles_after += indices.size() / 3
	result.array_bytes += vertices.size() * 24 + indices.size() * 4
