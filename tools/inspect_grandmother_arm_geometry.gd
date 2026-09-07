extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var actor := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	for side in ["left", "right"]:
		var elbow: Node3D = visual.get("_" + side + "_elbow")
		var shoulder: Node3D = visual.get("_" + side + "_shoulder")
		var wrist: Node3D = visual.get("_" + side + "_wrist")
		for part in ["upper_arm", "forearm"]:
			var limb: MeshInstance3D = visual.get("_" + side + "_" + part)
			var vertices: PackedVector3Array = limb.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var closest := INF
			var furthest := 0.0
			for vertex in vertices:
				var distance := limb.to_global(vertex).distance_to(elbow.global_position)
				closest = minf(closest, distance)
				furthest = maxf(furthest, distance)
			print("%s %s AABB=%s transform=%s elbow_gap=%.3f far=%.3f shoulder=%s elbow=%s wrist=%s" % [side, part, limb.get_aabb(), limb.transform, closest, furthest, shoulder.global_position, elbow.global_position, wrist.global_position])
	actor.queue_free()
	await process_frame
	quit(0)
