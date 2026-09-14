extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func box(world: Node, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = position
	world.add_child(body)
	return body

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, Vector3(0, -0.1, 0), Vector3(60, 0.2, 60))
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node3D = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var stalk: RefCounted = actor.stalking
	await physics_frame
	await physics_frame
	check(actor.dark_sight_distance > actor.stalking_distance + 3.0, "Cannot observe from stalking distance")
	check(not actor.can_ceiling_pounce() and not actor.can_begin_attack(), "Stalker retained ambush attacks")
	for fps in [30, 60, 120]:
		actor.position = Vector3.ZERO
		actor.rotation = Vector3.ZERO
		actor._evidence_position = Vector3(0, 0, 2)
		actor._evidence_age = 0.0
		stalk.retreat_remaining = 0.0
		stalk.decide(1.0 / fps, true)
		check(stalk.mode == stalk.Mode.RETREAT, "Close player does not trigger retreat")
		check(stalk.goal.distance_to(actor._evidence_position) > 4.0, "Retreat goal approaches player")
		actor._evidence_position = Vector3(0, 0, 8)
		stalk.retreat_remaining = 0.0
		stalk.decide(1.0 / fps, true)
		check(stalk.mode == stalk.Mode.RETREAT, "Being watched does not trigger withdrawal")
		actor._evidence_position = Vector3(0, 0, 12)
		actor._offscreen_seconds = 1.0
		stalk.retreat_remaining = 0.0
		stalk.decide(1.0 / fps, false)
		check(stalk.mode == stalk.Mode.STALK, "Offscreen stalk did not start")
		check(is_equal_approx(stalk.goal.distance_to(actor._evidence_position), actor.stalking_distance), "Stalking target invades personal space")
		stalk.decide(1.0 / fps, true)
		check(stalk.mode == stalk.Mode.WATCH, "Distant watcher continues approaching on camera")
		actor._evidence_age = 50.0
		stalk.decide(1.0 / fps, false)
		check(stalk.mode == stalk.Mode.WATCH, "Follows prey with expired memory")
		actor.upright_amount = 1.0
		visual._reset_contacts()
		for frame in fps:
			actor.position.z += 0.5 / fps
			visual._physics_process(1.0 / fps)
			check(visual.contacts[0].y > 0.65 and visual.contacts[1].y > 0.65, "Hands still walk on floor")
		check(visual._head.global_position.y > 1.9, "Head is not humanoid height")
		var landmarks: Array[Vector3] = visual._body_landmarks(0.0, 0.0)
		check((landmarks[1] - landmarks[0]).normalized().dot(Vector3.UP) > 0.9, "Torso remains horizontal")
	actor.position = Vector3.ZERO
	var ceiling := box(world, Vector3(0, 2.0, 0), Vector3(4, 0.2, 4))
	await physics_frame
	await physics_frame
	for frame in 30:
		actor._update_upright_stance(1.0 / 60.0)
	check(actor.humanoid_crouch == 1.0 and actor.upright_amount == 1.0 and not actor._stance_collision.disabled, "Low ceiling must bend knees without becoming quadrupedal")
	visual._physics_process(0.1)
	check(visual.contacts[0].y > 0.45 and visual.contacts[1].y > 0.45, "Humanoid crouch plants hands on floor")
	ceiling.queue_free()
	await physics_frame
	await physics_frame
	for frame in 30:
		actor._update_upright_stance(1.0 / 60.0)
	check(actor.humanoid_crouch == 0.0 and actor.upright_amount == 1.0 and not actor._stance_collision.disabled, "Does not stand back up")
	check(not actor.can_climb and not actor.spider_jump_enabled, "Humanoid-only stance still allows climbing or spider jumps")
	world.queue_free()
	await process_frame
	print("SHADOW STALKING: checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
