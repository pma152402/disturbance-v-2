extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var level := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	for _frame in range(240):
		await physics_frame

	var companion := get_first_node_in_group(&"companion_npc") as CharacterBody3D
	var player := get_first_node_in_group(&"player") as CharacterBody3D
	var candidates: Array[Dictionary] = []
	for node in level.find_children("*", "", true, false):
		if node.has_method(&"ensure_open_for_npc") and node.has_method(&"get_npc_traversal_portal"):
			var portal := node.call(&"get_npc_traversal_portal") as Dictionary
			var center: Vector3 = portal.get("center", (node as Node3D).global_position)
			candidates.append({
				"node": node,
				"center": center,
				"distance": center.distance_to(companion.global_position),
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	for index in range(mini(8, candidates.size())):
		var data := candidates[index]
		print("DOOR %d path=%s center=%s distance=%.2f" % [
			index,
			str((data.node as Node).get_path()),
			data.center,
			data.distance,
		])
	print("ACTORS companion=%s player=%s" % [companion.global_position, player.global_position])
	if candidates.is_empty():
		push_error("No hay puertas auditables")
		quit(1)
		return

	var door: Node = candidates[0].node
	var portal := door.call(&"get_npc_traversal_portal") as Dictionary
	var center: Vector3 = portal.center
	var normal: Vector3 = portal.normal
	normal.y = 0.0
	normal = normal.normalized()
	companion.global_position = center + normal * 0.72
	player.global_position = center - normal * 2.8 + Vector3.UP * 0.9
	companion.velocity = Vector3.ZERO
	door.call(&"ensure_open_for_npc", companion)
	companion.call(&"_begin_door_traversal", door)

	var initial_side := signf((companion.global_position - center).dot(normal))
	var previous_side := initial_side
	var side_changes := 0
	var previous_yaw := companion.rotation.y
	var angular_travel := 0.0
	for _frame in range(360):
		await physics_frame
		var side := signf((companion.global_position - center).dot(normal))
		if not is_zero_approx(side) and not is_equal_approx(side, previous_side):
			side_changes += 1
			previous_side = side
		angular_travel += absf(wrapf(companion.rotation.y - previous_yaw, -PI, PI))
		previous_yaw = companion.rotation.y

	var final_side := signf((companion.global_position - center).dot(normal))
	print("DOOR RESULT initial_side=%s final_side=%s changes=%d active=%s phase=%s angular=%.2f position=%s" % [
		initial_side,
		final_side,
		side_changes,
		companion.get("_door_traversal_active"),
		companion.get("_door_traversal_phase"),
		angular_travel,
		companion.global_position,
	])
	if final_side == initial_side or bool(companion.get("_door_traversal_active")) or side_changes != 1:
		push_error("El cruce de puerta no termino limpiamente")
		quit(2)
		return
	if angular_travel > PI * 1.25:
		push_error("El acompanante giro demasiado durante el cruce: %.2f rad" % angular_travel)
		quit(3)
		return

	# Prueba end-to-end: la hoja ya esta abierta y, por tanto, fuera del rayo
	# frontal. El seguidor debe descubrir el portal fijo mientras persigue la
	# posicion actual del jugador, cruzarlo una vez y continuar la ruta.
	companion.global_position = center + normal * 1.25
	player.global_position = center - normal * 3.0 + Vector3.UP * 0.9
	companion.velocity = Vector3.ZERO
	companion.set("_door_reentry_timer", 0.0)
	companion.call(&"issue_command", 1)
	initial_side = signf((companion.global_position - center).dot(normal))
	previous_side = initial_side
	side_changes = 0
	previous_yaw = companion.rotation.y
	angular_travel = 0.0
	var traversal_starts := 0
	var was_traversing := false
	for _frame in range(600):
		await physics_frame
		var is_traversing := bool(companion.get("_door_traversal_active"))
		if is_traversing and not was_traversing:
			traversal_starts += 1
		was_traversing = is_traversing
		var side := signf((companion.global_position - center).dot(normal))
		if not is_zero_approx(side) and not is_equal_approx(side, previous_side):
			side_changes += 1
			previous_side = side
		angular_travel += absf(wrapf(companion.rotation.y - previous_yaw, -PI, PI))
		previous_yaw = companion.rotation.y
	final_side = signf((companion.global_position - center).dot(normal))
	print("AUTO DOOR RESULT initial_side=%s final_side=%s changes=%d starts=%d active=%s angular=%.2f player_distance=%.2f position=%s" % [
		initial_side,
		final_side,
		side_changes,
		traversal_starts,
		companion.get("_door_traversal_active"),
		angular_travel,
		Vector2(companion.global_position.x, companion.global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z)),
		companion.global_position,
	])
	if final_side == initial_side or side_changes != 1 or traversal_starts != 1 or bool(companion.get("_door_traversal_active")):
		push_error("El seguimiento automatico no cruzo la puerta una sola vez")
		quit(4)
		return
	if angular_travel > PI * 1.5:
		push_error("El seguimiento automatico giro demasiado: %.2f rad" % angular_travel)
		quit(5)
		return
	quit(0)
