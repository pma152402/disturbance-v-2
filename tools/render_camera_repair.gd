extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.20, 0.24, 0.26)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.75
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	world.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2.5, 1)
	fill.omni_range = 12.0
	fill.light_energy = 4.0
	world.add_child(fill)
	var floor_body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 0.2, 20)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	world.add_child(floor_body)
	var visual_script := preload("res://systems/camera_repair_visual.gd")
	visual_script.box(world, shape.size, Vector3.ZERO, visual_script.material(Color(0.15, 0.2, 0.18)))
	for i in 4:
		visual_script.box(world, Vector3(0.75, 1.8, 0.8), Vector3(-2.1 + i * 1.4, 1, -4), visual_script.material([Color(0.7, 0.19, 0.15), Color(0.15, 0.5, 0.25), Color(0.12, 0.28, 0.65), Color(0.6, 0.45, 0.1)][i]))
	var game: Node = load("res://levels/test.tscn").instantiate()
	var player: CharacterBody3D = game.get_node("Player")
	var post: CanvasLayer = game.get_node("PS2PostProcess")
	game.remove_child(player)
	game.remove_child(post)
	game.free()
	player.position = Vector3(0, 0.15, 0)
	player.starts_with_flashlight = false
	world.add_child(player)
	world.add_child(post)
	for frame in 20: await physics_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.camera.make_current()
	player._monster_hits = 1
	player.camera_damage_overlay.set_damage_level(1, false)
	player.receive_camera_splatter(0.4)
	player.pick_up_item(&"repair_kit")
	player._equip_inventory_slot(player._inventory_slots.find(&"repair_kit"))
	player._update_interaction_prompt()
	var repair: Node = player.camera_repair
	var sheet := Image.create(1920, 1620, false, Image.FORMAT_RGBA8)
	var times := [0.0, 2.8, 4.65, 6.3, 8.3, 10.9]
	for stage in times.size():
		if stage == 1:
			if not repair.start():
				push_error("Cannot start repair preview")
				quit(1)
				return
			repair.set_process(false)
		if stage > 0: repair.advance(times[stage] - repair.elapsed)
		await process_frame
		if repair.active: repair.advance(0.0) # Apply after HUD's own refresh.
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(960, 540, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(shot, Rect2i(0, 0, 960, 540), Vector2i((stage % 2) * 960, (stage / 2) * 540))
		shot.save_png("res://tools/output/camera_repair_%d.png" % stage)
	sheet.save_png("res://tools/output/camera_repair_sequence.png")
	print("CAMERA REPAIR RENDER: PASS")
	viewport.queue_free()
	await process_frame
	quit()
