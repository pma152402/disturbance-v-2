extends SceneTree

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var house := (load("res://levels/house_baked.tscn") as PackedScene).instantiate()
	house.set_script(null)
	root.add_child(house)
	await physics_frame
	await physics_frame
	var ramps := house.get_node("CorridorStairRamps") as StaticBody3D
	var max_slope := 0.0
	for collision in ramps.get_children():
		var p: PackedVector3Array = collision.shape.get_faces()
		for index in range(0, p.size(), 3):
			var normal := (p[index + 1] - p[index]).cross(p[index + 2] - p[index]).normalized()
			max_slope = maxf(max_slope, rad_to_deg(acos(absf(normal.y))))
			var center := (p[index] + p[index + 1] + p[index + 2]) / 3.0
			var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 0.08, center - Vector3.UP * 0.08, 1)
			var hit := ramps.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				_fail("Missing ramp collision at " + str(center))
				return
	if max_slope > 45.0:
		_fail("Ramp too steep: " + str(max_slope))
		return
	var body := CharacterBody3D.new()
	body.floor_snap_length = 0.48
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 2.1
	collider.shape = capsule
	collider.position.y = 1.05
	body.add_child(collider)
	root.add_child(body)
	body.position = Vector3(-27.55, 0.02, -0.4)
	for target in [Vector3(-27.55, 2.03, 3.35), Vector3(-29.25, 2.03, 3.35), Vector3(-29.25, 4.14, -0.8)]:
		var reached := false
		for frame in 360:
			await physics_frame
			var offset: Vector3 = target - body.position
			offset.y = 0
			if offset.length() < 0.12:
				reached = true
				break
			var movement := offset.normalized() * 1.8
			body.velocity.x = movement.x
			body.velocity.z = movement.z
			body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0
			body.move_and_slide()
			if frame % 120 == 0:
				print("WALK ", frame, " pos=", body.position, " floor=", body.is_on_floor(), " velocity=", body.velocity)
		if not reached:
			for index in body.get_slide_collision_count():
				var hit := body.get_slide_collision(index)
				print("BLOCKER ", hit.get_collider().get_path(), " normal=", hit.get_normal(), " position=", hit.get_position())
			print("MAX_SLOPE ", max_slope)
			_fail("Walking blocked: " + str(body.position) + " toward " + str(target))
			return
	print("STAIR_VALIDATION_OK: full standing capsule ascended both flights and landing; maximum slope ", max_slope)
	for suffix in [9, 10, 11, 12, 13, 14, 15, 16, 17, 18]:
		var wall := house.get_node("ExteriorBasementAccess/BasementAccessAndInitialRoom/ShaftNorth%d" % suffix)
		var mesh := wall.get_node("Mesh2" if wall.has_node("Mesh2") else "Mesh") as MeshInstance3D
		var collision := wall.get_node("Collision") as CollisionShape3D
		if not mesh.global_transform.is_equal_approx(collision.global_transform) or not mesh.mesh.size.is_equal_approx(collision.shape.size):
			_fail("Tunnel visual/collision mismatch: " + str(wall.name))
			return
	print("TUNNEL_VALIDATION_OK: ten walls and matching colliders fit floor-to-ceiling height")
	body.free()
	house.free()
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
