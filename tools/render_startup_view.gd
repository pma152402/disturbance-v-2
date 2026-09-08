extends SceneTree

const OUTPUT_PATH := "res://tools/output/startup_view.png"


func _initialize() -> void:
	call_deferred("_capture_startup")


func _capture_startup() -> void:
	var packed := load("res://levels/test.tscn") as PackedScene
	if packed == null:
		push_error("Could not load levels/test.tscn")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(90):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Startup viewport did not produce an image")
		quit(1)
		return
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	var error := image.save_png(output_absolute)
	if error != OK:
		push_error("Could not save startup capture: %s" % error_string(error))
		quit(1)
		return
	print("STARTUP_CAPTURE_OK path=%s size=%s" % [output_absolute, image.get_size()])
	quit()
