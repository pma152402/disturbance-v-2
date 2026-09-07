extends SceneTree
func _init() -> void:
	var house: Node3D = load("res://levels/house_baked.tscn").instantiate()
	for path in ["Wall_08/Mesh", "Wall_08/Collision", "WallBaseboard_08", "WindowGlass_06/Mesh", "WindowLowerWall_06/Mesh", "WindowUpperWall_06/Mesh"]:
		var n: Node3D = house.get_node("UpperFloor/ExteriorWalls/" + path)
		print(path, " transform=", n.transform, " size=", n.mesh.size if n is MeshInstance3D else n.shape.size)
	house.free()
	quit()
