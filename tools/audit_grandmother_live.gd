extends SceneTree

func _initialize() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	call_deferred(&"_run")

func _run() -> void:
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var grandma := game.get_node("ImportedGrandmotherGroundFloor") as CharacterBody3D
	var distance := 0.0
	var maximum_speed := 0.0
	for frame in 240:
		await physics_frame
	var previous := grandma.global_position
	for frame in 900:
		await physics_frame
		distance += Vector2(grandma.global_position.x - previous.x, grandma.global_position.z - previous.z).length()
		previous = grandma.global_position
		var movement := grandma.get_real_velocity()
		maximum_speed = maxf(maximum_speed, Vector2(movement.x, movement.z).length())
	if distance < 0.5 or not grandma.is_physics_processing() or game.has_node("ChildCompanion"):
		push_error("Main scene NPC inactive: distance=%.2f process=%s mode=%s still=%s position=%s nav=%s target=%s path=%s velocity=%s" % [distance, grandma.is_physics_processing(), grandma.process_mode, grandma.get("remain_still"), grandma.position, grandma.get("_navigation_available"), grandma.get("_patrol_target"), grandma.get_node("NavigationAgent3D").get_current_navigation_path(), grandma.velocity])
		quit(1)
		return
	print("LIVE GRANDMOTHER PASSED: distance=%.2f max_speed=%.2f position=%s state=%s" % [distance, maximum_speed, grandma.global_position, grandma.get("current_state")])
	game.queue_free()
	await process_frame
	quit(0)
