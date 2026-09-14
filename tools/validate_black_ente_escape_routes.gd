extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func box(world: Node3D, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.position = at
	body.add_child(shape)
	world.add_child(body)
	return body
func setup() -> Array:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, Vector3(90, 0.2, 90), Vector3(0, -0.1, 0))
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor._shadow_visual.set_physics_process(false)
	return [world, actor]
func advance(actor: CharacterBody3D, frames: int) -> void:
	for frame in frames:
		actor._physics_process(1.0 / 60.0)
		actor._shadow_visual._physics_process(1.0 / 60.0)
		await physics_frame
func run() -> void:
	# No valid retreat in the old backwards fan: a U-shaped room opens toward
	# the observer. A short wait behind a closed exit must not finish the sprint.
	var fixture := setup()
	var world: Node3D = fixture[0]
	var actor: CharacterBody3D = fixture[1]
	box(world, Vector3(4.4, 4, 0.3), Vector3(0, 2, -1.5))
	box(world, Vector3(0.3, 4, 6), Vector3(-2, 2, 1.35))
	box(world, Vector3(0.3, 4, 6), Vector3(2, 2, 1.35))
	var exit_wall := box(world, Vector3(4.4, 4, 0.3), Vector3(0, 2, 4.2))
	await physics_frame
	await physics_frame
	actor._door_traversal_active = true
	actor.stalking._begin_sprint(Vector3(0, 1.7, 3.4))
	check(not actor._door_traversal_active, "Previous door route steals the sprint launch")
	await advance(actor, 240)
	check(actor.stalking.sprint_remaining > 0.0, "Blocked escape expires without reaching a distant destination")
	check(absf(actor.position.x) < 1.85 and actor.position.z > -1.35 and actor.position.z < 4.05, "Sprint passes through a closed wall")
	exit_wall.free()
	await physics_frame
	await physics_frame
	await advance(actor, 150)
	check(actor.position.z > 12.0, "Fails to leave a dead end through the available forward exit")
	print("BLACK ENTE DEAD END: ", actor.position)
	world.queue_free()
	await process_frame
	await physics_frame
	fixture = setup()
	world = fixture[0]
	actor = fixture[1]
	# Authored connected L-shaped navigation, with the direct ray blocked.
	var region := NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	nav.vertices = PackedVector3Array([Vector3(-2,0,-1), Vector3(-2,0,1), Vector3(6,0,1), Vector3(6,0,-1), Vector3(8,0,1), Vector3(8,0,-1), Vector3(6,0,-26), Vector3(8,0,-26)])
	nav.add_polygon(PackedInt32Array([0,1,2,3]))
	nav.add_polygon(PackedInt32Array([3,2,4,5]))
	nav.add_polygon(PackedInt32Array([6,3,5,7]))
	region.navigation_mesh = nav
	world.add_child(region)
	box(world, Vector3(9, 4, 0.3), Vector3(0, 2, -2))
	for frame in 6: await physics_frame
	actor.stalking._begin_sprint(Vector3(0, 1.7, 3.4))
	actor.stalking.decide(1.0 / 60.0, true)
	check(actor._navigation_available and actor.stalking._sprint_path.size() >= 3, "Escape does not find a route around the corner")
	var chosen: Vector3 = actor.stalking.goal
	check(chosen.z < -15.0, "Navigation escape does not select the distant corridor")
	# Perception can overwrite the shared navigation agent while sprinting.
	actor.navigation_agent.target_position = Vector3(0, 0, 3.4)
	await advance(actor, 150)
	check(actor.position.x > 4.5 and actor.position.z < -12.0, "Escape loses its path or sticks at the corner")
	print("BLACK ENTE CORNER: ", actor.position, " destination=", chosen)
	world.queue_free()
	await process_frame
	await physics_frame
	fixture = setup()
	world = fixture[0]
	actor = fixture[1]
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.7, 3.4)
	camera.look_at(Vector3(0, 1.9, 0))
	camera.make_current()
	await physics_frame
	await physics_frame
	actor.stalking.update_stare(3.75)
	camera.position.z = 12.0
	camera.look_at(Vector3(20, 1.9, 0))
	for frame in 15: actor.stalking.update_stare(1.0 / 60.0)
	check(actor.stalking.sprint_count == 1 and actor.stalking.sprint_remaining > 0.0, "Completed mouth animation cancels instead of launching when gaze shifts")
	await advance(actor, 30)
	check(Vector2(actor.velocity.x, actor.velocity.z).length() > 14.9, "Completed transformation fails to launch at full sprint speed")
	world.queue_free()
	await process_frame
	print("BLACK ENTE ESCAPE ROUTES: checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
