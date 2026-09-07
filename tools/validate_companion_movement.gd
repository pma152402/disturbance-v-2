extends SceneTree

const CompanionScene := preload("res://characters/companion/child_companion.tscn")

class StanceTestPlayer:
	extends CharacterBody3D
	var companion_stance := 0

	func get_companion_stance() -> int:
		return companion_stance


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	_add_floor(level)
	_add_navigation_plane(level)

	var player := StanceTestPlayer.new()
	player.name = "MovementTestPlayer"
	player.add_to_group(&"player")
	level.add_child(player)
	player.global_position = Vector3.ZERO

	var companion := CompanionScene.instantiate() as CharacterBody3D
	level.add_child(companion)
	companion.global_position = Vector3(0.0, 0.02, 5.0)
	for _frame in range(12):
		await physics_frame

	companion.call(&"issue_command", CompanionNPCBase.Command.FOLLOW)
	var start_position := companion.global_position
	var previous_position := start_position
	var previous_direction := Vector3.ZERO
	var sharp_reversals := 0
	for _frame in range(360):
		player.global_position.x += 0.004
		await physics_frame
		var frame_motion := companion.global_position - previous_position
		frame_motion.y = 0.0
		if frame_motion.length() > 0.001:
			var direction := frame_motion.normalized()
			if not previous_direction.is_zero_approx() and direction.dot(previous_direction) < -0.25:
				sharp_reversals += 1
			previous_direction = direction
		previous_position = companion.global_position

	var follow_progress := Vector2(start_position.x, start_position.z).distance_to(
		Vector2(companion.global_position.x, companion.global_position.z)
	)
	var follow_player_distance := _planar_distance(companion.global_position, player.global_position)

	# Una vez asentado, girar sobre uno mismo no debe hacer que el acompanante
	# orbite alrededor del jugador ni vuelva a reproducir la caminata.
	for _frame in range(180):
		await physics_frame
	var settled_position := companion.global_position
	var idle_moving_frames := 0
	for _frame in range(240):
		player.rotation.y += 0.035
		await physics_frame
		if Vector2(companion.velocity.x, companion.velocity.z).length() > 0.035:
			idle_moving_frames += 1
	var follow_idle_drift := _planar_distance(settled_position, companion.global_position)
	var visual := companion.get_node("VisualSocket/ChildVisual")
	var idle_locomotion := float(visual.get("_locomotion"))

	player.global_position = Vector3(3.0, 0.0, 0.0)
	companion.call(&"issue_command", CompanionNPCBase.Command.STAY_CLOSE)
	for _frame in range(300):
		await physics_frame
	var close_player_distance := _planar_distance(companion.global_position, player.global_position)
	var close_speed_scale := float(companion.call(&"get_player_speed_scale"))

	# Las posturas bajas conservan seguimiento, pero con una cadencia propia.
	player.companion_stance = 1
	companion.call(&"issue_command", CompanionNPCBase.Command.WAIT)
	for _frame in range(32):
		await physics_frame
	player.global_position = companion.global_position + Vector3(0.0, 0.0, 4.0)
	companion.call(&"issue_command", CompanionNPCBase.Command.FOLLOW)
	var crouch_max_speed := 0.0
	for _frame in range(240):
		await physics_frame
		crouch_max_speed = maxf(crouch_max_speed, Vector2(companion.velocity.x, companion.velocity.z).length())
	var crouch_pose := float(companion.get("_posture_blend"))

	player.companion_stance = 2
	companion.call(&"issue_command", CompanionNPCBase.Command.WAIT)
	for _frame in range(32):
		await physics_frame
	player.global_position = companion.global_position + Vector3(0.0, 0.0, 4.0)
	companion.call(&"issue_command", CompanionNPCBase.Command.FOLLOW)
	var prone_max_speed := 0.0
	for _frame in range(360):
		await physics_frame
		prone_max_speed = maxf(prone_max_speed, Vector2(companion.velocity.x, companion.velocity.z).length())
	var prone_pose := float(companion.get("_posture_blend"))

	companion.call(&"issue_command", CompanionNPCBase.Command.WAIT)
	var wait_position := companion.global_position
	for _frame in range(120):
		await physics_frame
	var wait_drift := _planar_distance(wait_position, companion.global_position)

	var failures: Array[String] = []
	if follow_progress < 1.5:
		failures.append("El acompanante no progreso lo suficiente: %.3f m" % follow_progress)
	if follow_player_distance > 2.8 or follow_player_distance < 1.7:
		failures.append("El seguimiento no respeto su zona personal: %.3f m" % follow_player_distance)
	if sharp_reversals > 2:
		failures.append("Se detectaron %d cambios bruscos de direccion" % sharp_reversals)
	if follow_idle_drift > 0.04 or idle_moving_frames > 2:
		failures.append("Girar quieto reactivo al acompanante: deriva %.3f m, %d frames" % [follow_idle_drift, idle_moving_frames])
	if idle_locomotion > 0.01:
		failures.append("La animacion de caminar siguio activa en reposo: %.3f" % idle_locomotion)
	if close_player_distance > 1.25 or close_player_distance < 0.55:
		failures.append("La orden CERCA no respeto su zona: %.3f m" % close_player_distance)
	if not is_equal_approx(close_speed_scale, 0.62):
		failures.append("CERCA no aplico la velocidad esperada: %.2f" % close_speed_scale)
	if crouch_pose < 0.99 or crouch_max_speed < 0.35 or crouch_max_speed > 0.95:
		failures.append("Seguimiento agachado invalido: pose %.2f, velocidad %.2f" % [crouch_pose, crouch_max_speed])
	if prone_pose < 1.99 or prone_max_speed < 0.2 or prone_max_speed > 0.62:
		failures.append("Seguimiento a cuatro patas invalido: pose %.2f, velocidad %.2f" % [prone_pose, prone_max_speed])
	if wait_drift > 0.035:
		failures.append("QUIETO genero una deriva de %.3f m" % wait_drift)

	if failures.is_empty():
		print(
			"Companion movement passed: progress=%.2fm follow_distance=%.2fm reversals=%d turn_drift=%.3fm idle_anim=%.3f close_distance=%.2fm crouch_speed=%.2f prone_speed=%.2f wait_drift=%.3fm"
			% [follow_progress, follow_player_distance, sharp_reversals, follow_idle_drift, idle_locomotion, close_player_distance, crouch_max_speed, prone_max_speed, wait_drift]
		)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _add_floor(parent: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(24.0, 0.2, 24.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor_body.add_child(floor_collision)
	parent.add_child(floor_body)


func _add_navigation_plane(parent: Node3D) -> void:
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.vertices = PackedVector3Array([
		Vector3(-10.0, 0.0, -10.0),
		Vector3(-10.0, 0.0, 10.0),
		Vector3(10.0, 0.0, 10.0),
		Vector3(10.0, 0.0, -10.0),
	])
	navigation_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = navigation_mesh
	parent.add_child(region)


func _planar_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
