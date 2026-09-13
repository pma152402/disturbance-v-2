extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var field := (load("res://environment/dirt_football_field.tscn") as PackedScene).instantiate()
	root.add_child(field)
	await process_frame
	assert(not field.has_node("Generated"))
	assert(field.get_node("Goals").get_child_count() == 2)
	assert(field.get_node("Goals/NorthGoal").position.z == -15.0)
	assert(field.get_node("Goals/SouthGoal").position.z == 15.0)
	for node in field.find_children("*", "", true, false):
		assert(node.owner == field, "Node is not saved/editable: " + str(node.name))
	for end_name in ["NorthEnd", "SouthEnd"]:
		var end := field.get_node("Markings/" + end_name)
		var s := -1.0 if end_name == "NorthEnd" else 1.0
		var arc: MeshInstance3D = end.get_node("PenaltyArc")
		var vertices: PackedVector3Array = arc.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var first := (vertices[0] + vertices[1]) / 2 + arc.position
		var last := (vertices[-2] + vertices[-1]) / 2 + arc.position
		assert(absf(first.z - s * 10.2) < 0.0001)
		assert(absf(last.z - s * 10.2) < 0.0001)
		for corner_name in ["WestCorner", "EastCorner"]:
			var corner: MeshInstance3D = end.get_node(corner_name)
			var points: PackedVector3Array = corner.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for i in range(0, points.size(), 2):
				var p := (points[i] + points[i+1]) / 2 + corner.position
				assert(absf(p.x) <= 9.0001 and absf(p.z) <= 15.0001)
	var line: Node3D = field.get_node("Markings/HalfwayLine")
	line.position.y = 0.123
	await process_frame
	assert(is_equal_approx(line.position.y, 0.123))
	print("PASS: editable scene, persistent edits, preserved goals, penalty intersections and inward corners")
	quit()
