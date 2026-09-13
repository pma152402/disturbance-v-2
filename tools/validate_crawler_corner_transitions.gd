extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
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

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, "Floor", Vector3(16, 0.2, 16), Vector3(0, -0.1, 0))
	# Underside ends at z=0. The fascia and balustrade make one climbable face.
	box(world, "BalconyUnderside", Vector3(10, 0.22, 5), Vector3(0, 4.0, -2.5))
	box(world, "BalconyFascia", Vector3(10, 0.32, 0.24), Vector3(0, 4.05, 0.0))
	box(world, "BalustradeCollision", Vector3(10, 1.15, 0.24), Vector3(0, 4.72, 0.0))
	var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	await physics_frame
	await physics_frame
	actor.surface.phase = actor.surface.Phase.CEILING
	actor.surface.normal = Vector3.DOWN
	actor.surface.ceiling_elapsed = 2.0
	actor.surface.cooldown = 0.0
	actor.position = Vector3(0, 3.81, -1.15)
	actor.basis = Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD)
	actor._evidence_position = Vector3(0, 0, 3)
	actor._evidence_age = 0.0
	visual._reset_contacts()
	var became_wall := false
	var returned_ceiling := false
	var crossed_rail := false
	var descended_other_face := false
	var maximum_step := 0.0
	for frame in 480:
		var before: Vector3 = actor.surface._center()
		actor.surface.step(1.0 / 60.0, actor._evidence_position, true)
		visual._physics_process(1.0 / 60.0)
		maximum_step = maxf(maximum_step, before.distance_to(actor.surface._center()))
		became_wall = became_wall or actor.surface.phase == actor.surface.Phase.WALL
		if became_wall and actor.surface.phase == actor.surface.Phase.CEILING and actor.surface.corner_transitions >= 2:
			returned_ceiling = true
		if returned_ceiling and actor.surface.phase == actor.surface.Phase.CEILING and actor.surface.normal.y > 0.65 and actor.surface._center().z < -0.35:
			crossed_rail = true
		if crossed_rail and actor.surface.phase == actor.surface.Phase.WALL and actor.surface.corner_transitions >= 3:
			descended_other_face = true
			break
		await physics_frame
	check(became_wall, "Could not wrap from balcony underside onto balustrade face")
	check(returned_ceiling, "Could not return from balustrade face to ceiling")
	check(crossed_rail, "Reached the rail cap but did not climb across it")
	check(descended_other_face, "Could not transition from the crossed rail back onto a wall")
	check(actor.surface.corner_transitions >= 3, "Missing connected ceiling-wall-rail transitions")
	check(maximum_step < 0.17, "Corner transition teleported the collision body")
	check(actor.surface.active(), "Dropped while a connected surface existed")
	print("CRAWLER CORNERS: failures=", failures, " transitions=", actor.surface.corner_transitions, " max_step=", maximum_step, " position=", actor.position)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
