extends RefCounted

## Prototipo de diagnostico, NO instalado en el juego. Ejecutar con escena
## estable, tras los optimizadores. install(House) o install(SchoolUpperFloor)
## devuelve estadisticas serializables. La instancia guarda restore().
## El script del branch explicito es la unica excepcion al filtro de scripts.
## Mantiene padres y originales; no agrupa transparencias, shaders, animacion,
## MultiMesh ni mallas importadas/LOD. Ninguna cifra representa FPS medidos.
const CELL_SIZE := 4.0
const MIN_GROUP_SIZE := 3
const PROBE_META := &"static_geometry_merge_probe"
const RENDER_PROPERTIES := [
	&"layers", &"cast_shadow", &"gi_mode", &"transparency",
	&"visibility_range_begin", &"visibility_range_begin_margin",
	&"visibility_range_end", &"visibility_range_end_margin", &"visibility_range_fade_mode",
	&"extra_cull_margin", &"ignore_occlusion_culling", &"sorting_offset",
	&"sorting_use_aabb_center", &"lod_bias",
]
const CHANNELS := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT,
	Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_INDEX]
var _batches: Array[MeshInstance3D] = []
var _original_visibility: Array[Dictionary] = []


func install(branch: Node3D) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := {"scanned_meshes": 0, "eligible_meshes": 0, "merged_meshes": 0,
		"batch_count": 0, "instance_reduction": 0, "triangles_before": 0,
		"triangles_after": 0, "added_array_bytes": 0, "build_ms": 0.0,
		"cell_size_m": CELL_SIZE, "skipped": {}}
	if not is_instance_valid(branch) or not branch.is_inside_tree():
		result.skipped["invalid_branch"] = 1
		return result
	var groups: Dictionary = {}
	_scan(branch, branch, groups, result)
	for sources: Array in groups.values():
		if sources.size() < MIN_GROUP_SIZE:
			_skip(result, "small_group", sources.size())
			continue
		_merge(sources, result)
	result.instance_reduction = int(result.merged_meshes) - int(result.batch_count)
	result.build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return result


func restore() -> void:
	for state: Dictionary in _original_visibility:
		var source: Variant = state.source
		if is_instance_valid(source):
			source.visible = bool(state.visible)
	for entry: Variant in _batches:
		if is_instance_valid(entry):
			(entry as Node).free()
	_original_visibility.clear()
	_batches.clear()


static func _scan(node: Node, boundary: Node, groups: Dictionary, result: Dictionary) -> void:
	if node != boundary:
		var unsafe := node.get_script() != null or node is RigidBody3D or node is CharacterBody3D or node is AnimatableBody3D
		unsafe = unsafe or node is AnimationPlayer or node is AnimationTree or _has_connections(node)
		if not unsafe:
			for child in node.get_children():
				if child is AnimationPlayer or child is AnimationTree:
					unsafe = true
		if unsafe:
			_skip(result, "script_motion_or_connections_branch", _count_meshes(node))
			return
	if node is MeshInstance3D:
		result.scanned_meshes += 1
		var source := node as MeshInstance3D
		var reason := _exclusion_reason(source)
		if not reason.is_empty():
			_skip(result, reason)
		else:
			var arrays := source.mesh.surface_get_arrays(0)
			var format := _attribute_format(arrays)
			if format < 0:
				_skip(result, "unsupported_vertex_format")
			else:
				var material := source.get_active_material(0)
				var bounds := source.global_transform * source.mesh.get_aabb()
				var center := bounds.get_center() / CELL_SIZE
				var cell := Vector3i(floori(center.x), floori(center.y), floori(center.z))
				var key: Array = [source.get_parent(), cell, material, format]
				for property: StringName in RENDER_PROPERTIES:
					key.append(source.get(property))
				if not groups.has(key):
					groups[key] = []
				groups[key].append(source)
				result.eligible_meshes += 1
	for child in node.get_children():
		_scan(child, boundary, groups, result)


