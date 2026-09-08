extends SceneTree


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var started_loading := Time.get_ticks_usec()
	change_scene_to_file("res://systems/startup_loader.tscn")
	for _frame in 1200:
		await process_frame
		if current_scene != null and current_scene.name == &"ThreeStoreyHouse" \
			and current_scene.get_node_or_null("StartupWarmup") == null:
			break
	var startup_ms := (Time.get_ticks_usec() - started_loading) / 1000.0
	for _frame in 60:
		await process_frame
	var draw_calls := 0
	var objects := 0
	var primitives := 0
	var measured_at := Time.get_ticks_usec()
	for _frame in 180:
		await process_frame
		draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var elapsed_ms := (Time.get_ticks_usec() - measured_at) / 1000.0
	var report := "FULL_GAME startup_ms=%s avg_frame_ms=%s fps=%s draw_calls=%s objects=%s primitives=%s" % [
		snappedf(startup_ms, 0.1),
		snappedf(elapsed_ms / 180.0, 0.001),
		Performance.get_monitor(Performance.TIME_FPS),
		draw_calls / 180,
		objects / 180,
		primitives / 180,
	]
	print(report)
	var report_file := FileAccess.open("res://tools/output/full_benchmark_current.log", FileAccess.WRITE)
	if report_file != null:
		report_file.store_line(report)
	quit(0)
