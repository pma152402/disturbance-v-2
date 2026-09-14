extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 540)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.18, 0.20, 0.23)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.9
	environment.environment = settings
	viewport.add_child(environment)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-40, -30, 0)
	lamp.light_energy = 2.0
	viewport.add_child(lamp)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.fov = 45
	camera.make_current()
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	viewport.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node3D = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var label := Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 22)
	viewport.add_child(label)
	var sheet := Image.create(1920, 540, false, Image.FORMAT_RGBA8)
	for pose in 3:
		label.text = ["Acechador erguido", "Luz: disolución al 50%", "Se agacha para trepar"][pose]
		actor.basis = Basis(Vector3.BACK, PI) if pose == 2 else Basis.IDENTITY
		actor.position = Vector3(0, 1.8, 0) if pose == 2 else Vector3.ZERO
		actor.surface.phase = 2 if pose == 2 else 0
		actor.upright_amount = 0.0 if pose == 2 else 1.0
		var focus: Vector3 = actor.transform * Vector3(0, 0.65 if pose == 2 else 1.15, 0)
		camera.position = focus + Vector3(2.3, 0.8, 3.2)
		camera.look_at(focus)
		actor.gaze_position = Vector3(0, 0.9, 5)
		visual._reset_contacts()
		for frame in 30:
			visual._physics_process(1.0 / 60.0)
		visual.shadow_coat.set_dissolution(0.5 if pose == 1 else 0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0, 0, 640, 540), Vector2i(pose * 640, 0))
	var result := sheet.save_png("res://tools/output/shadow_crawler.png")
	print("SHADOW CRAWLER RENDER: ", result)
	viewport.queue_free()
	await process_frame
	quit(result)
