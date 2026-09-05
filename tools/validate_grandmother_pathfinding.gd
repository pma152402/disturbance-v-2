extends SceneTree

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var game := (load("res://test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var monster := game.get_node("ImportedGrandmotherGroundFloor") as CharacterBody3D
	monster.set_physics_process(false)
	monster.set("dormant_until_door_opens", false)
	monster.set("remain_still", false)
	monster.global_position = Vector3(-1.8, 0.0, -3.8)
	var navigation := game.get_node("RuntimeHouseNavigation")
	if navigation.navigation_mesh == null:
		await navigation.navigation_baked
	for _frame in 4:
		await physics_frame
	monster.set("current_state", 1)
	monster.set("_last_known_player_position", Vector3(-8.5, 0.0, -5.8))
	monster.set("_target_refresh_timer", 0.0)
	var start := monster.global_position
	var last_progress := start
	var longest_stall := 0
	var current_stall := 0
	for frame in 720:
		monster.call("_update_movement", 1.0 / 60.0)
		monster.move_and_slide()
		monster.call("_try_open_door")
		await physics_frame
		if monster.global_position.distance_to(last_progress) >= 0.12:
			last_progress = monster.global_position
			current_stall = 0
		else:
			current_stall += 1
			longest_stall = maxi(longest_stall, current_stall)
		if monster.global_position.distance_to(Vector3(-8.5, 0.0, -5.8)) < 1.0:
			break
		if monster.navigation_agent.is_navigation_finished() and start.distance_to(monster.global_position) > 2.0:
			break
		var active_path: PackedVector3Array = monster.navigation_agent.get_current_navigation_path()
		if not active_path.is_empty() and monster.global_position.distance_to(active_path[-1]) < 0.7:
			break
	if start.distance_to(monster.global_position) < 2.0:
		var path: PackedVector3Array = monster.navigation_agent.get_current_navigation_path()
		var probe_target: Vector3 = path[mini(1, path.size() - 1)]
		var origin := monster.global_position + Vector3.UP * 0.72
		var probe := PhysicsRayQueryParameters3D.create(origin, Vector3(probe_target.x, origin.y, probe_target.z), monster.collision_mask)
		probe.exclude = [monster.get_rid()]
		var hit := monster.get_world_3d().direct_space_state.intersect_ray(probe)
		return _fail("No consiguió salir del pasillo inicial; avance=%s, ruta=%s, índice=%s, final=%s, recuperación=%s, bloqueo=%s" % [start.distance_to(monster.global_position), path, monster.navigation_agent.get_current_navigation_path_index(), monster.global_position, monster.get("_recovery_direction"), hit])
	if longest_stall > 180:
		return _fail("Permaneció atascada más de tres segundos (avance=%.2f, atasco=%.2f, final=%s, ruta=%s)" % [start.distance_to(monster.global_position), longest_stall / 60.0, monster.global_position, monster.navigation_agent.get_current_navigation_path()])
	print("OK: ruta con obstáculos recorrida; avance=%.2f m, atasco máximo=%.2f s" % [start.distance_to(monster.global_position), longest_stall / 60.0])
	current_scene = null
	game.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
