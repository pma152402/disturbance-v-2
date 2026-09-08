extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var actor := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual") as Node3D
	visual.set_physics_process(false)
	var hair := actor.get_node("FloatingHair") as MeshInstance3D
	var head := visual.get_node("CleanModel/EditableGrannyRig/HeadPivot") as Node3D
	if hair.mesh == null or hair.mesh.get_surface_count() != 1:
		_fail("El cabello procedural no generó su superficie")
		return
	var arrays := hair.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var total_strands := int(hair.get("strand_count")) + int(hair.get("crown_strand_count")) + int(hair.get("front_wisp_count"))
	var expected_vertices := total_strands * (int(hair.get("segments_per_strand")) + 1) * 2
	if vertices.size() != expected_vertices or uvs.size() != vertices.size() or uv2s.size() != vertices.size():
		_fail("La topología o los datos de fase del cabello están incompletos")
		return
	var root_count := 0
	var maximum_length := 0.0
	var vertices_per_strand := (int(hair.get("segments_per_strand")) + 1) * 2
	var crown_roots := 0
	var front_roots := 0
	var surface_roots := 0
	for strand in total_strands:
		var first := strand * vertices_per_strand
		var last := first + vertices_per_strand - 2
		if is_zero_approx(uvs[first].y) and is_zero_approx(uvs[first + 1].y):
			root_count += 1
		var root := (vertices[first] + vertices[first + 1]) * 0.5
		if root.y > 0.50:
			crown_roots += 1
		if root.z > 0.43:
			front_roots += 1
		var normalized_root := Vector3((root.x + 0.003) / 0.372, (root.y - 0.25) / 0.365, (root.z - 0.185) / 0.305)
		if normalized_root.length() >= 0.94:
			surface_roots += 1
		maximum_length = maxf(maximum_length, vertices[first].distance_to(vertices[last]))
	if root_count != total_strands or maximum_length < 0.5 or crown_roots < 10 or front_roots < 8:
		_fail("Faltan raíces visibles en coronilla/frente o mechones realmente largos")
		return
	if surface_roots < total_strands - 2:
		_fail("Hay raíces de pelo enterradas dentro del volumen de la cabeza")
		return
	var material := hair.material_override as ShaderMaterial
	if material == null or material.shader == null or "unnatural_lift" not in material.shader.code:
		_fail("Falta la deformación flotante del cabello")
		return
	actor.set("current_state", 3)
	for frame in 90:
		actor.set("_motion_phase", frame / 60.0 * 4.0)
		visual.call(&"_physics_process", 1.0 / 60.0)
		hair.call(&"_process", 1.0 / 60.0)
	if hair.global_position.distance_to(head.global_position) > 0.0001:
		_fail("El cabello se separa de la cabeza durante la animación")
		return
	if absf(hair.global_basis.get_scale().x - 1.0) > 0.001:
		_fail("El cabello heredó la escala deformada del GLB")
		return
	print("FLOATING HAIR PASSED: strands=%d surface=%d crown=%d front=%d vertices=%d longest=%.2fm root_error=%.6fm" % [
		root_count, surface_roots, crown_roots, front_roots, vertices.size(), maximum_length,
		hair.global_position.distance_to(head.global_position),
	])
	actor.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
