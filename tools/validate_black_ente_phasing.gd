extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func box(world: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	body.position = at
	world.add_child(body)
func make_player(world: Node3D) -> CharacterBody3D:
	var player := CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = CapsuleShape3D.new()
	collider.shape.radius = 0.3
	collider.shape.height = 1.8
	collider.position.y = 0.9
	player.add_child(collider)
	player.add_to_group(&"player")
	world.add_child(player)
	return player
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, Vector3(40, 0.2, 40), Vector3(0, -0.1, 0))
	box(world, Vector3(0.3, 4, 20), Vector3(3, 2, 0))
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor._shadow_visual.set_physics_process(false)
	# Player created after the enemy: late spawn must also be handled.
	var player := make_player(world)
	actor._sync_player_phasing()
	actor._player = player
	await physics_frame
	await physics_frame
	check(actor.get_collision_exceptions().has(player) and player.get_collision_exceptions().has(actor), "Missing reciprocal player/Black Ente collision exception")
	check(actor.surface.ensure_body_clear(), "Safety recovery treats the overlapping player as a solid obstacle")
	actor._update_upright_stance(0.2)
	check(actor.humanoid_crouch == 0.0, "Overlapping player forces the entity to crouch")
	player.position.x = -2.0
	for frame in 120:
		player.velocity = Vector3(3.0, -0.5, 0)
		player.move_and_slide()
		await physics_frame
	check(player.position.x > 2.0, "Player cannot walk through stationary Black Ente")
	check(player.position.x < 2.6, "Phasing disables the player's wall collision")
	player.position = Vector3.ZERO
	actor.position = Vector3(-2, 0.01, 0)
	actor.stalking._begin_sprint(Vector3(-4, 1.7, 0))
	actor.stalking.goal = Vector3(5, 0, 0)
	actor.stalking._sprint_path = PackedVector3Array([actor.position, actor.stalking.goal])
	actor.stalking._sprint_path_index = 1
	var peak := 0.0
	for frame in 30:
		actor._update_upright_stance(1.0 / 60.0)
		actor.surface.ensure_body_clear()
		actor._apply_gravity(1.0 / 60.0)
		actor.stalking._move(1.0 / 60.0)
		actor.move_and_slide()
		peak = maxf(peak, Vector2(actor.velocity.x, actor.velocity.z).length())
		await physics_frame
	check(actor.position.x > 1.0 and peak > 14.9, "Entity cannot sprint through the solid player capsule")
	check(player.position.is_equal_approx(Vector3.ZERO), "Sprinting entity pushes the player")
	check(actor.position.x < 2.8 and absf(actor.position.y) < 0.05, "Entity loses wall or floor collision")
	var old_player := player
	old_player.remove_from_group(&"player")
	player = make_player(world)
	actor._sync_player_phasing()
	check(not old_player.get_collision_exceptions().has(actor) and player.get_collision_exceptions().has(actor), "Player replacement leaves stale collision exceptions")
	print("BLACK ENTE PHASING: checks=%d failures=%d" % [checks, failures])
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
