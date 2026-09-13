extends "res://tools/performance_benchmark.gd"

## Real level, native physics/navigation and rendering. CPU timing isolates this NPC.
## --legacy compares the previous controller/visual with the same world/settings.
func _run() -> void:
	seed(19831)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var game := (load(MAIN_SCENE) as PackedScene).instantiate()
	var actor := game.get_node("ImportedGrandmotherGroundFloor") as CharacterBody3D
	var legacy := "--legacy" in OS.get_cmdline_user_args()
	var search_trial := "--search" in OS.get_cmdline_user_args()
	if legacy:
		var old := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate() as CharacterBody3D
		for property in old.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage) & PROPERTY_USAGE_STORAGE:
				old.set(property.name, actor.get(property.name))
		old.transform = actor.transform
		game.remove_child(actor)
		actor.free()
		old.name = "ImportedGrandmotherGroundFloor"
		game.add_child(old)
		actor = old
		actor.set("supernatural_player_reveal", true)
		actor.set("attack_windup_seconds", 0.24)
		actor.set("attack_hit_seconds", 0.43)
		actor.set("attack_animation_seconds", 0.98)
	root.add_child(game)
	current_scene = game
	actor.set_physics_process(false)
	for frame in 180:
		await process_frame
	_freeze_nondeterministic_systems()
	_install_camera()
	actor.set("prioritize_children", false)
	actor.call(&"_refresh_preferred_prey", true)
	var visual := actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var spawn := actor.global_position
	_benchmark_player.global_position = Vector3(0.5, 0.1, -31.0)
	_benchmark_player.velocity = Vector3.ZERO
	_benchmark_camera.global_position = Vector3(4.0, 2.5, -27.5)
	_benchmark_camera.look_at(Vector3(0.5, 1.3, -34.0))
	var brain_us: Array[float] = []
	var visual_us: Array[float] = []
	var trace: Array[Dictionary] = []
	var maximum_travel := 0.0
	for frame in (2400 if search_trial else 900):
		await physics_frame
		if frame == 120:
			# Audible clue around the altar; a real ray/nav query decides response.
			actor.call(&"_on_player_footstep_heard", _benchmark_player.global_position, 12.0)
		if frame == 540:
			_benchmark_player.global_position = Vector3(-8.0, 0.1, -5.0) if search_trial else Vector3(4.5, 0.1, -23.0)
		var before := Time.get_ticks_usec()
		actor.call(&"_physics_process", 1.0 / 60.0)
		brain_us.append(float(Time.get_ticks_usec() - before))
		before = Time.get_ticks_usec()
		visual.call(&"_physics_process", 1.0 / 60.0)
		visual_us.append(float(Time.get_ticks_usec() - before))
		maximum_travel = maxf(maximum_travel, actor.global_position.distance_to(spawn))
		if frame % 60 == 0:
			var entry := {"second": frame / 60.0, "position": str(actor.global_position), "state": actor.get("current_state"), "destination": str(actor.get("_last_known_player_position"))}
			if actor.has_method(&"get_behavior_debug_state"):
				entry.merge(actor.call(&"get_behavior_debug_state"))
			trace.append(entry)
		if frame in [300, 600] and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tools/output/church_runtime_%s_%s.png" % ["legacy" if legacy else "new", frame])
	var result := {"variant": "legacy" if legacy else "new", "samples": brain_us.size(), "maximum_travel_m": maximum_travel,
		"brain_cpu_us": {"p50": _percentile(brain_us, 0.5), "p95": _percentile(brain_us, 0.95), "p99": _percentile(brain_us, 0.99)},
		"visual_cpu_us": {"p50": _percentile(visual_us, 0.5), "p95": _percentile(visual_us, 0.95), "p99": _percentile(visual_us, 0.99)}, "trace": trace}
	_write_json("res://tools/output/church_runtime_%s%s.json" % [result.variant, "_search" if search_trial else ""], result)
	print("CHURCH RUNTIME: ", JSON.stringify(result))
	quit(0 if maximum_travel > 1.0 else 1)
