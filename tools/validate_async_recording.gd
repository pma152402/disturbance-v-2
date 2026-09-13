extends SceneTree

var _failed := false


func _init() -> void:
	call_deferred(&"_run")
	_watchdog()


func _watchdog() -> void:
	await create_timer(90.0, true, false, true).timeout
	push_error("ASYNC RECORDING timeout")
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This validation needs real GPU readback")
		quit(2)
		return
	change_scene_to_file("res://levels/test.tscn")
	for frame in 180:
		await process_frame
	var recorder := current_scene.get_node("PS2PostProcess/CameraHUD")
	recorder.set_process(false)
	_check(recorder.get("_recording_viewport") == null, "Prewarm retained a viewport")
	_check((recorder.get("_saved_clips") as Array).is_empty(), "Prewarm used a tape slot")
	_check(float(recorder.get("_lifetime_recorded_seconds")) == 0.0, "Prewarm changed recorded time")
	recorder.start_recording()
	for capture in 5:
		recorder._request_capture_frame()
		await RenderingServer.frame_post_draw
		var viewport: SubViewport = recorder.get("_recording_viewport")
		var expected := viewport.get_texture().get_image().save_jpg_to_buffer(recorder.archive_jpeg_quality)
		await _wait_capture(recorder)
		var clip: Array = recorder.get("_current_clip")
		_check(clip.size() == capture + 1, "Capture did not complete")
		if not clip.is_empty():
			_check(clip.back() == expected, "Async JPEG differs from synchronous JPEG (colour/orientation/content)")
			if capture == 0:
				var saved := FileAccess.open("res://tools/output/async_recording.jpg", FileAccess.WRITE)
				saved.store_buffer(clip.back())
	# Calling START twice must not erase the current clip.
	recorder.start_recording()
	_check((recorder.get("_current_clip") as Array).size() == 5, "Repeated START erased frames")
	recorder.stop_recording()
	_check(int(recorder.get("_capture_readback_fallbacks")) == 0, "GPU test unexpectedly used synchronous fallback")
	_check(recorder.get("_recording_viewport") == null, "Recorder retained an idle viewport")
	_check((recorder.get("_saved_clips") as Array).size() == 1, "STOP did not archive the clip")
	# HDR output is deliberately unsupported by the raw RGBA8 path. Verify the
	# fallback still produces exactly Godot's original colour conversion + JPEG.
	recorder.start_recording()
	(recorder.get("_recording_viewport") as SubViewport).use_hdr_2d = true
	recorder._request_capture_frame()
	await RenderingServer.frame_post_draw
	var hdr_viewport: SubViewport = recorder.get("_recording_viewport")
	var hdr_reference := hdr_viewport.get_texture().get_image().save_jpg_to_buffer(recorder.archive_jpeg_quality)
	await _wait_capture(recorder)
	var hdr_clip: Array = recorder.get("_current_clip")
	_check(hdr_clip.size() == 1 and hdr_clip[0] == hdr_reference, "Fallback JPEG changed")
	_check(int(recorder.get("_capture_readback_fallbacks")) == 1, "Unsupported format did not use fallback")
	recorder.stop_recording()
	for cycle in 8:
		recorder.start_recording()
		recorder._request_capture_frame()
		await RenderingServer.frame_post_draw
		recorder.stop_recording()
		recorder.start_recording()
		await _wait_capture(recorder)
		_check((recorder.get("_current_clip") as Array).is_empty(), "Late result leaked into a new recording")
		recorder.stop_recording()
		_check(recorder.get("_recording_viewport") == null, "STOP leaked a viewport after pending readback")
	# Scene teardown with an outstanding GPU callback must be safe as well.
	recorder.start_recording()
	recorder._request_capture_frame()
	await RenderingServer.frame_post_draw
	current_scene.queue_free()
	current_scene = null
	for frame in 30:
		await process_frame
	print("ASYNC RECORDING ", "FAILED" if _failed else "PASSED: 5 byte-identical JPEGs, HDR fallback, prewarm, repeated START, 8 STOP/START races, pending scene teardown")
	quit(1 if _failed else 0)


func _wait_capture(recorder: Node) -> void:
	for frame in 240:
		if not bool(recorder.get("_capture_pending")):
			return
		await process_frame
	_check(false, "Capture stayed pending")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
