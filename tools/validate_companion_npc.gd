extends SceneTree

const CompanionScene := preload("res://characters/companion/child_companion.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var companion := CompanionScene.instantiate()
	root.add_child(companion)
	await process_frame

	var failures: Array[String] = []
	for method_name in [
		&"issue_command",
		&"receive_menu_command",
		&"get_command_menu_text",
		&"get_player_speed_scale",
		&"interact",
	]:
		if not companion.has_method(method_name):
			failures.append("Falta el metodo %s" % method_name)

	var required_nodes := [
		"Collision",
		"NavigationAgent3D",
		"DoorRay",
		"VisualSocket/ChildVisual",
		"VisualSocket/ChildVisual/Body/Head/Face/LeftEye",
		"VisualSocket/ChildVisual/Body/Backpack",
		"ResponseLabel",
	]
	for node_path in required_nodes:
		if companion.get_node_or_null(node_path) == null:
			failures.append("Falta el nodo %s" % node_path)

	var menu_text := str(companion.call(&"get_command_menu_text"))
	for expected_text in ["QUIETO", "SIGUEME", "CERCA", "AVANZA", "VE ALLI"]:
		if expected_text not in menu_text:
			failures.append("El menu no contiene %s" % expected_text)

	for command_index in range(1, 6):
		var accepted := bool(companion.call(&"receive_menu_command", command_index, Vector3(2.0, 0.0, 2.0)))
		if not accepted or int(companion.get("current_command")) != command_index - 1:
			failures.append("La orden %d no cambia al estado esperado" % command_index)

	if failures.is_empty():
		print("Companion NPC validation passed: base, visual and five commands are ready.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
