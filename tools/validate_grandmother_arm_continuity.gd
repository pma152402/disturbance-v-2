extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var actor := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual") as Node3D
	visual.set_physics_process(false)
	if not visual.scale.is_equal_approx(Vector3.ONE * 0.207):
		_fail("Visual is not 15 percent taller")
		return
	var arms: Array = visual.get("_continuous_arms")
	if arms.size() != 2:
		_fail("Missing continuous arm skins")
		return
	var maximum_seam := 0.0
	for pose in 7:
		actor.set("current_state", [0,1,3,2,4,0,5][pose])
		actor.set("_waiting_covered_eyes", pose == 5)
		actor.set("_door_traversal_active", pose == 3)
		actor.set("_door_exit_point", Vector3(0,0,2))
		for frame in 120:
			actor.set("_attack_timer", fposmod(frame / 60.0, 0.98))
			actor.set("_eating_elapsed", frame / 60.0)
			actor.set("_motion_phase", frame / 60.0 * 6.0)
			visual.call(&"_physics_process", 1.0 / 60.0)
			for arm: MeshInstance3D in arms:
				var cloth: Array = arm.mesh.surface_get_arrays(0)
				var skin: Array = arm.mesh.surface_get_arrays(1)
				var vertices: PackedVector3Array = skin[Mesh.ARRAY_VERTEX]
				var elbow_center := Vector3.ZERO
				for index in range(48, 60):
					elbow_center += vertices[index] / 12.0
				var gap := arm.to_global(elbow_center).distance_to(arm.get("elbow").global_position)
				maximum_seam = maxf(maximum_seam, gap)
				if gap > 0.0001:
					_fail("Elbow surface lost its pivot")
					return
				for index in range(24, 36):
					if vertices[index] != cloth[Mesh.ARRAY_VERTEX][index]:
						_fail("Sleeve and skin separated")
						return
				for vertex in vertices:
					if not vertex.is_finite():
						_fail("Invalid arm geometry")
						return
				# Merge the material boundaries topologically. Only the two end
				# rings embedded inside the torso/palm may be open.
				if frame == 119:
					var edges := {}
					for arrays in [cloth, skin]:
						var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
						for triangle in range(0, indices.size(), 3):
							for edge in 3:
								var a := indices[triangle + edge]
								var b := indices[triangle + (edge + 1) % 3]
								var key := Vector2i(mini(a,b),maxi(a,b))
								edges[key] = edges.get(key,0) + 1
					for edge: Vector2i in edges:
						if edges[edge] != 2 and not (edge.y < 12 or edge.x >= 96):
							_fail("Open seam within the arm")
							return
	print("ARM CONTINUITY PASSED: 840 frames, seven poses, two connected elbows, sleeve seam %.6f m, scale +15%%" % maximum_seam)
	actor.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
