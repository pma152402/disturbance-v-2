extends SceneTree


func _initialize() -> void:
	var house := (load("res://levels/house_baked.tscn") as PackedScene).instantiate()
	root.add_child(house)
	await process_frame
	var shapes: Array[Dictionary] = []
	var disabled := 0
	var total := 0
	var duplicates := {}
	var collision_paths := {}
	var branches := {}
	for node in house.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		total += 1
		var relative_path := str(house.get_path_to(collision))
		var branch := relative_path.get_slice("/", 0)
		branches[branch] = int(branches.get(branch, 0)) + 1
		if collision.disabled:
			disabled += 1
		if collision.shape == null:
			continue
		var size := _shape_size(collision.shape) * collision.global_basis.get_scale().abs()
		var volume := size.x * size.y * size.z
		shapes.append({"path": relative_path, "size": size, "volume": volume})
		var p := collision.global_position
		var key := "%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f" % [collision.shape.get_class(), p.x,p.y,p.z,size.x,size.y,size.z]
		duplicates[key] = int(duplicates.get(key, 0)) + 1
		if not collision_paths.has(key):
			collision_paths[key] = []
		collision_paths[key].append(relative_path)
	shapes.sort_custom(func(a, b): return a.volume > b.volume)
	var duplicate_count := 0
	for count in duplicates.values():
		if count > 1:
			duplicate_count += count - 1
	print("COLLISIONS total=%d disabled=%d exact_duplicates=%d" % [total, disabled, duplicate_count])
	print("BRANCHES ", branches)
	for key in duplicates:
		if duplicates[key] > 1:
			print("DUPLICATE ", collision_paths[key])
	for index in mini(20, shapes.size()):
		print("LARGE ", shapes[index].path, " size=", shapes[index].size)
	quit(0)


func _shape_size(shape: Shape3D) -> Vector3:
	if shape is BoxShape3D:
		return shape.size
	if shape is SphereShape3D:
		return Vector3.ONE * shape.radius * 2.0
	if shape is CapsuleShape3D:
		return Vector3(shape.radius * 2.0, shape.height, shape.radius * 2.0)
	if shape is CylinderShape3D:
		return Vector3(shape.radius * 2.0, shape.height, shape.radius * 2.0)
	return shape.get_debug_mesh().get_aabb().size
