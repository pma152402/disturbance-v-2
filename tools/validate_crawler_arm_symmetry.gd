extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var reference_wrists: Array[Quaternion] = []
	var maximum_mirror_error := 0.0
	var minimum_alignment := 1.0
	var minimum_alignment_by_arm := [1.0, 1.0]
	for spawn_yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
		actor.rotation.y = spawn_yaw
		world.add_child(actor)
		actor.set_physics_process(false)
		var visual = actor.get_node("EditableVisual")
		visual.set_physics_process(false)
		await physics_frame
		await physics_frame
		for frame in 90:
			actor._idle_clock += 1.0 / 60.0
			visual._physics_process(1.0 / 60.0)
		var inverse: Transform3D = actor.global_transform.affine_inverse()
		var left_palm: Vector3 = inverse * visual._left_palm.to_global(visual._left_palm.get_aabb().get_center())
		var right_palm: Vector3 = inverse * visual._right_palm.to_global(visual._right_palm.get_aabb().get_center())
		maximum_mirror_error = maxf(maximum_mirror_error, left_palm.distance_to(Vector3(-right_palm.x, right_palm.y, right_palm.z)))
		var wrists: Array[Node3D] = [visual._left_wrist, visual._right_wrist]
		var elbows: Array[Node3D] = [visual._left_elbow, visual._right_elbow]
		var palms: Array[MeshInstance3D] = [visual._left_palm, visual._right_palm]
		for i in 2:
			var palm_center: Vector3 = palms[i].to_global(palms[i].get_aabb().get_center())
			var alignment := (wrists[i].global_position - elbows[i].global_position).normalized().dot((palm_center - wrists[i].global_position).normalized())
			minimum_alignment = minf(minimum_alignment, alignment)
			minimum_alignment_by_arm[i] = minf(minimum_alignment_by_arm[i], alignment)
			var local_wrist: Quaternion = (actor.global_basis.inverse() * wrists[i].global_basis).orthonormalized().get_rotation_quaternion()
			if reference_wrists.size() < 2:
				reference_wrists.append(local_wrist)
			else:
				check(reference_wrists[i].angle_to(local_wrist) < 0.01, "Wrist pose depends on the crawler's authored spawn rotation")
		check(left_palm.x > 0.0 and right_palm.x < 0.0, "Crawler hands crossed sides")
		actor.queue_free()
		await process_frame
	check(maximum_mirror_error < 0.025, "Right arm no longer mirrors the left planted pose")
	check(minimum_alignment > 0.3, "A crawler hand folds back against its forearm")
	print("CRAWLER ARM SYMMETRY: failures=", failures, " mirror_error=", maximum_mirror_error, " min_alignment=", minimum_alignment, " by_arm=", minimum_alignment_by_arm)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
