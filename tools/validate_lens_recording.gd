extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func capture(recorder: Control) -> Image:
	recorder.start_recording()
	for i in 100:
		await process_frame
		if recorder._current_clip.size() >= 2: break
	var image := Image.new()
	check(not recorder._current_clip.is_empty(), "Recorder produced no frames")
	if not recorder._current_clip.is_empty(): image.load_jpg_from_buffer(recorder._current_clip.back())
	recorder.stop_recording()
	for i in 3: await process_frame
	return image

func run() -> void:
	var game: Node3D = load("res://levels/test.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var player: CharacterBody3D = game.get_node("Player")
	player.set_physics_process(false)
	player.set_process(false)
	var recorder: Control = game.get_node("PS2PostProcess/CameraHUD")
	var lens: CanvasLayer = player.get_camera_lens_grime()
	for i in 8: await process_frame
	var clean := await capture(recorder)
	player.receive_camera_splatter(1.0)
	var dirty := await capture(recorder)
	if not clean.is_empty() and not dirty.is_empty():
		var difference := 0.0
		for y in range(0, clean.get_height(), 8):
			for x in range(0, clean.get_width(), 8):
				var a := clean.get_pixel(x, y)
				var b := dirty.get_pixel(x, y)
				difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
		check(difference > 10.0, "Recorded image did not bake visible grime")
		clean.save_png("res://tools/output/lens_tape_clean.png")
		dirty.save_png("res://tools/output/lens_tape_dirty.png")
	check(recorder._saved_clips.size() == 2, "Clean/dirty tapes were not saved")
	var saved: PackedByteArray = recorder._saved_clips.back().back().duplicate()
	lens.dirt = 0.0
	lens._refresh()
	recorder._ensure_low_resolution_recorder()
	check(not recorder._recording_viewport.get_node("RecordedLensGrime/LensGrime").visible, "Clean recording still renders grime pass")
	check(recorder._saved_clips.back().back() == saved, "Cleaning changed previous tape")
	print("LENS RECORDING: failures=", failures, " checks=", checks)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
