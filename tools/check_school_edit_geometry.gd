extends SceneTree
func _init() -> void:
	var source := "res://school_upper_floor.tscn"
	var scene := load(source).instantiate() as Node3D
	var geometry := {}
	var collisions := {}
	collect(scene, Transform3D.IDENTITY, geometry, collisions)
	var snapshot := {"geometry": geometry, "collisions": collisions}
	var path := "res://tools/school_edit_geometry.json"
	# Baseline captured from the original merged scene before conversion.
	if FileAccess.file_exists(path):
		var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		# A rebased primitive can round onto the adjacent millimetre bin.
		# Match those residual vertices with multiplicity, within 1.8 mm.
		var missing := {}
		var extra := {}
		for key in before.geometry:
			var count := int(before.geometry[key]) - int(geometry.get(key, 0))
			if count > 0: missing[key] = count
		for key in geometry:
			var count := int(geometry[key]) - int(before.geometry.get(key, 0))
			if count > 0: extra[key] = count
		for key in missing:
			var p := point_from_key(key)
			for other in extra:
				if extra[other] > 0 and p.distance_to(point_from_key(other)) < 0.0018:
					var count: int = mini(missing[key], extra[other])
					missing[key] -= count
					extra[other] -= count
					geometry[key] = geometry.get(key, 0) + count
					geometry[other] -= count
					if geometry[other] == 0: geometry.erase(other)
					if missing[key] == 0: break
		var changed := 0
		for section in ["geometry", "collisions"]:
			var section_changed := 0
			for key in before[section]:
				if before[section][key] != snapshot[section].get(key, -1):
					changed += 1
					section_changed += 1
					if section_changed < 8: print(section, " ", key, " before=", before[section][key], " after=", snapshot[section].get(key, -1))
			for key in snapshot[section]:
				if not before[section].has(key): changed += 1
		print("EDIT GEOMETRY: ", changed, " changed vertex/collision signatures")
		print("Serialized navigation obstacles: ", scene.find_children("*", "NavigationObstacle3D", true, false).size())
		print("Geometry signature check completed")
		if changed > 0:
			scene.free()
			quit(1)
			return
	else:
		push_error("Missing original school geometry baseline")
		scene.free()
		quit(1)
		return
	scene.free()
	quit()
func point_from_key(key: String) -> Vector3:
	var values := key.trim_prefix("(").trim_suffix(")").split(",")
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
func collect(node: Node, parent_transform: Transform3D, geometry: Dictionary, collisions: Dictionary) -> void:
	var t := parent_transform
	if node is Node3D: t = t * node.transform
	if node is MeshInstance3D and node.mesh:
		for point in node.mesh.get_faces():
			var key := str((t * point + Vector3.ONE * 0.001234).snapped(Vector3.ONE * 0.001))
			geometry[key] = geometry.get(key, 0) + 1
	if node is CollisionShape3D and node.shape:
		for point in node.shape.get_debug_mesh().get_faces():
			var key := str((t * point + Vector3.ONE * 0.001234).snapped(Vector3.ONE * 0.001)) + str(node.disabled)
			collisions[key] = collisions.get(key, 0) + 1
	for n in node.get_children(): collect(n, t, geometry, collisions)
