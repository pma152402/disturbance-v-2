extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 540)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.10, 0.11, 0.13)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.fov = 32
	viewport.add_child(camera)
	camera.make_current()
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	viewport.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node3D = actor._shadow_visual
	visual.set_physics_process(false)
	var label := Label.new()
	label.position = Vector2(18, 18)
	label.add_theme_font_size_override("font_size", 22)
	viewport.add_child(label)
	var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	for tile in 8:
		var pose := tile % 4
		label.text = ["Black Ente · 0 s", "1 s", "2 s", "Carga completa"][pose]
		camera.position = Vector3(0, 2.2, 2.4) if tile < 4 else Vector3(1.6, 1.8, 5.6)
		camera.look_at(Vector3(0, 2.00, 0.45) if tile < 4 else Vector3(0, 1.25, 0.2))
		actor.gaze_position = camera.position
		visual.shadow_coat.set_stare_progress([0.0, 0.25, 0.5, 1.0][pose], 1.0)
		for frame in 50: visual._physics_process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0, 0, 480, 540), Vector2i(pose * 480, (tile / 4) * 540))
	var result := sheet.save_png("res://tools/output/black_ente_smile.png")
	print("BLACK ENTE SMILE RENDER: ", result)
	viewport.queue_free()
	await process_frame
	quit(result)
