extends SceneTree

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
	camera.look_at(Vector3(0, 1.1, 0))
	camera.fov = 40
	camera.make_current()
	var actor := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate()
	viewport.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	actor.set("_last_known_player_position", Vector3(0, 0, 2))
	var sheet := Image.create(480 * 3, 600 * 2, false, Image.FORMAT_RGBA8)
	for pose in 6:
		actor.set("current_state", [0,3,2,4,0,5][pose])
		actor.set("_waiting_covered_eyes", pose == 4)
		actor.set("_door_traversal_active", pose == 2)
		actor.set("_door_exit_point", Vector3(0,0,2))
		actor.set("_attack_timer", 0.36)
		actor.set("_eating_elapsed", 0.2)
		for frame in 90:
			visual.call(&"_physics_process", 1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0,0,480,600), Vector2i((pose % 3) * 480, (pose / 3) * 600))
	var suffix := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var path := "res://tools/grandmother_poses_%s.png" % suffix
	sheet.save_png(ProjectSettings.globalize_path(path))
	print("POSE SHEET: " + path)
	quit(0)