static func _exclusion_reason(source: MeshInstance3D) -> String:
	if source.has_meta(PROBE_META) or not source.is_visible_in_tree():
		return "hidden_or_probe"
	if source.get_child_count() != 0 or source.get_parent() is not Node3D:
		return "children_or_nonspatial_parent"
	if source.mesh is not PrimitiveMesh or source.mesh.get_surface_count() != 1:
		return "nonprimitive_or_multisurface"
	# MeshInstance3D usa ".." como ruta skeleton incluso sin Skin. Los canales
	# de huesos se rechazan además en _attribute_format.
	if source.skin != null or source.get_blend_shape_count() > 0:
		return "skin_blend_or_skeleton"
	if source.is_set_as_top_level() or not source.visibility_parent.is_empty() or source.custom_aabb != AABB():
		return "custom_transform_or_visibility"
	if source.visibility_range_begin != 0.0 or source.visibility_range_end != 0.0 or source.transparency != 0.0 or source.material_overlay != null:
		return "visibility_fade_or_overlay"
	if absf(source.transform.basis.determinant()) < 0.000001 or absf(source.global_basis.determinant()) < 0.000001:
		return "singular_transform"
	var bounds := source.global_transform * source.mesh.get_aabb()
	if maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) > CELL_SIZE:
		return "larger_than_cell"
	var material := source.get_active_material(0) as StandardMaterial3D
	if material == null:
		return "shader_or_missing_material"
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.next_pass != null:
		return "transparent_or_next_pass"
	if material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or material.grow or material.proximity_fade_enabled or material.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
		return "material_vertex_or_fade_effect"
	if (material.uv1_triplanar and not material.uv1_world_triplanar) or (material.uv2_triplanar and not material.uv2_world_triplanar):
		return "local_triplanar"
	if material.normal_enabled or material.heightmap_enabled or material.anisotropy_enabled or material.subsurf_scatter_enabled:
		return "tangent_or_subsurface_material"
	return ""


static func _attribute_format(arrays: Array) -> int:
	if arrays.size() != Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
		return -1
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return -1
	var format := 0
	for channel in Mesh.ARRAY_MAX:
		if arrays[channel] == null or arrays[channel].is_empty():
			continue
		if channel not in CHANNELS:
			return -1
		# El indice se genera siempre. Los otros atributos deben coincidir para
		# unir superficies sin inventar colores, coordenadas o normales.
		if channel != Mesh.ARRAY_INDEX:
			format |= 1 << channel
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if (indices.size() if not indices.is_empty() else vertices.size()) % 3 != 0:
		return -1
	return format


