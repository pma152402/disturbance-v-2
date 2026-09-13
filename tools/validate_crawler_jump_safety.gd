extends SceneTree
## Adversarial physics checks, including changes after planning and variable FPS.
var failures := 0
var samples := 0
var actor: CharacterBody3D
var visual: Node
var planning_usec := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 20:
			push_error(message)

func box(parent: Node, name_: String, size: Vector3, point: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = point
	return body

func reset_actor() -> void:
	actor.global_transform = Transform3D.IDENTITY
	actor.force_update_transform()
	actor.velocity = Vector3.ZERO
	actor.surface.phase = actor.surface.Phase.GROUND
	actor.surface.normal = Vector3.UP
	actor.surface.spider_winding_up = false
	actor.surface.spider_leaping = false
	actor.surface._spider_retreating = false
	actor.surface.spider_settling = 0.0
	actor.surface.spider_jump_cooldown = 0.0
	actor.surface._release_remaining = 0.0
	actor._spider_chain_remaining = 0
	visual._reset_contacts()

func overlaps() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	# Resting floor contact is expected. Detect penetration beyond a 2mm
	# numerical tolerance, rather than counting touching as interpenetration.
	var shape: CapsuleShape3D = actor.get_node("Collision").shape.duplicate()
	shape.radius -= 0.002
	shape.height -= 0.004
	query.shape = shape
	query.transform = actor.get_node("Collision").global_transform
	query.exclude = [actor.get_rid()]
	query.collision_mask = actor.collision_mask | (1 << 19)
	query.margin = 0.0
	return not actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func tick(dt: float) -> void:
	actor.surface.step(dt, Vector3.ZERO, false)
	actor._idle_clock += dt
	visual._physics_process(dt)
	samples += 1
	check(not overlaps(), "Rotating capsule penetrated scenery during a jump")
	if actor.surface.spider_leaping and actor.surface.spider_flight_time / actor.surface.spider_flight_duration >= 0.9:
		check(actor.global_basis.y.normalized().dot(actor.surface.spider_target_normal) > 0.995, "Llegó al apoyo todavía girando de lado")
		for index in 4:
			var contact: Vector3 = actor.to_local(visual.contacts[index])
			check(contact.distance_to(visual.REST_CONTACTS[index]) < 0.02, "Las extremidades seguían recogidas justo antes del aterrizaje")
		for index in 2:
			check(visual.ankles[index].global_position.distance_to(visual.contacts[index + 2]) < 0.02, "El pie visible no alcanzó su apoyo antes de aterrizar")
	await physics_frame

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, "Floor", Vector3(20, 0.2, 20), Vector3(0, -0.1, 0))
	var roof := box(world, "Roof", Vector3(20, 0.2, 20), Vector3(0, 4.1, 0))
	actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.spider_jump_enabled = false
	visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	await physics_frame
	await physics_frame
	for fps in [30, 60, 120]:
		reset_actor()
		var began := Time.get_ticks_usec()
		var started: bool = actor.surface.begin_spider_jump({"position": Vector3(0, 4, 0), "normal": Vector3.DOWN})
		planning_usec = maxi(planning_usec, Time.get_ticks_usec() - began)
		check(started, "Valid ceiling jump rejected at %d FPS" % fps)
		for frame in fps * 3:
			await tick(1.0 / fps)
			if not actor.surface.spider_busy():
				break
		check(actor.surface.phase == actor.surface.Phase.CEILING and actor.global_basis.y.y < -0.995, "Did not reach ceiling feet-first at %d FPS" % fps)
		actor.surface.spider_jump_cooldown = 0.0
		started = actor.surface.begin_spider_jump({"position": Vector3(0.8, 0, 0), "normal": Vector3.UP})
		check(started, "Valid ceiling-to-floor jump rejected at %d FPS" % fps)
		for frame in fps * 3:
			await tick(1.0 / fps)
			if not actor.surface.spider_busy():
				break
		check(actor.surface.phase == actor.surface.Phase.GROUND and actor.global_basis.y.y > 0.995, "Landed on back at %d FPS" % fps)
		var foot_error := 0.0
		for point in visual.contacts:
			foot_error = maxf(foot_error, absf(point.y - 0.065))
		check(foot_error < 0.02, "Landing limbs remained in the flight pose: %.4f at %d FPS" % [foot_error, fps])
		reset_actor()
		check(not actor.surface.begin_spider_jump({"position": Vector3(0, 0, 5.2), "normal": Vector3.UP}), "Accepted a jump beyond the five-metre limit")
		started = actor.surface.begin_spider_jump({"position": Vector3(0, 0, 4.8), "normal": Vector3.UP})
		check(started, "Safe 4.8m jump rejected at %d FPS" % fps)
		for frame in fps * 3:
			await tick(1.0 / fps)
			if not actor.surface.spider_busy():
				break
		check(actor.surface.phase == actor.surface.Phase.GROUND and actor.global_basis.y.y > 0.995, "Long jump did not land feet-first at %d FPS" % fps)
		check(absf(actor.global_position.z - 4.8) < 0.03, "Long jump stopped short of its validated destination")
		check(actor.surface.spider_flight_duration < 0.68, "Long jump lost its fast flight speed")

	reset_actor()
	actor.surface._spider_recent.clear()
	var escape: Dictionary = actor.surface.find_spider_jump_target(Vector3.BACK)
	check(not escape.is_empty() and Vector3(escape.get("position", Vector3.ZERO)).z > 3.3, "Open-space recovery still prefers tiny hops")

	# Valid endpoint behind an impassable divider: the arc must be rejected
	# BEFORE takeoff, which the original endpoint-only checks could not do.
	reset_actor()
	var barrier := box(world, "Divider", Vector3(6, 5, 0.2), Vector3(0, 2.5, 1.1))
	await physics_frame
	await physics_frame
	check(not actor.surface.begin_spider_jump({"position": Vector3(0, 0, 2.2), "normal": Vector3.UP}), "Accepted a clear endpoint through a solid wall")
	barrier.queue_free()
	await physics_frame
	await physics_frame
	# A low roof must select a low arc, rather than the fixed high hop.
	roof.position.y = 1.9
	await physics_frame
	await physics_frame
	check(actor.surface.begin_spider_jump({"position": Vector3(0, 0, 2.0), "normal": Vector3.UP}), "Could not choose a low arc under a 1.8m roof")
	for frame in 180:
		await tick(1.0 / 60.0)
		if not actor.surface.spider_busy():
			break
	check(actor.surface.phase == actor.surface.Phase.GROUND, "Low-ceiling hop wedged on the roof")
	roof.position.y = 4.1

	# Move an obstacle into the already planned landing during preparation.
	reset_actor()
	var obstacle := box(world, "MovingBlocker", Vector3(1.2, 1.6, 0.6), Vector3(7, 0.8, 2.2))
	await physics_frame
	await physics_frame
	check(actor.surface.begin_spider_jump({"position": Vector3(0, 0, 2.2), "normal": Vector3.UP}), "Could not prepare cancellation test")
	var count: int = actor.surface.spider_jump_count
	obstacle.position.x = 0.0
	await physics_frame
	await physics_frame
	for frame in 40:
		await tick(1.0 / 60.0)
	check(actor.surface.spider_jump_count == count and actor.surface.phase == actor.surface.Phase.GROUND, "Took off into an obstacle arriving during windup")

	# Move that obstacle in AFTER takeoff. The actor must retreat physically and
	# regain its support without ending sideways or remaining in DROP forever.
	reset_actor()
	obstacle.position.x = 7.0
	await physics_frame
	await physics_frame
	check(actor.surface.begin_spider_jump({"position": Vector3(0, 0, 2.2), "normal": Vector3.UP}), "Could not prepare interrupted flight")
	for frame in 90:
		await tick(1.0 / 60.0)
		if actor.surface.spider_leaping:
			break
	var aborts_before: int = actor.surface.spider_aborts
	obstacle.position.x = 0.0
	await physics_frame
	await physics_frame
	for frame in 240:
		await tick(1.0 / 60.0)
		if not actor.surface.spider_busy() and actor.surface.phase == actor.surface.Phase.GROUND:
			break
	check(actor.surface.spider_aborts == aborts_before + 1, "Moving obstacle did not trigger a single controlled retreat")
	check(actor.surface.phase == actor.surface.Phase.GROUND and actor.global_basis.y.y > 0.995, "Interrupted flight never recovered an upright floor pose")
	check(actor.global_position.z < 1.0, "Interrupted flight crossed its blocking object")

	# A transition can become impossible after its corner was selected. It must
	# release and recover rather than staying forever in an exempt corner state.
	reset_actor()
	actor.surface.phase = actor.surface.Phase.CEILING
	actor.surface.corner_active = true
	actor.surface._corner_kind = 0
	actor.surface._corner_stage = 0
	actor.surface._corner_old_normal = Vector3.UP
	actor.surface._corner_face_normal = Vector3.BACK
	actor.surface._corner_face_position = Vector3(0, 0, 4)
	var released := false
	for frame in 360:
		await tick(1.0 / 60.0)
		released = released or not actor.surface.corner_active
		if released and actor.surface.phase == actor.surface.Phase.GROUND:
			break
	check(released and actor.surface.phase == actor.surface.Phase.GROUND, "Blocked corner remained outside every recovery watchdog")
	# A recovery must preserve real evidence and an interrupted child interaction.
	reset_actor()
	var memory := Vector3(1.7, 0, -2)
	actor._evidence_position = memory
	actor._evidence_age = 2.0
	actor._sight_confirmed = false
	actor.on_spider_jump_landed("stuck", Vector3.UP, actor.surface.Phase.GROUND)
	check(actor._evidence_position == memory and actor._evidence_age == 2.0, "Recovery invented a fresh player clue")
	var meal := CharacterBody3D.new()
	world.add_child(meal)
	actor._eating_target = meal
	actor._eating_timer = 9.0
	actor._spider_meal_suspended = true
	actor._resume_after_escape()
	check(actor.current_state == actor.State.EAT and actor._eating_timer == 9.0, "Recovery lost an unfinished eating interaction")

	print("CRAWLER JUMP SAFETY: failures=", failures, " samples=", samples, " fps=30/60/120 planning_max_us=", planning_usec, " retreats=", actor.surface.spider_aborts)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
