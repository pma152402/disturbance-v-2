extends SceneTree
var roots := []
func _initialize() -> void:
	call_deferred(&"_run")
func _root(index: int) -> int:
	while roots[index] != index:
		roots[index] = roots[roots[index]]
		index = roots[index]
	return index
func _run() -> void:
	var actor := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("EditableVisual").set_physics_process(false)
	var body := actor.get_node("EditableVisual/CleanModel/EditableGrannyRig/Body") as MeshInstance3D
	print("BODY ", body.get_aabb(), " transform ", body.global_transform)
	for surface in body.mesh.get_surface_count():
		print("SURFACE ", surface)
		var arrays := body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var welded := {}
		roots.clear()
		for index in vertices.size():
			var key := vertices[index].snapped(Vector3.ONE * 0.0001)
			roots.append(welded.get(key, index))
			welded[key] = roots[index]
		for triangle in range(0, indices.size(), 3):
			var first := _root(indices[triangle])
			roots[_root(indices[triangle+1])] = first
			roots[_root(indices[triangle+2])] = first
		var components := {}
		for index in vertices.size():
			var component := _root(index)
			var point := body.to_global(vertices[index])
			if not components.has(component):
				components[component] = {"count":0,"bounds":AABB(point,Vector3.ZERO)}
			components[component].count += 1
			components[component].bounds = components[component].bounds.expand(point)
		for component in components.values():
			if component.count > 5:
				print(component)
	actor.queue_free()
	await process_frame
	quit()
