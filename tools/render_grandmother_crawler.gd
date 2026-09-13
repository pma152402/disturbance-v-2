extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 560)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.10, 0.12, 0.14)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_energy = 0.65
	env.environment = settings
	viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.2
	viewport.add_child(light)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.fov = 45
	camera.make_current()
	var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	viewport.add_child(actor)
	actor.set_physics_process(false)
	var visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var sheet := Image.create(1920, 1120, false, Image.FORMAT_RGBA8)
	var label := Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 22)
	viewport.add_child(label)
	for pose in 6:
		actor.transform = Transform3D.IDENTITY
		actor.surface.phase = 0
		actor.current_state = 0
		actor._attack_timer = 0.0
		actor.gaze_position = Vector3(0, 0.9, 5)
		camera.position = [Vector3(2.3, 1.7, 3.1), Vector3(2.6, 1.4, -2.8), Vector3(3.5, 1.2, 0.3), Vector3(2.3, 1.5, 3.1), Vector3(2.3, 1.8, 3.1), Vector3(2.3, 1.3, 3.1)][pose]
		var focus := Vector3(0, 0.65, 0)
		label.text = ["Cuatro apoyos", "Torso y piernas", "Perfil", "Ataque desde arriba", "Pared", "Techo"][pose]
		if pose == 3:
			actor.current_state = 4
			actor._attack_timer = 0.38
		if pose >= 4:
			actor.surface.phase = 1 if pose == 4 else 2
			actor.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP) if pose == 4 else Basis(Vector3.BACK, PI)
			actor.position = Vector3(0, 1.0 if pose == 4 else 1.8, 0)
			focus = actor.transform * Vector3(0, 0.65, 0)
			camera.position = focus + Vector3(2.5, 1.1, 3.5)
		if "--ambush" in OS.get_cmdline_user_args():
			label.text = ["Acecho", "Preparacion del salto", "Salto: giro", "Ataque aereo", "Aterrizaje", "Vuelta al techo"][pose]
			actor.current_state = 0
			actor.surface.phase = 2 if pose in [0, 1, 5] else 3 if pose in [2, 3] else 0
			actor.surface.winding_up = pose == 1
			actor.surface.windup_time = 0.5
			actor.surface.pouncing = pose in [2, 3]
			actor.surface.landing_recovery = 0.25 if pose == 4 else 0.0
			actor.rotation = Vector3(0, 0, PI if pose in [0, 1, 5] else PI * 0.5 if pose == 2 else 0.0)
			actor.position = Vector3(0, 2.0 if pose in [0, 1, 5] else 1.2 if pose in [2, 3] else 0.0, 0)
			actor.gaze_position = Vector3(0.4, 0.1, 1.5)
			focus = actor.transform * Vector3(0, 0.65, 0)
			camera.position = focus + Vector3(2.0, 0.8, 3.3)
		camera.look_at(focus)
		visual._reset_contacts()
		for frame in 90:
			actor._idle_clock += 1.0 / 60.0
			visual._physics_process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0, 0, 640, 560), Vector2i((pose % 3) * 640, (pose / 3) * 560))
	sheet.save_png("res://tools/output/grandmother_crawler_ambush.png" if "--ambush" in OS.get_cmdline_user_args() else "res://tools/output/grandmother_crawler_poses.png")
	print("CRAWLER RENDER PASS")
	viewport.queue_free()
	await process_frame
	quit()
