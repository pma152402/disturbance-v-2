extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level: Node3D = load("res://levels/test.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var actor: CharacterBody3D = level.get_node("BlackEnteAtSpawn")
	var player: CharacterBody3D = level.get_node("Player")
	actor.set_physics_process(false)
	player.set_physics_process(false)
	for frame in 90:
		actor._apply_gravity(1.0 / 60.0)
		actor.move_and_slide()
		await physics_frame
	var start := actor.global_position
	actor.stalking._begin_sprint(player.global_position + Vector3.UP * 1.7)
	var peak := 0.0
	# Exercise the real room geometry/navigation while isolating locomotion from
	# light damage (covered by separate tests).
	for frame in 240:
		actor._update_upright_stance(1.0 / 60.0)
		actor.stalking.step(1.0 / 60.0)
		peak = maxf(peak, Vector2(actor.velocity.x, actor.velocity.z).length())
		await physics_frame
	var distance := actor.global_position.distance_to(start)
	print("BLACK ENTE LEVEL ESCAPE: distance=", distance, " peak=", peak, " position=", actor.global_position, " goal=", actor.stalking.goal, " pending=", actor.stalking.sprint_remaining)
	var ok := distance >= 8.0 and peak >= 14.9
	if not ok: push_error("Black Ente failed to sprint away from its actual level spawn")
	level.queue_free()
	await process_frame
	quit(0 if ok else 1)
