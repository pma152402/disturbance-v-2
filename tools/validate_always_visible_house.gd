extends SceneTree


func _init() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
	return condition


func _run() -> void:
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var house := game.get_node("House") as Node3D
	var player := game.get_node("Player") as CharacterBody3D
	var navigation := game.get_node("RuntimeHouseNavigation")
	player.set_physics_process(false)
	var ok := true
	var school := house.get_node_or_null("SchoolUpperFloor") as Node3D
	ok = _check(school != null, "School must be present from startup") and ok
	ok = _check(house.get_node_or_null("RuntimeHouseSectorManager") == null, "Coarse floor sector manager must stay removed") and ok
	for local_position in [Vector3(8.0, 1.2, -20.0), Vector3(8.0, 5.2, -20.0), Vector3(-4.5, 1.2, -3.0)]:
		player.global_position = house.to_global(local_position)
		for _frame in 3:
			await process_frame
		ok = _check(house.get_node("GroundFloor").visible, "GroundFloor disappeared while moving through the church/house sightline") and ok
		ok = _check(house.get_node("UpperFloor").visible, "UpperFloor disappeared while visible from church or courtyard") and ok
		ok = _check(school != null and school.visible, "SchoolUpperFloor disappeared during traversal") and ok

	for _frame in 900:
		await process_frame
		if navigation.bake_revision >= 1:
			break
	if school != null:
		ok = _check(school.transform.origin.is_equal_approx(Vector3(0.0, 4.16, 0.0)), "Startup school transform changed") and ok
		ok = _check(school.get_node_or_null("RuntimeStaticDetail") != null or school.find_children("RuntimeStaticDetail", "MeshInstance3D", true, false).size() > 0, "School runtime batching did not run") and ok
	ok = _check(navigation.bake_revision == 1, "Navigation should bake once at startup, without a traversal rebake") and ok
	print("ALWAYS VISIBLE HOUSE ", "PASSED" if ok else "FAILED", ": navigation revisions=", navigation.bake_revision)
	quit(0 if ok else 1)
