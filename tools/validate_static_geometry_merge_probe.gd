extends SceneTree

## Validacion sintetica y headless del prototipo, sin iniciar el juego.
## Los arrays del ArrayMesh se comprueban solo si el renderer los conserva.
## No verifica el resultado visual, el culling por celda ni la ganancia de FPS.
const Probe := preload("res://tools/static_geometry_merge_probe.gd")
const POSITION_TOLERANCE := 0.00001
const DIRECTION_TOLERANCE := 0.001

var _failed := false
var _checks := 0
var _array_checks := 0
var _max_position_error := 0.0
var _max_normal_error := 0.0
var _max_tangent_error := 0.0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if "--merge-internals" in OS.get_cmdline_user_args():
		_run_geometry_only()
		return
	if "--inspect-connections" in OS.get_cmdline_user_args():
		for scene_name: String in ["dirty_laundry_basket", "detailed_wood_fired_oven", "shoe_dresser"]:
			var prop := (load("res://house_props/%s.tscn" % scene_name) as PackedScene).instantiate()
			var members := prop.find_children("*", "MeshInstance3D", true, false)
			if not members.is_empty():
				_print_connections(members[0], scene_name + "/" + str(prop.get_path_to(members[0])))
			prop.free()
	var probe := Probe.new()
	var fixtures: Array[Dictionary] = [
		_make_fixture("RotatedNonuniform", Vector3(1.8, 1.8, 1.8)),
		_make_fixture("SecondBranch", Vector3(9.8, 1.8, 1.8)),
	]
	var reports: Array[Dictionary] = []
	for fixture in fixtures:
		var stats := probe.install(fixture.branch)
		reports.append(stats)
		_check_counts(stats, fixture)
		_check_fixture(fixture, true)
		var batches := _find_batches(fixture.branch)
		_check(batches.size() == 1, "Una sola malla combinada por rama")
		if batches.size() == 1:
			_check_batch(batches[0], fixture)
		var second := probe.install(fixture.branch)
		_check(int(second.merged_meshes) == 0 and int(second.batch_count) == 0, "Instalar dos veces es idempotente")
		_check(_find_batches(fixture.branch).size() == 1, "La segunda instalacion no duplica batches")
	probe.restore()
	for fixture in fixtures:
		_check_fixture(fixture, false)
		_check(_find_batches(fixture.branch).is_empty(), "restore elimina todos los batches de ambas ramas")
	probe.restore()
	for fixture in fixtures:
		_check_fixture(fixture, false)
	# La misma instancia del diagnostico debe poder reutilizarse tras restore.
	var repeated := probe.install(fixtures[0].branch)
	_check_counts(repeated, fixtures[0])
	probe.restore()
	_check_fixture(fixtures[0], false)
	# Una conexion de gameplay debe seguir excluyendo el mesh aunque el motor
	# tambien conecte sus notificaciones internas al recurso PrimitiveMesh.
	for state: Dictionary in fixtures[0].sources:
		(state.node as MeshInstance3D).visibility_changed.connect(_on_test_visibility)
	var with_callbacks := probe.install(fixtures[0].branch)
	_check(int(with_callbacks.merged_meshes) == 0 and int(with_callbacks.skipped.get("script_motion_or_connections_branch", 0)) == 3, "Los callbacks de gameplay impiden el merge")
	_check_fixture(fixtures[0], false)
	var report := {
		"checks": _checks, "branches": reports, "array_checks": _array_checks,
		"merged_arrays_available": _array_checks > 0,
		"max_world_vertex_error_m": _max_position_error if _array_checks > 0 else null,
		"max_world_normal_error": _max_normal_error if _array_checks > 0 else null,
		"max_world_tangent_error": _max_tangent_error if _array_checks > 0 else null,
		"visual_and_gpu_validation": "pendiente; este script no mide FPS ni rasterizacion",
	}
	print("STATIC_GEOMETRY_MERGE_VALIDATION ", JSON.stringify(report))
	for fixture in fixtures:
		(fixture.branch as Node).free()
	if not _failed:
		print("OK: merge restaurable, geometria disponible comprobada y colisiones hermanas intactas.")
	quit(1 if _failed else 0)


func _run_geometry_only() -> void:
	# Aisla el horneado cuando un filtro de elegibilidad falla. No sustituye la
	# validacion normal de install: las fuentes se entregan explicitamente.
	var fixture := _make_fixture("GeometryOnly", Vector3(1.8, 1.8, 1.8))
	var probe := Probe.new()
	var sources: Array = []
	for state: Dictionary in fixture.sources:
		sources.append(state.node)
	var stats := {"merged_meshes": 0, "batch_count": 0, "triangles_before": 0, "triangles_after": 0, "added_array_bytes": 0}
	probe.call(&"_merge", sources, stats)
	_check(int(stats.merged_meshes) == 3 and int(stats.batch_count) == 1, "Horneado explicito de tres primitivas")
	var batches := _find_batches(fixture.branch)
	_check(batches.size() == 1, "Batch explicito creado")
	if batches.size() == 1:
		_check_batch(batches[0], fixture)
	_check_fixture(fixture, true)
	probe.restore()
	_check_fixture(fixture, false)
	print("GEOMETRY_ONLY_VALIDATION ", JSON.stringify({"stats": stats, "array_checks": _array_checks,
		"max_world_vertex_error_m": _max_position_error if _array_checks > 0 else null,
		"max_world_normal_error": _max_normal_error if _array_checks > 0 else null,
		"max_world_tangent_error": _max_tangent_error if _array_checks > 0 else null,
		"install_validation": "NO ejecutada en este modo"}))
	(fixture.branch as Node).free()
	quit(1 if _failed else 0)


