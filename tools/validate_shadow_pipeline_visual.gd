extends "res://tools/performance_benchmark.gd"

## A/B/A de rasterización en una misma escena y pose, con scripts/IA congelados.
## No sustituye una revisión jugando. Se conservan materiales y luces originales.
const ShadowProbe := preload("res://systems/static_shadow_batcher.gd")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var variant := "shadow_batch"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			variant = argument.get_slice("=", 1)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	seed(140926)
	change_scene_to_file(MAIN_SCENE)
	await scene_changed
	while current_scene.get_node_or_null("StartupWarmup") != null:
		await process_frame
	for frame in 90:
		await physics_frame
	# El sistema ya forma parte del arranque normal. Restaurar la referencia para
	# construir el A/B/A en esta misma escena.
	var installed_pipeline := current_scene.get_node_or_null("RuntimeShadowPipeline")
	if installed_pipeline != null:
		installed_pipeline.disable()
	_freeze_nondeterministic_systems()
	var player := current_scene.get_node("Player") as CharacterBody3D
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(player.get("flashlight") as SpotLight3D).visible = true
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	for node in current_scene.find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).speed_scale = 0.0
	for node in current_scene.find_children("*", "CPUParticles3D", true, false):
		(node as CPUParticles3D).speed_scale = 0.0
	# Fijar un instante de los efectos 2D en copias locales a la prueba. TIME no
	# depende de process_mode; de lo contrario VHS/flicker contaminan el A/B.
	var time_token := RegEx.new()
	time_token.compile("\\bTIME\\b")
	for node in current_scene.find_children("*", "CanvasItem", true, false):
		var canvas := node as CanvasItem
		if canvas.material is ShaderMaterial:
			var material := (canvas.material as ShaderMaterial).duplicate() as ShaderMaterial
			if material.shader != null and "TIME" in material.shader.code:
				material.shader = material.shader.duplicate() as Shader
				material.shader.code = time_token.sub(material.shader.code, "0.0", true)
				canvas.material = material
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var poses := [
		{"id": "spawn_floor", "position": Vector3(0.759, 1.524, 8.066), "rotation": Vector3(-0.35, 0.1815, 0.0)},
		{"id": "washer", "position": Vector3(-2.757, 1.522, -4.599), "rotation": Vector3(-0.35, 0.56645, 0.0)},
		{"id": "entrance_window", "position": Vector3(0.759, 1.524, 8.066), "rotation": Vector3(-0.05, -1.5708, 0.0)},
	]
	var results: Array = []
	for pose: Dictionary in poses:
		player.global_position = pose.position - Vector3(0.0, 1.324, 0.0)
		player.rotation = Vector3.ZERO
		camera.global_position = pose.position
		camera.global_rotation = pose.rotation
		var prefix := OUTPUT_DIR + "/shadow_visual_%s_%s" % [variant, pose.id]
		var before := await _snapshot(prefix + "_before.png")
		var control := await _snapshot(prefix + "_control.png")
		var shadow_probe := ShadowProbe.new()
		var occlusion_probe: RefCounted
		var metadata: Dictionary = {}
		if variant in ["shadow_batch", "combined"]:
			metadata["house"] = shadow_probe.install(current_scene.get_node("House"))
			metadata["school"] = shadow_probe.install(current_scene.get_node("House/SchoolUpperFloor"))
		if variant in ["exact_occlusion", "combined"]:
			occlusion_probe = load("res://systems/runtime_exact_occlusion.gd").new()
			metadata["occlusion"] = occlusion_probe.install(current_scene)
		var after := await _snapshot(prefix + "_after.png")
		shadow_probe.restore()
		if occlusion_probe != null:
			occlusion_probe.restore()
		var restored := await _snapshot(prefix + "_restored.png")
		var result := {"pose": pose.id, "variant": variant, "metadata": metadata,
			"control_noise": _image_difference(before, control),
			"change": _image_difference(control, after),
			"restore": _image_difference(before, restored),
			"sun_mode": (current_scene.get_node("Weather/OvercastLight") as DirectionalLight3D).directional_shadow_mode,
			"flashlight_shadow": (player.get("flashlight") as SpotLight3D).shadow_enabled}
		results.append(result)
		print("SHADOW_VISUAL ", JSON.stringify(result))
	_write_json(OUTPUT_DIR + "/shadow_visual_%s.json" % variant, {"results": results, "frozen": true, "canvas_time_frozen": true, "metric_region": "central 70 percent height, excludes HUD", "window": [root.size.x, root.size.y]})
	print("SHADOW_VISUAL_DONE")
	quit()


func _snapshot(path: String) -> Image:
	for frame in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(path)
	return image


func _image_difference(a: Image, b: Image) -> Dictionary:
	var native_region := Rect2i(0, floori(a.get_height() * 0.15), a.get_width(), floori(a.get_height() * 0.70))
	var identical := a.get_region(native_region).get_data() == b.get_region(native_region).get_data()
	# Análisis reducido: mismo muestreo en control/cambio/restauración; los PNG
	# completos se guardan para inspeccionar detalles finos de sombras/linterna.
	var first := a.duplicate() as Image
	var second := b.duplicate() as Image
	first.resize(860, 341, Image.INTERPOLATE_BILINEAR)
	second.resize(860, 341, Image.INTERPOLATE_BILINEAR)
	var total := 0.0
	var changed := 0
	var max_difference := 0.0
	var first_row := floori(first.get_height() * 0.15)
	var last_row := floori(first.get_height() * 0.85)
	for y in range(first_row, last_row):
		for x in first.get_width():
			var ca := first.get_pixel(x, y)
			var cb := second.get_pixel(x, y)
			var difference := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			total += difference
			max_difference = maxf(max_difference, difference)
			if difference > 2.0 / 255.0:
				changed += 1
	var count := first.get_width() * (last_row - first_row)
	return {"full_resolution_region_identical": identical, "mean_max_rgb_255": total * 255.0 / count, "over_2_levels_percent": changed * 100.0 / count, "maximum_255": max_difference * 255.0}