func _merge(sources: Array, result: Dictionary) -> void:
	var first := sources[0] as MeshInstance3D
	var parent := first.get_parent() as Node3D
	var center := (first.global_transform * first.mesh.get_aabb()).get_center() / CELL_SIZE
	var world_origin := Vector3(floor(center.x), floor(center.y), floor(center.z)) * CELL_SIZE
	var local_origin := parent.to_local(world_origin)
	var batch_transform := Transform3D(Basis.IDENTITY, local_origin)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var indices := PackedInt32Array()
	var source_triangle_count := 0
	for source: MeshInstance3D in sources:
		var arrays := source.mesh.surface_get_arrays(0)
		var relative := batch_transform.affine_inverse() * source.transform
		var normal_basis := relative.basis.inverse().transposed()
		var determinant := relative.basis.determinant()
		var vertex_offset := vertices.size()
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in source_vertices:
			vertices.append(relative * vertex)
		if arrays[Mesh.ARRAY_NORMAL] != null:
			for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
				normals.append((normal_basis * normal).normalized())
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var source_tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for offset in range(0, source_tangents.size(), 4):
				var tangent := (relative.basis * Vector3(source_tangents[offset], source_tangents[offset + 1], source_tangents[offset + 2])).normalized()
				tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, source_tangents[offset + 3] * (-1.0 if determinant < 0.0 else 1.0)]))
		if arrays[Mesh.ARRAY_COLOR] != null:
			colors.append_array(arrays[Mesh.ARRAY_COLOR])
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			uv.append_array(arrays[Mesh.ARRAY_TEX_UV])
		if arrays[Mesh.ARRAY_TEX_UV2] != null:
			uv2.append_array(arrays[Mesh.ARRAY_TEX_UV2])
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var element_count := source_indices.size() if not source_indices.is_empty() else source_vertices.size()
		source_triangle_count += element_count / 3
		var winding: Array = [0, 2, 1] if determinant < 0.0 else [0, 1, 2]
		for triangle in range(0, element_count, 3):
			for corner in winding:
				indices.append(vertex_offset + (source_indices[triangle + corner] if not source_indices.is_empty() else triangle + corner))
	var combined: Array = []
	combined.resize(Mesh.ARRAY_MAX)
	combined[Mesh.ARRAY_VERTEX] = vertices
	if not normals.is_empty(): combined[Mesh.ARRAY_NORMAL] = normals
	if not tangents.is_empty(): combined[Mesh.ARRAY_TANGENT] = tangents
	if not colors.is_empty(): combined[Mesh.ARRAY_COLOR] = colors
	if not uv.is_empty(): combined[Mesh.ARRAY_TEX_UV] = uv
	if not uv2.is_empty(): combined[Mesh.ARRAY_TEX_UV2] = uv2
	combined[Mesh.ARRAY_INDEX] = indices
	var merged_mesh := ArrayMesh.new()
	# Sin cuantizar posiciones/UV adicionales ni generar LOD o triangulos nuevos.
	merged_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined)
	merged_mesh.surface_set_material(0, first.get_active_material(0))
	var batch := MeshInstance3D.new()
	batch.name = "StaticGeometryMergeProbe"
	batch.set_meta(PROBE_META, true)
	batch.mesh = merged_mesh
	batch.transform = batch_transform
	for property: StringName in RENDER_PROPERTIES:
		batch.set(property, first.get(property))
	parent.add_child(batch)
	for source: MeshInstance3D in sources:
		_original_visibility.append({"source": source, "visible": source.visible})
		source.hide()
	_batches.append(batch)
	result.merged_meshes += sources.size()
	result.batch_count += 1
	result.triangles_before += source_triangle_count
	result.triangles_after += indices.size() / 3
	result.added_array_bytes += (vertices.size() + normals.size()) * 12 + tangents.size() * 4 + colors.size() * 16 + (uv.size() + uv2.size()) * 8 + indices.size() * 4


static func _has_connections(node: Node) -> bool:
	for connection: Dictionary in node.get_incoming_connections():
		if not _is_native_resource_notification(node, connection):
			return true
	for signal_info in node.get_signal_list():
		if not node.get_signal_connection_list(signal_info.name).is_empty():
			return true
	return false


static func _is_native_resource_notification(node: Node, connection: Dictionary) -> bool:
	# MeshInstance3D conecta estas notificaciones al asignar sus recursos, incluso
	# en primitivas recien creadas sin scripts. No son callbacks de gameplay.
	if node is not MeshInstance3D or int(connection.flags) != 0:
		return false
	var callback: Callable = connection.callable
	var source_signal: Signal = connection.signal
	# Godot expone estos callables C++ como custom, con nombre cualificado.
	if callback.get_object() != node or not callback.is_custom() or callback.get_bound_arguments_count() != 0 or callback.get_unbound_arguments_count() != 0:
		return false
	var source := node as MeshInstance3D
	if source_signal.get_name() == &"changed" and callback.get_method() == &"MeshInstance3D::_mesh_changed":
		return source_signal.get_object() == source.mesh
	if source_signal.get_name() == &"property_list_changed" and callback.get_method() == &"Object::notify_property_list_changed":
		return source_signal.get_object() == source.get_active_material(0)
	return false


static func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count


static func _skip(result: Dictionary, reason: String, count := 1) -> void:
	result.skipped[reason] = int(result.skipped.get(reason, 0)) + count