func _make_fixture(label: String, origin: Vector3) -> Dictionary:
	var branch := Node3D.new()
	branch.name = label
	root.add_child(branch)
	var parent := StaticBody3D.new()
	parent.name = "CommonStaticParent"
	parent.transform = Transform3D(Basis.from_euler(Vector3(0.31, -0.42, 0.23)) * Basis.from_scale(Vector3(1.3, 0.7, 1.1)), origin)
	parent.collision_layer = 5
	parent.collision_mask = 10
	branch.add_child(parent)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.5, 0.7)
	material.roughness = 0.65
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.2, 0.25)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.15
	cylinder.height = 0.3
	cylinder.radial_segments = 8
	cylinder.rings = 1
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	sphere.radial_segments = 8
	sphere.rings = 4
	var meshes: Array[PrimitiveMesh] = [box, cylinder, sphere]
	var sources: Array[Dictionary] = []
	var triangles := 0
	for index in meshes.size():
		var source := MeshInstance3D.new()
		source.name = "Primitive%d" % index
		source.mesh = meshes[index]
		source.material_override = material
		source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		source.layers = 5
		source.extra_cull_margin = 0.12
		var scale_value := Vector3(-0.7, 1.2, 0.9) if index == 1 else Vector3(0.8, 1.1, 0.9)
		source.transform = Transform3D(Basis.from_euler(Vector3(0.17 * index, 0.23, -0.12 * index)) * Basis.from_scale(scale_value), Vector3(0.2 * (index - 1), 0.04 * index, 0.0))
		parent.add_child(source)
		var arrays := source.mesh.surface_get_arrays(0)
		_check(arrays.size() == Mesh.ARRAY_MAX and not arrays[Mesh.ARRAY_VERTEX].is_empty(), "La primitiva conserva sus arrays de origen")
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		triangles += indices.size() / 3
		sources.append({"node": source, "mesh": source.mesh, "material": material,
			"transform": source.transform, "world": source.global_transform,
			"arrays": arrays, "visible": source.visible})
	var hidden := MeshInstance3D.new()
	hidden.name = "OriginallyHidden"
	hidden.mesh = box
	hidden.material_override = material
	hidden.visible = false
	parent.add_child(hidden)
	var collision := CollisionShape3D.new()
	collision.name = "SiblingCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.4, 0.5)
	collision.shape = shape
	collision.transform = Transform3D(Basis.from_euler(Vector3(0.11, 0.22, 0.33)), Vector3(0.0, 0.2, 0.0))
	parent.add_child(collision)
	return {"branch": branch, "parent": parent, "sources": sources,
		"hidden": hidden, "triangles": triangles, "collision": collision,
		"shape": shape, "shape_size": shape.size, "collision_world": collision.global_transform,
		"collision_path": collision.get_path(), "parent_world": parent.global_transform}


func _check_counts(stats: Dictionary, fixture: Dictionary) -> void:
	_check(JSON.parse_string(JSON.stringify(stats)) is Dictionary, "Las estadisticas son serializables")
	_check(int(stats.scanned_meshes) == 4, "Se inspeccionan tres primitivas y un control oculto")
	_check(int(stats.eligible_meshes) == 3 and int(stats.merged_meshes) == 3, "Se agrupan las tres primitivas distintas")
	_check(int(stats.batch_count) == 1 and int(stats.instance_reduction) == 2, "Tres instancias se convierten en una")
	_check(int(stats.triangles_before) == int(fixture.triangles) and int(stats.triangles_after) == int(fixture.triangles), "No se anaden ni eliminan triangulos")
	_check(int(stats.added_array_bytes) > 0, "Se declara la memoria adicional de arrays")


func _check_fixture(fixture: Dictionary, merged: bool) -> void:
	for state: Dictionary in fixture.sources:
		var source := state.node as MeshInstance3D
		_check(source.visible == (false if merged else bool(state.visible)), "La visibilidad original se restaura")
		_check(source.mesh == state.mesh and source.get_active_material(0) == state.material, "Malla y material originales intactos")
		_check(source.transform == state.transform and source.global_transform == state.world, "Transformaciones originales intactas")
	_check(not (fixture.hidden as MeshInstance3D).visible, "El control oculto nunca se revela")
	var collision := fixture.collision as CollisionShape3D
	_check(collision.shape == fixture.shape and collision.shape.size == fixture.shape_size, "Shape de colision original intacta")
	_check(collision.global_transform == fixture.collision_world and collision.get_path() == fixture.collision_path and not collision.disabled, "Ruta, transformacion y activacion de colision intactas")
	var parent := fixture.parent as StaticBody3D
	_check(parent.global_transform == fixture.parent_world and parent.collision_layer == 5 and parent.collision_mask == 10, "Transformacion y capas del cuerpo intactas")


