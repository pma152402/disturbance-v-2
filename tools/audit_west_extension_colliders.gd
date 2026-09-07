extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var house: Node3D = load("res://levels/house_baked.tscn").instantiate()
	root.add_child(house)
	await physics_frame
	for wall_name in [
		"OfficeBackWall", "ExtensionSouthWall", "BranchWestWall",
		"BranchEastNorthWall", "BranchEastNorthWall2", "BranchEastSouthWall",
		"BranchNorthEnd", "BranchSouthEnd",
	]:
		var wall := house.get_node_or_null(wall_name) as StaticBody3D
		if wall == null or wall.find_children("*", "CollisionShape3D", true, false).is_empty():
			push_error("Extension wall has no collider: " + wall_name)
			quit(1)
			return
	for line in [
		[Vector3(-19, 1.0, -13.4), Vector3(-19, 1.0, -14.4)],
		[Vector3(-24.3, 1.0, -3.0), Vector3(-24.3, 1.0, -1.4)],
		[Vector3(-28, 1.0, -12.4), Vector3(-28, 1.0, -13.4)],
		[Vector3(-28, 1.0, 4.4), Vector3(-28, 1.0, 5.4)],
	]:
		var query := PhysicsRayQueryParameters3D.create(line[0], line[1], 1)
		if house.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			push_error("Missing extension wall collider on ray " + str(line))
			quit(1)
			return
	print("PASS: west extension wall colliders are present")
	house.queue_free()
	await process_frame
	quit()
