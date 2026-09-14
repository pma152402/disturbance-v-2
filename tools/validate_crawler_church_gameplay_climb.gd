extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	# Use the complete playable level and the crawler's real physics process.
	# This catches decisions and transform ordering that direct traversal tests do not.
	var level := load("res://levels/test.tscn").instantiate() as Node3D
	root.add_child(level)
	current_scene = level
	var actor = level.get_node("ImportedGrandmotherGroundFloor")
	var player = level.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 0.0, -31.0)
	await physics_frame
	await physics_frame
	actor.global_basis = Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD)
	actor.global_position = Vector3(0.0, 3.92, -23.75)
	actor.velocity = Vector3.ZERO
	actor.surface.phase = actor.surface.Phase.CEILING
	actor.surface.normal = Vector3.DOWN
	actor.surface.ceiling_elapsed = 0.0
	actor.surface.elapsed = 0.0
	actor.surface.cooldown = 0.0
	actor._evidence_position = player.global_position
	actor._evidence_age = 0.0
	actor._surface_sense_timer = 999.0
	actor._player = player
	var gripped_face := false
	var reached_cap := false
	var entered_balcony := false
	var maximum_step := 0.0
	for frame in 300:
		var before: Vector3 = actor.surface._center()
		var before_state: String = str([actor.surface.phase, actor.surface.corner_active, actor.surface._corner_stage])
		await physics_frame
		if "--trace" in OS.get_cmdline_user_args() and before_state != str([actor.surface.phase, actor.surface.corner_active, actor.surface._corner_stage]): print("GAMEPLAY RAIL frame=", frame, " before=", before_state, " after=", [actor.surface.phase, actor.surface.corner_active, actor.surface._corner_stage], " center=", actor.surface._center(), " normal=", actor.surface.normal, " up=", actor.basis.y, " commit=", actor.surface._horizontal_commit_remaining, " jumps=", actor.surface.spider_jump_count)
		maximum_step = maxf(maximum_step, before.distance_to(actor.surface._center()))
		gripped_face = gripped_face or actor.surface.phase == actor.surface.Phase.WALL
		reached_cap = reached_cap or (actor.surface.phase == actor.surface.Phase.CEILING and actor.surface.normal.y > 0.65 and actor.surface.corner_transitions >= 2)
		if reached_cap and actor.surface.phase == actor.surface.Phase.CEILING and actor.surface._center().z > -24.7:
			entered_balcony = true
			break
	check(gripped_face, "Gameplay AI did not grip the church balustrade")
	check(reached_cap, "Gameplay AI did not climb onto the church rail cap")
	check(entered_balcony, "Gameplay AI stayed on the rail instead of crossing onto the balcony")
	check(actor.surface.phase != actor.surface.Phase.DROP, "Gameplay AI dropped during the connected climb")
	check(maximum_step < 0.17, "Gameplay climb teleported the collision body")
	print("CHURCH GAMEPLAY CLIMB: failures=", failures, " transitions=", actor.surface.corner_transitions, " max_step=", maximum_step, " position=", actor.global_position)
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)
