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
	camera.position = Vector3(0.0, 1.0, 3.1)
	camera.look_at(Vector3(0.0, 0.78, 0.0))
	camera.fov = 34.0
	camera.make_current()

	for _frame in range(8):
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
		quit(0)
	else:
		push_error("Could not save companion preview: %s" % error_string(error))
		quit(1)
