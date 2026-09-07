extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var house = load("res://levels/house_baked.tscn").instantiate()
	root.add_child(house)
	await physics_frame
	await physics_frame
	var space = house.get_world_3d().direct_space_state
	var failures := 0
	for n in ["KitchenBottle15", "LivingCan7", "MainEntranceMatchbox3"]:
		var item = house.get_node("FurnitureAndPickups/"+n)
		var shapes = item.find_children("*", "CollisionShape3D", true, false)
		var end = shapes[0].global_position
		var query = PhysicsRayQueryParameters3D.create(Vector3(-2,-5.65,end.z),end, 3)
		query.collide_with_areas = true
		var hit = space.intersect_ray(query)
		print(n, " pos=", item.global_position, " hit=", hit.get("collider"), " path=", hit.collider.get_path() if not hit.is_empty() else "none")
		if hit.get("collider") != item:
			failures += 1
	house.queue_free()
	await process_frame
	print("Pickup ray failures: ", failures)
	quit(1 if failures else 0)
