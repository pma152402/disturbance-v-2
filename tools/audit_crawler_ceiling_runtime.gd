extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var level := load("res://levels/test.tscn").instantiate() as Node3D
	root.add_child(level)
	current_scene = level
	var actor: CharacterBody3D = level.get_node("ImportedGrandmotherGroundFloor")
	var ceiling := false
	var peak := actor.position.y
	for frame in 1800:
		await physics_frame
		peak = maxf(peak, actor.position.y)
		if actor.surface.phase == 2 and actor.basis.y.y < -0.9:
			ceiling = true
			break
	print("LIVE CHURCH CEILING: reached=", ceiling, " position=", actor.position, " peak=", peak, " phase=", actor.surface.phase, " goal=", actor._has_ceiling_goal, " target=", actor._ceiling_goal)
	if not ceiling:
		push_error("Crawler did not prioritize the ceiling from the actual church spawn")
	level.queue_free()
	await process_frame
	quit(0 if ceiling else 1)
