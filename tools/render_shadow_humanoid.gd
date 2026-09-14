extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	environment.environment = settings
	viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.fov = 40.0
	viewport.add_child(camera)
	camera.make_current()
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	viewport.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node3D = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var label := Label.new()
	label.position = Vector2(18, 18)
	label.add_theme_font_size_override("font_size", 20)
	viewport.add_child(label)
	var sheet := Image.create(1280, 1280, false, Image.FORMAT_RGBA8)
	for pose in 4:
		label.text = ["Humanoide", "Perfil / mirada", "Agachado: dos apoyos", "Oscuridad"][pose]
		actor.humanoid_crouch = 1.0 if pose == 2 else 0.0
		actor.position = Vector3.ZERO
		actor.rotation = Vector3.ZERO
		camera.position = Vector3(4.0, 1.4, 3.0) if pose == 1 else Vector3(0, 1.25, 5.0)
		camera.look_at(Vector3(0, 1.25, 0))
		actor.gaze_position = camera.global_position
		visual._reset_contacts()
		for frame in 50: visual._physics_process(1.0 / 60.0)
		settings.background_color = Color.BLACK if pose == 3 else Color(0.13, 0.15, 0.17)
		settings.ambient_light_energy = 0.0 if pose == 3 else 0.9
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0, 0, 640, 640), Vector2i(pose % 2 * 640, pose / 2 * 640))
	sheet.save_png("res://tools/output/shadow_humanoid.png")
	print("SHADOW HUMANOID RENDER: PASS")
	viewport.queue_free()
	await process_frame
	quit()
