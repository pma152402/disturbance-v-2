extends SceneTree
## Compare scaled-box contact refinement against an equivalent unscaled body.
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	seed(140926)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var guard := preload("res://enemies/crawler_collision_guard.gd").new()
	for dimensions in [Vector3(12, 0.24, 16), Vector3(0.24, 4, 10), Vector3(3, 3, 6)]:
		var rotation_ := Basis(Vector3(0.3, 0.6, 0.8).normalized(), 0.38)
		var origin := Vector3(1.7, 8.3, -5.6)
		var scaled := StaticBody3D.new()
		scaled.collision_layer = 16
		var source := CollisionShape3D.new()
		source.shape = BoxShape3D.new()
		source.shape.size = Vector3.ONE
		scaled.add_child(source)
		world.add_child(scaled)
		scaled.transform = Transform3D(rotation_.scaled_local(dimensions), origin)
		var reference := StaticBody3D.new()
		reference.collision_layer = 32
		var baked := CollisionShape3D.new()
		baked.shape = BoxShape3D.new()
		baked.shape.size = dimensions
		reference.add_child(baked)
		world.add_child(reference)
		reference.transform = Transform3D(rotation_, origin)
		await physics_frame
		await physics_frame
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = CapsuleShape3D.new()
		query.shape.height = 1.4
		query.shape.radius = 0.36
		query.collision_mask = 32
		query.margin = 0.0
		for sample in 320:
			var point: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (dimensions * 0.5 + Vector3.ONE)
			var pose_basis := Basis(Vector3(randf(), randf(), randf()).normalized(), randf_range(-PI, PI))
			query.transform = Transform3D(pose_basis, origin + rotation_ * point)
			var expected := not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
			check(guard._capsule_overlaps_box(query, source) == expected, "Scaled-box contact differs from equivalent baked collider: %s sample %s" % [dimensions, sample])
		query.transform = Transform3D(rotation_, origin)
		check(guard._capsule_overlaps_box(query, source), "Fully contained capsule was treated as clear")
		scaled.free()
		reference.free()
	print("SCALED BOX CONTACTS: failures=", failures, " checks=", checks)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
