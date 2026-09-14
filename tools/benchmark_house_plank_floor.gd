extends "res://tools/performance_benchmark.gd"

## A/B/A sobre la misma escena y camara. Las variantes solo existen en esta
## instancia de diagnostico: nunca se guardan cambios de material o visibilidad.
const FLOOR_VIEWS := [
	{"id": "living_room", "position": Vector3(5.3, 1.6, 9.6), "target": Vector3(7.5, 0.25, 4.5)},
	{"id": "gate", "position": Vector3(-5.083, 1.5, -3.939), "target": Vector3(-6.883, 0.3, -3.960)},
	{"id": "upper_floor", "position": Vector3(5.0, 5.8, 6.0), "target": Vector3(3.0, 4.3, 0.0)},
]


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("El benchmark de tarima requiere renderizador real.")
		quit(2)
		return
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(140926)
	change_scene_to_file(MAIN_SCENE)
	for frame in 180:
		await process_frame
	var navigation := current_scene.get_node("RuntimeHouseNavigation") as NavigationRegion3D
	if navigation.navigation_mesh == null:
		await navigation.navigation_baked
	_freeze_nondeterministic_systems()
	# El benchmark general congela el cuerpo; aqui se inmovilizan tambien sus
	# animadores descendientes para que no contaminen la comparacion del suelo.
	for body in current_scene.find_children("*", "CharacterBody3D", true, false):
		body.process_mode = Node.PROCESS_MODE_DISABLED
	_install_camera()
	var player_camera := _benchmark_player.get_node("Head/Camera3D") as Camera3D
	_benchmark_camera.fov = player_camera.fov
	_benchmark_camera.near = player_camera.near
	_benchmark_camera.far = player_camera.far
	_benchmark_camera.cull_mask = player_camera.cull_mask
	var shadow_diagnosis := "--shadows" in OS.get_cmdline_user_args()
	var close_floor := "--close" in OS.get_cmdline_user_args()
	var all_diagnoses := "--all" in OS.get_cmdline_user_args()
	var lit := "--lit" in OS.get_cmdline_user_args() or shadow_diagnosis or close_floor or all_diagnoses
	if all_diagnoses:
		_sample_frames = 120
	if lit:
		# Reutilizar la linterna real, con su textura y parámetros originales.
		# La cámara del benchmark sustituye al jugador congelado.
		var flashlight := _benchmark_player.get("flashlight") as SpotLight3D
		var flashlight_pose := player_camera.global_transform.affine_inverse() * flashlight.global_transform
		flashlight.reparent(_benchmark_camera, false)
		flashlight.transform = flashlight_pose
		flashlight.visible = true
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var floor_layer := current_scene.get_node("House/HousePlankFloor") as Node3D
	var materials: Dictionary = {}
	var triangle_count := 0
	for panel: MeshInstance3D in floor_layer.get_children():
		materials[panel] = panel.material_override
		triangle_count += panel.mesh.get_faces().size() / 3
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color(0.30, 0.21, 0.14)
	plain.roughness = 0.85
	var results: Array[Dictionary] = []
	var views: Array = FLOOR_VIEWS.duplicate()
	var close_view := {"id": "floor_close", "position": Vector3(1.0, 1.65, 1.0), "target": Vector3(1.0, 0.0, 0.4)}
	if close_floor:
		views = [close_view]
	elif all_diagnoses:
		views.append(close_view)
	for view: Dictionary in views:
		_position_camera(view)
		# Conservar el offset real cabeza/cuerpo y la orientación de las manos.
		# La cámara general usaba -0,9 m y todas las capas, incluyendo el avatar.
		var head := _benchmark_player.get_node("Head") as Node3D
		_benchmark_player.global_position = view.position - Vector3.UP * head.position.y
		_benchmark_player.rotation.y = _benchmark_camera.rotation.y
		head.global_basis = _benchmark_camera.global_basis
		var optimizer := current_scene.get_node("House/RuntimeRenderOptimizer")
		optimizer.process_mode = Node.PROCESS_MODE_INHERIT
		for frame in 90:
			await process_frame
		optimizer.process_mode = Node.PROCESS_MODE_DISABLED
		var shadow_states: Dictionary = {}
		for light: Light3D in current_scene.find_children("*", "Light3D", true, false):
			shadow_states[light] = light.shadow_enabled
		var variants := ["original", "hidden", "plain_material", "original_repeat"]
		if shadow_diagnosis:
			variants = ["original", "without_shadows", "original_repeat"]
		elif all_diagnoses:
			variants = ["original", "hidden", "plain_material", "original_repeat", "without_shadows", "original_after_shadows"]
		for pass_index in 2:
			for variant: String in variants:
				floor_layer.visible = variant != "hidden"
				for light: Light3D in shadow_states:
					light.shadow_enabled = false if variant == "without_shadows" else shadow_states[light]
				for panel: MeshInstance3D in materials:
					panel.material_override = plain if variant == "plain_material" else materials[panel]
				for frame in 90:
					await process_frame
				var measurement := await _measure_pass(pass_index + 1)
				measurement["view"] = view.id
				measurement["variant"] = variant
				results.append(measurement)
				print("FLOOR_SAMPLE ", view.id, " ", variant, " ", JSON.stringify(measurement.metrics))
				if pass_index == 0 and variant in ["original", "hidden"]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://tools/output/floor_%s_%s%s.png" % [view.id, variant, "_lit" if lit else ""])
	floor_layer.visible = true
	for panel: MeshInstance3D in materials:
		panel.material_override = materials[panel]
	var suffix := ("_lit" if lit else "") + ("_shadows" if shadow_diagnosis else "") + ("_close" if close_floor else "") + ("_all" if all_diagnoses else "")
	_write_json("res://tools/output/house_plank_floor_benchmark%s.json" % suffix, {
		"system": _system_metadata(), "results": results, "views": views,
		"panels": materials.size(), "triangles": triangle_count,
		"flashlight_on": lit, "shadow_diagnosis": shadow_diagnosis,
		"all_diagnoses": all_diagnoses,
		"sample_frames_per_variant": _sample_frames, "passes_per_view": 2,
		"camera_matches_player": true, "camera_cull_mask": _benchmark_camera.cull_mask,
		"camera_near": _benchmark_camera.near, "camera_far": _benchmark_camera.far,
		"conditions": "1920x1080, FOV95, escala 3D del proyecto, VSync off; IA/animadores/relampagos congelados; 2 pasadas por vista, original antes y despues; seleccion de sombras asentada y congelada por vista; sin cambios guardados",
	})
	print("FLOOR_BENCHMARK_DONE")
	quit(0)