func _check_batch(batch: MeshInstance3D, fixture: Dictionary) -> void:
	var first: MeshInstance3D = fixture.sources[0].node
	_check(batch.get_parent() == first.get_parent(), "El batch conserva el padre espacial")
	_check(batch.get_active_material(0) == first.get_active_material(0), "El batch comparte el material original")
	for property: StringName in Probe.RENDER_PROPERTIES:
		_check(batch.get(property) == first.get(property), "Propiedad de render conservada: %s" % property)
	var arrays := batch.mesh.surface_get_arrays(0)
	if arrays.size() != Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].is_empty():
		print("LIMITACION: el renderer no conserva arrays del ArrayMesh; sin afirmacion de equivalencia geometrica.")
		return
	_array_checks += 1
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var vertex_offset := 0
	var index_offset := 0
	var batch_normal_basis := batch.global_basis.inverse().transposed()
	for state: Dictionary in fixture.sources:
		var original: Array = state.arrays
		var source_world: Transform3D = state.world
		var source_normal_basis := source_world.basis.inverse().transposed()
		var source_vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = original[Mesh.ARRAY_NORMAL]
		var source_tangents: PackedFloat32Array = original[Mesh.ARRAY_TANGENT]
		var source_uv: PackedVector2Array = original[Mesh.ARRAY_TEX_UV]
		for i in source_vertices.size():
			var position_error := (source_world * source_vertices[i]).distance_to(batch.global_transform * vertices[vertex_offset + i])
			_max_position_error = maxf(_max_position_error, position_error)
			var normal_error := (source_normal_basis * source_normals[i]).normalized().distance_to((batch_normal_basis * normals[vertex_offset + i]).normalized())
			_max_normal_error = maxf(_max_normal_error, normal_error)
			_check(uv[vertex_offset + i].is_equal_approx(source_uv[i]), "UV conservadas")
			var offset := i * 4
			var merged_offset := (vertex_offset + i) * 4
			var original_tangent := Vector3(source_tangents[offset], source_tangents[offset + 1], source_tangents[offset + 2])
			var merged_tangent := Vector3(tangents[merged_offset], tangents[merged_offset + 1], tangents[merged_offset + 2])
			_max_tangent_error = maxf(_max_tangent_error, (source_world.basis * original_tangent).normalized().distance_to((batch.global_basis * merged_tangent).normalized()))
			_check(is_equal_approx(source_tangents[offset + 3] * signf(source_world.basis.determinant()), tangents[merged_offset + 3] * signf(batch.global_basis.determinant())), "Orientacion de tangente conservada con escala negativa")
		var source_indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
		var reversed := signf(source_world.basis.determinant()) != signf(batch.global_basis.determinant())
		var corner_order: Array = [0, 2, 1] if reversed else [0, 1, 2]
		for triangle in range(0, source_indices.size(), 3):
			for corner in 3:
				_check(indices[index_offset + triangle + corner] == vertex_offset + source_indices[triangle + corner_order[corner]], "Indices y winding conservan las caras bajo reflexion")
		vertex_offset += source_vertices.size()
		index_offset += source_indices.size()
	_check(vertex_offset == vertices.size() and index_offset == indices.size(), "No hay vertices ni indices adicionales")
	_check(_max_position_error <= POSITION_TOLERANCE, "Error geometrico mundial dentro de tolerancia")
	_check(_max_normal_error <= DIRECTION_TOLERANCE, "Normales mundiales dentro de tolerancia")
	_check(_max_tangent_error <= DIRECTION_TOLERANCE, "Tangentes mundiales dentro de tolerancia")


func _find_batches(branch: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in branch.get_children():
		if child is MeshInstance3D and child.has_meta(Probe.PROBE_META):
			result.append(child)
		result.append_array(_find_batches(child))
	return result


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("FALLO: " + message)


func _print_connections(node: Node, label := "") -> void:
	var outgoing: Array = []
	for signal_info in node.get_signal_list():
		outgoing.append_array(node.get_signal_connection_list(signal_info.name))
	print("CONNECTION_PROBE ", str(node.get_path()) if label.is_empty() else label, " incoming=", node.get_incoming_connections(), " outgoing=", outgoing)
	for connection: Dictionary in node.get_incoming_connections():
		var callback: Callable = connection.callable
		var source_signal: Signal = connection.signal
		print("CONNECTION_DETAILS ", callback.get_method(), " custom=", callback.is_custom(), " target_is_node=", callback.get_object() == node,
			" source_is_mesh=", source_signal.get_object() == (node as MeshInstance3D).mesh,
			" source_is_material=", source_signal.get_object() == (node as MeshInstance3D).get_active_material(0))


func _on_test_visibility() -> void:
	pass
