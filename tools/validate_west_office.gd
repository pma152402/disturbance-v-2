extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var house := load("res://levels/house_baked.tscn").instantiate() as Node3D
	root.add_child(house)
	await physics_frame
	await physics_frame
	var space := house.get_world_3d().direct_space_state
	for point in [Vector3(-16.7,1,-4),Vector3(-16.7,1,-8),Vector3(-24.5,1,-4),Vector3(-28,1,-4),Vector3(-28,1,-11),Vector3(-28,1,3)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point - Vector3(0,2,0),1))
		if hit.is_empty():
			push_error("Falta suelo: %s" % point)
			quit(1)
			return
	for pair in [[Vector3(-16.7,1,-3),Vector3(-16.7,1,-8)],[Vector3(-21,1,-4),Vector3(-28,1,-4)],[Vector3(-28,1,-4),Vector3(-28,1,-11)],[Vector3(-28,1,-4),Vector3(-28,1,3)]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pair[0],pair[1],1))
		if not hit.is_empty():
			push_error("Paso bloqueado: %s -> %s por %s" % [pair[0],pair[1],hit.collider.get_path()])
			quit(1)
			return
	var count := 0
	for child in house.get_children():
		if str(child.name).begins_with("Office") and not child.scene_file_path.is_empty(): count += 1
	for piece in ["OfficeFloor", "OfficeBackWall", "OfficeLight", "ExtensionFloor", "BranchFloor", "BranchNorthEnd", "BranchSouthEnd"]:
		var node := house.get_node_or_null(piece)
		if node == null or node.owner != house or not node.scene_file_path.is_empty():
			push_error("Pieza no editable directamente en house_baked: " + piece)
			quit(1)
			return
	if count != 10:
		push_error("El despacho no tiene diez objetos")
		quit(1)
		return
	print("OK: despacho con 10 objetos, suelo continuo y conexiones despejadas en T")
	quit(0)
