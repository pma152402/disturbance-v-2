extends SceneTree
## Validación sintética de geometría/datos; no requiere renderizador ni nivel.
const Probe := preload("res://systems/static_shadow_batcher.gd")
signal callback_probe
var _checks := 0
var _failures := 0

class ScriptedMesh extends MeshInstance3D:
	var mutable_state := 0

func _initialize() -> void:
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		if _failures <= 20:
			push_error(message)

func _noop() -> void:
	pass

func _make_group(parent: Node3D, label: String, cull: int = BaseMaterial3D.CULL_BACK, cast: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for index in 3:
		var node := MeshInstance3D.new()
		node.name = label + str(index)
		var primitive := BoxMesh.new()
		primitive.size = Vector3(0.45, 0.55, 0.35)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.2 + index * 0.22, 0.7 - index * 0.16, 0.3 + index * 0.11)
		material.cull_mode = cull
		primitive.material = material
		node.mesh = primitive
		node.cast_shadow = cast
		node.layers = 3
		node.extra_cull_margin = 0.15
		node.ignore_occlusion_culling = true
		var scales := Vector3(-0.8, 1.1, 0.7) if index == 1 else Vector3(0.7 + index * 0.12, 1.15, 0.85)
		node.transform = Transform3D(Basis.from_euler(Vector3(0.13 * index, 0.23, -0.08)).scaled(scales), Vector3(index * 0.25, index * 0.1, 0.0))
		parent.add_child(node)
		meshes.append(node)
	return meshes

func _snapshot(sources: Array[MeshInstance3D]) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for source in sources:
		states.append({"node": source, "mesh": source.mesh, "material": source.get_active_material(0),
			"override": source.material_override, "color": (source.get_active_material(0) as StandardMaterial3D).albedo_color,
			"visible": source.visible, "transform": source.transform, "cast": source.cast_shadow,
			"layers": source.layers, "gi": source.gi_mode, "vertices": source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array()})
	return states

