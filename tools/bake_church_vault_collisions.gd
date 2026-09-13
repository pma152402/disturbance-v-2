extends SceneTree
## Bake the eight sheared vault meshes into unscaled convex collision hulls.
## Text insertion preserves existing instance overrides and node identifiers.
func _init() -> void:
	var path := "res://levels/house_baked.tscn"
	var source := FileAccess.get_file_as_string(path)
	if "ChurchVaultSurfaceCollision1" in source:
		print("Church vault collisions already baked")
		quit(0)
		return
	var scene := load(path).instantiate() as Node3D
	var resources := ""
	var nodes := ""
	for index in range(1, 9):
		var mesh := scene.get_node("UpperFloor/ChurchVaultPanel%d" % index) as MeshInstance3D
		var bounds := mesh.mesh.get_aabb()
		var values := PackedStringArray()
		for corner in 8:
			var point := mesh.transform * bounds.get_endpoint(corner)
			for value in [point.x, point.y, point.z]:
				values.append("%.8f" % value)
		resources += '[sub_resource type="ConvexPolygonShape3D" id="ChurchVaultHull%d"]\npoints = PackedVector3Array(%s)\n\n' % [index, ", ".join(values)]
		nodes += '\n[node name="ChurchVaultSurfaceCollision%d" type="StaticBody3D" parent="UpperFloor"]\ncollision_layer = 524288\n\n[node name="Collision" type="CollisionShape3D" parent="UpperFloor/ChurchVaultSurfaceCollision%d"]\nshape = SubResource("ChurchVaultHull%d")\n' % [index, index, index]
	var first_node := source.find("[node ")
	source = source.insert(first_node, resources) + nodes
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	scene.free()
	print("Baked eight vault hulls matching the visible ceiling")
	quit(0)
