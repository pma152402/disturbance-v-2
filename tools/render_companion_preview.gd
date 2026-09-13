extends SceneTree

const VisualScene := preload("res://characters/companion/child_visual.tscn")


func _initialize() -> void:
	call_deferred(&"_render")


func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	root.add_child(viewport)

	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.055, 0.065, 0.07)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.48, 0.55, 0.58)
	settings.ambient_light_energy = 1.15
	environment.environment = settings
	viewport.add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	light.light_color = Color(1.0, 0.88, 0.72)
	light.light_energy = 1.65
	viewport.add_child(light)

	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(1.45, 1.25, 3.25)
	camera.look_at(Vector3(0.0, 0.82, 0.0))
	camera.fov = 42.0
	camera.make_current()

	var sheet := Image.create(480 * 3, 600 * 2, false, Image.FORMAT_RGBA8)
	var velocities: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(0.0, 0.0, -1.4),
		Vector3(0.0, 0.0, -3.6),
		Vector3(0.35, 0.0, -0.9),
		Vector3(0.0, 0.0, -0.55),
		Vector3.ZERO,
	]
	var stances := [0.0, 0.0, 0.0, 1.0, 2.0, 0.0]
	var items: Array[StringName] = [&"", &"", &"", &"", &"", &"candle"]
	for pose in 6:
		var visual := VisualScene.instantiate() as Node3D
		viewport.add_child(visual)
		visual.call(&"set_hidden_from_player_camera", false)
		for frame in 24:
			visual.call(
				&"update_player_animation",
				1.0 / 20.0,
				velocities[pose],
				stances[pose],
				true,
				pose == 2,
				-0.12 if pose == 5 else 0.0,
				0.35 if pose == 3 else 0.0,
				items[pose],
				&"place" if pose == 5 else &""
			)
			await process_frame
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0, 0, 480, 600), Vector2i((pose % 3) * 480, (pose / 3) * 600))
		visual.queue_free()
		await process_frame

	var output_path := ProjectSettings.globalize_path("res://tools/output/player_child_pose_sheet.png")
	var error := sheet.save_png(output_path)
	if error != OK:
		push_error("No se pudo guardar la hoja de poses: %s" % error_string(error))
		quit(1)
		return
	print("PLAYER CHILD POSE SHEET: " + output_path)
	quit(0)
