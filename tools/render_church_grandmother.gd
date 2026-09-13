extends SceneTree

const Brain := preload("res://enemies/church_grandmother.gd")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 600)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.09, 0.105, 0.12)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.8, 0.85, 0.95)
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.2
	viewport.add_child(light)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(1.6, 1.4, 3.0)
	if "--back" in OS.get_cmdline_user_args():
		camera.position.z *= -1.0
	camera.look_at(Vector3(0, 1.1, 0))
	camera.fov = 46
	camera.make_current()
	var actor := (load("res://enemies/church_grandmother.tscn") as PackedScene).instantiate() as Brain
	viewport.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var caption := Label.new()
	caption.position = Vector2(16, 16)
	caption.add_theme_font_size_override("font_size", 23)
	viewport.add_child(caption)
	var sheet := Image.create(1440, 1200, false, Image.FORMAT_RGBA8)
	var labels := ["Reposo", "Escucha", "Busqueda", "Anticipacion", "Golpe", "Recuperacion"]
	var surfaces := "--surfaces" in OS.get_cmdline_user_args()
	if surfaces:
		labels = ["Pared: agarre", "Pared: avance", "Techo: agarre", "Techo: avance", "Descenso", "Encorvada"]
		camera.position = Vector3(3.6, 2.8, 5.2)
		camera.look_at(Vector3(0, 1.8, 0))
	for pose in 6:
		caption.text = labels[pose]
		actor.current_state = [0, 1, 3, 4, 4, 4][pose]
		actor.intent = [Brain.Intent.ROAM, Brain.Intent.LISTEN, Brain.Intent.SEARCH, Brain.Intent.STRIKE, Brain.Intent.STRIKE, Brain.Intent.STRIKE][pose]
		actor._search_dwell = -1.0
		actor._attack_timer = [0.0, 0.0, 0.0, 0.32, 0.6, 1.15][pose]
		actor._attack_direction = Vector3.BACK
		actor.attack_target_position = Vector3(0, 1, 1.3)
		actor.gaze_position = Vector3(2 if pose == 1 else -1 if pose == 2 else 0, 1.1, 3)
		actor.tension = 0.0 if pose == 0 else 0.8
		if surfaces:
			actor.surface.phase = [1, 1, 2, 2, 3, 0][pose]
			actor.rotation = Vector3(0, 0, PI * 0.5 if pose < 2 else PI if pose < 4 else 0.0)
			if pose < 2:
				actor.basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
			actor.position = Vector3(0, 1.8 if pose < 2 else 3.0 if pose < 4 else 0.0, 0)
			actor._idle_clock = 0.3 if pose % 2 == 0 else 1.1
			actor.current_state = 0
			actor.intent = Brain.Intent.HUNT
			var focus := actor.global_transform * Vector3(0, 0.8, 0.6)
			camera.position = focus + Vector3(2.5, 1.1, 4.2)
			camera.look_at(focus)
		for frame in 100:
			if not surfaces:
				actor._idle_clock += 1.0 / 60.0
			visual.call(&"_physics_process", 1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0,0,480,600), Vector2i((pose % 3) * 480, (pose / 3) * 600))
	var path := "res://tools/output/church_grandmother_poses%s.png" % ("_surfaces" if surfaces else "_back" if "--back" in OS.get_cmdline_user_args() else "")
	sheet.save_png(path)
	print("CHURCH POSES: ", path)
	quit(0)
