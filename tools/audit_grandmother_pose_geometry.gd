extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var actor := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual") as Node3D
	visual.set_physics_process(false)
	var rig := visual.get_node("CleanModel/EditableGrannyRig") as Node3D
	var audited_head := rig.get_node("HeadPivot") as Node3D
	print("HEAD BASIS x=", audited_head.global_basis.x.normalized(), " y=", audited_head.global_basis.y.normalized(), " z=", audited_head.global_basis.z.normalized())
	var head_mesh := audited_head.get_node("Head") as MeshInstance3D
	for material_index in head_mesh.mesh.get_surface_count():
		var face_material := head_mesh.get_active_material(material_index)
		print("HEAD MATERIAL ", material_index, " type=", face_material.get_class() if face_material else "none", " albedo=", face_material.get("albedo_color") if face_material is StandardMaterial3D else "textured")
	var head_basis_inverse := audited_head.global_basis.orthonormalized().inverse()
	var head_bounds := AABB()
	var has_head_point := false
	for surface_index in head_mesh.mesh.get_surface_count():
		var head_arrays := head_mesh.mesh.surface_get_arrays(surface_index)
		var head_vertices: PackedVector3Array = head_arrays[Mesh.ARRAY_VERTEX]
		for vertex in head_vertices:
			var local_point := head_basis_inverse * (head_mesh.to_global(vertex) - audited_head.global_position)
			if not has_head_point:
				head_bounds = AABB(local_point, Vector3.ZERO)
				has_head_point = true
			else:
				head_bounds = head_bounds.expand(local_point)
	print("VISIBLE HEAD BOUNDS RELATIVE TO PIVOT ", head_bounds)
	var torso_mesh := rig.get_node("Body") as MeshInstance3D
	var torso_front := -INF
	var torso_back := INF
	var torso_left := INF
	var torso_right := -INF
	var torso_samples := 0
	var torso_bounds := AABB()
	var has_torso_point := false
	for surface_index in torso_mesh.mesh.get_surface_count():
		var torso_arrays := torso_mesh.mesh.surface_get_arrays(surface_index)
		var torso_vertices: PackedVector3Array = torso_arrays[Mesh.ARRAY_VERTEX]
		for vertex in torso_vertices:
			var body_point := actor.global_basis.inverse() * (torso_mesh.to_global(vertex) - actor.global_position)
			if not has_torso_point:
				torso_bounds = AABB(body_point, Vector3.ZERO)
				has_torso_point = true
			else:
				torso_bounds = torso_bounds.expand(body_point)
			if body_point.y >= 1.25 and body_point.y <= 1.58:
				torso_front = maxf(torso_front, body_point.z)
				torso_back = minf(torso_back, body_point.z)
				torso_left = minf(torso_left, body_point.x)
				torso_right = maxf(torso_right, body_point.x)
				torso_samples += 1
	print("TORSO BOUNDS ", torso_bounds, " CHEST BAND samples=", torso_samples, " x=[", torso_left, ",", torso_right, "] z=[", torso_back, ",", torso_front, "]")
	for wrist_name in ["LeftShoulderPivot/LeftElbowPivot/LeftWristPivot", "RightShoulderPivot/RightElbowPivot/RightWristPivot"]:
		var wrist := rig.get_node(wrist_name) as Node3D
		print(wrist_name, " children:")
		for child in wrist.get_children():
			if child is Node3D:
				print("  ", child.name, " local=", (child as Node3D).position, " global=", (child as Node3D).global_position)
	for pose_name in ["idle", "covered"]:
		actor.set("current_state", 0)
		actor.set("_waiting_covered_eyes", pose_name == "covered")
		for frame in 180:
			actor.set("_motion_phase", frame / 60.0 * 2.0)
			visual.call(&"_physics_process", 1.0 / 60.0)
		var inverse := actor.global_basis.inverse()
		print("POSE ", pose_name)
		for side in ["Left", "Right"]:
			var shoulder := rig.get_node(side + "ShoulderPivot") as Node3D
			var elbow := shoulder.get_node(side + "ElbowPivot") as Node3D
			var wrist := elbow.get_node(side + "WristPivot") as Node3D
			var palm := wrist.get_node(side + "Palm") as Node3D
			print(side, " shoulder=", inverse * (shoulder.global_position - actor.global_position), " elbow=", inverse * (elbow.global_position - actor.global_position), " wrist=", inverse * (wrist.global_position - actor.global_position), " palm=", inverse * (palm.global_position - actor.global_position), " palm_forward=", inverse * palm.global_basis.z.normalized())
		print("head=", inverse * ((rig.get_node("HeadPivot") as Node3D).global_position - actor.global_position))
	actor.queue_free()
	await process_frame
	quit(0)
