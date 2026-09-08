extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game: Node = load("res://levels/test.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in 4:
		await physics_frame
	var rat := game.get_node("House/TunnelRat") as CharacterBody3D
	assert(not rat.is_physics_processing(), "La rata oculta sigue ejecutando física distante")
	assert(rat.velocity.is_zero_approx(), "La rata oculta conserva velocidad")
	rat.set("escape_delay", 0.0)
	rat.call(&"_on_escape_triggered")
	await create_timer(0.02).timeout
	assert(rat.is_physics_processing(), "La rata no reactiva su IA al abrir la trampilla")

	var active_rigid := 0
	for node in game.find_children("*", "RigidBody3D", true, false):
		var body := node as RigidBody3D
		if not body.freeze and not body.sleeping:
			active_rigid += 1
	assert(active_rigid == 0, "Hay cuerpos rígidos lejanos simulándose sin necesidad")
	print("PASS: distant hidden AI sleeps, wakes on its event, and rigid props remain at rest")
	quit()
