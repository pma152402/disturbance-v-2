extends SceneTree
## Sustained support, not merely reaching CEILING for a single frame.
var failures := 0
var checks := 0
var world: Node3D
var actor: CharacterBody3D

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func box(size_: Vector3, point: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size_
	body.add_child(shape)
	world.add_child(body)
	body.position = point
	return body

func place(center: Vector3, up: Vector3 = Vector3.DOWN, forward: Vector3 = Vector3.BACK) -> void:
	var basis_: Basis = actor.surface.JumpPlanner.aligned_basis(up, forward)
	actor.global_transform = Transform3D(basis_, center - basis_ * actor.surface.collision.position)
	actor.force_update_transform()
	actor.surface.phase = actor.surface.Phase.CEILING
	actor.surface.normal = up
	actor.surface.corner_active = false
	actor.surface.spider_winding_up = false
	actor.surface.spider_leaping = false
	actor.surface._spider_retreating = false
	actor.surface.spider_settling = 0.0
	actor.surface.spider_jump_cooldown = 0.0
	actor.surface.pouncing = false
	actor.surface.winding_up = false
	actor.surface._horizontal_commit_remaining = 0.0
	actor.surface._release_remaining = 0.0
	actor._spider_chain_remaining = 0
	actor.velocity = Vector3.ZERO

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	box(Vector3(30, 0.04, 30), Vector3(0, -0.02, 0))
	var roof := box(Vector3(18, 0.2, 18), Vector3(0, 5.1, 0))
	actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("EditableVisual").set_physics_process(false)
	await physics_frame
	await physics_frame
	# The vault's existing attachment reach is 1.8 m. Previously anticipation
	# used 1.15 m and discarded the very support which had approved the jump.
	place(Vector3(0, 3.8, 0))
	check(actor.surface.begin_spider_jump({"position": Vector3(0, 5, 3.6), "normal": Vector3.DOWN}), "Could not prepare supported ceiling relocation")
	actor.surface.step(1.0 / 60.0, Vector3.ZERO, false)
	check(actor.surface.spider_winding_up, "Ceiling relocation immediately cancels and falls despite valid launch support")
	for i in 150:
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, false)
		await physics_frame
	check(actor.surface.phase == 2 and actor.basis.y.y < -0.98, "Ceiling relocation failed to land and retain ceiling support")
	# A small external correction may invalidate a flight, but a supported
	# crawler must retain its grip instead of dropping all the way to the floor.
	place(Vector3(0, 4.325, 0))
	for i in 30:
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, false)
		await physics_frame
	check(actor.surface.phase == 2 and actor.basis.y.y < -0.98, "Recovering a 2.5 cm ceiling overlap discards a valid grip")
	check(not actor.surface.collision_guard.penetrates(actor.surface, actor.surface.collision.global_transform), "Ceiling recovery leaves physical overlap")
	place(Vector3(0, 4.22, 0))
	actor._was_trying_to_move = true # Cached ground intent must not shorten a perch.
	actor._spider_was_advancing = false
	actor._spider_stuck_origin = actor.surface._center()
	actor._spider_stuck_elapsed = 0.0
	actor._spider_retry_timer = 0.0
	actor._evidence_age = 1000.0
	var jumps_before: int = actor.surface.spider_jump_count
	for i in 225:
		actor._update_spider_jump_behavior(1.0 / 60.0)
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, false)
		await physics_frame
	check(actor.surface.spider_jump_count == jumps_before and not actor.surface.spider_winding_up, "An intentional perch inherits the 0.8 s blocked-ground timer")
	var prepared := false
	for i in 60:
		actor._update_spider_jump_behavior(1.0 / 60.0)
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, false)
		await physics_frame
		if actor.surface.spider_winding_up:
			prepared = true
			break
	check(prepared, "Four seconds idle on the ceiling did not prepare relocation")
	check(actor.surface.spider_target_normal.y < -0.65, "Ceiling relocation ignored available ceiling landings")
	# Turn in place by 180 degrees without releasing, at multiple frame rates.
	for fps in [20, 30, 60, 120]:
		place(Vector3(0, 4.22, 0))
		var turn_time := 0.0
		for i in fps:
			actor.surface._orient(Vector3.DOWN, Vector3.FORWARD, 1.0 / fps)
			turn_time += 1.0 / fps
			if actor.global_basis.z.dot(Vector3.FORWARD) > cos(deg_to_rad(10.0)): break
		check(turn_time <= 0.35, "Ceiling half turn too slow at %s FPS: %s s" % [fps, turn_time])
		var ceiling_turn_time := turn_time
		check(actor.surface.phase == 2 and actor.basis.y.y < -0.98, "Fast turn lost ceiling orientation")
		actor.basis = Basis.IDENTITY
		turn_time = 0.0
		for i in fps:
			actor._turn_toward(PI, 1.0 / fps, 5.0)
			turn_time += 1.0 / fps
			if absf(wrapf(actor.rotation.y - PI, -PI, PI)) < deg_to_rad(10.0): break
		check(turn_time <= 0.5, "Ground half turn too slow at %s FPS: %s s" % [fps, turn_time])
		print("CRAWLER HALF TURN: fps=", fps, " ceiling=", ceiling_turn_time, " ground=", turn_time)
	# Two ceiling panels separated by a 2 cm seam: shoulders/feet still have
	# support on both sides when the centre ray passes through the join.
	roof.free()
	var left := box(Vector3(6, 0.2, 12), Vector3(-3.01, 5.1, 0))
	var right := box(Vector3(6, 0.2, 12), Vector3(3.01, 5.1, 0))
	await physics_frame
	await physics_frame
	place(Vector3(0, 4.22, 0), Vector3.DOWN, Vector3.RIGHT)
	for i in 120:
		actor.surface.step(1.0 / 60.0, Vector3(4, 0, 0), true)
		await physics_frame
	check(actor.surface.phase == 2 and actor.surface._center().x > 2, "Narrow ceiling panel seam causes a fall or prevents travel")
	# Retain real geometry requirements: removing both panels must release her.
	left.free()
	right.free()
	for i in 180:
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, false)
		await physics_frame
	check(actor.surface.phase == 0 and actor.position.y < 0.1, "Missing ceiling leaves unsupported hovering")
	print("CEILING ATTACHMENT: failures=", failures, " checks=", checks)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
