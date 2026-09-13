extends "res://tools/performance_benchmark.gd"
## Wall-clock samples include capture stalls; a frame-count-only median hides them.


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Recording benchmark requires a real renderer")
		quit(2)
		return
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file(MAIN_SCENE)
	for frame in 240:
		await process_frame
	# Wait for the loading overlay: it can restore player physics after freezing.
	while current_scene.get_node_or_null("StartupWarmup") != null:
		await process_frame
	_freeze_nondeterministic_systems()
	_install_camera()
	_benchmark_camera.cull_mask &= ~(1 << 19)
	var recorder := current_scene.get_node("PS2PostProcess/CameraHUD")
	var walking_hud := "--walking-hud" in OS.get_cmdline_user_args()
	if walking_hud:
		current_scene.get_node("Player/StanceUI/StanceIndicator").set_walking(true)
	var result := {"system": _system_metadata(), "locations": {}, "seconds_per_stage": 6.0,
		"configuration": {"window_size": [root.size.x, root.size.y], "ai_frozen": true,
			"capture_size": [recorder.capture_resolution.x, recorder.capture_resolution.y],
			"capture_interval": recorder.capture_interval, "jpeg_quality": recorder.archive_jpeg_quality,
			"walking_hud": walking_hud,
			"full_startup_visibility": current_scene.get_node("House").get("full_startup_visibility")}}
	for location: Dictionary in LOCATIONS:
		_position_camera(location)
		for frame in 90:
			await process_frame
		var stages := {}
		# Alternating A/B twice reduces thermal/background-load bias. Use exactly
		# the original synchronous path as control, with identical render settings.
		for stage in ["standby", "sync_1", "async_1", "sync_2", "async_2", "stopped"]:
			recorder.stop_recording()
			while bool(recorder.get("_capture_pending")):
				await process_frame
			(recorder.get("_saved_clips") as Array).clear()
			var action_start := Time.get_ticks_usec()
			if stage.begins_with("sync") or stage.begins_with("async"):
				recorder.asynchronous_capture = stage.begins_with("async")
				recorder.start_recording()
			elif stage == "stopped":
				recorder.stop_recording()
			var action_ms := (Time.get_ticks_usec() - action_start) / 1000.0
			var samples: Array = []
			var capture_samples: Array = []
			var previous := Time.get_ticks_usec()
			var deadline := previous + 6000000
			while Time.get_ticks_usec() < deadline:
				var capturing := bool(recorder.get("_is_recording")) and float(recorder.get("_capture_timer")) <= 0.02
				await process_frame
				var now := Time.get_ticks_usec()
				var elapsed := (now - previous) / 1000.0
				samples.append(elapsed)
				if capturing:
					capture_samples.append(elapsed)
				previous = now
			var total := 0.0
			for value: float in samples:
				total += value
			stages[stage] = {
				"mean_ms": total / samples.size(), "p50_ms": _median(samples),
				"p95_ms": _percentile(samples, 0.95), "p99_ms": _percentile(samples, 0.99),
				"p999_ms": _percentile(samples, 0.999),
				"max_ms": samples.max(), "action_ms": action_ms,
				"near_capture_max_ms": -1.0 if capture_samples.is_empty() else capture_samples.max(),
				"frames": samples.size(), "captured_frames": (recorder.get("_current_clip") as Array).size(),
				"readback_fallbacks": recorder.get("_capture_readback_fallbacks"),
			}
			if (stage.begins_with("sync") or stage.begins_with("async")) and (recorder.get("_current_clip") as Array).size() < 10:
				push_error("Recording benchmark captured fewer than 10 frames in six seconds")
				quit(2)
				return
			print("RECORDING_BENCHMARK ", location.id, " ", stage, " ", JSON.stringify(stages[stage]))
		result.locations[location.id] = stages
		(recorder.get("_saved_clips") as Array).clear()
	var output_path := OUTPUT_DIR + "/recording_current.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_write_json(output_path, result)
	print("RECORDING_BENCHMARK_DONE ", output_path)
	quit(0)
