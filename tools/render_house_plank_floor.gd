extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var house := load("res://levels/house_baked.tscn").instantiate() as Node3D
	world.add_child(house)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.15, 0.18)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.80, 0.85, 1.0)
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(5.3, 1.6, 9.6)
	camera.look_at(Vector3(7.5, 0.25, 4.5))
	camera.fov = 70.0
	var light := OmniLight3D.new()
	light.position = Vector3(6.5, 2.6, 7.8)
	light.omni_range = 10.0
	light.light_color = Color(1.0, 0.86, 0.71)
	light.light_energy = 2.0
	world.add_child(light)
	for frame in 12:
		await process_frame
	var layer := house.get_node("HousePlankFloor")
	assert(layer.get_child_count() == layer.surface_count and layer.surface_count == 10, "Los optimizadores han alterado la capa")
	for panel: MeshInstance3D in layer.get_children():
		assert(panel.material_override is ShaderMaterial and panel.visible, "Un optimizador ha ocultado o sustituido los tablones")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/output/house_plank_floor_living_room.png")
		print("OK: captura del salon guardada")
		if "--rooms" in OS.get_cmdline_user_args():
			for view in [
				["kitchen_marble", Vector3(4.2, 1.7, 0.5), Vector3(8.0, 0.0, -3.8)],
				["bathroom_tiles", Vector3(-3.0, 1.7, 9.8), Vector3(-5.2, 0.0, 6.3)],
			]:
				camera.position = view[1]
				camera.look_at(view[2])
				light.position = camera.position + Vector3.UP * 0.5
				for frame in 6:
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://tools/output/house_%s.png" % view[0])
				print("OK: captura %s guardada" % view[0])
	print("OK: capa integrada en la casa real con %d paneles" % layer.surface_count)
	world.queue_free()
	await process_frame
	quit(0)
