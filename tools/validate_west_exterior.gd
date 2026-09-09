extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var bounds = load("res://environment/west_extension_bounds.gd")
	var exterior = load("res://environment/exterior_environment.tscn").instantiate()
	root.add_child(exterior)
	var audio = load("res://sounds/ambient/indoor_weather_audio.gd").new()
	var failures: int = 0
	for point in [Vector3(-19,1.8,-10), Vector3(-18,1.8,2), Vector3(-24.8,1.8,-4), Vector3(-28,1.8,-10), Vector3(-28,1.8,2)]:
		if not exterior._is_inside_house_footprint(point,0) or audio._get_acoustic_level(point) != 1.0:
			push_error("Interior not covered: " + str(point))
			failures += 1
	for point in [Vector3(-32,1.8,-4), Vector3(-25,1.8,-10), Vector3(-19,5,2)]:
		if audio._is_inside_explicit_volume(point):
			push_error("Exterior incorrectly treated as indoor: " + str(point))
			failures += 1
	var expected_instances := {
		"Vegetation/Grass": 2500,
		"Vegetation/TallGrass": 800,
		"Vegetation/PaleWeeds": 600,
		"Vegetation/GroundCover": 700,
		"Trees": 220,
	}
	for node_name: String in expected_instances:
		var container := exterior.get_node(node_name) as MultiMeshInstance3D
		var multimeshes := _collect_multimeshes(container)
		var instance_total := 0
		if multimeshes.size() <= 1:
			push_error("Exterior group is not spatially partitioned: " + node_name)
			failures += 1
		for mm in multimeshes:
			instance_total += mm.instance_count
			for i in mm.instance_count:
				if bounds.contains_ground_point(mm.get_instance_transform(i).origin, 0.4):
					failures += 1
		if instance_total != int(expected_instances[node_name]):
			push_error("Unexpected instance count in %s: %d" % [node_name, instance_total])
			failures += 1
	var fence: MultiMesh = exterior.get_node("Fence/Visual").multimesh
	for i in fence.instance_count:
		var box: AABB = fence.get_instance_transform(i) * fence.mesh.get_aabb()
		for rect in bounds.FOOTPRINTS:
			if Rect2(box.position.x,box.position.z,box.size.x,box.size.z).intersects(rect):
				failures += 1
	await physics_frame
	await physics_frame
	var space = exterior.get_world_3d().direct_space_state
	var old_fence = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-25,0.8,-4), Vector3(-23,0.8,-4),1))
	var new_fence = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-35,0.8,-4), Vector3(-33,0.8,-4),1))
	if not old_fence.is_empty() or new_fence.is_empty():
		failures += 1
	print("West extension exterior/audio validation failures: ", failures)
	audio.free()
	exterior.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _collect_multimeshes(container: MultiMeshInstance3D) -> Array[MultiMesh]:
	var result: Array[MultiMesh] = []
	if container.multimesh != null:
		result.append(container.multimesh)
	for child in container.get_children():
		if child is MultiMeshInstance3D and child.multimesh != null:
			result.append(child.multimesh)
	return result
