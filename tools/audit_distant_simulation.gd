extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game: Node = load("res://levels/test.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in 4:
		await physics_frame
	var player := game.get_node("Player") as Node3D
	var active_characters: Array[String] = []
	var active_rigid := 0
	var sleeping_rigid := 0
	for node in game.find_children("*", "CharacterBody3D", true, false):
		var body := node as CharacterBody3D
		if body == player or not body.is_physics_processing() or not body.can_process():
			continue
		active_characters.append("%s:%.1fm" % [str(body.get_path()), body.global_position.distance_to(player.global_position)])
	for node in game.find_children("*", "RigidBody3D", true, false):
		var body := node as RigidBody3D
		if body.freeze or body.sleeping:
			sleeping_rigid += 1
		else:
			active_rigid += 1
	print("ACTIVE_CHARACTERS=", active_characters)
	print("ACTIVE_RIGID=", active_rigid, " RESTING_OR_FROZEN_RIGID=", sleeping_rigid)
	quit()