func _compare_originals(states: Array[Dictionary], restored: bool) -> void:
	for state in states:
		var source: MeshInstance3D = state.node
		_check(is_instance_valid(source) and source.is_inside_tree(), "Se eliminó una malla original")
		_check(source.mesh == state.mesh and source.get_active_material(0) == state.material and source.material_override == state.override, "Se sustituyó malla/material de color")
		_check((source.get_active_material(0) as StandardMaterial3D).albedo_color == state.color, "Se alteró el color original")
		_check(source.visible == state.visible and source.transform == state.transform, "Se alteró visibilidad/transformación original")
		_check(source.layers == state.layers and source.gi_mode == state.gi, "Se alteraron capas o iluminación global original")
		_check(source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array() == state.vertices, "Se modificaron vértices del recurso original")
		_check(source.cast_shadow == (state.cast if restored else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "Estado de sombra original incorrecto")

func _triangles(source: MeshInstance3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var arrays := source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_transform := source.global_basis.inverse().transposed()
	for index in range(0, indices.size(), 3):
		var points: Array[Vector3] = []
		var directions: Array[Vector3] = []
		for corner in 3:
			var vertex_index := indices[index + corner]
			points.append(source.global_transform * vertices[vertex_index])
			directions.append((normal_transform * normals[vertex_index]).normalized())
		# El renderer invierte el frente al reflejar la instancia. Expresar aquí
		# ese frente efectivo permite comparar una instancia con un vértice horneado.
		var front := (points[2] - points[0]).cross(points[1] - points[0]).normalized() * signf(source.global_basis.determinant())
		result.append({"points": points, "normals": directions, "front": front})
	return result

func _same_triangle(a: Dictionary, b: Dictionary) -> bool:
	if (a.front as Vector3).distance_to(b.front) > 0.0002:
		return false
	var used: Array[int] = []
	for corner in 3:
		var matched := false
		for other in 3:
			if other not in used and (a.points[corner] as Vector3).distance_to(b.points[other]) < 0.00002 and (a.normals[corner] as Vector3).distance_to(b.normals[other]) < 0.0002:
				used.append(other)
				matched = true
				break
		if not matched:
			return false
	return true

func _validate_geometry() -> void:
	var branch := Node3D.new()
	root.add_child(branch)
	var all_sources: Array[MeshInstance3D] = []
	var expected_by_parent: Dictionary = {}
	var culls_by_parent: Dictionary = {}
	for mode in 4:
		var parent := Node3D.new()
		parent.name = "Group" + str(mode)
		var scales := Vector3(-1.2, 0.85, 1.1) if mode == 1 else Vector3(1.15, 0.82, 1.1)
		parent.transform = Transform3D(Basis.from_euler(Vector3(0.16, -0.23, 0.07)).scaled(scales), Vector3(2.0, 2.0, 2.0))
		branch.add_child(parent)
		var cull: int = [BaseMaterial3D.CULL_BACK, BaseMaterial3D.CULL_FRONT, BaseMaterial3D.CULL_DISABLED, BaseMaterial3D.CULL_BACK][mode]
		var cast := GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if mode == 3 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var sources := _make_group(parent, "Source", cull, cast)
		all_sources.append_array(sources)
		var expected: Array[Dictionary] = []
		for source in sources:
			expected.append_array(_triangles(source))
		expected_by_parent[parent] = expected
		culls_by_parent[parent] = BaseMaterial3D.CULL_DISABLED if mode == 3 else cull
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.4, 3.0)
	collider.shape = shape
	body.add_child(collider)
	branch.add_child(body)
	body.position = Vector3(4, -0.3, 1)
	var collision_state := [body.get_instance_id(), body.get_rid(), body.global_transform, body.collision_layer, body.collision_mask, collider.shape, collider.transform, collider.disabled, shape.size]
	var states := _snapshot(all_sources)
	var probe := Probe.new()
	var result := probe.install(branch)
	_check(result.sources == 12 and result.batches == 4, "No une materiales opacos distintos en cuatro grupos: " + str(result))
	_check(result.triangles_before == 144 and result.triangles_after == 144, "No conserva los 144 triángulos")
	_compare_originals(states, false)
	var batches: Array[MeshInstance3D] = []
	for candidate: Node in branch.find_children("*", "MeshInstance3D", true, false):
		if candidate.has_meta(Probe.PROBE_META):
			batches.append(candidate as MeshInstance3D)
	_check(batches.size() == 4, "Cantidad inesperada de mallas auxiliares")
	for batch in batches:
		_check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and batch.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "El auxiliar dibuja color o contribuye a GI")
		var original := batch.get_parent().get_child(0) as MeshInstance3D
		_check(batch.layers == original.layers and batch.extra_cull_margin == original.extra_cull_margin and batch.ignore_occlusion_culling == original.ignore_occlusion_culling, "Propiedades de descarte/capas diferentes")
		_check((batch.get_active_material(0) as StandardMaterial3D).cull_mode == culls_by_parent[batch.get_parent()], "Culling frontal/doble cara incorrecto")
		var expected: Array = expected_by_parent[batch.get_parent()].duplicate()
		var actual := _triangles(batch)
		_check(actual.size() == expected.size(), "Cantidad geométrica distinta")
		for triangle in actual:
			var found := -1
			for index in expected.size():
				if _same_triangle(triangle, expected[index]):
					found = index
					break
			_check(found >= 0, "Triángulo/normal/frente distinto con escalas no uniformes o reflejadas")
			if found >= 0:
				expected.remove_at(found)
		_check(expected.is_empty(), "Faltan triángulos originales")
	_check(collision_state == [body.get_instance_id(), body.get_rid(), body.global_transform, body.collision_layer, body.collision_mask, collider.shape, collider.transform, collider.disabled, shape.size], "Colisión alterada al agrupar")
	var repeated := probe.install(branch)
	_check(repeated.sources == 0 and repeated.batches == 0, "Instalación no idempotente")
	var second := Probe.new()
	_check(second.install(branch).sources == 0, "Otra instancia vuelve a agrupar auxiliares")
	second.restore()
	_compare_originals(states, false)
	probe.restore()
	_compare_originals(states, true)
	for batch in batches:
		_check(not is_instance_valid(batch), "restore conserva una sombra auxiliar")
	_check(collision_state == [body.get_instance_id(), body.get_rid(), body.global_transform, body.collision_layer, body.collision_mask, collider.shape, collider.transform, collider.disabled, shape.size], "Colisión alterada al restaurar")
	probe.restore()
	_compare_originals(states, true)
	_check(probe.install(branch).sources == 12, "No permite reinstalar tras restore")
	probe.restore()
	branch.free()

