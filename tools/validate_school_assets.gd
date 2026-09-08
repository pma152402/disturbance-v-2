extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var door := load("res://house_props/school_double_door.tscn").instantiate() as Node3D
	stage.add_child(door)
	var lockers := load("res://house_props/school_lockers.tscn").instantiate() as Node3D
	stage.add_child(lockers)
	lockers.position = Vector3(3.6, 0, 0)
	var actor := Node3D.new()
	stage.add_child(actor)
	actor.position = Vector3(0, 0, 3)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(0.5, 1.3, 2), Vector3(0.5, 1.3, -2))
	assert(not space.intersect_ray(q).is_empty(), "Closed leaf must block passage")
	var left := door.get_node("LeftLeaf")
	var right := door.get_node("RightLeaf")
	assert(is_equal_approx(left.position.x, -1.2) and is_equal_approx(right.position.x, 1.2), "Hinges must be on the outer jambs")
	left.interact(actor)
	await create_timer(0.9).timeout
	await physics_frame
	assert(left.rotation.y > 1.5 and right.rotation.y < -1.5, "Leaves must open together in opposite rotations")
	assert((left.to_global(Vector3(1.19, 0, 0))).z < -1.0)
	assert((right.to_global(Vector3(-1.19, 0, 0))).z < -1.0)
	assert(space.intersect_ray(q).is_empty(), "Open double doorway must have clear passage")
	right.interact(actor)
	await create_timer(0.9).timeout
	await physics_frame
	assert(absf(left.rotation.y) < 0.001 and absf(right.rotation.y) < 0.001)
	assert(not space.intersect_ray(q).is_empty())
	print("PASS: both leaves open outwards together, opening is clear, closing restores collision.")
	if "--preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(1500, 850)
		var env := WorldEnvironment.new()
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.10, 0.12, 0.14)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.72, 0.8, 0.86)
		environment.ambient_light_energy = 0.65
		env.environment = environment
		stage.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, -30, 0)
		sun.light_energy = 1.4
		stage.add_child(sun)
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.position = Vector3(6.8, 3.5, 10)
		camera.look_at(Vector3(1.8, 1.4, 0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 7.6
		camera.make_current()
		for i in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png("res://tools/output/school_assets_preview.png")
		print("Preview saved.")
	stage.queue_free()
	await process_frame
	quit()
