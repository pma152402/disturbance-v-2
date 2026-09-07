extends SceneTree

const VisualScene := preload("res://characters/companion/child_visual.tscn")


func _initialize() -> void:
	call_deferred(&"_render")


func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	root.add_child(viewport)

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.055, 0.065, 0.07)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.48, 0.55, 0.58)
	environment_resource.ambient_light_energy = 1.15
	environment.environment = environment_resource
	viewport.add_child(environment)

	var visual := VisualScene.instantiate()
	viewport.add_child(visual)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key_light.light_color = Color(1.0, 0.88, 0.72)
	key_light.light_energy = 1.65
	viewport.add_child(key_light)

	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0.65, 1.15, 3.8)
	camera.look_at(Vector3(0.0, 0.88, 0.0))
	camera.fov = 34.0
	camera.make_current()

	for _frame in range(90):
		visual.call(&"set_motion_context", 0.0, 0.0, camera.position, false)
		visual.call(&"update_companion_animation", 1.0 / 60.0, 0.0, true)
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("The active display driver cannot render the preview.")
		quit(2)
		return
	var output_path := ProjectSettings.globalize_path("res://tools/companion_preview.png")
	var error := image.save_png(output_path)
	if error == OK:
		print("Companion preview saved: %s" % output_path)
		var motion_sheet := Image.create(640 * 4, 720, false, Image.FORMAT_RGBA8)
		for sample in 4:
			for frame in 12:
				visual.call(&"set_motion_context", 1.15, 0.0, camera.position, false)
				visual.call(&"update_companion_animation", 1.0 / 60.0, 1.0, false)
			await process_frame
			await RenderingServer.frame_post_draw
			var sample_image := viewport.get_texture().get_image()
			sample_image.convert(Image.FORMAT_RGBA8)
			motion_sheet.blit_rect(sample_image, Rect2i(0, 0, 640, 720), Vector2i(sample * 640, 0))
		motion_sheet.save_png(ProjectSettings.globalize_path("res://tools/companion_motion_preview.png"))
		quit(0)
	else:
		push_error("Could not save companion preview: %s" % error_string(error))
		quit(1)
