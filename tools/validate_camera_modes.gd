extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	shape.shape = box
	floor_body.add_child(shape)
	world.add_child(floor_body)
	floor_body.position.y = -0.1
	var player := load("res://player/player.tscn").instantiate() as CharacterBody3D
	world.add_child(player)
	player.position.y = 0.9
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	player.call("_ensure_filming_modes")
	var modes: Node = player.get("filming_modes")
	var original: Camera3D = player.get("camera")
	modes.toggle_selfie()
	assert(root.get_camera_3d() == modes.filming)
	assert(not modes.filming.get_cull_mask_value(2), "Avatar must stay culled while the lens leaves the head")
	assert(modes._selfie_transition_active)
	assert(modes.filming.global_transform.is_equal_approx(original.global_transform), "Selfie transition must begin at the first-person lens")
	var avatar := player.get_node("PlayerAvatar")
	assert(avatar.find_children("Finger*", "Node", true, false).is_empty(), "Selfie no debe conservar dedos")
	for frame in range(24):
		modes.update_view(1.0 / 60.0)
	assert(modes.filming.get_cull_mask_value(2))
	assert(modes.filming.global_basis.z.dot(player.global_basis.z) < -0.9)
	var selfie_distance: float = modes.filming.global_position.distance_to(original.global_position)
	assert(selfie_distance > 0.58 and selfie_distance < 0.9, "Selfie framing should be close but no longer cramped")
	var face_in_view: Vector3 = modes.filming.to_local(original.global_position)
	assert(face_in_view.x < 0.0 and face_in_view.y < 0.0 and face_in_view.z < 0.0, "Face should sit bottom-left")
	player.set("_look_pitch", 0.35)
	modes.update_view()
	assert((-modes.filming.global_basis.z).y > 0.3, "Selfie must follow vertical mouse look")
	player.set("_look_pitch", 0.0)
	assert(modes.toggle_ground())
	assert(modes.placing and not player.call("is_camera_on_ground"), "O must preview, never drop immediately")
	assert(not modes.confirm_placement(), "No placement without a surface")
	modes.toggle_ground()
	assert(not modes.placing and modes.mode == modes.Mode.SELFIE, "O cancels preview")
	modes.toggle_ground()
	original.get_parent().rotation.x = -0.8
	modes.update_view()
	assert(modes.placement_valid and modes.preview.visible, "Floor must show valid preview")
	assert(modes.preview_material.albedo_color.g > modes.preview_material.albedo_color.r, "Valid preview must be green")
	assert(modes.confirm_placement())
	assert(not modes.preview.visible)
	assert(player.call("is_camera_on_ground"))
	var fixed_fov: float = modes.filming.fov
	var zoom_target: float = player.get("_zoom_fov_target")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	player.call("_input", wheel)
	assert(is_equal_approx(player.get("_zoom_fov_target"), zoom_target))
	original.fov = 35.0
	modes.update_view()
	assert(is_equal_approx(modes.filming.fov, fixed_fov), "Ground lens must stay fixed")
	var fixed: Transform3D = modes.filming.global_transform
	player.position.x += 3.0
	player.rotate_y(0.5)
	modes.update_view()
	assert(modes.filming.global_transform.is_equal_approx(fixed), "Ground view must stay fixed while player moves")
	modes.toggle_selfie()
	assert(modes.filming.global_position.is_equal_approx(fixed.origin))
	var reversed_forward: Vector3 = modes.filming.global_basis.z
	assert(Vector2(reversed_forward.x, reversed_forward.z).normalized().dot(Vector2(fixed.basis.z.x, fixed.basis.z.z).normalized()) < -0.99)
	assert(modes.toggle_ground())
	assert(modes.mode == modes.Mode.SELFIE)
	modes.toggle_selfie()
	assert(modes._selfie_transition_active and modes._selfie_transition_leaving)
	for frame in range(24):
		modes.update_view(1.0 / 60.0)
	assert(root.get_camera_3d() == original)
	assert(avatar.find_children("Finger*", "Node", true, false).is_empty(), "Salir de selfie no debe recrear dedos")
	for mesh in modes.hand_layers:
		assert(mesh.layers == modes.hand_layers[mesh])
	print("CAMERA MODES PASSED: selfie sin dedos, colocacion en suelo, transformacion fija y recuperacion")
	world.queue_free()
	await process_frame
	quit()
