extends SceneTree


func _initialize() -> void:
	call_deferred(&"_render")


func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 760)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var field := (load("res://environment/dirt_football_field.tscn") as PackedScene).instantiate()
	world.add_child(field)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	world.add_child(light)
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.055, 0.05, 0.045)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment_resource.ambient_light_energy = 0.52
	environment.environment = environment_resource
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(19.0, 23.0, 26.0)
	camera.look_at(Vector3.ZERO)
	camera.fov = 50.0
	camera.current = true
	for _frame in 5:
		await process_frame
	var image := viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tools/output/dirt_football_field_preview.png"))
	quit(0)
