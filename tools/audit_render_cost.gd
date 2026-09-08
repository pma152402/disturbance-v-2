extends SceneTree
func _init() -> void:
	var house: Node3D = load("res://levels/house_baked.tscn").instantiate()
	var school: Node3D = load("res://environment/school_upper_floor.tscn").instantiate()
	var weather: Node3D = load("res://environment/rainy_weather.tscn").instantiate()
	var totals := {"meshes":0,"surfaces":0,"triangles":0,"materials":{},"lights":0,"shadow_lights":0,"unfaded_lights":0,"particles":0,"particle_amount":0,"multimeshes":0}
	scan(house,totals)
	scan(weather,totals)
	print(JSON.stringify({"meshes":totals.meshes,"surfaces":totals.surfaces,"triangles":totals.triangles,"materials":totals.materials.size(),"lights":totals.lights,"shadow_lights":totals.shadow_lights,"unfaded_lights":totals.unfaded_lights,"particles":totals.particles,"particle_amount":totals.particle_amount,"multimeshes":totals.multimeshes},"  "))
	var school_totals := {"meshes":0,"surfaces":0,"triangles":0,"materials":{},"lights":0,"shadow_lights":0,"unfaded_lights":0,"particles":0,"particle_amount":0,"multimeshes":0}
	scan(school,school_totals)
	print("SCHOOL ",JSON.stringify({"meshes":school_totals.meshes,"triangles":school_totals.triangles,"lights":school_totals.lights,"shadow_lights":school_totals.shadow_lights,"materials":school_totals.materials.size()}))
	house.free(); school.free(); weather.free(); quit()
func scan(node: Node, totals: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh:
		totals.meshes += 1
		totals.surfaces += node.mesh.get_surface_count()
		for s in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(s)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			totals.triangles += (indices.size() if indices.size() else vertices.size()) / 3
			var material: Material = node.get_active_material(s)
			if material: totals.materials[material.get_instance_id()] = true
	if node is MultiMeshInstance3D: totals.multimeshes += 1
	if node is Light3D:
		totals.lights += 1
		if node.shadow_enabled: totals.shadow_lights += 1
		if node is OmniLight3D and not node.distance_fade_enabled: totals.unfaded_lights += 1
	if node is GPUParticles3D:
		totals.particles += 1
		totals.particle_amount += node.amount
	for n in node.get_children(): scan(n,totals)
