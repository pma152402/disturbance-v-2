extends SceneTree

var failures := 0
class Target:
	extends CharacterBody3D
	var hits := 0
	func is_personal_light_on() -> bool: return true
	func receive_monster_attack(_source: Node3D) -> void: hits += 1

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	seed(170925)
	var level := load("res://levels/test.tscn").instantiate() as Node3D
	root.add_child(level)
	current_scene = level
	var actor = level.get_node("ImportedGrandmotherGroundFloor")
	var original_player = level.get_node("Player")
	original_player.set_physics_process(false)
	original_player.remove_from_group("player")
	original_player.global_position = Vector3(0, 0, -29)
	original_player.collision_layer = 0
	actor.set_physics_process(false)
	var visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var target := Target.new()
	target.add_to_group("player")
	target.collision_layer = 2
	target.collision_mask = 5
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	collision.shape = shape
	collision.position.y = 0.85
	target.add_child(collision)
	level.add_child(target)
	target.position = Vector3(0.25, 0, -26)
	for frame in 180:
		await physics_frame
	var longest_stall := 0.0
	var detours := 0
	var visible_samples := 0
	var total_moved := 0.0
	var worst_step := 0.0
	var attempted_frames := 0
	var total_physics_us := 0
	# Central and outer church aisles. The target reverses naturally at each end
	# while the complete senses/navigation/combat/escape stack continues running.
	for lane_x in [0.25, -8.25]:
		actor.global_position = Vector3(lane_x, 0.0, -29.5)
		actor.global_basis = Basis.IDENTITY
		actor.velocity = Vector3.ZERO
		actor.force_update_transform()
		actor.surface.phase = actor.surface.Phase.GROUND
		actor.surface.normal = Vector3.UP
		actor.surface.cooldown = 0.0
		actor.surface.spider_winding_up = false
		actor.surface.spider_leaping = false
		actor.surface._spider_retreating = false
		actor.surface.spider_settling = 0.0
		actor.surface.corner_active = false
		actor.surface.pouncing = false
		actor.surface.winding_up = false
		actor._spider_chain_remaining = 0
		actor._spider_stuck_origin = actor.surface._center()
		actor._spider_stuck_elapsed = 0.0
		actor._spider_goal_stall = 0.0
		actor._spider_best_goal_distance = INF
		actor._spider_was_advancing = false
		actor._spider_retry_timer = 0.0
		actor._navigation_detour_timer = 0.0
		actor._escape_walk_remaining = 0.0
		actor._steering_timer = 0.0
		actor._player = target
		actor._prey = target
		actor._prey_refresh_timer = 1000.0
		target.global_position = Vector3(lane_x, 0, -26.0)
		actor._evidence_position = target.global_position
		actor._evidence_age = 0.0
		actor._recognition = 1.0
		actor._sight_confirmed = true
		actor.intent = actor.Intent.HUNT
		actor._change_state(actor.State.CHASE)
		actor._has_ceiling_goal = true
		actor._ceiling_goal = Vector3(-11, 0, -29.5)
		visual._reset_contacts()
		var progress_origin: Vector3 = actor.surface._center()
		var stalled := 0.0
		for frame in 1800:
			var dt := 1.0 / 60.0
			var cycle := fposmod(float(frame) * dt * 2.15, 14.0)
			var z := -26.0 - (cycle if cycle < 7.0 else 14.0 - cycle)
			var next := Vector3(lane_x, 0.0, z)
			target.velocity = ((next - target.global_position) / dt).limit_length(2.15)
			target.move_and_slide()
			var before: Vector3 = actor.surface._center()
			var state_before: int = actor.current_state
			var chains_before: int = actor._spider_forced_jumps
			var stall_before: float = actor._spider_stuck_elapsed
			var began := Time.get_ticks_usec()
			actor._physics_process(dt)
			if actor._spider_forced_jumps > chains_before and "--trace" in OS.get_cmdline_user_args():
				print("ESCAPE pasillo=", lane_x, " frame=", frame, " posición=", before, " estado=", state_before, " atasco=", stall_before, " sin_acercarse=", actor._spider_goal_stall, " objetivo=", actor._spider_progress_goal)
			total_physics_us += Time.get_ticks_usec() - began
			visual._physics_process(dt)
			var after: Vector3 = actor.surface._center()
			if before.distance_to(after) > 0.42:
				print("LARGE STEP lane=", lane_x, " frame=", frame, " from=", before, " to=", after, " state=", state_before, "/", actor.current_state, " phase=", actor.surface.phase, " target=", target.global_position)
			total_moved += before.distance_to(after)
			worst_step = maxf(worst_step, before.distance_to(after))
			if actor._sight_confirmed and actor._evidence_position.distance_to(actor.global_position) < 6.0 and not actor.surface.active():
				visible_samples += 1
				if actor._has_ceiling_goal:
					detours += 1
			if actor._was_trying_to_move and actor.current_state not in [actor.State.ATTACK, actor.State.EAT]:
				attempted_frames += 1
				if after.distance_to(progress_origin) >= 0.16:
					progress_origin = after
					stalled = 0.0
				else:
					stalled += dt
					longest_stall = maxf(longest_stall, stalled)
			else:
				progress_origin = after
				stalled = 0.0
			await physics_frame
	check(visible_samples > 900, "Sustained church chase lost a lit nearby target excessively")
	check(detours == 0, "A nearby visible player was abandoned for a ceiling detour")
	check(total_moved > 20.0 and attempted_frames > 400, "Creature did not sustain pursuit through church aisles")
	check(longest_stall < 1.6, "La persecución permaneció bloqueada más allá del plazo de recuperación rápida")
	check(worst_step < 0.42, "Navigation/escape teleported the creature")
	print("CRAWLER PURSUIT STABILITY: failures=", failures, " seconds=60 visible_frames=", visible_samples, " detours=", detours, " travelled=", total_moved, " longest_stall=", longest_stall, " max_step=", worst_step, " hits=", target.hits, " forced_chains=", actor._spider_forced_jumps, " physics_avg_us=", total_physics_us / 3600)
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)
