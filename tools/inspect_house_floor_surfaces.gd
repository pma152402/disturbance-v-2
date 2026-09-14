extends SceneTree

func _initialize() -> void:
	var house := load("res://levels/house_baked.tscn").instantiate() as Node3D
	for branch_name in ["GroundFloor", "UpperFloor"]:
		var branch := house.get_node(branch_name)
		for node: Node in branch.get_children():
			if "FloorSlab" not in str(node.name) and str(node.name) != "Mesh2":
				continue
			var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
			if node is MeshInstance3D:
				meshes.append(node)
			for mesh: MeshInstance3D in meshes:
				var pose := mesh.transform
				var ancestor := mesh.get_parent()
				while ancestor != house:
					if ancestor is Node3D:
						pose = (ancestor as Node3D).transform * pose
					ancestor = ancestor.get_parent()
				print(house.get_path_to(mesh), " ", pose * mesh.get_aabb())
	house.free()
	quit()
