extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func add_box(parent: Node, size: Vector3, point: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	parent.add_child(body)
	body.position = point

func run() -> void:
	var dive := "--dive" in OS.get_cmdline_user_args()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.055, 0.065, 0.075)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_energy = 0.72
	environment.environment = settings
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -32, 0)
	light.light_energy = 1.35
	viewport.add_child(light)
	var surface_material := StandardMaterial3D.new()
	surface_material.albedo_color = Color(0.24, 0.27, 0.30)
	surface_material.roughness = 0.9
	add_box(viewport, Vector3(12, 0.2, 12), Vector3(0, -0.1, 0), surface_material)
	add_box(viewport, Vector3(12, 0.2, 12), Vector3(0, 4.1, 0), surface_material)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(5.2, 2.2, 6.8)
	camera.look_at(Vector3(0, 2.0, 0))
	camera.fov = 42
	camera.make_current()
	var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	viewport.add_child(actor)
	actor.set_physics_process(false)
	actor.spider_jump_enabled = false
	var visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	await physics_frame
	await physics_frame
	if dive:
		actor.global_transform = Transform3D(Basis(Vector3.BACK, PI), Vector3(0, 3.88, 0))
		actor.surface.phase = actor.surface.Phase.CEILING
		actor.surface.normal = Vector3.DOWN
		actor.surface.winding_up = true
		actor.surface.windup_time = 0.0
		actor.surface.pounce_aim = Vector3(1.1, 0.85, 1.4)
		visual._reset_contacts()
	else:
		actor.surface.begin_spider_jump({"position": Vector3(0, 4.0, 0), "normal": Vector3.DOWN}, false, "render")
	var sheet := Image.create(1920, 960, false, Image.FORMAT_RGBA8)
	var captures := [0, 24, 37, 47, 58, 82] if dive else [1, 15, 27, 32, 40, 52]
	var capture_index := 0
	for frame in (90 if dive else 55):
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, true)
		actor._idle_clock += 1.0 / 60.0
		visual._physics_process(1.0 / 60.0)
		await physics_frame
		await RenderingServer.frame_post_draw
		if capture_index < captures.size() and frame == captures[capture_index]:
			var image := viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(image, Rect2i(0, 0, 640, 480), Vector2i((capture_index % 3) * 640, (capture_index / 3) * 480))
			capture_index += 1
	sheet.save_png("res://tools/output/grandmother_crawler_ceiling_dive.png" if dive else "res://tools/output/grandmother_crawler_spider_jump.png")
	print("SPIDER JUMP RENDER PASS captures=", capture_index)
	viewport.queue_free()
	await process_frame
	quit(0 if capture_index == captures.size() else 1)
