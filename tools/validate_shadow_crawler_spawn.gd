extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level: Node3D = load("res://levels/test.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var actor: CharacterBody3D = level.get_node("BlackEnteAtSpawn")
	var player: CharacterBody3D = level.get_node("Player")
	actor.set_physics_process(false)
	player.set_physics_process(false)
	var distance := actor.position.distance_to(player.position)
	var initial_hits: int = player._monster_hits
	await physics_frame
	await physics_frame
	var clear: bool = not actor.surface.collision_guard.penetrates(actor.surface, actor.surface.collision.global_transform)
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position, actor.global_position + Vector3.DOWN * 4.0, 1, [actor.get_rid(), player.get_rid()])
	var floor_hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	var supported: bool = not floor_hit.is_empty() and floor_hit.normal.y > 0.5
	actor.set_physics_process(true)
	for frame in 90:
		await physics_frame
	var harmless: bool = player._monster_hits == initial_hits
	var silent := true
	if is_instance_valid(actor):
		for sound_name in ["BreathingSound", "FootstepSound", "VoiceSound"]:
			var sound: AudioStreamPlayer3D = actor.get_node(sound_name)
			silent = silent and sound.stream == null and not sound.playing
		print("SPAWN RUNTIME: position=", actor.position, " dissolution=", actor.dissolution)
	else:
		print("SPAWN RUNTIME: dissolved in spawn lighting")
	var ok := distance > 1.5 and distance < 2.5 and clear and supported and harmless and silent
	print("SHADOW SPAWN: distance=", distance, " clear=", clear, " floor=", supported, " harmless=", harmless, " silent=", silent)
	if not ok:
		push_error("Invalid shadow crawler spawn")
	level.queue_free()
	await process_frame
	quit(0 if ok else 1)
