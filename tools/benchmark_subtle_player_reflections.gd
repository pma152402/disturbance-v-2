extends SceneTree
## A/B en el nivel real. GPU necesaria; salida regenerable en tools/output/.

var _failed := false


func _init() -> void:
	call_deferred(&"_run")
	_watchdog()


func _watchdog() -> void:
	await create_timer(150.0).timeout
	push_error("Tiempo agotado al validar reflejos en el nivel")
	quit(1)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	change_scene_to_file("res://levels/test.tscn")
	await _frames(180)
	var controller := current_scene.get_node("SubtlePlayerReflections")
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	controller.process_mode = Node.PROCESS_MODE_ALWAYS
	for node in current_scene.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.cull_mask = 1048573
	camera.fov = 75
	camera.current = true
	var player := get_first_node_in_group(&"player") as Node3D
	var report := {"surfaces": controller.surfaces.size(), "locations": []}
	var chosen: Array[Dictionary] = []
	for surface: Dictionary in controller.surfaces:
		if surface.mirror and chosen.is_empty() and surface.source.is_visible_in_tree():
			chosen.append(surface)
	for surface: Dictionary in controller.surfaces:
		if not surface.mirror and surface.source.is_visible_in_tree() and "GroundFloor/ExteriorWalls" in String(surface.source.get_path()):
			chosen.append(surface)
			break
	for surface: Dictionary in controller.surfaces:
		if surface.source.has_meta(&"reflection_batched_source") and controller._surface_visible(surface.source):
			chosen.append(surface)
			break
	if chosen.size() != 3:
		push_error("Falta espejo o ventana del nivel")
		quit(1)
		return
	for surface in chosen:
		var mesh := surface.source as MeshInstance3D
		var center: Vector3 = mesh.to_global(surface.center)
		var normal: Vector3 = (mesh.global_basis.inverse().transposed() * surface.normal).normalized()
		camera.global_position = center + normal * 1.6
		camera.look_at(center)
		player.global_position = camera.global_position - Vector3.UP * 0.62
		player.global_rotation.y = camera.global_rotation.y
		controller.enabled = true
		await _frames(45)
		controller._select_surfaces(camera)
		var active := 0
		for slot: Dictionary in controller.slots:
			if not slot.surface.is_empty():
				active += 1
		if active == 0:
			push_error("Superficie real no activa: " + str(mesh.get_path()))
			_failed = true
		var location := {"path": String(mesh.get_path()), "active": active, "passes": []}
		for pass_index in 4:
			controller.enabled = pass_index % 2 == 1
			await _frames(30)
			var count: int = controller.capture_count
			var start := Time.get_ticks_usec()
			var frames := 0
			while Time.get_ticks_usec() - start < 2000000 or frames < 120:
				await process_frame
				frames += 1
			var seconds := float(Time.get_ticks_usec() - start) / 1000000.0
			location.passes.append({"enabled": controller.enabled, "frame_ms": seconds * 1000.0 / float(frames),
				"captures_per_second": float(controller.capture_count - count) / seconds})
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var label := "mirror" if surface.mirror else ("school_window" if mesh.has_meta(&"reflection_batched_source") else "window")
			root.get_texture().get_image().save_png("res://tools/output/subtle_reflections_%s.png" % label)
		report.locations.append(location)
		print("REFLEJOS NIVEL: ", JSON.stringify(location))
	var file := FileAccess.open("res://tools/output/subtle_reflections_benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("REFLEJOS NIVEL: ", "FALLO" if _failed else "OK", " superficies=", controller.surfaces.size())
	quit(1 if _failed else 0)


func _frames(count: int) -> void:
	for frame in count:
		await process_frame
