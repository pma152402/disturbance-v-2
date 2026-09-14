extends SceneTree
## Reproduce penetration, interrupted dives and loss of support, not just clear arcs.
var failures := 0
var checks := 0
var world: Node3D
var actor: CharacterBody3D
var visual: Node3D

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

func reset_at(center: Vector3, basis_: Basis, phase_: int) -> void:
	actor.vomit.cancel()
	actor.global_transform = Transform3D(basis_, center - basis_ * actor.surface.collision.position)
	actor.force_update_transform()
	actor.velocity = Vector3.ZERO
	actor.surface.phase = phase_
	actor.surface.normal = basis_.y.normalized()
	actor.surface.wall_normal = Vector3.BACK
	actor.surface.spider_winding_up = false
	actor.surface.spider_leaping = false
	actor.surface._spider_retreating = false
	actor.surface.spider_settling = 0.0
	actor.surface._release_remaining = 0.0
	actor.surface.corner_active = false
	actor.surface.pouncing = false
	actor.surface.winding_up = false
	actor.surface.spider_jump_cooldown = 0.0
	actor._spider_chain_remaining = 0
	visual._reset_contacts()

func bottom() -> float:
	var shape: CapsuleShape3D = actor.surface.collision.shape
	var up: Vector3 = actor.surface.collision.global_basis.y
	return actor.surface._center().y - (shape.height * 0.5 - shape.radius) * absf(up.y) - shape.radius * up.length()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	box(Vector3(24, 0.04, 24), Vector3(0, -0.02, 0))
	actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.spider_jump_enabled = false
	visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	await physics_frame
	await physics_frame
	# A tiny initial overlap makes cast_motion ignore the already intersecting
	# floor. Recovery must move to the free side, never continue down through it.
	reset_at(Vector3(0, 0.675, 0), Basis.IDENTITY, actor.surface.Phase.DROP)
	var lowest := bottom()
	for i in 90:
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, false)
		lowest = minf(lowest, bottom())
		await physics_frame
	check(lowest > -0.035 and bottom() > -0.004, "Initial overlap sends crawler through a thin floor instead of recovering")
	check(actor.surface.phase == actor.surface.Phase.GROUND, "Recovered penetration never hands back grounded movement")
	# Initial penetration can also happen against walls/ceilings or a moving
	# door. Recovery stays bounded and invalidates the saved animation/route.
	var wall := box(Vector3(0.05, 5, 8), Vector3(3, 2.5, 0))
	var roof := box(Vector3(8, 0.05, 8), Vector3(0, 4, 0))
	await physics_frame
	await physics_frame
	for placement in [Transform3D(Basis.IDENTITY, Vector3(2.65, 1.7, 0)), Transform3D(Basis(Vector3.BACK, PI), Vector3(0, 3.30, 0))]:
		reset_at(placement.origin, placement.basis, actor.surface.Phase.DROP)
		actor.surface.spider_leaping = true
		actor._has_ceiling_goal = true
		var largest_correction := 0.0
		for i in 15:
			var before: Vector3 = actor.surface._center()
			actor.surface.ensure_body_clear()
			largest_correction = maxf(largest_correction, before.distance_to(actor.surface._center()))
			await physics_frame
		check(not actor.surface.collision_guard.penetrates(actor.surface, actor.surface.collision.global_transform), "Wall/ceiling overlap is not released")
		check(not actor.surface.spider_leaping and not actor._has_ceiling_goal and largest_correction <= 0.081, "Overlap retained an obsolete flight/route or teleported")
	wall.free()
	roof.free()
	# Both end capsules fit, but the middle of a half turn clips this beam.
	var beam := box(Vector3(4, 0.16, 0.1), Vector3(0, 2, 0.57))
	reset_at(Vector3(0, 2, 0), Basis.IDENTITY, actor.surface.Phase.DROP)
	await physics_frame
	await physics_frame
	var before_turn: Transform3D = actor.global_transform
	check(not actor.surface.collision_guard.rotate_to(actor.surface, Basis(Vector3.RIGHT, PI)), "Rotation only checked its endpoints and passed through a beam")
	check(actor.global_transform.is_equal_approx(before_turn), "Failed rotation left the capsule half inside the beam")
	check(not actor.surface.JumpPlanner.clear_segment(actor.surface, actor.surface.collision.global_transform, Transform3D(Basis(Vector3.RIGHT, PI), actor.surface._center())), "Jump planner missed the same intermediate rotation collision")
	beam.free()
	# The ordinary ceiling dive must rotate before contact, including slow
	# frames and the low underside of a church balcony.
	for height in [1.9, 3.2, 6.8]:
		for fps in [20, 30, 60, 120]:
			reset_at(Vector3(0, height, 0), Basis(Vector3.BACK, PI), actor.surface.Phase.CEILING)
			actor.surface.pounce_aim = Vector3(1.1, 0.85, 1.4)
			actor.surface._begin_pounce()
			lowest = 100.0
			var contact_alignment := -1.0
			var limb_ready := true
			for i in fps * 5:
				actor.surface.step(1.0 / fps, Vector3.ZERO, false)
				visual._physics_process(1.0 / fps)
				lowest = minf(lowest, bottom())
				if contact_alignment < 0.0 and bottom() < 0.03:
					contact_alignment = actor.global_basis.y.y
					if actor.surface.pouncing:
						for index in 4:
							limb_ready = limb_ready and actor.to_local(visual.contacts[index]).distance_to(visual.REST_CONTACTS[index]) < 0.02
				if actor.surface.phase == actor.surface.Phase.GROUND: break
				await physics_frame
			check(lowest > -0.004, "Ceiling dive penetrates floor at height=%s fps=%s" % [height, fps])
			check(actor.surface.phase == actor.surface.Phase.GROUND and actor.global_basis.y.y > 0.995, "Ceiling dive remains sideways/stuck at height=%s fps=%s" % [height, fps])
			check(contact_alignment > 0.98, "Ceiling dive reaches floor before preparing feet at height=%s fps=%s alignment=%s" % [height, fps, contact_alignment])
			check(limb_ready, "Dive reaches floor with hands/feet still tucked at height=%s fps=%s" % [height, fps])
	# A long frame must not push a fast drop through a four-centimetre slab.
	reset_at(Vector3(0, 1.8, 0), Basis.IDENTITY, actor.surface.Phase.DROP)
	actor.velocity = Vector3.DOWN * 18
	actor.surface.step(0.25, Vector3.ZERO, false)
	check(bottom() > -0.004 and actor.surface.phase == actor.surface.Phase.GROUND, "Frame hitch tunnels through a thin floor")
	# Removing the launch platform during anticipation cancels the saved jump.
	var launch := box(Vector3(3, 0.15, 2.4), Vector3(0, 2, 0))
	reset_at(Vector3(0, 2.775, 0), Basis.IDENTITY, actor.surface.Phase.GROUND)
	await physics_frame
	await physics_frame
	check(actor.surface.begin_spider_jump({"position": Vector3(0, 0, 3.2), "normal": Vector3.UP}), "Could not set up a disappearing launch platform")
	launch.free()
	actor.surface.step(1.0 / 60.0, Vector3.ZERO, false)
	check(not actor.surface.spider_winding_up and not actor.surface.spider_leaping and actor.surface.phase == actor.surface.Phase.DROP, "Jump took off from a launch platform that no longer exists")
	# Settling must notice when its supporting platform is removed.
	var platform := box(Vector3(5, 0.15, 5), Vector3(0, 2, 0))
	await physics_frame
	await physics_frame
	reset_at(Vector3(0, 2.895, 0), Basis.IDENTITY, actor.surface.Phase.GROUND)
	actor.surface.spider_settling = 0.28
	platform.free()
	for i in 120:
		actor._physics_process(1.0 / 60.0)
		await physics_frame
	check(actor.global_position.y < 0.1 and bottom() > -0.004, "Removed landing support leaves crawler floating or underground")
	print("CRAWLER PHYSICS RECOVERY: failures=", failures, " checks=", checks)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
