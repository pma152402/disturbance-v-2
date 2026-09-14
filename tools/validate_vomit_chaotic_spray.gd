extends SceneTree
var failures := 0
var checks := 0
var world: Node3D

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func box(size_: Vector3, point: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = size_
	body.add_child(collision)
	world.add_child(body)
	body.position = point
	return body

func run() -> void:
	seed(93502)
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	box(Vector3(24, 0.2, 24), Vector3(0, -0.1, 0))
	box(Vector3(24, 0.2, 24), Vector3(0, 4.1, 0))
	box(Vector3(0.2, 4.2, 24), Vector3(5.1, 2, 0))
	var player: CharacterBody3D = load("res://player/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	var actor: CharacterBody3D = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node3D = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var attack: Node3D = actor.vomit
	var effects: Node3D = attack.effects
	var cost_usec := 0
	var effect_steps := 0
	for attachment in 3:
		for fps in [30, 60, 120]:
			attack.cancel()
			actor.current_state = actor.State.CHASE
			actor._prey = player
			actor._sight_confirmed = true
			actor._spider_chain_remaining = 0
			actor.surface.phase = attachment
			actor.surface.normal = [Vector3.UP, Vector3.LEFT, Vector3.DOWN][attachment]
			actor.transform = [Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), Transform3D(Basis(Vector3.UP, Vector3.LEFT, Vector3.BACK), Vector3(4.88, 1.8, 0)), Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, PI), Vector3(0, 3.88, 0))][attachment]
			player.position = Vector3(2.2 if attachment == 1 else 0.0, 0.9, 3.2)
			player.get_camera_lens_grime().dirt = 0.0
			visual._reset_contacts()
			for i in 35: visual._physics_process(1.0 / 60.0)
			await physics_frame
			attack._begin()
			attack.phase = attack.Phase.SPRAY
			attack.spray_duration = 12.0
			effects.set_physics_process(false)
			var planted: Transform3D = actor.global_transform
			var max_tracking_error := 0.0
			var max_head_error := 0.0
			var max_chaos := 0.0
			var chaos_sum := 0.0
			var body_motion := 0.0
			var quadrants_hit := 0
			for i in fps * 8:
				var t: float = float(i) / fps
				var angle := t * TAU / 8.0
				# Full circle on floor/ceiling, and both ends of a wall while
				# remaining inside the room. No target freezes at a yaw limit.
				player.position = Vector3(sin(angle) * 3.2, 0.9, cos(angle) * 3.2) if attachment != 1 else Vector3(2.2, 0.9, cos(angle) * 3.2)
				var delta: float = 1.0 / fps
				actor._physics_process(delta)
				visual._physics_process(delta)
				var start := Time.get_ticks_usec()
				effects._physics_process(delta)
				cost_usec += Time.get_ticks_usec() - start
				effect_steps += 1
				if t > 0.6:
					max_tracking_error = maxf(max_tracking_error, attack.tracking_direction.angle_to(attack._aim_at(attack._last_aim)))
					max_head_error = maxf(max_head_error, visual._head.global_basis.z.normalized().angle_to(attack.aim_direction))
				var chaos: float = attack.tracking_direction.angle_to(attack.aim_direction)
				max_chaos = maxf(max_chaos, chaos)
				chaos_sum += chaos
				body_motion = maxf(body_motion, actor.global_position.distance_to(planted.origin) + actor.global_basis.y.distance_to(planted.basis.y) + actor.global_basis.z.distance_to(planted.basis.z))
				if i % (fps * 2) == fps * 2 - 1:
					if player.get_camera_lens_grime().dirt > 0.0: quadrants_hit += 1
					player.get_camera_lens_grime().dirt = 0.0
				await physics_frame
			check(body_motion < 0.0001 and attack.stationary(), "Creature moves during circular tracking")
			check(max_tracking_error < 0.18, "Tracking freezes when player passes around her")
			check(max_head_error < 0.4, "Articulated mouth detaches from current spray direction")
			check(max_chaos > 0.14 and chaos_sum / (fps * 8) > 0.06 and max_chaos < 0.45, "Spray lacks bounded chaotic motion")
			check(quadrants_hit >= 3 and player._monster_hits == 0, "Wide stream misses most quadrants or damages health")
			print("CHAOTIC SPRAY surface=", attachment, " fps=", fps, " tracking_error=", max_tracking_error, " head_error=", max_head_error, " chaos=", max_chaos, " quadrants=", quadrants_hit)
	# Expansion starts from the existing throat width, growing along travel.
	attack.cancel()
	attack.phase = attack.Phase.SPRAY
	var throat: float = effects._stream_radius(0.0)
	var far_width: float = effects._stream_radius(6.0)
	check(throat >= 0.081 and throat <= 0.136 and far_width > throat * 5.0, "Cone does not preserve throat width then expand strongly")
	# A glancing hit by expanded liquid counts, while a solid wall shields it.
	actor.transform = Transform3D.IDENTITY
	player.position = Vector3(0.65, 0.9, 3.0)
	await physics_frame
	attack._lens_contact_cooldown = 0.0
	player.get_camera_lens_grime().dirt = 0.0
	effects._touch_wide_stream(Vector3(0, 1.0, 2.8), Vector3(0, 1.0, 3.2), 0.5)
	check(player.get_camera_lens_grime().dirt >= 0.09, "Visible edge of wide spray does not stain camera")
	var blocker := box(Vector3(0.15, 2, 2), Vector3(0.28, 1, 3))
	await physics_frame
	await physics_frame
	attack._lens_contact_cooldown = 0.0
	player.get_camera_lens_grime().dirt = 0.0
	effects._touch_wide_stream(Vector3(0, 1.0, 2.8), Vector3(0, 1.0, 3.2), 0.5)
	check(player.get_camera_lens_grime().dirt == 0.0, "Expanded spray stains camera through a wall")
	blocker.free()
	attack.cancel()
	print("CHAOTIC SPRAY: failures=", failures, " checks=", checks, " average_effect_cpu_us=", float(cost_usec) / effect_steps)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
