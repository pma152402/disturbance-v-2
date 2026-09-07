extends SceneTree

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var house := (load("res://levels/house_baked.tscn") as PackedScene).instantiate()
	house.set_script(null)
	root.add_child(house)
	for node in house.find_children("*", "MeshInstance3D", true, false):
		var path := str(house.get_path_to(node))
		if path.begins_with("ExteriorBasementAccess/BasementAccessAndInitialRoom/") or path.begins_with("FurnitureAndPickups/StraightThree"):
			print(path, " | ", node.global_transform * node.get_aabb())
	house.free()
	quit()
