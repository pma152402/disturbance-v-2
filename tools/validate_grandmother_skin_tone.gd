extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var actor := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual") as Node3D
	visual.set_physics_process(false)
	var skin := visual.get("_skin_material") as StandardMaterial3D
	if skin == null or skin.albedo_texture == null:
		_fail("No se creó el material de piel pálida")
		return
	var image := skin.albedo_texture.get_image()
	var average := Vector3.ZERO
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			average += Vector3(pixel.r, pixel.g, pixel.b)
	average /= float(image.get_width() * image.get_height())
	var base := skin.albedo_color
	var rendered_average := Vector3(average.x * base.r, average.y * base.g, average.z * base.b)
	var warmth := rendered_average.x - rendered_average.z
	var luminance := rendered_average.dot(Vector3(0.2126, 0.7152, 0.0722))
	if luminance < 0.57 or warmth > 0.075:
		_fail("La piel resultante sigue demasiado oscura o marrón: %s" % rendered_average)
		return
	var arms: Array = visual.get("_continuous_arms")
	for arm: MeshInstance3D in arms:
		if arm.mesh.surface_get_material(1) != skin:
			_fail("Un brazo continuo no está usando el material pálido")
			return
	print("GRANDMOTHER PALE SKIN PASSED: final_rgb=(%.3f, %.3f, %.3f) luminance=%.3f warmth=%.3f" % [
		rendered_average.x, rendered_average.y, rendered_average.z, luminance, warmth,
	])
	actor.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
