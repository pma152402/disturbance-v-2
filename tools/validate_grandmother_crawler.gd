extends SceneTree
var failures := 0
var samples := 0
var max_contact_error := 0.0
var visual_usec := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures <= 15:
			push_error(message)

func box(parent: Node, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = at

func closed_mesh(mesh: ArrayMesh) -> bool:
	var edges := {}
	var arrays := mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		for j in 3:
			var a := indices[i + j]
			var b := indices[i + (j + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			edges[key] = edges.get(key, 0) + 1
	for count in edges.values():
		if count != 2:
			return false
	return true

func audit(visual: Node, contacts: bool = false) -> void:
	samples += 1
	for i in 2:
		var leg = visual.legs[i]
		var hip: Vector3 = visual.hips[i].global_position
		var knee: Vector3 = visual.knees[i].global_position
		var ankle: Vector3 = visual.ankles[i].global_position
		check(absf(hip.distance_to(knee) - 0.73) < 0.0001, "Thigh changed length")
		check(absf(knee.distance_to(ankle) - 0.73) < 0.0001, "Shin changed length")
		check(leg.to_global(leg.points[3]).distance_to(knee) < 0.0001, "Knee detached from skin")
		check(leg.to_global(leg.points[5]).distance_to(ankle) < 0.0001, "Ankle detached from skin")
		var arm = visual._continuous_arms[i]
		check(arm.to_global(arm._last_points[4]).distance_to(arm.elbow.global_position) < 0.0001, "Elbow detached")
		check(arm.to_global(arm._last_points[8]).distance_to(arm.palm.to_global(arm.palm.get_aabb().get_center())) < 0.0001, "Palm detached")
		var chest: Vector3 = visual.torso.points[4]
		check(visual.anatomy.to_local(arm.to_global(arm.mount)).distance_to(chest) < 0.24, "Shoulder mount outside torso")
		check(leg.points[0].distance_to(visual.torso.points[1]) < 0.19, "Hip mount outside pelvis")
		if contacts:
			var palm_error: float = arm.palm.global_position.distance_to(visual.contacts[i])
			var foot_error := ankle.distance_to(visual.contacts[i + 2])
			max_contact_error = maxf(max_contact_error, maxf(palm_error, foot_error))
			check(palm_error < 0.09, "Hand lost support: %.3f" % palm_error)
			check(foot_error < 0.09, "Foot lost support: %.3f" % foot_error)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, Vector3(30, 0.2, 30), Vector3(0, -0.1, 0))
	var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	var visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(not visual._rig.get_node("Body").visible, "Original skirt still visible")
	for fps in [30, 60, 120]:
		actor.position = Vector3.ZERO
		actor.rotation = Vector3.ZERO
		visual._reset_contacts()
		for frame in fps * 4:
			var dt: float = 1.0 / fps
			var moving: bool = frame < fps * 3
			if moving:
				actor.rotation.y += dt * 0.25
				actor.position += actor.basis.z * dt * 1.4
			actor._idle_clock += dt
			var start := Time.get_ticks_usec()
			visual._physics_process(dt)
			visual_usec += Time.get_ticks_usec() - start
			audit(visual, true)
		for point in visual.contacts:
			check(absf(point.y - 0.065) < 0.012, "Limb remains airborne after stopping")
		# Also exercise the actual chase speed configured in levels/test.tscn.
		actor.position = Vector3.ZERO
		actor.rotation = Vector3.ZERO
		visual._reset_contacts()
		for frame in fps * 2:
			var dt: float = 1.0 / fps
			actor.position.z += dt * 3.55
			actor._idle_clock += dt
			var start := Time.get_ticks_usec()
			visual._physics_process(dt)
			visual_usec += Time.get_ticks_usec() - start
			audit(visual, true)
	for part in [visual.torso, visual.collar, visual.legs[0], visual.legs[1]]:
		check(closed_mesh(part.mesh), "Open edges in " + str(part.name))
	for side in [1.0, -1.0]:
		actor.current_state = 4
		actor.attack_side = side
		for frame in 90:
			actor._attack_timer = float(frame) / 60.0
			visual._physics_process(1.0 / 60.0)
			audit(visual)
	actor.current_state = 0
	actor.position = Vector3.ZERO
	actor.rotation = Vector3.ZERO
	box(world, Vector3(18, 6, 0.2), Vector3(0, 3, 1.5))
	box(world, Vector3(18, 0.2, 18), Vector3(0, 5.1, 0))
	var church := "--church" in OS.get_cmdline_user_args()
	var clue := Vector3(0, 0, -3)
	var wall_clue := Vector3(0, 0, 5)
	if church:
		for node in world.get_children():
			if node is StaticBody3D:
				node.free()
		var scene := load("res://levels/house_baked.tscn").instantiate() as Node3D
		for floor_name in ["GroundFloor", "UpperFloor"]:
			var floor_root := scene.get_node(floor_name) as Node3D
			for child in floor_root.get_children():
				if child is StaticBody3D and str(child.name).begins_with("Church"):
					var body := child.duplicate() as StaticBody3D
					body.transform = floor_root.transform * child.transform
					world.add_child(body)
		actor.position = Vector3(-10.5, 0, -32.5)
		wall_clue = Vector3(-20, 0, -32.5)
		clue = Vector3(-5, 0, -32.5)
		scene.free()
	await physics_frame
	await physics_frame
	actor.surface.cooldown = 0
	actor.surface.consider(0.6, wall_clue, true)
	check(actor.surface.active(), "Did not attach to wall")
	var ceiling := false
	var inverted := false
	var peak := 0.0
	var perch_frames := 0
	for frame in 1500:
		var before: Vector3 = actor.surface._center()
		var was_falling: bool = actor.surface.phase == actor.surface.Phase.DROP
		actor.surface.step(1.0 / 60.0, clue, true)
		var after: Vector3 = actor.surface._center()
		# Manual release uses a 10 m/s terminal fall (16.67 cm at 60 Hz).
		# Keep the stricter bound for supported travel and corner transitions.
		check(before.distance_to(after) < (10.0 / 60.0 + 0.001 if was_falling else 0.16), "Teleport during surface transition")
		ceiling = ceiling or actor.surface.phase == 2
		inverted = inverted or actor.basis.y.y < -0.85
		if actor.surface.phase == 2 and actor.basis.y.y < -0.85:
			perch_frames += 1
			if perch_frames == 600:
				# The new variant stays upstairs. Explicitly release to test landing.
				actor.surface.phase = 3
		peak = maxf(peak, after.y)
		visual._physics_process(1.0 / 60.0)
		audit(visual)
		if not actor.surface.active():
			break
		await physics_frame
	check(ceiling and inverted, "Did not crawl inverted on ceiling")
	check(perch_frames >= 600, "Abandoned the ceiling without an attack or lost support")
	check(not actor.surface.active() and actor.basis.y.y > 0.99, "Did not land upright")
	check(peak > (6.0 if church else 3.5), "Did not reach roof")
	actor.position = Vector3(0, 0, -6)
	actor.surface.cooldown = 0
	actor.surface.scan_timer = 0
	actor.surface.consider(0.6, Vector3(0, 0, -12), true)
	check(not actor.surface.active(), "Climbed empty air")
	actor.surface.phase = 1
	actor.surface.step(1.0 / 60.0, clue, false)
	check(not actor.surface.pouncing, "Launched an attack without a fresh sighting")
	print("CRAWLER VALIDATION: failures=", failures, " samples=", samples, " contact_error=", max_contact_error, " visual_us=", visual_usec / 1260, " peak=", peak, " ceiling=", ceiling, " inverted=", inverted, " church=", church)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
