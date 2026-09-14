extends "res://tools/performance_benchmark.gd"

var results: Array[Dictionary] = []


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_sample_frames = 150
	change_scene_to_file(MAIN_SCENE)
	for frame in 150:
		await process_frame
	_freeze_nondeterministic_systems()
	_install_camera()
	_benchmark_camera.fov = 95.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var gate := current_scene.get_node("House/AsylumWovenGate") as Node3D
	if "--focused" in OS.get_cmdline_user_args():
		await _focused_shadows(gate)
		quit()
		return
	var views: Array[Dictionary] = []
	for distance in [6.0, 1.8, -1.8, -6.0]:
		views.append({"id": "gate_%s" % distance,
			"position": gate.to_global(Vector3(0, 1.5, distance)),
			"target": gate.to_global(Vector3(0, 1.5, 0))})
	var worst_view: Dictionary = views[0]
	var worst_ms := 0.0
	for view in views:
		_position_camera(view)
		var data := await _sample(view.id)
		if float(data.metrics.frame_ms) > worst_ms:
			worst_ms = float(data.metrics.frame_ms)
			worst_view = view
	_position_camera(worst_view)
	await _sample("worst_baseline")
	# Todas las variaciones pertenecen exclusivamente a esta instancia de prueba.
	gate.visible = false
	var surround := current_scene.get_node("House/AsylumGateSurround4m") as Node3D
	surround.visible = false
	await _sample("without_gate_and_surround")
	gate.visible = true
	surround.visible = true
	var saved_shadows: Dictionary = {}
	var optimizer_modes: Dictionary = {}
	for node in current_scene.find_children("*Optimizer", "Node", true, false):
		optimizer_modes[node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for light in current_scene.find_children("*", "Light3D", true, false):
		saved_shadows[light] = light.shadow_enabled
		light.shadow_enabled = false
	await _sample("without_shadows")
	for light in saved_shadows:
		light.shadow_enabled = saved_shadows[light]
	for node in optimizer_modes:
		node.process_mode = optimizer_modes[node]
	var exterior := current_scene.get_node_or_null("ExteriorEnvironment") as Node3D
	if exterior != null:
		exterior.visible = false
		await _sample("without_exterior_geometry")
		exterior.visible = true
	var particles: Dictionary = {}
	for node in current_scene.find_children("*", "GPUParticles3D", true, false):
		particles[node] = node.visible
		node.visible = false
	await _sample("without_gpu_particles")
	for node in particles:
		node.visible = particles[node]
	var filter := current_scene.get_node("PS2PostProcess/ScreenFilter") as CanvasItem
	filter.visible = false
	await _sample("without_screen_filter")
	filter.visible = true
	var reflections := current_scene.get_node_or_null("SubtlePlayerReflections")
	if reflections != null:
		reflections.set("enabled", false)
		await _sample("without_player_reflections")
		reflections.set("enabled", true)
	await _sample("worst_baseline_repeat")
	var lights: Array[Dictionary] = []
	for light in current_scene.find_children("*", "Light3D", true, false):
		if light.is_visible_in_tree() and light.light_energy > 0.0 and light.global_position.distance_to(_benchmark_camera.global_position) < 18.0:
			lights.append({"path": str(light.get_path()), "shadow": light.shadow_enabled,
				"range": light.omni_range if light is OmniLight3D else (light.spot_range if light is SpotLight3D else -1),
				"distance": light.global_position.distance_to(_benchmark_camera.global_position)})
	var observer := get_first_node_in_group(&"camera_observer")
	var report := {"system": _system_metadata(), "views": views, "worst_view": worst_view,
		"results": results, "nearby_active_lights": lights,
		"observer_processing": observer.is_processing() if observer != null else false,
		"conditions": "1920x1080, FOV95, actual project 3D scale, actors frozen, lightning frozen, no saved scene changes"}
	_write_json("res://tools/output/gate_diagnosis.json", report)
	print("GATE_DIAGNOSIS_DONE")
	quit()


func _sample(label: String) -> Dictionary:
	for frame in 70:
		await process_frame
	var data := await _measure_pass(1)
	data["label"] = label
	results.append(data)
	print("GATE_SAMPLE ", label, " ", JSON.stringify(data.metrics))
	return data


func _focused_shadows(gate: Node3D) -> void:
	_sample_frames = 240
	_position_camera({"position": gate.to_global(Vector3(0, 1.5, 1.8)), "target": gate.to_global(Vector3(0, 1.5, 0))})
	for frame in 120:
		await process_frame
	for node in current_scene.find_children("*Optimizer", "Node", true, false):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	var lights: Dictionary = {}
	for light in current_scene.find_children("*", "Light3D", true, false):
		lights[light] = light.shadow_enabled
	await _sample("focused_baseline")
	var particles: Dictionary = {}
	for node in current_scene.find_children("*", "GPUParticles3D", true, false):
		particles[node] = node.cast_shadow
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await _sample("particles_visible_without_casting_shadows")
	for node in particles:
		node.cast_shadow = particles[node]
	for kind in ["sun", "school", "streetlamps", "all"]:
		for light in lights:
			var path := str(light.get_path())
			if kind == "all" or (kind == "sun" and light is DirectionalLight3D) or (kind == "school" and "/SchoolUpperFloor/" in path) or (kind == "streetlamps" and "CourtyardStreetlamp" in path):
				light.shadow_enabled = false
		await _sample("without_%s_shadows" % kind)
		for light in lights:
			light.shadow_enabled = lights[light]
	await _sample("focused_baseline_repeat")
	_write_json("res://tools/output/gate_shadows_diagnosis.json", {"results": results, "system": _system_metadata()})
	print("GATE_FOCUSED_DONE")
