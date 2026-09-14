extends "res://tools/diagnose_gate_performance.gd"


func _run() -> void:
	change_scene_to_file(MAIN_SCENE)
	for frame in 120:
		await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_sample_frames = 180
	_freeze_nondeterministic_systems()
	_install_camera()
	_benchmark_camera.cull_mask = (_benchmark_player.get_node("Head/Camera3D") as Camera3D).cull_mask
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var weather := current_scene.get_node("Weather")
	var rain := weather.get_node("Rain/NorthRain") as GPUParticles3D
	for node in current_scene.find_children("ChurchVault*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		print("VAULT_BOUNDS ", mesh.name, " ", mesh.global_transform * mesh.get_aabb())
	for location in [LOCATIONS[1], {"id": "corridor", "position": Vector3(0.25, 1.5, -16.4), "target": Vector3(10, 1.5, -16.4)}]:
		_position_camera(location)
		weather.call("_update_rain_position")
		await _sample(location.id + "_rain")
		rain.visible = false
		rain.emitting = false
		await _sample(location.id + "_without_rain")
		rain.visible = true
		rain.emitting = true
		await _sample(location.id + "_rain_repeat")
	var suffix := "after" if "--after" in OS.get_cmdline_user_args() else "before"
	_write_json("res://tools/output/local_rain_" + suffix + ".json", {"results": results})
	quit()
