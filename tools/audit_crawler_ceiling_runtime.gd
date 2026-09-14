extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	seed(140926)
	var level := load("res://levels/test.tscn").instantiate() as Node3D
	root.add_child(level)
	current_scene = level
	var actor: CharacterBody3D = level.get_node("ImportedGrandmotherGroundFloor")
	actor.set_physics_process(false)
	var ceiling := false
	var peak := actor.position.y
	var ceiling_frames := 0
	var accidental_drops := 0
	var previous_phase: int = actor.surface.phase
	var unsupported_frames := 0
	var physics_us := 0
	var ceiling_travel := 0.0
	var route: Array[Vector3] = [Vector3(-9, 0, -24), Vector3(9, 0, -24), Vector3(9, 0, -34), Vector3(-9, 0, -34)]
	for frame in 3600:
		await physics_frame
		if ceiling and "--patrol" in OS.get_cmdline_user_args():
			actor._evidence_position = route[(frame / 480) % route.size()]
			actor._evidence_age = 0.0
			actor._surface_sense_timer = 999.0
			actor._sight_confirmed = false
		var previous_center: Vector3 = actor.surface._center()
		var previous_support: Dictionary = actor.surface._ray(previous_center, previous_center - actor.surface.normal * 1.8)
		var penetration: bool = actor.surface.collision_guard.penetrates(actor.surface, actor.surface.collision.global_transform)
		var began := Time.get_ticks_usec()
		actor._physics_process(1.0 / 60.0)
		physics_us += Time.get_ticks_usec() - began
		if previous_phase == 2 and actor.surface.phase == 2 and not actor.surface.spider_busy(): ceiling_travel += previous_center.distance_to(actor.surface._center())
		if ceiling and actor.surface.phase == 3 and not actor.surface.spider_busy() and not actor.surface.pouncing: unsupported_frames += 1
		peak = maxf(peak, actor.position.y)
		if actor.surface.phase == 2 and actor.basis.y.y < -0.9:
			ceiling = true
			ceiling_frames += 1
		if actor.surface.phase == 3 and previous_phase in [1, 2] and not actor.surface.spider_busy() and not actor.surface.pouncing:
			accidental_drops += 1
		if "--trace" in OS.get_cmdline_user_args() and previous_phase != actor.surface.phase:
			print("LIVE TRANSITION frame=", frame, " from=", previous_phase, " to=", actor.surface.phase, " center=", actor.surface._center(), " normal=", actor.surface.normal, " up=", actor.basis.y, " corner=", actor.surface.corner_active, " recoveries=", actor.surface.collision_guard.recoveries, " jump=", actor.surface.spider_busy(), " pounce=", actor.surface.pouncing)
			if actor.surface.phase == 3: print("DROP CAUSE: penetration=", penetration, " support=", previous_support, " stuck=", actor._spider_stuck_elapsed, " goal_stall=", actor._spider_goal_stall, " transition_stall=", actor.surface._transition_stall, " reason=", actor.surface.spider_jump_reason, " forced=", actor._spider_forced_jumps, " plans=", actor.surface.spider_plans_checked, " target=", actor.surface.spider_target_position)
		previous_phase = actor.surface.phase
	print("LIVE CHURCH CEILING: reached=", ceiling, " position=", actor.position, " peak=", peak, " phase=", actor.surface.phase, " goal=", actor._has_ceiling_goal, " target=", actor._ceiling_goal)
	print("LIVE CEILING ENDURANCE: ceiling_seconds=", ceiling_frames / 60.0, " accidental_drops=", accidental_drops, " unsupported_frames=", unsupported_frames, " jumps=", actor.surface.spider_jump_count, " ceiling_travel=", ceiling_travel, " physics_avg_us=", physics_us / 3600)
	if not ceiling:
		push_error("Crawler did not prioritize the ceiling from the actual church spawn")
	level.queue_free()
	await process_frame
	if accidental_drops > 0 or unsupported_frames > 0 or ceiling_frames <= 1200: push_error("Crawler could not sustain ceiling travel/perching")
	var travelled := "--patrol" not in OS.get_cmdline_user_args() or ceiling_travel > 12.0
	if not travelled: push_error("Crawler remained perched instead of traversing the church vault")
	quit(0 if ceiling and ceiling_frames > 1200 and accidental_drops == 0 and unsupported_frames == 0 and travelled else 1)
