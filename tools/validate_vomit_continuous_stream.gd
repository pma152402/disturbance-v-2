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
	seed(74560)
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	box(Vector3(50, 0.2, 50), Vector3(0, -0.1, 0))
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
	# Fix the mouth in an open lane to measure physical reach independently
	# from chaotic aim. Other suites exercise the real animated mouth.
	effects.mouth.top_level = true
	effects.mouth.global_position = Vector3(0, 1.2, 0)
	var origin: Vector3 = effects.mouth_position()
	var head_scale: Vector3 = visual._head.global_basis.get_scale()
	actor._prey = player
	actor._sight_confirmed = true
	actor.current_state = actor.State.CHASE
	attack.unlocked = true
	for fps in [30, 60, 120]:
		attack.cancel()
		player.position = Vector3(0, 0.9, 13.5)
		player.get_camera_lens_grime().dirt = 0.0
		await physics_frame
		await physics_frame
		check(attack.can_begin(), "Target at 13.5 m is still outside acquisition range")
		var direction: Vector3 = attack._aim_at(attack._target_point())
		var side := Vector3.UP.cross(direction).normalized()
		visual._head.global_basis = Basis(side, direction.cross(side), direction).scaled_local(head_scale)
		attack.phase = attack.Phase.SPRAY
		effects.wake()
		effects.set_physics_process(false)
		var first_contact := -1.0
		var max_range := 0.0
		for i in fps * 2:
			attack._lens_contact_cooldown = maxf(0.0, attack._lens_contact_cooldown - 1.0 / fps)
			effects._physics_process(1.0 / fps)
			if player.get_camera_lens_grime().dirt > 0.0 and first_contact < 0.0:
				first_contact = float(i + 1) / fps
			if not effects._stream_points.is_empty():
				max_range = maxf(max_range, effects._stream_points[-1].distance_to(origin))
			await physics_frame
		check(first_contact > 0.8 and first_contact < 1.2 and player.get_camera_lens_grime().dirt > 0.3, "Jet fails actual long-range contact or teleports to target")
		check(effects.stream.visible and effects.stream.ring_count > 20 and effects.stream.ring_count <= effects.stream.MAX_RINGS, "Missing/unbounded continuous long-range surface")
		check(effects._stream_points[0].is_equal_approx(origin), "Continuous jet detaches from mouth")
		check(effects.batch.multimesh.mesh is SphereMesh and effects._sizes[0] < 0.05 and effects._chunks[0] != 0, "Large spheres still form the stream silhouette")
		check(player._monster_hits == 0, "Continuous stream damages health")
		print("CONTINUOUS RANGE fps=", fps, " first_contact=", first_contact, " distance=", max_range, " rings=", effects.stream.ring_count)
		attack.cancel()
	# Without a player stopping it, the centreline must reach exactly 14 m.
	player.position = Vector3(8, 0.9, 16)
	await physics_frame
	var direction: Vector3 = attack._aim_at(origin + Vector3(0, 0, 14))
	var side := Vector3.UP.cross(direction).normalized()
	visual._head.global_basis = Basis(side, direction.cross(side), direction).scaled_local(head_scale)
	attack.phase = attack.Phase.SPRAY
	effects.wake()
	effects.set_physics_process(false)
	for i in 90: effects._physics_process(1.0 / 60.0)
	check(absf(effects._stream_points[-1].distance_to(origin) - 14.0) < 0.01, "Pool/time cap silently shortens the 14 m jet")
	check(absf(effects._stream_radii[0] - 0.105) < 0.001 and effects._stream_radii[-1] > 1.05 and effects._stream_radii[-1] < 1.15, "Jet does not retain its mouth attachment and narrower end")
	var mesh: ArrayMesh = effects.stream.mesh
	var arrays := mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uses := {}
	for i in range(0, indices.size(), 3):
		for corner in 3:
			var a := indices[i + corner]
			var b := indices[i + (corner + 1) % 3]
			var edge := Vector2i(mini(a, b), maxi(a, b))
			uses[edge] = int(uses.get(edge, 0)) + 1
	var closed := true
	for count_: int in uses.values():
		if count_ != 2: closed = false
	check(closed and mesh.get_surface_count() == 1, "Liquid has disconnected/open triangles instead of one closed surface")
	# A wall must stop the centre and the full visible edge of the column.
	var blocker := box(Vector3(12, 8, 0.2), Vector3(0, 4, 7))
	player.position = Vector3(0, 0.9, 12)
	player.get_camera_lens_grime().dirt = 0.0
	await physics_frame
	await physics_frame
	for i in 75:
		attack._lens_contact_cooldown = 0.0
		effects._physics_process(1.0 / 60.0)
		await physics_frame
	var crossed_wall := false
	for vertex: Vector3 in effects.stream.vertices:
		if vertex.z > 6.91: crossed_wall = true
	check(not crossed_wall and effects._stream_points[-1].z < 6.91, "Wide liquid mesh protrudes through a blocking wall")
	check(player.get_camera_lens_grime().dirt == 0.0, "Wall does not shield long-range lens contact")
	check(effects.puddles.deposited_hits > 0, "Clipped liquid leaves no impact stains")
	attack.phase = attack.Phase.DRIP
	var escaped_during_drain := false
	for i in 110:
		effects._physics_process(1.0 / 60.0)
		if effects.stream.visible:
			for vertex: Vector3 in effects.stream.vertices:
				if vertex.z > 6.91: escaped_during_drain = true
	check(not escaped_during_drain and not effects.stream.visible, "Draining tail reappears beyond the impact wall")
	blocker.free()
	# A wall alongside the stream clips its edge without stopping the centre.
	blocker = box(Vector3(0.2, 8, 30), Vector3(0.9, 4, 10))
	player.position = Vector3(8, 0.9, 16)
	await physics_frame
	await physics_frame
	attack.phase = attack.Phase.SPRAY
	for i in 90: effects._physics_process(1.0 / 60.0)
	var crossed_side := false
	for vertex: Vector3 in effects.stream.vertices:
		if vertex.x > 0.81: crossed_side = true
	check(not crossed_side and effects._stream_points[-1].z > 13.9, "Expanded edge clips incorrectly or stops a clear central path")
	attack.phase = attack.Phase.DRIP
	for i in 110: effects._physics_process(1.0 / 60.0)
	check(not effects.stream.visible and effects._stream_age == 0.0, "Continuous surface remains suspended after draining")
	attack.cancel()
	check(not effects.stream.visible and not effects.is_physics_processing(), "Cancel leaves stream/process active")
	print("CONTINUOUS STREAM: failures=", failures, " checks=", checks)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
