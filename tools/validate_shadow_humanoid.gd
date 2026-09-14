extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_ := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(40, 0.2, 40)
	collider.position.y = -0.1
	floor_.add_child(collider)
	world.add_child(floor_)
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node3D = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var player := CharacterBody3D.new()
	world.add_child(player)
	actor._player = player
	actor._prey = player
	var original: CharacterBody3D = load("res://enemies/grandmother_crawler.tscn").instantiate()
	original.position = Vector3(15, 0, 0)
	world.add_child(original)
	original.set_physics_process(false)
	var old_visual: Node3D = original.get_node("EditableVisual")
	old_visual.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(original.can_climb and original.spider_jump_enabled, "Original crawler lost climbing")
	check(not actor.can_climb and not actor.spider_jump_enabled and not actor.obstacle_jump_enabled, "Humanoid can still become a spider")
	check(visual.torso.get_aabb().size.x < old_visual.torso.get_aabb().size.x * 0.65, "Torso was not substantially narrowed")
	check(visual.legs[0].widths[2].x < old_visual.legs[0].widths[2].x * 0.6, "Legs remain too thick")
	check(visual._continuous_arms[0].thickness_scale < old_visual._continuous_arms[0].thickness_scale * 0.6, "Arms remain too thick")
	check(visual.shadow_coat.eyes.size() == 2 and visual.shadow_coat.eyes[0].mesh.radius > 0.2, "Larger white eyes are missing")
	check(actor.find_children("*", "Light3D", true, false).is_empty(), "Eyes introduced extra lights")
	for target in [Vector3(0, 0, 5), Vector3(5, 0, 0), Vector3(0, 0, -5)]:
		player.position = target
		for frame in 60:
			actor._update_fixed_gaze(1.0 / 60.0)
			actor.face_shadow_attention(Vector3.FORWARD, 1.0 / 60.0, 8.0)
			visual._physics_process(1.0 / 60.0)
		var eyes: Array = visual.shadow_coat.eyes
		var center: Vector3 = (eyes[0].global_position + eyes[1].global_position) * 0.5
		var to_player: Vector3 = (target + Vector3.UP * 1.5 - center).normalized()
		check(actor.gaze_has_sight and visual._head.global_basis.z.normalized().dot(to_player) > 0.98, "Head fails to stare at visible player")
		check(visual.contacts[0].y > 0.65 and visual.contacts[1].y > 0.65, "Hands became ground supports")
		var neck_end: Vector3 = visual.anatomy.to_global(visual.collar.points[-1])
		check(neck_end.distance_to(visual._head.to_global(Vector3(0, 0.15, 0.08))) < 0.001, "Turning head disconnected its neck")
	# Back away while keeping the body and face toward the actual observation.
	actor.position = Vector3.ZERO
	player.position = Vector3(0, 0, 3)
	actor.rotation = Vector3.ZERO
	for frame in 45:
		actor._physics_process(1.0 / 60.0)
		visual._physics_process(1.0 / 60.0)
		await physics_frame
	print("HUMANOID RETREAT: position=", actor.position, " mode=", actor.stalking.mode, " goal=", actor.stalking.goal, " evidence=", actor._evidence_position, " age=", actor._evidence_age, " sight=", actor._sight_confirmed)
	check(actor.position.z < -0.5, "Staring prevents retreat")
	check(actor.global_basis.z.dot((player.position - actor.position).normalized()) > 0.95, "Retreat turns its back on the player")
	check(actor.surface.phase == actor.surface.Phase.GROUND and actor.upright_amount == 1.0, "Retreat changed humanoid stance")
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	wall_shape.shape = BoxShape3D.new()
	wall_shape.shape.size = Vector3(8, 4, 0.3)
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 2, 1.5)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	var last_seen: Vector3 = actor._fixed_gaze_position
	player.position.x = 1.5
	actor._update_fixed_gaze(0.12)
	check(not actor.gaze_has_sight and actor._fixed_gaze_position == last_seen, "Gaze tracks a hidden player through walls")
	world.queue_free()
	await process_frame
	print("SHADOW HUMANOID: checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
