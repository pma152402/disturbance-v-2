extends "res://tools/performance_benchmark.gd"

## Diagnostico del recorrido de aparicion a lavadora con el jugador real.
## No modifica recursos del proyecto ni suspende IA, fisica o animaciones.
class RouteDriver extends Node:
	var player: CharacterBody3D
	var points := PackedVector3Array()
	var index := 0
	var elapsed := 0.0
	var distance := 0.0
	var previous := Vector3.ZERO
	var trail: Array = []
	var next_sample := 0.0
	var walking := false

	func _physics_process(delta: float) -> void:
		elapsed += delta
		distance += player.global_position.distance_to(previous)
		previous = player.global_position
		if elapsed >= next_sample:
			trail.append([elapsed, previous.x, previous.y, previous.z])
			next_sample += 0.5
		player.set("_look_pitch", -0.35)
		if not walking:
			return
		while index < points.size() and Vector2(points[index].x - previous.x, points[index].z - previous.z).length() < 0.4:
			index += 1
		if index >= points.size():
			Input.action_release(&"move_forward")
			return
		var direction := points[index] - previous
		var yaw := atan2(-direction.x, -direction.z)
		player.rotation.y = lerp_angle(player.rotation.y, yaw, 1.0 - exp(-8.0 * delta))
		Input.action_press(&"move_forward")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Requiere renderizador real.")
		quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var results: Array = []
	var batching := "--batching" in OS.get_cmdline_user_args()
	var variants := _select_variants(batching)
	for variant: String in variants:
		preload("res://systems/static_decor_batcher.gd").exact_batching_enabled = variant == "batch_on" if batching else true
		seed(140926)
		change_scene_to_file(MAIN_SCENE)
		await scene_changed
		var authored_player_pose: Transform3D = current_scene.get_node("Player").transform
		while current_scene.get_node_or_null("StartupWarmup") != null:
			await process_frame
		for frame in 90:
			await physics_frame
		var player := current_scene.get_node("Player") as CharacterBody3D
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# El ratón de escritorio puede girar al jugador durante StartupWarmup.
		# Restablecer el encuadre y la posición horizontal antes de cada pasada.
		player.rotation = authored_player_pose.basis.get_euler()
		player.position.x = authored_player_pose.origin.x
		player.position.z = authored_player_pose.origin.z
		player.velocity = Vector3.ZERO
		player.set("_look_pitch", -0.35)
		player.set("_hand_yaw", 0.0)
		player.set("_hand_pitch", 0.0)
		var flashlight := player.get("flashlight") as SpotLight3D
		flashlight.visible = true
		current_scene.get_node("House/HousePlankFloor").visible = variant != "hidden"
		var variant_metadata := _configure_variant(variant)
		var washer := current_scene.get_node("House/FurnitureAndPickups/EntranceWashingMachine") as Node3D
		var target := washer.global_position + Vector3(0.0, 0.0, 1.5)
		var points := NavigationServer3D.map_get_path(player.get_world_3d().navigation_map, player.global_position, target, true)
		if points.size() < 2:
			push_error("No hay ruta navegable desde aparicion a lavadora.")
			quit(3)
			return
		var driver := RouteDriver.new()
		driver.player = player
		driver.points = points
		driver.previous = player.global_position
		driver.process_physics_priority = -1000
		current_scene.add_child(driver)
		for frame in 60:
			await process_frame
		print("GAMEPLAY_START %s window=%s route=%s" % [variant, root.size, points])
		for phase: String in ["spawn_idle", "walk_to_washer"]:
			driver.walking = phase == "walk_to_washer"
			var samples: Array = []
			var draw_calls: Array = []
			var render_cpu: Array = []
			var gpu: Array = []
			var start := Time.get_ticks_usec()
			var previous := start
			var duration := 12.0 if driver.walking else 3.0
			while (Time.get_ticks_usec() - start) / 1000000.0 < duration:
				await process_frame
				var now := Time.get_ticks_usec()
				samples.append((now - previous) / 1000.0)
				previous = now
				draw_calls.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
				render_cpu.append(RenderingServer.get_frame_setup_time_cpu() + RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				gpu.append(_gpu_frame_ms())
			var result := {
				"variant": variant, "phase": phase, "window": [root.size.x, root.size.y],
				"frames": samples.size(), "frame_ms": _median(samples), "p95_ms": _percentile(samples, 0.95),
				"p99_ms": _percentile(samples, 0.99), "max_ms": samples.max(),
				"draw_calls": _median(draw_calls), "render_cpu_ms": _median(render_cpu), "gpu_ms": _median(gpu),
				"distance_m": driver.distance, "route_reached": driver.index >= points.size(),
				"dead": player.get("_monster_restart_pending"), "flashlight_visible": flashlight.visible,
				"diagnostic": variant_metadata,
				"camera_position": _vector_to_array((player.get_node("Head/Camera3D") as Camera3D).global_position),
				"camera_rotation": _vector_to_array((player.get_node("Head/Camera3D") as Camera3D).global_rotation),
				"trail": driver.trail.duplicate(true), "frame_samples_ms": samples,
			}
			results.append(result)
			var summary := result.duplicate()
			summary.erase("trail")
			summary.erase("frame_samples_ms")
			print("GAMEPLAY_RESULT ", JSON.stringify(summary))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT_DIR + "/gameplay_%s_%s.png" % [variant, phase])
		Input.action_release(&"move_forward")
		driver.set_physics_process(false)
	preload("res://systems/static_decor_batcher.gd").exact_batching_enabled = true
	var output := _result_filename(batching)
	_write_json(OUTPUT_DIR + output, {"system": _system_metadata(), "results": results, "ai_frozen": false, "camera": "Player/Head/Camera3D", "vsync": false})
	print("GAMEPLAY_DONE")
	quit()


func _select_variants(batching: bool) -> Array:
	return ["batch_off", "batch_on", "batch_off_repeat"] if batching else ["original", "hidden", "original_repeat"]


func _configure_variant(_variant: String) -> Dictionary:
	return {}


func _result_filename(batching: bool) -> String:
	return "/ground_floor_gameplay_batching.json" if batching else "/ground_floor_gameplay.json"