func _validate_exclusions() -> void:
	for kind in ["alpha", "scissor", "shader", "normalmap", "heightmap", "animation", "animation_tree", "boundary_animation", "boundary_animation_tree", "script", "callback_in", "callback_out", "hidden", "hidden_parent", "next_pass"]:
		var branch := Node3D.new()
		branch.position = Vector3(2, 2, 2)
		root.add_child(branch)
		var parent := Node3D.new()
		branch.add_child(parent)
		var sources := _make_group(parent, "Excluded")
		if kind == "animation": parent.add_child(AnimationPlayer.new())
		if kind == "animation_tree": parent.add_child(AnimationTree.new())
		if kind == "boundary_animation": branch.add_child(AnimationPlayer.new())
		if kind == "boundary_animation_tree": branch.add_child(AnimationTree.new())
		if kind == "hidden_parent": parent.hide()
		for source in sources:
			var material := source.get_active_material(0) as StandardMaterial3D
			match kind:
				"alpha": material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				"scissor": material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				"normalmap": material.normal_enabled = true
				"heightmap": material.heightmap_enabled = true
				"shader":
					var shader := Shader.new()
					shader.code = "shader_type spatial; void fragment() { ALBEDO = vec3(1.0); }"
					var custom := ShaderMaterial.new()
					custom.shader = shader
					source.material_override = custom
				"script": source.set_script(ScriptedMesh)
				"callback_in": callback_probe.connect(source.hide)
				"callback_out": source.visibility_changed.connect(_noop)
				"hidden": source.hide()
				"next_pass": material.next_pass = StandardMaterial3D.new()
		var probe := Probe.new()
		var result := probe.install(branch)
		_check(result.sources == 0 and result.batches == 0 and result.eligible == 0, "No excluye " + kind + ": " + str(result))
		for source in sources:
			_check(source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Exclusión cambia sombra: " + kind)
		probe.restore()
		branch.free()

func _validate_raster_boundaries() -> void:
	var branch := Node3D.new()
	branch.position = Vector3(2, 2, 2)
	root.add_child(branch)
	var sources: Array[MeshInstance3D] = []
	sources.append_array(_make_group(branch, "Back", BaseMaterial3D.CULL_BACK))
	sources.append_array(_make_group(branch, "Front", BaseMaterial3D.CULL_FRONT))
	sources.append_array(_make_group(branch, "None", BaseMaterial3D.CULL_DISABLED))
	sources.append_array(_make_group(branch, "Double", BaseMaterial3D.CULL_BACK, GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED))
	var states := _snapshot(sources)
	var probe := Probe.new()
	var result := probe.install(branch)
	_check(result.sources == 12 and result.batches == 3, "El mismo padre debe separar frente/dorso y unir doble cara compatible: " + str(result))
	var triangle_counts := {}
	for child in branch.get_children():
		if child is MeshInstance3D and child.has_meta(Probe.PROBE_META):
			var batch := child as MeshInstance3D
			var cull := (batch.get_active_material(0) as StandardMaterial3D).cull_mode
			triangle_counts[cull] = _triangles(batch).size()
	_check(triangle_counts.get(BaseMaterial3D.CULL_BACK, 0) == 36, "Grupo cull_back incompatible")
	_check(triangle_counts.get(BaseMaterial3D.CULL_FRONT, 0) == 36, "Grupo cull_front incompatible")
	_check(triangle_counts.get(BaseMaterial3D.CULL_DISABLED, 0) == 72, "Doble cara no combina rasterización equivalente")
	_compare_originals(states, false)
	probe.restore()
	_compare_originals(states, true)
	branch.free()

func _run() -> void:
	_validate_geometry()
	_validate_exclusions()
	_validate_raster_boundaries()
	print("STATIC_SHADOW_BATCH_PROBE checks=", _checks, " failures=", _failures)
	quit(1 if _failures else 0)
