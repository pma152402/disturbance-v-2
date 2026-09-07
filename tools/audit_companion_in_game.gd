extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load("res://levels/test.tscn") as PackedScene
	if packed_scene == null:
		push_error("No se pudo cargar test.tscn")
		quit(1)
		return
	var level := packed_scene.instantiate()
	root.add_child(level)
	current_scene = level

	var companion: CharacterBody3D
	var player: CharacterBody3D
	for _frame in range(720):
		await physics_frame
		companion = get_first_node_in_group(&"companion_npc") as CharacterBody3D
		player = get_first_node_in_group(&"player") as CharacterBody3D
		if companion != null and player != null and bool(companion.get("_navigation_ready")):
			var live_map := (companion.get_node("NavigationAgent3D") as NavigationAgent3D).get_navigation_map()
			var runtime_navigation := level.get_node_or_null("RuntimeHouseNavigation") as NavigationRegion3D
			if runtime_navigation != null and runtime_navigation.navigation_mesh != null:
				break

	if companion == null or player == null:
		push_error("No aparecieron jugador y acompanante en la escena real")
		quit(1)
		return
	for _frame in range(30):
		await physics_frame

	var agent := companion.get_node("NavigationAgent3D") as NavigationAgent3D
	var navigation_map := agent.get_navigation_map()
	var movement_target := player.global_position
	for _attempt in range(500):
		var candidate := NavigationServer3D.map_get_random_point(navigation_map, 1, true)
		var candidate_path := NavigationServer3D.map_get_path(
			navigation_map, companion.global_position, candidate, true
		)
		if candidate_path.size() >= 2:
			var reachable_endpoint := candidate_path[-1]
			var endpoint_distance := _planar_distance(companion.global_position, reachable_endpoint)
			var same_floor := absf(reachable_endpoint.y - 0.5) < 0.7
			if endpoint_distance > 3.2 and endpoint_distance < 5.2 and same_floor and _path_length(candidate_path) < 7.0:
				movement_target = reachable_endpoint
				break
	player.global_position = movement_target + Vector3.UP * 0.9
	print("AUDIT start companion=%s player=%s floor=%s nav_ready=%s map_iteration=%d" % [
		companion.global_position,
		player.global_position,
		companion.is_on_floor(),
		companion.get("_navigation_ready"),
		NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()),
	])

	companion.call(&"issue_command", CompanionNPCBase.Command.FOLLOW)
	var start_position := companion.global_position
	var maximum_speed := 0.0
	var moving_frames := 0
	var navigation_path_points := 0
	var previous_motion_direction := Vector3.ZERO
	var sharp_reversals := 0
	for frame in range(360):
		await physics_frame
		var planar_speed := Vector2(companion.velocity.x, companion.velocity.z).length()
		maximum_speed = maxf(maximum_speed, planar_speed)
		if planar_speed > 0.05:
			moving_frames += 1
			var motion_direction := Vector3(companion.velocity.x, 0.0, companion.velocity.z).normalized()
			if not previous_motion_direction.is_zero_approx() and motion_direction.dot(previous_motion_direction) < -0.25:
				sharp_reversals += 1
			previous_motion_direction = motion_direction
		navigation_path_points = maxi(navigation_path_points, agent.get_current_navigation_path().size())
		if frame == 180:
			print("AUDIT route player=%s companion=%s goal=%s target=%s finished=%s reachable=%s points=%d path=%s next=%s" % [
				player.global_position,
				companion.global_position,
				companion.get("_current_goal"),
				agent.target_position,
				agent.is_navigation_finished(),
				agent.is_target_reachable(),
				navigation_path_points,
				agent.get_current_navigation_path(),
				agent.get_next_path_position(),
			])

	var displacement := Vector2(start_position.x, start_position.z).distance_to(
		Vector2(companion.global_position.x, companion.global_position.z)
	)
	var player_distance := _planar_distance(companion.global_position, player.global_position)
	for _frame in range(150):
		await physics_frame
	var settled_position := companion.global_position
	var orbiting_frames := 0
	for _frame in range(240):
		player.rotation.y += 0.04
		await physics_frame
		if Vector2(companion.velocity.x, companion.velocity.z).length() > 0.035:
			orbiting_frames += 1
	var turn_drift := _planar_distance(settled_position, companion.global_position)
	var idle_locomotion := float(companion.get_node("VisualSocket/ChildVisual").get("_locomotion"))
	print("AUDIT result displacement=%.3f max_speed=%.3f moving_frames=%d reversals=%d player_distance=%.3f turn_drift=%.3f orbiting_frames=%d idle_anim=%.3f stuck_cycles=%s floor=%s iteration=%d reachable=%s path=%s" % [
		displacement,
		maximum_speed,
		moving_frames,
		sharp_reversals,
		player_distance,
		turn_drift,
		orbiting_frames,
		idle_locomotion,
		companion.get("_stuck_cycles"),
		companion.is_on_floor(),
		NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()),
		agent.is_target_reachable(),
		agent.get_current_navigation_path(),
	])

	if displacement < 0.5 or maximum_speed < 0.2 or navigation_path_points < 2:
		push_error("La auditoria real confirma que el acompanante no se desplaza correctamente")
		quit(2)
		return
	if sharp_reversals > 2:
		push_error("La auditoria detecto temblor direccional: %d inversiones" % sharp_reversals)
		quit(3)
		return
	if player_distance < 1.7 or player_distance > 2.8:
		push_error("El acompanante no termino dentro de su zona personal: %.3f m" % player_distance)
		quit(4)
		return
	if turn_drift > 0.04 or orbiting_frames > 2:
		push_error("El acompanante orbita cuando el jugador gira: %.3f m, %d frames" % [turn_drift, orbiting_frames])
		quit(5)
		return
	if idle_locomotion > 0.01:
		push_error("La animacion de andar continuo en reposo: %.3f" % idle_locomotion)
		quit(6)
		return
	quit(0)


func _planar_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total
